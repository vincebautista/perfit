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

class SplitSquatScreen extends StatefulWidget {
  const SplitSquatScreen({super.key});

  @override
  State<SplitSquatScreen> createState() => _SplitSquatScreenState();
}

enum ExerciseStage { distanceCheck, gestureDetection, formCorrection }

class _SplitSquatScreenState extends State<SplitSquatScreen> {
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
  int _splitSquatCount = 0;
  int _correctCount = 0;
  int _wrongCount = 0;
  List<String> _feedback = [];
  List<String> _allFeedbacks = [];

  bool _isAtBottom = false;
  bool _startedDown = false;
  bool _reachedBottom = false;
  bool _reachedTop = false;

  // Stability tracking
  double? _previousTorsoAngle;
  double? _previousHipAngleLeft;
  double? _previousHipAngleRight;
  double _torsoDrift = 0;
  double _hipDrift = 0;

  // Thresholds (left leg = front, right leg = rear)
  final double _minTorsoAngle = 70.0;
  final double _maxTorsoAngle = 100.0;
  final double _bottomKneeMin = 80.0;
  final double _bottomKneeMax = 100.0;
  final double _topKneeThreshold = 120.0;
  final double _minRearKneeAngle = 90.0;
  final double _minHipAngle = 70.0;
  final double _maxHipAngle = 90.0;
  final double _maxHipImbalance = 15.0;
  final double _maxKneeOverAnkle = 10.0;
  final double _maxKneeCollapse = 15.0;
  final double _maxTorsoDrift = 6.0;
  final double _maxHipDrift = 6.0;

  Pose? _lastPose;
  Size? _cameraImageSize;

