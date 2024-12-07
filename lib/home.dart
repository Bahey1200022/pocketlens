// ignore: file_names
// ignore_for_file: avoid_print, sized_box_for_whitespace

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:pocketlens/yolo.dart';
import 'package:image/image.dart' as img;

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
  final YoloModel model = YoloModel(
    'assets/best_15e_float32.tflite',
    640,
    640,
    12,
  );
  File? imageFile;
  List<List<double>>? inferenceOutput;
  List<int> classes = [];
  List<List<double>> bboxes = [];
  List<double> scores = [];
  int? imageWidth;
  int? imageHeight;

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

  Future<XFile?> takePhoto() async {
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
      return file;
    } catch (e) {
      print('Error: $e');
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    initCamera();
    model.init();
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
            Column(
              children: [
                Container(
                  width: 200,
                  height: 200,
                  child: FloatingActionButton(
                    onPressed: () async {
                      XFile? imageFile = await takePhoto();

                      if (imageFile != null) {
                        /// run model ????
                        Uint8List imageBytes = await imageFile.readAsBytes();
                        final image = img.decodeImage(imageBytes)!;
                        imageWidth = image.width;
                        imageHeight = image.height;
                        inferenceOutput = model.infer(image);
                      }
                    },
                    child: const Icon(Icons.camera_alt),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
