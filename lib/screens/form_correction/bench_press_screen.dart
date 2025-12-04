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

class BenchPressScreen extends StatefulWidget {
  const BenchPressScreen({super.key});

  @override
  State<BenchPressScreen> createState() => _BenchPressScreenState();
}

enum ExerciseStage { distanceCheck, gestureDetection, formCorrection }

class _BenchPressScreenState extends State<BenchPressScreen> {
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
  int _benchPressCount = 0;
  int _correctCount = 0;
  int _wrongCount = 0;
  List<String> _feedback = [];
  List<String> _allFeedbacks = [];

  bool _startedDown = false;
  bool _reachedBottom = false;
  bool _reachedTop = false;
  double _minElbowAngleDuringRep = 180.0;
  double _maxElbowAngleDuringRep = 0.0;

  // Stability tracking
  double? _previousTorsoAngle;
  double? _previousElbowForStability;
  double _torsoDrift = 0;
  double _elbowDrift = 0;
  bool _pendingLockoutCheck = false;

  // Thresholds
  final double _bottomElbowMin = 80.0;
  final double _bottomElbowMax = 100.0;
  final double _topElbowThreshold = 160.0;
  final double _maxTorsoDrift = 6.0;
  final double _maxElbowDrift = 8.0;
  final double _minFlareAngle = 45.0;
  final double _minShoulderAngle = 20.0;
  final double _maxShoulderAngle = 45.0;
  final double _maxWristStackAngle = 10.0;
  final double _maxLegImbalance = 20.0;
  final double _minHipAngle = 40.0;

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
      _allFeedbacks.add("Ensure your full body stays visible to the camera.");
      return;
    }

    final leftShoulderOffset = Offset(leftShoulder.x, leftShoulder.y);
    final rightShoulderOffset = Offset(rightShoulder.x, rightShoulder.y);
    final leftElbowOffset = Offset(leftElbow.x, leftElbow.y);
    final rightElbowOffset = Offset(rightElbow.x, rightElbow.y);
    final leftWristOffset = Offset(leftWrist.x, leftWrist.y);
    final rightWristOffset = Offset(rightWrist.x, rightWrist.y);
    final leftHipOffset = Offset(leftHip.x, leftHip.y);
    final rightHipOffset = Offset(rightHip.x, rightHip.y);

    // Calculate angles
    final elbowAngleLeft = _calculateAngle(leftShoulderOffset, leftElbowOffset, leftWristOffset);
    final elbowAngleRight = _calculateAngle(rightShoulderOffset, rightElbowOffset, rightWristOffset);
    final avgElbowAngle = (elbowAngleLeft + elbowAngleRight) / 2;

    final kneeAngleLeft = _calculateAngle(leftHipOffset, Offset(leftKnee.x, leftKnee.y), Offset(leftAnkle.x, leftAnkle.y));
    final kneeAngleRight = _calculateAngle(rightHipOffset, Offset(rightKnee.x, rightKnee.y), Offset(rightAnkle.x, rightAnkle.y));

    final hipAngleLeft = _calculateAngle(leftShoulderOffset, leftHipOffset, Offset(leftKnee.x, leftKnee.y));
    final hipAngleRight = _calculateAngle(rightShoulderOffset, rightHipOffset, Offset(rightKnee.x, rightKnee.y));
    final hipAngle = (hipAngleLeft + hipAngleRight) / 2;

    final shoulderAngle = (_calculateAngle(leftHipOffset, leftShoulderOffset, leftElbowOffset) +
        _calculateAngle(rightHipOffset, rightShoulderOffset, rightElbowOffset)) / 2;

    final torsoAngle = _torsoAngleFromHorizontal(
      leftShoulderOffset,
      rightShoulderOffset,
      leftHipOffset,
      rightHipOffset,
    );

    // Update stability
    final poseStable = _updateStability(torsoAngle, avgElbowAngle);
    if (!poseStable) {
      _allFeedbacks.add("Hold still briefly for accurate feedback.");
      return;
    }

    // Track min/max during rep
    _minElbowAngleDuringRep = math.min(_minElbowAngleDuringRep, avgElbowAngle);
    _maxElbowAngleDuringRep = math.max(_maxElbowAngleDuringRep, avgElbowAngle);

    // Detect bottom and top positions
    final atBottom = (elbowAngleLeft >= _bottomElbowMin && elbowAngleLeft <= _bottomElbowMax) &&
        (elbowAngleRight >= _bottomElbowMin && elbowAngleRight <= _bottomElbowMax);
    final atTop = elbowAngleLeft >= _topElbowThreshold && elbowAngleRight >= _topElbowThreshold;

    if (atBottom) {
      _reachedBottom = true;
      _pendingLockoutCheck = true;
    }

    if (atTop) {
      if (!_pendingLockoutCheck) {
        _allFeedbacks.add("Lower the bar until elbows reach roughly 90°.");
        return;
      } else {
        _pendingLockoutCheck = false;
        _reachedBottom = false;
      }
    }

    // Rep detection: started down, reached bottom, now at top
    if (!_startedDown && avgElbowAngle >= _topElbowThreshold) {
      _startedDown = true;
    }

    if (_startedDown && !_reachedBottom && atBottom) {
      _reachedBottom = true;
    }

    if (_startedDown && _reachedBottom && atTop) {
      _benchPressCount++;

      bool isCorrect = true;
      String correction = "";

      // Check form errors
      final flareAngleLeft = _calculateAngle(leftElbowOffset, leftShoulderOffset, leftWristOffset);
      final flareAngleRight = _calculateAngle(rightElbowOffset, rightShoulderOffset, rightWristOffset);

      if (flareAngleLeft < _minFlareAngle || flareAngleRight < _minFlareAngle) {
        isCorrect = false;
        correction = "Keep elbows ~45° from the torso to avoid flaring.";
      }

      if (shoulderAngle < _minShoulderAngle || shoulderAngle > _maxShoulderAngle) {
        isCorrect = false;
        correction = "Pinch shoulder blades (20°–45°) to stay retracted.";
      }

      final wristStackLeft = _verticalStackAngle(leftWristOffset, leftElbowOffset);
      final wristStackRight = _verticalStackAngle(rightWristOffset, rightElbowOffset);
      if (wristStackLeft > _maxWristStackAngle || wristStackRight > _maxWristStackAngle) {
        isCorrect = false;
        correction = "Stack wrists directly above elbows; bar is drifting.";
      }

      final legImbalance = (kneeAngleLeft - kneeAngleRight).abs();
      if (legImbalance > _maxLegImbalance) {
        isCorrect = false;
        correction = "Drive evenly through both feet to stay stable.";
      }

      if (hipAngle < _minHipAngle) {
        isCorrect = false;
        correction = "Keep hips glued to the bench—avoid excessive bridging.";
      }

      if (_pendingLockoutCheck &&
          !atTop &&
          !atBottom &&
          _previousElbowForStability != null &&
          avgElbowAngle < _previousElbowForStability! - 5) {
        isCorrect = false;
        correction = "Press through until the elbows lock out (160°+).";
      }

      if (isCorrect) {
        _correctCount++;
        _lastRepCorrect = true;
        _allFeedbacks.add("Correct form!");
      } else {
        _wrongCount++;
        _feedback.add("Rep $_benchPressCount: $correction");
        _allFeedbacks.add(correction);
        _lastRepCorrect = false;
      }

      _startedDown = false;
      _reachedBottom = false;
      _minElbowAngleDuringRep = 180.0;
      _maxElbowAngleDuringRep = 0.0;

      if (_benchPressCount >= 5) {
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

    _previousElbowForStability = avgElbowAngle;
  }

  double _torsoAngleFromHorizontal(
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
    return math.atan2(torso.dy.abs(), torso.dx.abs() + 1e-6) * 180 / math.pi;
  }

  double _verticalStackAngle(Offset upper, Offset lower) {
    final dx = (upper.dx - lower.dx).abs();
    final dy = (upper.dy - lower.dy).abs() + 1e-6;
    return math.atan2(dx, dy) * 180 / math.pi;
  }

  bool _updateStability(double torsoAngle, double elbowAngle) {
    if (_previousTorsoAngle != null) {
      final delta = (torsoAngle - _previousTorsoAngle!).abs();
      _torsoDrift = _torsoDrift * 0.7 + delta * 0.3;
    }
    if (_previousElbowForStability != null) {
      final delta = (elbowAngle - _previousElbowForStability!).abs();
      _elbowDrift = _elbowDrift * 0.7 + delta * 0.3;
    }
    _previousTorsoAngle = torsoAngle;
    _previousElbowForStability = elbowAngle;
    return _torsoDrift < _maxTorsoDrift && _elbowDrift < _maxElbowDrift;
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
      appBar: AppBar(title: const Text("Bench Press Exercise")),
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