  bool _lastRepCorrect = true;

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
      distanceStatus = "Too Close! Move back";
    } else if (distanceCm > maxCm) {
      distanceStatus = "Too Far! Move closer";
    } else {
      distanceStatus = "Perfect Distance! Stay in that position.";
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

  Future<void> _handleFormCorrection(Pose pose) async {
    final landmarks = pose.landmarks;

    final leftShoulder = landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = landmarks[PoseLandmarkType.rightShoulder];
    final leftHip = landmarks[PoseLandmarkType.leftHip];
    final rightHip = landmarks[PoseLandmarkType.rightHip];
    final leftKnee = landmarks[PoseLandmarkType.leftKnee];
    final rightKnee = landmarks[PoseLandmarkType.rightKnee];
    final leftAnkle = landmarks[PoseLandmarkType.leftAnkle];
    final rightAnkle = landmarks[PoseLandmarkType.rightAnkle];

    if (leftShoulder == null ||
        rightShoulder == null ||
        leftHip == null ||
        rightHip == null ||
        leftKnee == null ||
        rightKnee == null ||
        leftAnkle == null ||
        rightAnkle == null) {
      _allFeedbacks.add("Step fully into frame so we can see both legs.");
      return;
    }

    final leftShoulderOffset = Offset(leftShoulder.x, leftShoulder.y);
    final rightShoulderOffset = Offset(rightShoulder.x, rightShoulder.y);
    final leftHipOffset = Offset(leftHip.x, leftHip.y);
    final rightHipOffset = Offset(rightHip.x, rightHip.y);
    final leftKneeOffset = Offset(leftKnee.x, leftKnee.y);
    final rightKneeOffset = Offset(rightKnee.x, rightKnee.y);
    final leftAnkleOffset = Offset(leftAnkle.x, leftAnkle.y);
    final rightAnkleOffset = Offset(rightAnkle.x, rightAnkle.y);

    // Calculate angles (left = front leg, right = rear leg)
    final frontKneeAngle = _calculateAngle(leftHipOffset, leftKneeOffset, leftAnkleOffset);
    final backKneeAngle = _calculateAngle(rightHipOffset, rightKneeOffset, rightAnkleOffset);

    final hipAngleLeft = _calculateAngle(leftShoulderOffset, leftHipOffset, leftKneeOffset);
    final hipAngleRight = _calculateAngle(rightShoulderOffset, rightHipOffset, rightKneeOffset);
    final hipAngle = (hipAngleLeft + hipAngleRight) / 2;

    final torsoAngle = _torsoAngleFromVertical(
      leftShoulderOffset,
      rightShoulderOffset,
      leftHipOffset,
      rightHipOffset,
    );

    // Update stability
    final stable = _updateStability(torsoAngle, hipAngleLeft, hipAngleRight);
    if (!stable) {
      _allFeedbacks.add("Hold the split-squat position briefly to analyze your form.");
      return;
    }

    // Bottom detection: front knee 80°–100°
    if (frontKneeAngle >= _bottomKneeMin && frontKneeAngle <= _bottomKneeMax) {
      _isAtBottom = true;
      _reachedBottom = true;
    } else if (frontKneeAngle > _topKneeThreshold) {
      _isAtBottom = false;
    }

    // Rep detection: started down, reached bottom, back to top
    if (!_startedDown && frontKneeAngle > _topKneeThreshold) {
      _startedDown = true;
    }

    if (_startedDown && !_reachedBottom && _isAtBottom) {
      _reachedBottom = true;
    }

    if (_startedDown && _reachedBottom && frontKneeAngle > _topKneeThreshold) {
      _reachedTop = true;
    }

    if (_startedDown && _reachedBottom && _reachedTop) {
      _splitSquatCount++;

      bool isCorrect = true;
      String correction = "";

      final errors = <String>[];

      if (torsoAngle < _minTorsoAngle || torsoAngle > _maxTorsoAngle) {
        errors.add("Keep your torso more upright over your hips.");
      }

      if (frontKneeAngle > _topKneeThreshold) {
        errors.add("Lower your back knee—go deeper into the split squat.");
      }

      if (_isAtBottom && backKneeAngle < _minRearKneeAngle) {
        errors.add("Bend your rear knee to about 90° at the bottom.");
      }

      if (hipAngle < _minHipAngle || hipAngle > _maxHipAngle) {
        errors.add("Stack your hips under your torso—avoid leaning or arching.");
      }

      if ((hipAngleLeft - hipAngleRight).abs() > _maxHipImbalance) {
        errors.add("Center your hips—avoid shifting weight too far to one side.");
      }

      final frontKneeForward = _kneeOverAnkle(knee: leftKneeOffset, ankle: leftAnkleOffset);
      if (frontKneeForward > _maxKneeOverAnkle) {
        errors.add("Keep your front knee stacked over the ankle, not past your toes.");
      }

      final kneeCollapse = _kneeCollapseInward(
        hip: leftHipOffset,
        knee: leftKneeOffset,
        ankle: leftAnkleOffset,
      );
      if (kneeCollapse > _maxKneeCollapse) {
        errors.add("Push your front knee out—don't let it cave inward.");
      }

      if (errors.isNotEmpty) {
        isCorrect = false;
        correction = errors.first;
      }

      if (isCorrect) {
        _correctCount++;
        _lastRepCorrect = true;
        _allFeedbacks.add("Correct form!");
      } else {
        _wrongCount++;
        _feedback.add("Rep $_splitSquatCount: $correction");
        _allFeedbacks.add(correction);
        _lastRepCorrect = false;
      }

      _startedDown = false;
      _reachedBottom = false;
      _reachedTop = false;

      if (_splitSquatCount >= 5) {
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
                  feedbacks: _allFeedbacks,
                ),
          ),
        );
      }
    }
  }

  double _torsoAngleFromVertical(
    Offset leftShoulder,
    Offset rightShoulder,
    Offset leftHip,
    Offset rightHip,
  ) {
    final shoulder = Offset(
      (leftShoulder.dx + rightShoulder.dx) / 2,
      (leftShoulder.dy + rightShoulder.dy) / 2,
    );
    final hip = Offset(
      (leftHip.dx + rightHip.dx) / 2,
      (leftHip.dy + rightHip.dy) / 2,
    );
    final torso = shoulder - hip;
    return math.atan2(torso.dx.abs(), torso.dy.abs() + 1e-6) * 180 / math.pi;
  }

  double _kneeOverAnkle({
    required Offset knee,
    required Offset ankle,
  }) {
    final dx = (knee.dx - ankle.dx).abs();
    final dy = (knee.dy - ankle.dy).abs() + 1e-6;
    return math.atan2(dx, dy) * 180 / math.pi;
  }

  double _kneeCollapseInward({
    required Offset hip,
    required Offset knee,
    required Offset ankle,
  }) {
    final hipToAnkleDx = ankle.dx - hip.dx;
    final hipToAnkleDy = ankle.dy - hip.dy;
    final hipToKneeDx = knee.dx - hip.dx;
    final hipToKneeDy = knee.dy - hip.dy;

    final cross = (hipToAnkleDx * hipToKneeDy) - (hipToAnkleDy * hipToKneeDx);
    final baseLen = math.sqrt(
      hipToAnkleDx * hipToAnkleDx + hipToAnkleDy * hipToAnkleDy,
    );
    if (baseLen == 0) return 0;

    final distance = (cross.abs() / baseLen);
    final hipToKneeLen =
        math.sqrt(hipToKneeDx * hipToKneeDx + hipToKneeDy * hipToKneeDy) + 1e-6;
    return math.atan2(distance, hipToKneeLen) * 180 / math.pi;
  }

  bool _updateStability(
    double torsoAngle,
    double hipAngleLeft,
    double hipAngleRight,
  ) {
    if (_previousTorsoAngle != null) {
      final delta = (torsoAngle - _previousTorsoAngle!).abs();
      _torsoDrift = _torsoDrift * 0.7 + delta * 0.3;
    }
    if (_previousHipAngleLeft != null && _previousHipAngleRight != null) {
      final leftDelta = (hipAngleLeft - _previousHipAngleLeft!).abs();
      final rightDelta = (hipAngleRight - _previousHipAngleRight!).abs();
      final avg = (leftDelta + rightDelta) / 2;
      _hipDrift = _hipDrift * 0.7 + avg * 0.3;
    }

    _previousTorsoAngle = torsoAngle;
    _previousHipAngleLeft = hipAngleLeft;
    _previousHipAngleRight = hipAngleRight;

    return _torsoDrift < _maxTorsoDrift && _hipDrift < _maxHipDrift;
  }

  double _distance(Offset a, Offset b) =>
      math.sqrt(math.pow(a.dx - b.dx, 2) + math.pow(a.dy - b.dy, 2));

  double _calculateAngle(Offset a, Offset b, Offset c) {
    final ab = Offset(a.dx - b.dx, a.dy - b.dy);
    final cb = Offset(c.dx - b.dx, c.dy - b.dy);

    final dot = ab.dx * cb.dx + ab.dy * cb.dy;
    final magAB = math.sqrt(ab.dx * ab.dx + ab.dy * ab.dy);
    final magCB = math.sqrt(cb.dx * cb.dx + cb.dy * cb.dy);

    final cosine = (dot / (magAB * magCB)).clamp(-1.0, 1.0);
    return math.acos(cosine) * 180 / math.pi;
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized || _cameraService.controller == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Determine the current message
    String displayMessage = "";
    Color bgColor = AppColors.primary;

    switch (currentStage) {
      case ExerciseStage.distanceCheck:
        displayMessage = distanceStatus;
        if (displayMessage.toLowerCase().contains("too")) {
          bgColor = AppColors.red;
        } else if (displayMessage.toLowerCase().contains("perfect")) {
          bgColor = AppColors.green;
        } else {
          bgColor = AppColors.primary;
        }
        break;

      case ExerciseStage.gestureDetection:
        displayMessage = handsStatus;
        if (displayMessage.toLowerCase().contains("raise your hand")) {
          bgColor = AppColors.red;
        } else if (displayMessage.toLowerCase().contains("hands detected") ||
            displayMessage.toLowerCase().contains("timer complete")) {
          bgColor = AppColors.green;
        } else {
          bgColor = AppColors.primary;
        }
        break;

      case ExerciseStage.formCorrection:
        if (_allFeedbacks.isNotEmpty) {
          displayMessage = _allFeedbacks.last;
          bgColor = _lastRepCorrect ? AppColors.green : AppColors.red;
        } else {
          displayMessage = "Please perform the exercise.";
          bgColor = AppColors.primary;
        }
        break;
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Split Squat Exercise")),
      body: Column(
        children: [
          // Single message panel
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
