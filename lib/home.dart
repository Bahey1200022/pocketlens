// ignore: file_names
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:tflite_v2/tflite_v2.dart';

class HomeScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const HomeScreen({super.key, required this.cameras});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  CameraController? controller;
  bool isCameraInitialized = false;

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
    try {
      await Tflite.loadModel(
        model: "assets/best_float32.tflite",
        labels: "assets/labels.txt",
      );
    } catch (e) {
      print("Failed to load model: $e");
    }
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
                  List? recognitions = await Tflite.runModelOnBinary(
                    binary: image,
                    numResults: 6,
                    threshold: 0.05,
                    asynch: true,
                  );
                  print(recognitions);
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
