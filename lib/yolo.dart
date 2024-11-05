import 'package:flutter/foundation.dart';
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

    print(output[0].length);
    debugPrint(
        'Prediction time: ${DateTime.now().millisecondsSinceEpoch - predictionTimeStart} ms');
    return output[0];
  }
}
