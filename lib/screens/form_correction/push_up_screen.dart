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

class PushUpScreen extends StatefulWidget {
  const PushUpScreen({super.key});

  @override
  State<PushUpScreen> createState() => _PushUpScreenState();
}

enum ExerciseStage { distanceCheck, gestureDetection, formCorrection }

class _PushUpScreenState extends State<PushUpScreen> {
  final CameraService _cameraService = CameraService();
  final PoseDetectionService _poseService = PoseDetectionService();
  final DistanceService _distanceService = DistanceService();
  final GestureService _gestureService = GestureService();

  bool _isInitialized = false;
  bool _isBusy = false;

  ExerciseStage currentStage = ExerciseStage.distanceCheck;

  String distanceStatus = "Checking distance...";
  String handsStatus = "Raise your right hand above the head";
  String countdownStatus = "";
  int countdown = 3;

  // Form correction variables
  int _rightCurlCount = 0;
  int _rightCorrectCount = 0;
  int _rightWrongCount = 0;
  List<String> _feedback = [];

  bool _rightStartedDown = false;
  bool _rightReachedUp = false;
  double _rightMinElbowAngleDuringRep = 180.0;
  double _rightMaxShoulderAngleDuringRep = 0.0;

  // Thresholds
  final double _maxAllowedShoulderMovement = 60.0;
  final double _downThreshold = 165.0;
  final double _upThreshold = 50.0;
  final double _shoulderBySideThreshold = 45.0;
  final double _wristToShoulderTopRatio = 0.45;

  Pose? _lastPose;
  Size? _cameraImageSize;

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
      if (mounted) setState(() {}); // Only one UI update per frame
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

    final rightShoulder = landmarks[PoseLandmarkType.rightShoulder];
    final rightElbow = landmarks[PoseLandmarkType.rightElbow];
    final rightWrist = landmarks[PoseLandmarkType.rightWrist];
    final rightHip = landmarks[PoseLandmarkType.rightHip];

    if (rightShoulder != null && rightElbow != null && rightWrist != null) {
      final s = Offset(rightShoulder.x, rightShoulder.y);
      final e = Offset(rightElbow.x, rightElbow.y);
      final w = Offset(rightWrist.x, rightWrist.y);

      final double elbowAngle = _calculateAngle(s, e, w);

      final bool canCheckRightShoulder = rightHip != null;
      final double rightShoulderAngle =
          canCheckRightShoulder
              ? _calculateAngle(Offset(rightHip.x, rightHip.y), s, e)
              : 0.0;

      double torsoLenRight =
          rightHip != null ? _distance(s, Offset(rightHip.x, rightHip.y)) : 1.0;

      final double wristShoulderNormRight =
          _distance(w, s) / (torsoLenRight > 0 ? torsoLenRight : 1.0);
      final bool reachedTopByProximityRight =
          wristShoulderNormRight <= _wristToShoulderTopRatio;
      final bool reachedTopByAngleRight = elbowAngle <= _upThreshold;
      final bool isArmUpRight =
          reachedTopByAngleRight && reachedTopByProximityRight;

      final bool upperArmBySideRight =
          !canCheckRightShoulder ||
          (rightShoulderAngle < _shoulderBySideThreshold);
      final bool isArmDownRight =
          (elbowAngle >= _downThreshold) && upperArmBySideRight;

      _rightMinElbowAngleDuringRep = math.min(
        _rightMinElbowAngleDuringRep,
        elbowAngle,
      );
      if (_rightStartedDown && canCheckRightShoulder) {
        _rightMaxShoulderAngleDuringRep = math.max(
          _rightMaxShoulderAngleDuringRep,
          rightShoulderAngle,
        );
      }

      if (!_rightStartedDown && elbowAngle >= _downThreshold)
        _rightStartedDown = true;
      if (_rightStartedDown && !_rightReachedUp && elbowAngle <= 160.0)
        _rightReachedUp = true;

      if (_rightStartedDown && _rightReachedUp && isArmDownRight) {
        _rightCurlCount++;

        bool isCorrect = true;
        String correction = "";

        if (_rightMaxShoulderAngleDuringRep > _maxAllowedShoulderMovement) {
          isCorrect = false;
          correction = "Too much shoulder movement";
        }
        if (_rightMinElbowAngleDuringRep > _upThreshold) {
          isCorrect = false;
          correction = "Under-bending";
        } else if (_rightMinElbowAngleDuringRep < 15) {
          isCorrect = false;
          correction = "Over-bending";
        }

        if (isCorrect) {
          _rightCorrectCount++;
        } else {
          _rightWrongCount++;
          _feedback.add("Rep $_rightCurlCount: $correction");
        }

        // Reset for next rep
        _rightStartedDown = false;
        _rightReachedUp = false;
        _rightMinElbowAngleDuringRep = 180.0;
        _rightMaxShoulderAngleDuringRep = 0.0;

        // Stop after 5 reps
        if (_rightCurlCount >= 5) {
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

class PosePainter extends CustomPainter {
  final Pose pose;
  final Size imageSize;

  PosePainter(this.pose, this.imageSize);

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = Colors.greenAccent
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round;

    // Map from image coordinates to widget coordinates
    double scaleX = size.width / imageSize.width;
    double scaleY = size.height / imageSize.height;

    Offset toOffset(PoseLandmark landmark) {
      return Offset(landmark.x * scaleX, landmark.y * scaleY);
    }

    // List of bones (pairs of landmarks to connect)
    List<List<PoseLandmarkType>> bones = [
      [PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder],
      [PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow],
      [PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist],
      [PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow],
      [PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist],
      [PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip],
      [PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip],
      [PoseLandmarkType.leftHip, PoseLandmarkType.rightHip],
      [PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee],
      [PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle],
      [PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee],
      [PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle],
    ];

    // Draw lines
    for (var bone in bones) {
      final start = pose.landmarks[bone[0]];
      final end = pose.landmarks[bone[1]];
      if (start != null && end != null) {
        canvas.drawLine(toOffset(start), toOffset(end), paint);
      }
    }

    // Draw landmarks as circles
    for (var landmark in pose.landmarks.values) {
      canvas.drawCircle(toOffset(landmark), 6, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
