//tristy
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

class BarbellRowScreen extends StatefulWidget {
  const BarbellRowScreen({super.key});

  @override
  State<BarbellRowScreen> createState() => _BarbellRowScreenState();
}

enum ExerciseStage { distanceCheck, gestureDetection, formCorrection }

class _BarbellRowScreenState extends State<BarbellRowScreen> {
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
  int _rowCount = 0;
  int _correctCount = 0;
  int _wrongCount = 0;
  List<String> _feedback = [];

  bool _startedRep = false;
  bool isAtTop = false;
  double _previousTorsoAngle = 0.0;
  double _torsoAngleVariance = 0.0;

  // Feedback display
  String feedback = "";
  Color feedbackColor = Colors.green;

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

  // Helper function to calculate angle from three landmarks
  double calculateAngle(PoseLandmark a, PoseLandmark b, PoseLandmark c) {
    return _calculateAngle(
      Offset(a.x, a.y),
      Offset(b.x, b.y),
      Offset(c.x, c.y),
    );
  }

  Future<void> _handleFormCorrection(Pose pose) async {
    final landmarks = pose.landmarks;

    // Get required landmarks for barbell row
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

    // Verify all required landmarks exist
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
      feedback = "Please ensure all body parts are visible";
      feedbackColor = Colors.orange;
      return;
    }

    // Calculate angles
    // Knee angles: hip-knee-ankle (calculated per requirements)
    // ignore: unused_local_variable
    double kneeAngleLeft = calculateAngle(leftHip, leftKnee, leftAnkle);
    // ignore: unused_local_variable
    double kneeAngleRight = calculateAngle(rightHip, rightKnee, rightAnkle);

    // Hip angles: shoulder-hip-knee
    double hipAngleLeft = calculateAngle(leftShoulder, leftHip, leftKnee);
    double hipAngleRight = calculateAngle(rightShoulder, rightHip, rightKnee);
    final avgHipAngle = (hipAngleLeft + hipAngleRight) / 2;

    // Elbow angles: shoulder-elbow-wrist
    double elbowAngleLeft = calculateAngle(leftShoulder, leftElbow, leftWrist);
    double elbowAngleRight = calculateAngle(
      rightShoulder,
      rightElbow,
      rightWrist,
    );
    final avgElbowAngle = (elbowAngleLeft + elbowAngleRight) / 2;

    // Shoulder angle: hip-shoulder-elbow (calculated per requirements)
    double shoulderAngleLeft = calculateAngle(leftHip, leftShoulder, leftElbow);
    double shoulderAngleRight = calculateAngle(
      rightHip,
      rightShoulder,
      rightElbow,
    );
    // ignore: unused_local_variable
    final avgShoulderAngle = (shoulderAngleLeft + shoulderAngleRight) / 2;

    // Hip angle: average hip angle (for general hip position)
    double hipAngle = avgHipAngle;

    // Torso angle: angle between shoulder-hip line and horizontal
    final avgShoulder = Offset(
      (leftShoulder.x + rightShoulder.x) / 2,
      (leftShoulder.y + rightShoulder.y) / 2,
    );
    final avgHip = Offset(
      (leftHip.x + rightHip.x) / 2,
      (leftHip.y + rightHip.y) / 2,
    );
    final horizontal = Offset(1, 0);
    final shoulderHip = Offset(
      avgShoulder.dx - avgHip.dx,
      avgShoulder.dy - avgHip.dy,
    );
    final dot = horizontal.dx * shoulderHip.dx + horizontal.dy * shoulderHip.dy;
    final magHorizontal = math.sqrt(
      horizontal.dx * horizontal.dx + horizontal.dy * horizontal.dy,
    );
    final magShoulderHip = math.sqrt(
      shoulderHip.dx * shoulderHip.dx + shoulderHip.dy * shoulderHip.dy,
    );
    final cosine = dot / (magHorizontal * magShoulderHip);
    double torsoAngle = math.acos(cosine.clamp(-1.0, 1.0)) * 180 / math.pi;

