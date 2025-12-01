import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:perfit/core/services/setting_service.dart';

class ThumbsUpTimerScreen extends StatefulWidget {
  @override
  State<ThumbsUpTimerScreen> createState() => _ThumbsUpTimerScreenState();
}

class _ThumbsUpTimerScreenState extends State<ThumbsUpTimerScreen> {
  CameraController? _cameraController;
  PoseDetector? _poseDetector;
  Timer? _countdownTimer;
  bool _isCounting = false;
  int _secondsLeft = 10;
  bool _isBusy = false;

  DateTime? _handAboveStartTime;
  bool _handCurrentlyAbove = false;

  bool _gestureLocked = false;

  final SettingService _settings = SettingService();

  @override
  void initState() {
    super.initState();
    _poseDetector = PoseDetector(options: PoseDetectorOptions());
    _initCamera();
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    // Select front camera
    final frontCamera = cameras.firstWhere(
      (cam) => cam.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    _cameraController = CameraController(
      frontCamera,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    await _cameraController?.initialize();
    await _cameraController?.startImageStream(_processCameraImage);
    setState(() {});
  }

  void _processCameraImage(CameraImage image) async {
    if (_isBusy) return;
    _isBusy = true;

    try {
      final inputImage = _cameraImageToInputImage(
        image,
        _cameraController!.description.sensorOrientation,
      );

      final poses = await _poseDetector!.processImage(inputImage);

      if (poses.isNotEmpty) {
        final landmarks = poses.first.landmarks;

        final rightWrist = landmarks[PoseLandmarkType.rightWrist];
        final nose = landmarks[PoseLandmarkType.nose];

        if (rightWrist != null && nose != null) {
          _evaluateRightHandAbove(rightWrist, nose);
        } else {
          _resetHandAbove();
        }
      } else {
        _resetHandAbove();
      }
    } catch (e) {
      debugPrint("Error processing pose: $e");
    } finally {
      _isBusy = false;
    }
  }

  void _evaluateRightHandAbove(
    PoseLandmark rightWrist,
    PoseLandmark headPoint,
  ) {
    final isRightHandAbove = rightWrist.y < headPoint.y;

    if (isRightHandAbove) {
      if (!_handCurrentlyAbove) {
        // Just started going above head
        _handCurrentlyAbove = true;
        _handAboveStartTime = DateTime.now();
      } else {
        // Already above — check duration
        final elapsed = DateTime.now().difference(_handAboveStartTime!);
        if (elapsed.inMilliseconds >= 1000) {
          _resetHandAbove();
          _handleGesture(); // Trigger start/stop
        }
      }
    } else {
      _resetHandAbove();
    }
  }

  void _resetHandAbove() {
    _handCurrentlyAbove = false;
    _handAboveStartTime = null;
  }

  void _handleGesture() {
    if (_gestureLocked) return; // prevents repeated triggers from same gesture
    _gestureLocked = true;

    if (_isCounting) {
      _stopCountdown();
    } else {
      _startCountdown();
    }

    // Unlock gesture after a short delay to avoid multiple triggers
    Future.delayed(Duration(seconds: 1), () {
      _gestureLocked = false;
    });
  }

  void _stopCountdown() {
    _countdownTimer?.cancel();
    setState(() {
      _isCounting = false;
    });
  }

  InputImage _cameraImageToInputImage(CameraImage image, int rotation) {
    final int width = image.width;
    final int height = image.height;
    final uvRowStride = image.planes[1].bytesPerRow;
    final uvPixelStride = image.planes[1].bytesPerPixel!;

    final nv21 = Uint8List(width * height * 3 ~/ 2);

    for (int i = 0; i < height; i++) {
      nv21.setRange(
        i * width,
        (i + 1) * width,
        image.planes[0].bytes,
        i * image.planes[0].bytesPerRow,
      );
    }

    int uvIndex = 0;
    for (int i = 0; i < height ~/ 2; i++) {
      for (int j = 0; j < width ~/ 2; j++) {
        final u = image.planes[1].bytes[i * uvRowStride + j * uvPixelStride];
        final v = image.planes[2].bytes[i * uvRowStride + j * uvPixelStride];
        nv21[width * height + uvIndex++] = v;
        nv21[width * height + uvIndex++] = u;
      }
    }

    return InputImage.fromBytes(
      bytes: nv21,
      metadata: InputImageMetadata(
        size: Size(width.toDouble(), height.toDouble()),
        rotation:
            InputImageRotationValue.fromRawValue(rotation) ??
            InputImageRotation.rotation0deg,
        format: InputImageFormat.nv21,
        bytesPerRow: image.planes[0].bytesPerRow,
      ),
    );
  }

  void _startCountdown() async {
    final countdownData = await _settings.loadCountdown();
    final countdownSeconds = countdownData["countdown"] ?? 3;

    setState(() {
      _isCounting = true;
      _secondsLeft = countdownSeconds;
    });

    _countdownTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        if (_secondsLeft > 0) {
          _secondsLeft--;
        } else {
          _stopCountdown();
        }
      });
    });
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _poseDetector?.close();
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: Text("Hands Up Timer")),
      body: Stack(
        children: [
          // FULLSCREEN CAMERA
          Positioned.fill(child: CameraPreview(_cameraController!)),

          // BORDER: green when running, red when stopped
          _buildBorder(),

          // COUNTDOWN TEXT
          Positioned(
            bottom: 60,
            left: 20,
            right: 20,
            child: Center(
              child: Text(
                _isCounting
                    ? 'Countdown: $_secondsLeft s'
                    : 'Place right hand above head ✋⬆️',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      blurRadius: 10,
                      color: Colors.black,
                      offset: Offset(2, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBorder() {
    return Positioned.fill(
      child: IgnorePointer(
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: _isCounting ? Colors.green : Colors.red,
              width: 8,
            ),
          ),
        ),
      ),
    );
  }
}



// import 'dart:typed_data';

// import 'package:camera/camera.dart';
// import 'package:flutter/material.dart';
// import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
// import 'package:perfit/core/services/camera_service.dart';
// import 'package:perfit/core/services/distance_service.dart';
// import 'package:perfit/core/services/gesture_service.dart';
// import 'package:perfit/core/services/pose_detection_service.dart';
// import 'package:perfit/core/services/setting_service.dart';

// class TestExercise extends StatefulWidget {
//   const TestExercise({super.key});

//   @override
//   State<TestExercise> createState() => _TestExerciseState();
// }

// enum ExerciseStage { distanceCheck, gestureDetection, formCorrection }

// class _TestExerciseState extends State<TestExercise> {
//   final CameraService _cameraService = CameraService();
//   final PoseDetectionService _poseService = PoseDetectionService();
//   final DistanceService _distanceService = DistanceService();
//   final GestureService _gestureService = GestureService();

//   bool _isInitialized = false;

//   ExerciseStage currentStage = ExerciseStage.distanceCheck;

//   String distanceStatus = "Checking distance...";

//   String handsStatus = "Raise your right hand above the head";
//   String countdownStatus = "";

//   int countdown = 3;
  

//   @override
//   void initState() {
//     super.initState();
//     _initCamera();
//     _loadCountdown();
//   }

//   Future<void> _loadCountdown() async {
//     final countdownData = await SettingService().loadCountdown();
//     setState(() {
//       countdown = countdownData["countdown"] ?? 3;
//     });
//   }

//   Future<void> _initCamera() async {
//     await _cameraService.initCamera();

//     // Start receiving frames
//     _cameraService.startStream(_processCameraImage);

//     setState(() {
//       _isInitialized = true;
//     });
//   }

//   @override
//   void dispose() {
//     _cameraService.dispose();
//     super.dispose();
//   }

//   Future<void> _processCameraImage(CameraImage image) async {
//     final inputImage = _cameraImageToInputImage(
//       image,
//       _cameraService.controller!.description.sensorOrientation,
//     );

//     final poses = await _poseService.detectPoses(inputImage);
//     if (poses.isEmpty) return;

//     final pose = poses.first;

//     if (currentStage == ExerciseStage.distanceCheck) {
//       _handleDistanceCheck(pose);
//     } else if (currentStage == ExerciseStage.gestureDetection) {
//       _handleGestureDetection(pose);
//     }
//   }

//   InputImage _cameraImageToInputImage(CameraImage image, int rotation) {
//     final int width = image.width;
//     final int height = image.height;
//     final uvRowStride = image.planes[1].bytesPerRow;
//     final uvPixelStride = image.planes[1].bytesPerPixel!;

//     final nv21 = Uint8List(width * height * 3 ~/ 2);

//     for (int i = 0; i < height; i++) {
//       nv21.setRange(
//         i * width,
//         (i + 1) * width,
//         image.planes[0].bytes,
//         i * image.planes[0].bytesPerRow,
//       );
//     }

//     int uvIndex = 0;
//     for (int i = 0; i < height ~/ 2; i++) {
//       for (int j = 0; j < width ~/ 2; j++) {
//         final u = image.planes[1].bytes[i * uvRowStride + j * uvPixelStride];
//         final v = image.planes[2].bytes[i * uvRowStride + j * uvPixelStride];
//         nv21[width * height + uvIndex++] = v;
//         nv21[width * height + uvIndex++] = u;
//       }
//     }

//     return InputImage.fromBytes(
//       bytes: nv21,
//       metadata: InputImageMetadata(
//         size: Size(width.toDouble(), height.toDouble()),
//         rotation:
//             InputImageRotationValue.fromRawValue(rotation) ??
//             InputImageRotation.rotation0deg,
//         format: InputImageFormat.nv21,
//         bytesPerRow: image.planes[0].bytesPerRow,
//       ),
//     );
//   }

//   void _handleDistanceCheck(Pose pose) {
//     final distanceCm = _distanceService.computeSmoothedDistance(pose);
//     const minCm = 100;
//     const maxCm = 150;

//     String newStatus;
//     if (distanceCm < minCm) {
//       newStatus = "❌ Too Close! Move back";
//     } else if (distanceCm > maxCm) {
//       newStatus = "❌ Too Far! Move closer";
//     } else {
//       newStatus = "✅ Perfect Distance! Stay in that position.";
//       currentStage = ExerciseStage.gestureDetection;
//       handsStatus = "Raise your right hand above the head";
//     }

//     if (distanceStatus != newStatus) {
//       setState(() {
//         distanceStatus = newStatus;
//       });
//     }
//   }

//   void _handleGestureDetection(Pose pose) {
//     final handsUp = _gestureService.update(
//       pose,
//       startCountdown: countdown,
//       onHoldProgress: (progress) {
//         setState(() {
//           countdownStatus =
//               "✋ Raise your hand for 1 second… ${(progress * 100).toInt()}%";
//         });
//       },
//       onHandsUpDetected: () {
//         setState(() {
//           handsStatus = "✅ Hands detected! Starting countdown...";
//           countdownStatus = "";
//         });
//       },
//       onCountdownTick: (seconds) {
//         setState(() {
//           countdownStatus = "⏱ $seconds s remaining";
//         });
//       },
//       onCountdownComplete: () {
//         setState(() {
//           countdownStatus = "✅ Timer complete!";
//           currentStage = ExerciseStage.formCorrection;
//         });
//       },
//     );

//     if (!handsUp && !_gestureService.countdownRunning) {
//       setState(() {
//         handsStatus = "❌ Raise your hand!";
//         countdownStatus = "";
//       });
//     }
//   }

//   void handleFormCorrection(Pose pose) {}

//   @override
//   Widget build(BuildContext context) {
//     if (!_isInitialized ||
//         _cameraService.controller == null ||
//         !_cameraService.controller!.value.isInitialized) {
//       return const Scaffold(body: Center(child: CircularProgressIndicator()));
//     }

//     String displayMessage = "";
//     switch (currentStage) {
//       case ExerciseStage.distanceCheck:
//         displayMessage = distanceStatus;
//         break;
//       case ExerciseStage.gestureDetection:
//         displayMessage =
//             countdownStatus.isNotEmpty ? countdownStatus : handsStatus;
//         break;
//       case ExerciseStage.formCorrection:
//         displayMessage =
//             countdownStatus.isNotEmpty
//                 ? countdownStatus
//                 : "✅ Exercise complete!";
//         break;
//     }

//     return Scaffold(
//       appBar: AppBar(title: const Text("Test Exercise")),
//       body: Stack(
//         children: [
//           CameraPreview(_cameraService.controller!),
//           Positioned(
//             bottom: 150,
//             left: 0,
//             right: 0,
//             child: Center(
//               child: Container(
//                 padding: const EdgeInsets.all(16),
//                 decoration: BoxDecoration(
//                   color: Colors.black54,
//                   borderRadius: BorderRadius.circular(12),
//                 ),
//                 child: Text(
//                   displayMessage,
//                   textAlign: TextAlign.center,
//                   style: TextStyle(
//                     color:
//                         currentStage == ExerciseStage.formCorrection
//                             ? Colors.yellowAccent
//                             : Colors.white,
//                     fontSize: 20,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }