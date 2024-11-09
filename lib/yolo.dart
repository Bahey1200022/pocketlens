import 'package:flutter/foundation.dart';
import 'package:pocketlens/labels.dart';
import 'package:pocketlens/nms.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart';

class YoloModel {
  final String modelPath;
  final int inWidth;
  final int inHeight;
  final int numClasses;
  Interpreter? _interpreter;

  YoloModel(
    this.modelPath,
    this.inWidth,
    this.inHeight,
    this.numClasses,
  );

  Future<void> init() async {
    _interpreter = await Interpreter.fromAsset(modelPath);
  }

  List<List<double>> infer(Image image) {
    assert(_interpreter != null, 'The model must be initialized');

    final imgResized = copyResize(image, width: inWidth, height: inHeight);
    final imgNormalized = List.generate(
      inHeight,
      (y) => List.generate(
        inWidth,
        (x) {
          final pixel = imgResized.getPixel(x, y);
          return [pixel.rNormalized, pixel.gNormalized, pixel.bNormalized];
        },
      ),
    );

    // output shape:
    // 1 : batch size
    // 4 + 80: left, top, right, bottom and probabilities for each class
    // 8400: num predictions
    final output = [
      List<List<double>>.filled(4 + numClasses, List<double>.filled(8400, 0))
    ];
    int predictionTimeStart = DateTime.now().millisecondsSinceEpoch;
    _interpreter!.run([imgNormalized], output);

    processOutput(output, numClasses);
    debugPrint(
        'Prediction time: ${DateTime.now().millisecondsSinceEpoch - predictionTimeStart} ms');
    return output[0];
  }

  (List<int>, List<List<double>>, List<double>) postprocess(
    List<List<double>> unfilteredBboxes,
    int imageWidth,
    int imageHeight, {
    double confidenceThreshold = 0.4,
    double iouThreshold = 0.1,
    bool agnostic = false,
  }) {
    List<int> classes;
    List<List<double>> bboxes;
    List<double> scores;
    int nmsTimeStart = DateTime.now().millisecondsSinceEpoch;
    (classes, bboxes, scores) = nms(
      unfilteredBboxes,
      confidenceThreshold: confidenceThreshold,
      iouThreshold: iouThreshold,
      agnostic: agnostic,
    );
    debugPrint(
        'NMS time: ${DateTime.now().millisecondsSinceEpoch - nmsTimeStart} ms');
    for (var bbox in bboxes) {
      bbox[0] *= imageWidth;
      bbox[1] *= imageHeight;
      bbox[2] *= imageWidth;
      bbox[3] *= imageHeight;
    }
    return (classes, bboxes, scores);
  }

  (List<int>, List<List<double>>, List<double>) inferAndPostprocess(
    Image image, {
    double confidenceThreshold = 0.4,
    double iouThreshold = 0.1,
    bool agnostic = false,
  }) =>
      postprocess(
        infer(image),
        image.width,
        image.height,
        confidenceThreshold: confidenceThreshold,
        iouThreshold: iouThreshold,
        agnostic: agnostic,
      );

  void processOutput(List<List<List<double>>> output, int numClasses,
      {double threshold = 0.005}) {
    final predictions = output[0];
    final int numPredictions = predictions[0].length;

    Map<int, double> classProbabilities = {};

    for (int i = 0; i < numPredictions; i++) {
      final boundingBox = [
        predictions[0][i], // left
        predictions[1][i], // top
        predictions[2][i], // right
        predictions[3][i], // bottom
      ];

      // Extract class probabilities
      final classProbabilitiesList =
          predictions.sublist(4, 4 + numClasses).map((e) => e[i]).toList();

      // Find the class with the highest probability
      final maxProbability =
          classProbabilitiesList.reduce((a, b) => a > b ? a : b);
      final classIndex = classProbabilitiesList.indexOf(maxProbability);

      // Filter out low probability predictions
      if (maxProbability > threshold) {
        // Print the bounding box and the class label
        final classLabel = money[classIndex] ?? "Unknown";

        print(
            'BoundingBox: $boundingBox, Class: $classLabel, Probability: $maxProbability');

        // Update the cumulative probability for the class
        if (classProbabilities.containsKey(classIndex)) {
          classProbabilities[classIndex] =
              classProbabilities[classIndex]! + maxProbability;
        } else {
          classProbabilities[classIndex] = maxProbability;
        }
      }
    }

    // Determine the dominant class
    if (classProbabilities.isNotEmpty) {
      final dominantClassIndex = classProbabilities.entries
          .reduce((a, b) => a.value > b.value ? a : b)
          .key;
      final dominantClassLabel = money[dominantClassIndex] ?? "Unknown";
      print('Dominant Class: $dominantClassLabel');
    }
  }
}