    // Check if data is stable (both elbows have similar angles)
    final elbowAngleDiff = (elbowAngleLeft - elbowAngleRight).abs();
    if (elbowAngleDiff > 30) {
      feedback = "Please ensure both arms are visible";
      feedbackColor = Colors.orange;
      return;
    }

    // Track torso angle variance for stability check
    if (_previousTorsoAngle > 0) {
      final torsoChange = (torsoAngle - _previousTorsoAngle).abs();
      _torsoAngleVariance = (_torsoAngleVariance * 0.9) + (torsoChange * 0.1);
    }
    _previousTorsoAngle = torsoAngle;

    // Detect if at top position (elbow angles in 70-110° range)
    isAtTop = avgElbowAngle >= 70 && avgElbowAngle <= 110;

    // Initialize feedback
    feedback = "";
    feedbackColor = Colors.green;

    // Form error detection
    List<String> errors = [];

    // 1. Rounded back: torsoAngle varies > 10° OR spine curvature suggests < 40° or > 80°
    if (torsoAngle < 40 || torsoAngle > 80) {
      errors.add("Keep your back straight - maintain neutral spine");
      feedbackColor = Colors.red;
    }
    // Check torso wobble during rep
    if (_torsoAngleVariance > 15) {
      errors.add("Keep your torso stable - reduce movement");
      feedbackColor = Colors.red;
    }

    // 2. Insufficient hip hinge: hipAngle > 100° (standing too upright)
    if (hipAngle > 100) {
      errors.add("Hinge more at the hips - lean forward");
      feedbackColor = Colors.red;
    }

    // 3. Elbows not pulling correctly: elbow angle does not enter 70°-110° at contraction
    if (isAtTop && (avgElbowAngle < 70 || avgElbowAngle > 110)) {
      errors.add("Pull elbows back to 70-110° range");
      feedbackColor = Colors.red;
    }

    // 4. Shrugging instead of rowing: shoulder elevation > 20° (shoulders too close to ears)
    // Check shoulder position relative to hip (vertical distance)
    final shoulderElevation = (avgShoulder.dy - avgHip.dy).abs();
    final torsoLength = math.sqrt(
      (avgShoulder.dx - avgHip.dx) * (avgShoulder.dx - avgHip.dx) +
          (avgShoulder.dy - avgHip.dy) * (avgShoulder.dy - avgHip.dy),
    );
    if (torsoLength > 0) {
      final elevationRatio = shoulderElevation / torsoLength;
      // If shoulders are elevated relative to normal torso position
      if (elevationRatio > 0.3 && isAtTop) {
        errors.add("Don't shrug - pull with your back, not your shoulders");
        feedbackColor = Colors.red;
      }
    }

    // 5. Too much torso movement: torso wobble > 15° between frames
    // Already checked above with _torsoAngleVariance

    // Set feedback message
    if (errors.isEmpty) {
      if (isAtTop) {
        feedback = "✅ Good form!";
      } else {
        feedback = "Continue rowing";
      }
    } else {
      feedback = errors.join(". ");
    }

    // Rep counting logic
    if (!_startedRep && avgElbowAngle > 150) {
      _startedRep = true;
      _torsoAngleVariance = 0.0;
    }

    // Complete rep when returning to starting position
    if (_startedRep && isAtTop && avgElbowAngle > 150) {
      _rowCount++;

      if (feedbackColor == Colors.green) {
        _correctCount++;
      } else {
        _wrongCount++;
        _feedback.add("Rep $_rowCount: ${errors.join(", ")}");
      }

      // Reset for next rep
      _startedRep = false;
      _torsoAngleVariance = 0.0;

      // Stop after 5 reps
      if (_rowCount >= 5) {
        await _cameraService.controller?.stopImageStream();
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder:
                (_) => ExerciseSummaryScreen(
                  correct: _correctCount,
                  wrong: _wrongCount,
                  feedback: _feedback,
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
      appBar: AppBar(title: const Text("Barbell Row")),
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

          // Overlay rep counter and feedback
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Reps: $_rowCount\n✅ $_correctCount | ❌ $_wrongCount",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (feedback.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: feedbackColor.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            feedback,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
