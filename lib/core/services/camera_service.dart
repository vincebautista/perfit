import 'package:camera/camera.dart';

class CameraService {
  CameraController? controller;

  Future<void> initCamera() async {
    final cameras = await availableCameras();
    final frontCamera = cameras.firstWhere(
      (cam) => cam.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    controller = CameraController(
      frontCamera,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    await controller!.initialize();
  }

  void startStream(Function(CameraImage image) onFrame) {
    controller!.startImageStream(onFrame);
  }

  void dispose() {
    controller?.dispose();
  }
}
