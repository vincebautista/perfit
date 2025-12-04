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
import 'package:perfit/widgets/walk_animation.dart';

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

    final leftShoulder = landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = landmarks[PoseLandmarkType.rightShoulder];
    final leftElbow = landmarks[PoseLandmarkType.leftElbow];
    final rightElbow = landmarks[PoseLandmarkType.rightElbow];
    final leftWrist = landmarks[PoseLandmarkType.leftWrist];
    final rightWrist = landmarks[PoseLandmarkType.rightWrist];
    final leftHip = landmarks[PoseLandmarkType.leftHip];
    final rightHip = landmarks[PoseLandmarkType.rightHip];
    final leftKnee = landmarks[PoseLandmarkType.leftKnee];
    final rightKnee = landmarks[PoseLandmarkType.rightKnee];
    final leftAnkle = landmarks[PoseLandmarkType.leftAnkle];
    final rightAnkle = landmarks[PoseLandmarkType.rightAnkle];

    if (leftShoulder == null ||
        rightShoulder == null ||
        leftElbow == null ||
        rightElbow == null ||
        leftWrist == null ||
        rightWrist == null ||
        leftHip == null ||
        rightHip == null ||
        leftKnee == null ||
        rightKnee == null ||
        leftAnkle == null ||
        rightAnkle == null) {
      // Keep existing feedback mechanism list-based; this function only counts reps.
      _feedback.add("Rep helper: make sure your whole body is visible.");
      return;
    }

    // Core angle set.
    double kneeAngleLeft = _calculateAngle(
      Offset(leftHip.x, leftHip.y),
      Offset(leftKnee.x, leftKnee.y),
      Offset(leftAnkle.x, leftAnkle.y),
    );
    double kneeAngleRight = _calculateAngle(
      Offset(rightHip.x, rightHip.y),
      Offset(rightKnee.x, rightKnee.y),
      Offset(rightAnkle.x, rightAnkle.y),
    );

    double hipAngleLeft = _calculateAngle(
      Offset(leftShoulder.x, leftShoulder.y),
      Offset(leftHip.x, leftHip.y),
      Offset(leftKnee.x, leftKnee.y),
    );
    double hipAngleRight = _calculateAngle(
      Offset(rightShoulder.x, rightShoulder.y),
      Offset(rightHip.x, rightHip.y),
      Offset(rightKnee.x, rightKnee.y),
    );
    double hipAngle = (hipAngleLeft + hipAngleRight) / 2;

    // Torso: shoulders–hips vs horizontal.
    final midShoulder = Offset(
      (leftShoulder.x + rightShoulder.x) / 2,
      (leftShoulder.y + rightShoulder.y) / 2,
    );
    final midHip = Offset(
      (leftHip.x + rightHip.x) / 2,
      (leftHip.y + rightHip.y) / 2,
    );
    final torsoVec = midShoulder - midHip;
    double torsoAngle =
        math.atan2(torsoVec.dy.abs(), torsoVec.dx.abs() + 1e-6) * 180 / math.pi;

    double elbowAngleRight = _calculateAngle(
      Offset(rightShoulder.x, rightShoulder.y),
      Offset(rightElbow.x, rightElbow.y),
      Offset(rightWrist.x, rightWrist.y),
    );
    // Track left arm angles for future symmetry checks (unused but reserved).
    final elbowAngleLeft = _calculateAngle(
      Offset(leftShoulder.x, leftShoulder.y),
      Offset(leftElbow.x, leftElbow.y),
      Offset(leftWrist.x, leftWrist.y),
    );

    double shoulderAngleRight = _calculateAngle(
      Offset(rightHip.x, rightHip.y),
      Offset(rightShoulder.x, rightShoulder.y),
      Offset(rightElbow.x, rightElbow.y),
    );
    double shoulderAngleLeft = _calculateAngle(
      Offset(leftHip.x, leftHip.y),
      Offset(leftShoulder.x, leftShoulder.y),
      Offset(leftElbow.x, leftElbow.y),
    );
    final shoulderAngle = (shoulderAngleLeft + shoulderAngleRight) / 2;

    // Simple stability check: require symmetry and limited angle jitter.
    final kneeDiff = (kneeAngleLeft - kneeAngleRight).abs();
    final hipDiff = (hipAngleLeft - hipAngleRight).abs();

    // Prevent "unused" lints on reserved symmetry variables without affecting logic.
    if (elbowAngleLeft < -1 || shoulderAngle < -1) {
      // no-op
    }
    if (kneeDiff > 25 || hipDiff > 25) {
      // Skip this frame; probably mid-movement wobble or partial view.
      return;
    }

    // Depth/top detection using right elbow (primary tracking arm).
    const downMin = 80.0;
    const downMax = 100.0;
    const upMin = 160.0;
    final atBottom = elbowAngleRight >= downMin && elbowAngleRight <= downMax;
    final atTop = elbowAngleRight >= upMin;

    // Form quality flags for this rep.
    bool formGood = true;
    String correction = "";

    // 1. Body line – hips should roughly match torso (avoid sag/pike).
    if (hipAngle < torsoAngle - 15) {
      formGood = false;
      correction = "Push-up: lift hips slightly to keep a straight line.";
    } else if (hipAngle > torsoAngle + 15) {
      formGood = false;
      correction = "Push-up: lower hips to avoid piking.";
    }

    // 2. Torso angle: too much arch/round.
    if (formGood && (torsoAngle < 150 || torsoAngle > 190)) {
      formGood = false;
      correction = "Push-up: keep your torso closer to a plank position.";
    }

    // 3. Elbow flare: shoulder–elbow–wrist angle too small.
    final flareAngleRight = _calculateAngle(
      Offset(rightElbow.x, rightElbow.y),
      Offset(rightShoulder.x, rightShoulder.y),
      Offset(rightWrist.x, rightWrist.y),
    );
    if (formGood && flareAngleRight < 45) {
      formGood = false;
      correction =
          "Push-up: keep elbows about 45° from your torso, not flared out.";
    }

    // Rep state machine based on elbow angle.
    _rightMinElbowAngleDuringRep = math.min(
      _rightMinElbowAngleDuringRep,
      elbowAngleRight,
    );
    if (!_rightStartedDown && atTop) {
      _rightStartedDown = true;
    }
    if (_rightStartedDown && !_rightReachedUp && atBottom) {
      _rightReachedUp = true;
    }

    if (_rightStartedDown && _rightReachedUp && atTop) {
      _rightCurlCount++;

      if (!formGood ||
          _rightMinElbowAngleDuringRep < downMin ||
          _rightMinElbowAngleDuringRep > downMax) {
        _rightWrongCount++;
        _feedback.add(
          "Rep $_rightCurlCount: "
          "${correction.isNotEmpty ? correction : "Reach ~90° elbow depth."}",
        );
      } else {
        _rightCorrectCount++;
      }

      // Reset for next rep.
      _rightStartedDown = false;
      _rightReachedUp = false;
      _rightMinElbowAngleDuringRep = 180.0;

      // Stop after 5 reps (existing behavior).
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
                  feedbacks: _feedback,
                ),
          ),
        );
      }
    }
  }

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
      return const Scaffold(body: Center(child: WalkAnimation()));
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
