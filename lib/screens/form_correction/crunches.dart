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

class CrunchesScreen extends StatefulWidget {
  const CrunchesScreen({super.key});

  @override
  State<CrunchesScreen> createState() => _CrunchesScreenState();
}

enum ExerciseStage { distanceCheck, gestureDetection, formCorrection }

class _CrunchesScreenState extends State<CrunchesScreen> {
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
  int _crunchCount = 0;
  int _correctCount = 0;
  int _wrongCount = 0;
  List<String> _feedback = [];

  bool _startedRep = false;
  bool isAtTop = false;

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

    // Get required landmarks for crunches
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
    final nose = landmarks[PoseLandmarkType.nose];
    final leftEar = landmarks[PoseLandmarkType.leftEar];
    final rightEar = landmarks[PoseLandmarkType.rightEar];

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
        rightKnee == null) {
      feedback = "Please ensure all body parts are visible";
      feedbackColor = Colors.orange;
      return;
    }

    // Calculate angles
    // Knee angles: hip-knee-ankle (calculated per requirements)
    final leftAnkle = landmarks[PoseLandmarkType.leftAnkle];
    final rightAnkle = landmarks[PoseLandmarkType.rightAnkle];
    // ignore: unused_local_variable
    double kneeAngleLeft = 180.0;
    // ignore: unused_local_variable
    double kneeAngleRight = 180.0;
    if (leftAnkle != null && rightAnkle != null) {
      kneeAngleLeft = calculateAngle(leftHip, leftKnee, leftAnkle);
      kneeAngleRight = calculateAngle(rightHip, rightKnee, rightAnkle);
    }

    // Hip angles: shoulder-hip-knee (hip crease angle)
    double hipAngleLeft = calculateAngle(leftShoulder, leftHip, leftKnee);
    double hipAngleRight = calculateAngle(rightShoulder, rightHip, rightKnee);
    final avgHipAngle = (hipAngleLeft + hipAngleRight) / 2;

    // Elbow angles: shoulder-elbow-wrist (for elbow collapse check)
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

    // Hip angle: average hip crease angle
    double hipAngle = avgHipAngle;

    // Torso curl angle: shoulder-hip angle (shoulder-hip-knee gives curl amount)
    // For crunches, we measure the angle between shoulder and hip relative to horizontal
    final avgShoulder = Offset(
      (leftShoulder.x + rightShoulder.x) / 2,
      (leftShoulder.y + rightShoulder.y) / 2,
    );
    final avgHip = Offset(
      (leftHip.x + rightHip.x) / 2,
      (leftHip.y + rightHip.y) / 2,
    );
    // Calculate angle between shoulder-hip line and horizontal
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
    // ignore: unused_local_variable
    double baseTorsoAngle = math.acos(cosine.clamp(-1.0, 1.0)) * 180 / math.pi;

    // For crunches, torso curl angle is the change from lying flat (180°) to curled position
    // When lying flat, shoulder-hip line is horizontal (0° or 180°)
    // When curled, the angle changes - we measure the curl as deviation from flat
    // Use hip crease angle as proxy: when flat, hip angle is ~180°, when curled it decreases
    double torsoAngle = 180 - avgHipAngle; // Torso curl angle

    // Neck alignment: head-neck-torso angle (150°-180°)
    double neckAngle = 180.0; // Default
    if (nose != null && (leftEar != null || rightEar != null)) {
      final avgEar =
          leftEar != null && rightEar != null
              ? Offset(
                (leftEar.x + rightEar.x) / 2,
                (leftEar.y + rightEar.y) / 2,
              )
              : (leftEar != null
                  ? Offset(leftEar.x, leftEar.y)
                  : Offset(rightEar!.x, rightEar.y));
      // Calculate angle between nose-ear line and shoulder-hip line
      final noseEar = Offset(nose.x - avgEar.dx, nose.y - avgEar.dy);
      final earShoulder = Offset(
        avgShoulder.dx - avgEar.dx,
        avgShoulder.dy - avgEar.dy,
      );
      final dotNeck = noseEar.dx * earShoulder.dx + noseEar.dy * earShoulder.dy;
      final magNoseEar = math.sqrt(
        noseEar.dx * noseEar.dx + noseEar.dy * noseEar.dy,
      );
      final magEarShoulder = math.sqrt(
        earShoulder.dx * earShoulder.dx + earShoulder.dy * earShoulder.dy,
      );
      if (magNoseEar > 0 && magEarShoulder > 0) {
        final cosineNeck = dotNeck / (magNoseEar * magEarShoulder);
        neckAngle = math.acos(cosineNeck.clamp(-1.0, 1.0)) * 180 / math.pi;
      }
    }

    // Check if data is stable
    final hipAngleDiff = (hipAngleLeft - hipAngleRight).abs();
    if (hipAngleDiff > 30) {
      feedback = "Please face the camera directly";
      feedbackColor = Colors.orange;
      return;
    }

    // Detect if at top position (torso curl angle in 30°-45° range)
    isAtTop = torsoAngle >= 30 && torsoAngle <= 45;

    // Initialize feedback
    feedback = "";
    feedbackColor = Colors.green;

    // Form error detection
    List<String> errors = [];

    // 1. Using hips too much: hipAngle < 120° (legs lifting or hips flexing too far)
    if (hipAngle < 120) {
      errors.add("Don't lift your legs - focus on curling your torso");
      feedbackColor = Colors.red;
    }

    // 2. Neck strain: head pulled forward (neck angle < 150°)
    if (neckAngle < 150) {
      errors.add("Keep your neck neutral - don't pull your head forward");
      feedbackColor = Colors.red;
    }

    // 3. Insufficient curl: torsoAngle does not reach 30° minimum
    if (isAtTop && torsoAngle < 30) {
      errors.add("Curl up more - lift your shoulders higher");
      feedbackColor = Colors.red;
    }

    // 4. Over-crunching: torsoAngle > 50° (too much spinal flexion)
    if (torsoAngle > 50) {
      errors.add("Don't over-crunch - reduce the range of motion");
      feedbackColor = Colors.red;
    }

    // 5. Elbows collapsing inward: shoulder-elbow-wrist angle < 50° (hands pulling head)
    if (avgElbowAngle < 50) {
      errors.add("Keep elbows wide - don't pull on your head");
      feedbackColor = Colors.red;
    }

    // Set feedback message
    if (errors.isEmpty) {
      if (isAtTop) {
        feedback = "✅ Good form!";
      } else {
        feedback = "Continue crunching";
      }
    } else {
      feedback = errors.join(". ");
    }

    // Rep counting logic
    if (!_startedRep && torsoAngle < 10) {
      _startedRep = true;
    }

    // Complete rep when returning to starting position
    if (_startedRep && isAtTop && torsoAngle < 10) {
      _crunchCount++;

      if (feedbackColor == Colors.green) {
        _correctCount++;
      } else {
        _wrongCount++;
        _feedback.add("Rep $_crunchCount: ${errors.join(", ")}");
      }

      // Reset for next rep
      _startedRep = false;

      // Stop after 5 reps
      if (_crunchCount >= 5) {
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
      appBar: AppBar(title: const Text("Crunches")),
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
                      "Reps: $_crunchCount\n✅ $_correctCount | ❌ $_wrongCount",
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
