// ignore: file_names
// ignore_for_file: avoid_print, sized_box_for_whitespace

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:tflite_v2/tflite_v2.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class HomeScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const HomeScreen({super.key, required this.cameras});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  CameraController? controller;
  bool isCameraInitialized = false;
  String result = "";
  late Interpreter _interpreter;

  void initCamera() {
    controller = CameraController(widget.cameras[0], ResolutionPreset.medium);
    controller?.initialize().then((_) {
      if (!mounted) {
        return;
      }
      setState(() {
        isCameraInitialized = true;
      });
    });
  }

  void loadModel() async {
    // try {
    //   await Tflite.loadModel(
    //     model: "assets/best_float32.tflite",
    //     labels: "assets/labels.txt",
    //   );
    // } catch (e) {
    //   print("Failed to load model: $e");
    // }
    _interpreter = await Interpreter.fromAsset('assets/best_float32.tflite');
  }

  int getRed(int color) {
    return (color >> 16) & 0xFF;
  }

  int getGreen(int color) {
    return (color >> 8) & 0xFF;
  }

  int getBlue(int color) {
    return color & 0xFF;
  }

  Future<Uint8List?> takePhoto() async {
    if (!controller!.value.isInitialized) {
      print('Error: select a camera first.');
      return null;
    }

    if (controller!.value.isTakingPicture) {
      // A capture is already pending, do nothing.
      return null;
    }

    try {
      XFile file = await controller!.takePicture();
      Uint8List bytes = await file.readAsBytes();
      return bytes;
    } catch (e) {
      print('Error: $e');
      return null;
    }
  }

  void runModel(Uint8List imageBytes) async {
    // Decode the image bytes and resize to model input size
    final image = img.decodeImage(imageBytes);
    final resizedImage = img.copyResize(image!,
        width: 224, height: 224); // adjust to model's input size

    // Convert the image to a float32 input tensor
    final input = Float32List(
        224 * 224 * 3); // assuming model expects 224x224x3 RGB image
    for (int y = 0; y < 224; y++) {
      for (int x = 0; x < 224; x++) {
        final pixel =
            resizedImage.getPixel(x, y) as int; // no need to cast to int
        input[(y * 224 + x) * 3 + 0] =
            getRed(pixel) / 255.0; // normalize to [0, 1]
        input[(y * 224 + x) * 3 + 1] = getGreen(pixel) / 255.0;
        input[(y * 224 + x) * 3 + 2] = getBlue(pixel) / 255.0;
      }
    }

    // Prepare input and output buffers for TFLite interpreter
    final inputBuffer = input.buffer.asUint8List();
    final outputBuffer = List.generate(1 * 1001, (index) => 0.0)
        .reshape([1, 1001]); // adjust output shape

    // Run inference
    _interpreter.run(inputBuffer, outputBuffer);

    // Find the predicted label with highest confidence
    final maxIndex = outputBuffer[0]
        .indexOf(outputBuffer[0].reduce((a, b) => a > b ? a : b));
    setState(() {
      result =
          "Prediction: $maxIndex, Confidence: ${outputBuffer[0][maxIndex]}";
    });

    print("Inference result: $result");
  }

  @override
  void initState() {
    super.initState();
    loadModel();
    initCamera();
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Pocketlens"),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            isCameraInitialized
                ? AspectRatio(
                    aspectRatio: controller!.value.aspectRatio,
                    child: CameraPreview(controller!),
                  )
                : Container(
                    width: 100,
                    height: 100,
                    child: const Icon(Icons.camera_alt),
                  ),
            const SizedBox(height: 20),
            FloatingActionButton(
              onPressed: () async {
                Uint8List? image = await takePhoto();

                print("image: $image");
                if (image != null) {
                  /// run model ????
                  runModel(image);
                }
              },
              child: const Icon(Icons.camera_alt),
            ),
          ],
        ),
      ),
    );
  }
}
