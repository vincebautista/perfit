import 'dart:math' as math;
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:perfit/core/constants/colors.dart';
import 'package:perfit/core/constants/sizes.dart';
import 'package:perfit/core/services/camera_service.dart';
import 'package:perfit/core/services/distance_service.dart';
import 'package:perfit/core/services/gesture_service.dart';
import 'package:perfit/core/services/pose_detection_service.dart';
import 'package:perfit/core/services/setting_service.dart';
import 'package:perfit/screens/exercise_summary_screen.dart';
import 'package:perfit/widgets/text_styles.dart';

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
  List<String> _feedbackList = []; // Stores final rep feedback for summary

  bool _startedRep = false;
  bool isAtTop = false;

  // Live Feedback state for UI
  String _currentFeedback = "";
  bool _lastRepCorrect = true; // Determines Header Color (Green/Red)

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 1), () async {
      await _initCamera();
      _loadCountdown();
    });
  }

  Future<void> _loadCountdown() async {
    final countdownData = await SettingService().loadCountdown();
    countdown = countdownData["countdown"] ?? 3;
  }

  Future<void> _initCamera() async {
    await _cameraService.initCamera();
    _cameraService.startStream(_processCameraImage);

    if (!mounted) return;
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
      distanceStatus = "Too Close! Move back";
    } else if (distanceCm > maxCm) {
      distanceStatus = "Too Far! Move closer";
    } else {
      distanceStatus = "Perfect Distance! Stay there.";
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
              countdownStatus = "Raise your hand… ${(progress * 100).toInt()}%",
      onHandsUpDetected: () {
        handsStatus = "Hands detected! Starting countdown...";
        countdownStatus = "";
      },
      onCountdownTick: (seconds) => countdownStatus = "⏱ $seconds s",
      onCountdownComplete: () {
        countdownStatus = "Timer complete!";
        currentStage = ExerciseStage.formCorrection;
      },
    );

    if (!handsUp && !_gestureService.countdownRunning) {
      handsStatus = "Raise your hand!";
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
      _currentFeedback = "Ensure all body parts are visible";
      _lastRepCorrect = false;
      return;
    }

    // --- CRUNCH LOGIC ---

    // Hip angles: shoulder-hip-knee
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

    // Hip angle: average hip crease angle
    double hipAngle = avgHipAngle;

    // Torso curl angle logic (per original code)
    double torsoAngle = 180 - avgHipAngle;

    // Neck alignment logic
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

      final avgShoulder = Offset(
        (leftShoulder.x + rightShoulder.x) / 2,
        (leftShoulder.y + rightShoulder.y) / 2,
      );

      // Calculate angle between nose-ear line and shoulder-hip line (approximation)
      // Note: Simplified relative to original vector math for brevity, but retains logic structure
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

    // Stability Check
    final hipAngleDiff = (hipAngleLeft - hipAngleRight).abs();
    if (hipAngleDiff > 30) {
      _currentFeedback = "Please face camera directly";
      _lastRepCorrect = false;
      return;
    }

    // Detect if at top position (torso curl angle in 30°-45° range)
    isAtTop = torsoAngle >= 30 && torsoAngle <= 45;

    // Form error detection
    List<String> errors = [];

    // 1. Using hips too much
    if (hipAngle < 120) {
      errors.add("Don't lift legs");
    }

    // 2. Neck strain
    if (neckAngle < 150) {
      errors.add("Keep neck neutral");
    }

    // 3. Insufficient curl
    if (isAtTop && torsoAngle < 30) {
      errors.add("Curl up more");
    }

    // 4. Over-crunching
    if (torsoAngle > 50) {
      errors.add("Don't over-crunch");
    }

    // 5. Elbows collapsing
    if (avgElbowAngle < 50) {
      errors.add("Keep elbows wide");
    }

    // Set Live Feedback
    if (errors.isNotEmpty) {
      _currentFeedback = errors.join(". ");
      _lastRepCorrect = false;
    } else {
      if (isAtTop) {
        _currentFeedback = "Hold... Good form!";
        _lastRepCorrect = true;
      } else {
        _currentFeedback = "Crunch up";
        _lastRepCorrect =
            true; // Neutral state is technically correct form wise
      }
    }

    // Rep counting logic
    if (!_startedRep && torsoAngle < 10) {
      _startedRep = true;
    }

    // Complete rep when returning to starting position
    if (_startedRep && isAtTop && torsoAngle < 10) {
      _crunchCount++;

      if (errors.isEmpty) {
        _correctCount++;
        _feedbackList.add("Correct form!");
        _lastRepCorrect = true;
      } else {
        _wrongCount++;
        _feedbackList.add("Rep $_crunchCount: ${errors.join(", ")}");
        _lastRepCorrect = false;
      }

      // Reset for next rep
      _startedRep = false;

      // Stop after 5 reps
      if (_crunchCount >= 5) {
        await _cameraService.controller?.stopImageStream();
        if (!mounted) return;

        await Future.delayed(const Duration(seconds: 1));
        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder:
                (_) => ExerciseSummaryScreen(
                  correct: _correctCount,
                  wrong: _wrongCount,
                  feedbacks: _feedbackList,
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

    // Determine UI Colors and Messages based on Logic
    String displayMessage = "";
    Color bgColor = AppColors.primary;

    switch (currentStage) {
      case ExerciseStage.distanceCheck:
        displayMessage = distanceStatus;
        if (displayMessage.toLowerCase().contains("too")) {
          bgColor = AppColors.red;
        } else if (displayMessage.toLowerCase().contains("perfect")) {
          bgColor = AppColors.green;
        }
        break;

      case ExerciseStage.gestureDetection:
        displayMessage =
            countdownStatus.isNotEmpty ? countdownStatus : handsStatus;
        if (displayMessage.toLowerCase().contains("raise")) {
          bgColor = AppColors.red;
        } else if (displayMessage.toLowerCase().contains("detected") ||
            displayMessage.toLowerCase().contains("complete")) {
          bgColor = AppColors.green;
        }
        break;

      case ExerciseStage.formCorrection:
        if (_currentFeedback.isNotEmpty) {
          displayMessage = _currentFeedback;
          bgColor = _lastRepCorrect ? AppColors.green : AppColors.red;
        } else {
          displayMessage = "Start crunching!";
          bgColor = AppColors.primary;
        }
        break;
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Crunches Exercise")),
      body: Column(
        children: [
          // 1. TOP MESSAGE PANEL
          Container(
            width: double.infinity,
            color: bgColor,
            padding: const EdgeInsets.all(12),
            child: Text(
              displayMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.black,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          // 2. CAMERA + OVERLAY
          Expanded(
            child: Stack(
              children: [
                CameraPreview(_cameraService.controller!),

                Positioned.fill(
                  child: CustomPaint(
                    painter: CornerPainter(
                      cornerLength: 60,
                      strokeWidth: 5,
                      padding: 50,
                      topLeft: bgColor,
                      topRight: bgColor,
                      bottomLeft: bgColor,
                      bottomRight: bgColor,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Gap(AppSizes.gap10),

          // 3. SCORE CARD
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.padding16),
            child: Card(
              color: AppColors.grey,
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Column(
                      children: [
                        Text("CORRECT", style: TextStyles.label),
                        Gap(6),
                        Text(
                          "$_correctCount",
                          style: TextStyles.subtitle.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      height: 40,
                      width: 1.2,
                      color: Colors.grey.shade300,
                    ),
                    Column(
                      children: [
                        Text("WRONG", style: TextStyles.label),
                        Gap(6),
                        Text(
                          "$_wrongCount",
                          style: TextStyles.subtitle.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          Gap(AppSizes.gap10),
        ],
      ),
    );
  }
}

// Re-using the CornerPainter
class CornerPainter extends CustomPainter {
  final double cornerLength;
  final double strokeWidth;
  final double padding;
  final Color topLeft;
  final Color topRight;
  final Color bottomLeft;
  final Color bottomRight;

  CornerPainter({
    this.cornerLength = 30,
    this.strokeWidth = 4,
    this.padding = 20,
    required this.topLeft,
    required this.topRight,
    required this.bottomLeft,
    required this.bottomRight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.square
          ..style = PaintingStyle.stroke;

    // Top-left
    paint.color = topLeft;
    canvas.drawLine(
      Offset(padding, padding),
      Offset(padding + cornerLength, padding),
      paint,
    );
    canvas.drawLine(
      Offset(padding, padding),
      Offset(padding, padding + cornerLength),
      paint,
    );

    // Top-right
    paint.color = topRight;
    canvas.drawLine(
      Offset(size.width - padding - cornerLength, padding),
      Offset(size.width - padding, padding),
      paint,
    );
    canvas.drawLine(
      Offset(size.width - padding, padding),
      Offset(size.width - padding, padding + cornerLength),
      paint,
    );

    // Bottom-left
    paint.color = bottomLeft;
    canvas.drawLine(
      Offset(padding, size.height - padding - cornerLength),
      Offset(padding, size.height - padding),
      paint,
    );
    canvas.drawLine(
      Offset(padding, size.height - padding),
      Offset(padding + cornerLength, size.height - padding),
      paint,
    );

    // Bottom-right
    paint.color = bottomRight;
    canvas.drawLine(
      Offset(size.width - padding - cornerLength, size.height - padding),
      Offset(size.width - padding, size.height - padding),
      paint,
    );
    canvas.drawLine(
      Offset(size.width - padding, size.height - padding - cornerLength),
      Offset(size.width - padding, size.height - padding),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
