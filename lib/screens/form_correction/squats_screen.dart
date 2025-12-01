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

class SquatsScreen extends StatefulWidget {
  const SquatsScreen({super.key});

  @override
  State<SquatsScreen> createState() => _SquatsScreenState();
}

enum ExerciseStage { distanceCheck, gestureDetection, formCorrection }

class _SquatsScreenState extends State<SquatsScreen> {
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
  int _squatCount = 0;
  int _correctCount = 0;
  int _wrongCount = 0;
  List<String> _feedback = [];

  bool _startedDown = false;
  bool _reachedBottom = false;
  bool isAtBottom = false;
  double _minKneeAngleDuringRep =
      180.0; // Track minimum knee angle for depth check

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

    // Get required landmarks for squats
    final leftHip = landmarks[PoseLandmarkType.leftHip];
    final rightHip = landmarks[PoseLandmarkType.rightHip];
    final leftKnee = landmarks[PoseLandmarkType.leftKnee];
    final rightKnee = landmarks[PoseLandmarkType.rightKnee];
    final leftAnkle = landmarks[PoseLandmarkType.leftAnkle];
    final rightAnkle = landmarks[PoseLandmarkType.rightAnkle];
    final leftShoulder = landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = landmarks[PoseLandmarkType.rightShoulder];

    // Verify all required landmarks exist
    if (leftHip == null ||
        rightHip == null ||
        leftKnee == null ||
        rightKnee == null ||
        leftAnkle == null ||
        rightAnkle == null ||
        leftShoulder == null ||
        rightShoulder == null) {
      feedback = "Please ensure all body parts are visible";
      feedbackColor = Colors.orange;
      return;
    }

    // Calculate angles
    double kneeAngleLeft = calculateAngle(leftHip, leftKnee, leftAnkle);
    double kneeAngleRight = calculateAngle(rightHip, rightKnee, rightAnkle);

    // Hip angle: shoulder-hip-knee
    // ignore: unused_local_variable
    double hipAngleLeft = calculateAngle(leftShoulder, leftHip, leftKnee);
    // ignore: unused_local_variable
    double hipAngleRight = calculateAngle(rightShoulder, rightHip, rightKnee);

    // Torso angle: average of shoulder-hip angles (relative to vertical)
    // Using hip as center, calculate angle between shoulder and vertical
    final avgHip = Offset(
      (leftHip.x + rightHip.x) / 2,
      (leftHip.y + rightHip.y) / 2,
    );
    final avgShoulder = Offset(
      (leftShoulder.x + rightShoulder.x) / 2,
      (leftShoulder.y + rightShoulder.y) / 2,
    );
    // Torso angle: angle between vertical (downward) and shoulder-hip line
    final vertical = Offset(0, 1);
    final shoulderHip = Offset(
      avgShoulder.dx - avgHip.dx,
      avgShoulder.dy - avgHip.dy,
    );
    final dot = vertical.dx * shoulderHip.dx + vertical.dy * shoulderHip.dy;
    final magVertical = math.sqrt(
      vertical.dx * vertical.dx + vertical.dy * vertical.dy,
    );
    final magShoulderHip = math.sqrt(
      shoulderHip.dx * shoulderHip.dx + shoulderHip.dy * shoulderHip.dy,
    );
    final cosine = dot / (magVertical * magShoulderHip);
    double torsoAngle = math.acos(cosine.clamp(-1.0, 1.0)) * 180 / math.pi;

    // Check if data is stable (both knees have similar angles)
    final kneeAngleDiff = (kneeAngleLeft - kneeAngleRight).abs();
    if (kneeAngleDiff > 30) {
      feedback = "Please face the camera directly";
      feedbackColor = Colors.orange;
      return;
    }

    // Detect if at bottom position (knee angles in 80-110° range)
    final avgKneeAngle = (kneeAngleLeft + kneeAngleRight) / 2;
    isAtBottom = avgKneeAngle >= 80 && avgKneeAngle <= 110;

    // Initialize feedback
    feedback = "";
    feedbackColor = Colors.green;

    // Form error detection
    List<String> errors = [];

    // 1. Back rounding: torsoAngle < 70° or > 110°
    if (torsoAngle < 70 || torsoAngle > 110) {
      errors.add("Keep your back straight");
      feedbackColor = Colors.red;
    }

    // 2. Shallow squat: knee angles > 120° (never reached proper depth)
    // Track minimum knee angle during the rep
    if (_startedDown) {
      _minKneeAngleDuringRep = math.min(_minKneeAngleDuringRep, avgKneeAngle);
    }
    // Check if they went deep enough (knee angle should be 80-110° at bottom)
    if (_reachedBottom && _minKneeAngleDuringRep > 110) {
      errors.add("Go deeper - lower your hips");
      feedbackColor = Colors.red;
    }

    // 3. Knees caving in: lateral deviation > 15° measured by knee-over-ankle alignment
    final double kneeTrackingLeft = _kneeTrackingAngle(leftKnee, leftAnkle);
    final double kneeTrackingRight = _kneeTrackingAngle(rightKnee, rightAnkle);
    final double kneeTrackingDiff =
        (kneeTrackingLeft - kneeTrackingRight).abs();
    if (isAtBottom &&
        (kneeTrackingLeft.abs() > 15 ||
            kneeTrackingRight.abs() > 15 ||
            kneeTrackingDiff > 15)) {
      errors.add("Keep your knees tracking over your toes");
      feedbackColor = Colors.red;
    }

    // 4. Too much forward lean: hip too far in front of ankle
    final avgAnkle = Offset(
      (leftAnkle.x + rightAnkle.x) / 2,
      (leftAnkle.y + rightAnkle.y) / 2,
    );
    final hipAnkleHorizontal = (avgHip.dx - avgAnkle.dx).abs();
    final hipAnkleVertical = (avgHip.dy - avgAnkle.dy).abs();
    if (hipAnkleVertical > 0) {
      final forwardLeanRatio = hipAnkleHorizontal / hipAnkleVertical;
      if (forwardLeanRatio > 0.5 && isAtBottom) {
        errors.add("Keep your weight centered over your feet");
        feedbackColor = Colors.red;
      }
    }

    // Set feedback message
    if (errors.isEmpty) {
      if (isAtBottom) {
        feedback = "✅ Good form!";
      } else {
        feedback = "Continue squatting";
      }
    } else {
      feedback = errors.join(". ");
    }

    // Rep counting logic
    if (!_startedDown && avgKneeAngle > 140) {
      _startedDown = true;
    }

    if (_startedDown && !_reachedBottom && isAtBottom) {
      _reachedBottom = true;
    }

    // Complete rep when returning to standing position
    if (_startedDown && _reachedBottom && avgKneeAngle > 150) {
      _squatCount++;

      if (feedbackColor == Colors.green) {
        _correctCount++;
      } else {
        _wrongCount++;
        _feedback.add("Rep $_squatCount: ${errors.join(", ")}");
      }

      // Reset for next rep
      _startedDown = false;
      _reachedBottom = false;
      _minKneeAngleDuringRep = 180.0;

      // Stop after 5 reps
      if (_squatCount >= 5) {
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

  double _kneeTrackingAngle(PoseLandmark knee, PoseLandmark ankle) {
    final double dx = knee.x - ankle.x;
    final double dy = (knee.y - ankle.y).abs() + 1e-9;
    return math.atan2(dx, dy) * 180 / math.pi;
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Reps: $_squatCount\n✅ $_correctCount | ❌ $_wrongCount",
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
