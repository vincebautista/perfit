import 'dart:math' as math;
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:perfit/core/services/camera_service.dart';
import 'package:perfit/core/services/distance_service.dart';
import 'package:perfit/core/services/gesture_service.dart';
import 'package:perfit/core/services/pose_detection_service.dart';
import 'package:perfit/core/services/setting_service.dart';
import 'package:perfit/screens/exercise_summary_screen.dart';

class KneeExtensionSeatedPartialScreen extends StatefulWidget {
  const KneeExtensionSeatedPartialScreen({super.key});

  @override
  State<KneeExtensionSeatedPartialScreen> createState() =>
      _KneeExtensionSeatedPartialScreenState();
}

enum ExerciseStage { distanceCheck, gestureDetection, formCorrection }

class _KneeExtensionSeatedPartialScreenState
    extends State<KneeExtensionSeatedPartialScreen> {
  // Services
  final CameraService _cameraService = CameraService();
  final PoseDetectionService _poseService = PoseDetectionService();
  final DistanceService _distanceService = DistanceService();
  final GestureService _gestureService = GestureService();

  // Camera and stream state
  bool _isInitialized = false;
  bool _isBusy = false;
  Pose? _lastPose;
  Size? _cameraImageSize;

  double _currentKneeAngle = 0.0;
  double _maxKneeAngleDuringRep = 0.0;

  // Exercise stage
  ExerciseStage currentStage = ExerciseStage.distanceCheck;

  // Distance and gesture messages
  String distanceStatus = "Checking distance...";
  String handsStatus = "Raise your right hand above the head";
  String countdownStatus = "";
  int countdown = 3;

  // Form correction counters
  int _rightCurlCount = 0; // Number of reps completed
  int _rightCorrectCount = 0; // Number of correct reps
  int _rightWrongCount = 0; // Number of incorrect reps
  List<String> _feedback = []; // Feedback per rep

  // Form detection flags
  bool _rightStartedDown = false; // Leg bent start position detected
  bool _rightReachedUp = false; // Leg extended position detected

  // Knee extension thresholds
  final double _kneeMinBentAngle = 120.0; // Minimum knee angle (foot down)
  final double _kneeMaxExtendAngle = 160.0; // Maximum knee angle (leg extended)

  @override
  void initState() {
    super.initState();
    _initCamera();
    _loadCountdown();
  }

  Future<void> _loadCountdown() async {
    final countdownData = await SettingService().loadCountdown();
    countdown = countdownData["countdown"] ?? 3;
  }

  Future<void> _initCamera() async {
    await _cameraService.initCamera();
    _cameraService.startStream(_processCameraImage);
    setState(() => _isInitialized = true);
  }

  @override
  void dispose() {
    _cameraService.dispose();
    super.dispose();
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (_isBusy) return;
    _isBusy = true;

    _cameraImageSize ??= Size(image.width.toDouble(), image.height.toDouble());

    try {
      final inputImage = _cameraImageToInputImage(
        image,
        _cameraService.controller!.description.sensorOrientation,
      );

      final poses = await _poseService.detectPoses(inputImage);
      if (poses.isEmpty) return;

      final pose = poses.first;
      _lastPose = pose;

      switch (currentStage) {
        case ExerciseStage.distanceCheck:
          _handleDistanceCheck(pose);
          break;
        case ExerciseStage.gestureDetection:
          _handleGestureDetection(pose);
          break;
        case ExerciseStage.formCorrection:
          await _handleFormCorrection(pose);
          break;
      }
    } finally {
      _isBusy = false;
      if (mounted) setState(() {});
    }
  }

  InputImage _cameraImageToInputImage(CameraImage image, int rotation) {
    final width = image.width;
    final height = image.height;
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

  void _handleDistanceCheck(Pose pose) {
    final distanceCm = _distanceService.computeSmoothedDistance(pose);
    const minCm = 100;
    const maxCm = 150;

    if (distanceCm < minCm) {
      distanceStatus = "❌ Too Close! Move back";
    } else if (distanceCm > maxCm) {
      distanceStatus = "❌ Too Far! Move closer";
    } else {
      distanceStatus = "✅ Perfect Distance! Stay in that position.";
      currentStage = ExerciseStage.gestureDetection;
      handsStatus = "Raise your right hand above the head";
    }
  }

  void _handleGestureDetection(Pose pose) {
    final handsUp = _gestureService.update(
      pose,
      startCountdown: countdown,
      onHoldProgress:
          (progress) =>
              countdownStatus =
                  "✋ Raise your hand for 1 second… ${(progress * 100).toInt()}%",
      onHandsUpDetected: () {
        handsStatus = "✅ Hands detected! Starting countdown...";
        countdownStatus = "";
      },
      onCountdownTick: (seconds) => countdownStatus = "⏱ $seconds s remaining",
      onCountdownComplete: () {
        countdownStatus = "✅ Timer complete!";
        currentStage = ExerciseStage.formCorrection;
      },
    );

    if (!handsUp && !_gestureService.countdownRunning) {
      handsStatus = "❌ Raise your hand!";
      countdownStatus = "";
    }
  }

  Future<void> _handleFormCorrection(Pose pose) async {
    final landmarks = pose.landmarks;

    final rightHip = landmarks[PoseLandmarkType.rightHip];
    final rightKnee = landmarks[PoseLandmarkType.rightKnee];
    final rightAnkle = landmarks[PoseLandmarkType.rightAnkle];

    if (rightHip != null && rightKnee != null && rightAnkle != null) {
      final h = Offset(rightHip.x, rightHip.y);
      final k = Offset(rightKnee.x, rightKnee.y);
      final a = Offset(rightAnkle.x, rightAnkle.y);

      final double kneeAngle = _calculateAngle(h, k, a);
      _currentKneeAngle = kneeAngle;

      // Detect start of rep: leg bent
      if (!_rightStartedDown && kneeAngle <= _kneeMinBentAngle) {
        _rightStartedDown = true;
        _maxKneeAngleDuringRep = kneeAngle; // reset max for this rep
      }

      // If rep started, track max knee angle
      if (_rightStartedDown) {
        _maxKneeAngleDuringRep = math.max(_maxKneeAngleDuringRep, kneeAngle);

        // Complete rep: leg returns to bent position
        if (kneeAngle <= _kneeMinBentAngle &&
            _maxKneeAngleDuringRep > _kneeMinBentAngle) {
          _rightCurlCount++;

          String correction = "";
          bool isCorrect = true;

          // Evaluate rep based on max angle
          if (_maxKneeAngleDuringRep < 140.0 &&
              _maxKneeAngleDuringRep >= 110.0) {
            correction = "Not enough extension";
            isCorrect = false;
          } else if (_maxKneeAngleDuringRep > 160.0) {
            correction = "Extended too much";
            isCorrect = false;
          }

          _feedback.add(
            "Rep $_rightCurlCount: Max Knee Angle = ${_maxKneeAngleDuringRep.toStringAsFixed(1)}°" +
                (correction.isEmpty ? "" : " | $correction"),
          );

          if (isCorrect)
            _rightCorrectCount++;
          else
            _rightWrongCount++;

          // Reset flags for next rep
          _rightStartedDown = false;
          _rightReachedUp = false;
          _maxKneeAngleDuringRep = 0.0;

          // Stop after 5 reps
          if (_rightCurlCount >= 5) {
            print(_feedback);
            await _cameraService.controller?.stopImageStream();
            if (!mounted) return;
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder:
                    (_) => ExerciseSummaryScreen(
                      correct: _rightCorrectCount,
                      wrong: _rightWrongCount,
                      feedback: _feedback,
                    ),
              ),
            );
          }
        }
      }
    }
  }

  double _distance(Offset a, Offset b) =>
      math.sqrt(math.pow(a.dx - b.dx, 2) + math.pow(a.dy - b.dy, 2));

  double _calculateAngle(Offset a, Offset b, Offset c) {
    final ab = Offset(a.dx - b.dx, a.dy - b.dy);
    final cb = Offset(c.dx - b.dx, c.dy - b.dy);
    final dot = ab.dx * cb.dx + ab.dy * cb.dy;
    final magAB = math.sqrt(ab.dx * ab.dx + ab.dy * ab.dy);
    final magCB = math.sqrt(cb.dx * cb.dx + cb.dy * cb.dy);
    final cosine = dot / (magAB * magCB);
    return math.acos(cosine.clamp(-1.0, 1.0)) * 180 / math.pi;
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized || _cameraService.controller == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    String displayMessage = "";
    switch (currentStage) {
      case ExerciseStage.distanceCheck:
        displayMessage = distanceStatus;
        break;
      case ExerciseStage.gestureDetection:
        displayMessage =
            countdownStatus.isNotEmpty ? countdownStatus : handsStatus;
        break;
      case ExerciseStage.formCorrection:
        break;
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Test Exercise")),
      body: Stack(
        children: [
          CameraPreview(_cameraService.controller!),

          // Overlay messages
          if (currentStage != ExerciseStage.formCorrection)
            Positioned(
              bottom: 150,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    displayMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),

          if (currentStage == ExerciseStage.formCorrection)
            Positioned(
              top: 100,
              left: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "Knee Angle: ${_currentKneeAngle.toStringAsFixed(1)}°",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

          // Overlay rep counter
          if (currentStage == ExerciseStage.formCorrection)
            Positioned(
              top: 20,
              left: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "Reps: $_rightCurlCount\n✅ $_rightCorrectCount | ❌ $_rightWrongCount",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
