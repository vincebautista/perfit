import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

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

  // --- Split Squat Specific State Variables ---
  int _squatCount = 0;
  int _correctCount = 0;
  int _wrongCount = 0;
  List<String> _allFeedbacks = [];

  // Rep State Tracking
  bool _isAtBottom = false; // Has the user reached depth?
  bool _hasStartedRep = false; // Is the user currently performing a rep?
  bool _currentRepFailed =
      false; // Did they make a mistake in this specific rep?
  String _currentRepError = ""; // The specific error for this rep

  // Stability Tracking
  double? _previousTorsoAngle;
  double? _previousHipAngleLeft;
  double? _previousHipAngleRight;
  double _torsoDrift = 0;
  double _hipDrift = 0;

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

    _cameraImageSize = Size(image.width.toDouble(), image.height.toDouble());

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
    // Split squat might require seeing feet, so slightly further back is better
    const minCm = 120;
    const maxCm = 250;

    if (distanceCm < minCm) {
      distanceStatus = "Too Close! Move back so we see your feet.";
    } else if (distanceCm > maxCm) {
      distanceStatus = "Too Far! Move closer.";
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
      handsStatus = "Raise your hand to start!";
      countdownStatus = "";
    }
  }

  // ---------------------------------------------------------------------------
  // SPLIT SQUAT LOGIC
  // ---------------------------------------------------------------------------
  Future<void> _handleFormCorrection(Pose pose) async {
    final landmarks = pose.landmarks;

    // Check availability of required landmarks
    final requiredTypes = [
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.rightShoulder,
      PoseLandmarkType.leftHip,
      PoseLandmarkType.rightHip,
      PoseLandmarkType.leftKnee,
      PoseLandmarkType.rightKnee,
      PoseLandmarkType.leftAnkle,
      PoseLandmarkType.rightAnkle,
    ];

    if (requiredTypes.any((t) => landmarks[t] == null)) {
      // If we can't see the body, do nothing this frame
      return;
    }

    final handsUp = _gestureService.update(
      pose,
      startCountdown: 1, // 1 second hold
      onHoldProgress: (progress) {
        countdownStatus = "Hold hands up… ${(progress * 100).toInt()}%";
      },
      onHandsUpDetected: () async {
        // Stop camera and go to summary
        await _cameraService.controller?.stopImageStream();
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
      },
    );

    final leftShoulder = landmarks[PoseLandmarkType.leftShoulder]!;
    final rightShoulder = landmarks[PoseLandmarkType.rightShoulder]!;
    final leftHip = landmarks[PoseLandmarkType.leftHip]!;
    final rightHip = landmarks[PoseLandmarkType.rightHip]!;
    final leftKnee = landmarks[PoseLandmarkType.leftKnee]!;
    final rightKnee = landmarks[PoseLandmarkType.rightKnee]!;
    final leftAnkle = landmarks[PoseLandmarkType.leftAnkle]!;
    final rightAnkle = landmarks[PoseLandmarkType.rightAnkle]!;

    // --- Calculations ---
    // Assuming Left Leg is Front (standardize or detect based on depth)
    // A simple heuristic: The ankle with the higher Y value (lower on screen) is closer to camera usually,
    // but for Split Squat, we usually assume user sets up with Left forward for this logic.

    double kneeAngleLeft = _calculateAngle3Points(leftHip, leftKnee, leftAnkle);
    double kneeAngleRight = _calculateAngle3Points(
      rightHip,
      rightKnee,
      rightAnkle,
    );
    double hipAngleLeft = _calculateAngle3Points(
      leftShoulder,
      leftHip,
      leftKnee,
    );
    double hipAngleRight = _calculateAngle3Points(
      rightShoulder,
      rightHip,
      rightKnee,
    );
    double torsoAngle = _torsoAngleFromVertical(
      leftShoulder,
      rightShoulder,
      leftHip,
      rightHip,
    );

    // Use Left Leg as Front Leg for calculation
    final frontKneeAngle = kneeAngleLeft;
    final backKneeAngle = kneeAngleRight; // Right leg is rear

    // --- State Management ---

    // 1. Standing Position (Start/End of Rep)
    // Front knee is extended (> 150 degrees usually)
    bool isStanding = frontKneeAngle > 150;

    // 2. Bottom Position (Active part of Rep)
    // Front knee bent (80 - 100 degrees)
    bool isBottomFrame = frontKneeAngle >= 70 && frontKneeAngle <= 110;

    // --- Logic Loop ---

    if (isStanding) {
      if (_hasStartedRep && _isAtBottom) {
        // Rep Completed
        _squatCount++;

        if (!_currentRepFailed) {
          _correctCount++;
          _lastRepCorrect = true;
          _allFeedbacks.add("Great Rep!");
        } else {
          _wrongCount++;
          _lastRepCorrect = false;
          _allFeedbacks.add("Rep $_squatCount: $_currentRepError");
        }

        // Check for completion
        if (_squatCount >= 5) {
          await _finishExercise();
          return;
        }
      }

      // Reset Rep State
      _hasStartedRep = false;
      _isAtBottom = false;
      _currentRepFailed = false;
      _currentRepError = "";
    } else if (frontKneeAngle < 150) {
      // We are moving down or up
      _hasStartedRep = true;

      // Check for Bottom
      if (isBottomFrame) {
        _isAtBottom = true;
      }

      // --- Error Checks (Active during movement) ---

      // 1. Torso Alignment (Leaning too far forward or back)
      if (torsoAngle < 70 || torsoAngle > 110) {
        _currentRepFailed = true;
        _currentRepError = "Keep torso upright.";
      }

      // 2. Knee Stability (Knee collapsing inward)
      double kneeCollapse = _kneeCollapseInward(
        hip: leftHip,
        knee: leftKnee,
        ankle: leftAnkle,
      );
      if (kneeCollapse > 15) {
        _currentRepFailed = true;
        _currentRepError = "Push front knee out.";
      }

      // 3. Knee Over Ankle (Front knee too far forward)
      double kneeForward = _kneeOverAnkle(knee: leftKnee, ankle: leftAnkle);
      if (kneeForward > 15) {
        // Threshold for toes
        _currentRepFailed = true;
        _currentRepError = "Knee passing toes.";
      }

      // 4. Back Knee Depth (At bottom, back knee should be bent ~90)
      if (_isAtBottom && backKneeAngle > 120) {
        // If at bottom but back leg is straight, it's a lunge not a split squat
        _currentRepFailed = true;
        _currentRepError = "Bend back knee more.";
      }
    }
  }

  Future<void> _finishExercise() async {
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

  // --- Math Helpers ---

  double _calculateAngle3Points(
    PoseLandmark a,
    PoseLandmark b,
    PoseLandmark c,
  ) {
    final abX = a.x - b.x;
    final abY = a.y - b.y;
    final cbX = c.x - b.x;
    final cbY = c.y - b.y;
    final dot = abX * cbX + abY * cbY;
    final magAB = math.sqrt(abX * abX + abY * abY);
    final magCB = math.sqrt(cbX * cbX + cbY * cbY);
    final cosine = (dot / (magAB * magCB)).clamp(-1.0, 1.0);
    return math.acos(cosine) * 180 / math.pi;
  }

  double _torsoAngleFromVertical(
    PoseLandmark leftShoulder,
    PoseLandmark rightShoulder,
    PoseLandmark leftHip,
    PoseLandmark rightHip,
  ) {
    final shoulderX = (leftShoulder.x + rightShoulder.x) / 2;
    final shoulderY = (leftShoulder.y + rightShoulder.y) / 2;
    final hipX = (leftHip.x + rightHip.x) / 2;
    final hipY = (leftHip.y + rightHip.y) / 2;

    final dx = (shoulderX - hipX).abs();
    final dy = (shoulderY - hipY).abs() + 1e-6;
    return math.atan2(dx, dy) * 180 / math.pi;
  }

  double _kneeOverAnkle({
    required PoseLandmark knee,
    required PoseLandmark ankle,
  }) {
    final dx = (knee.x - ankle.x).abs();
    final dy = (knee.y - ankle.y).abs() + 1e-6;
    return math.atan2(dx, dy) * 180 / math.pi;
  }

  double _kneeCollapseInward({
    required PoseLandmark hip,
    required PoseLandmark knee,
    required PoseLandmark ankle,
  }) {
    final hipToAnkleDx = ankle.x - hip.x;
    final hipToAnkleDy = ankle.y - hip.y;
    final hipToKneeDx = knee.x - hip.x;
    final hipToKneeDy = knee.y - hip.y;

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

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized || _cameraService.controller == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

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
          displayMessage = "Go down into the Split Squat.";
          bgColor = AppColors.primary;
        }
        break;
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Split Squat Exercise")),
      body: Column(
        children: [
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
              fit: StackFit.expand,
              children: [
                // 1. Camera
                CameraPreview(_cameraService.controller!),

                // 2. Skeleton
                if (_lastPose != null && _cameraImageSize != null)
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final widgetSize = Size(
                        constraints.maxWidth,
                        constraints.maxHeight,
                      );
                      final controller = _cameraService.controller!;
                      final sensorOrientation =
                          controller.description.sensorOrientation;
                      final isFront =
                          controller.description.lensDirection ==
                          CameraLensDirection.front;

                      Color skeletonColor = AppColors.primary;

                      if (currentStage == ExerciseStage.formCorrection) {
                        skeletonColor =
                            _allFeedbacks.isNotEmpty
                                ? (_lastRepCorrect
                                    ? AppColors.green
                                    : AppColors.red)
                                : AppColors.primary;
                      }

                      return CustomPaint(
                        painter: PosePainter(
                          pose: _lastPose!,
                          imageSize: _cameraImageSize!,
                          widgetSize: widgetSize,
                          sensorOrientation: sensorOrientation,
                          isFrontCamera: isFront,
                          skeletonColor: skeletonColor,
                        ),
                        size: widgetSize,
                      );
                    },
                  ),

                // 3. Corners
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

// ---------------------------------------------------------------------------
// PAINTERS (Same as previous screen, reused for consistency)
// ---------------------------------------------------------------------------

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

class PosePainter extends CustomPainter {
  final Pose pose;
  final Size imageSize;
  final Size widgetSize;
  final int sensorOrientation;
  final bool isFrontCamera;
  final Color skeletonColor;

  PosePainter({
    required this.pose,
    required this.imageSize,
    required this.widgetSize,
    required this.sensorOrientation,
    required this.isFrontCamera,
    required this.skeletonColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paintLine =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4.0
          ..color = skeletonColor;
    final paintJoint =
        Paint()
          ..style = PaintingStyle.fill
          ..color = skeletonColor;

    final connections = [
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

    for (final connection in connections) {
      final start = pose.landmarks[connection[0]];
      final end = pose.landmarks[connection[1]];
      if (start != null && end != null) {
        canvas.drawLine(
          _translate(
            start.x,
            start.y,
            imageSize,
            widgetSize,
            sensorOrientation,
            isFrontCamera,
          ),
          _translate(
            end.x,
            end.y,
            imageSize,
            widgetSize,
            sensorOrientation,
            isFrontCamera,
          ),
          paintLine,
        );
      }
    }

    pose.landmarks.forEach((_, landmark) {
      canvas.drawCircle(
        _translate(
          landmark.x,
          landmark.y,
          imageSize,
          widgetSize,
          sensorOrientation,
          isFrontCamera,
        ),
        5,
        paintJoint,
      );
    });
  }

  Offset _translate(
    double x,
    double y,
    Size absoluteImageSize,
    Size widgetSize,
    int rotation,
    bool isFront,
  ) {
    final double imageWidth =
        (rotation == 90 || rotation == 270)
            ? absoluteImageSize.height
            : absoluteImageSize.width;
    final double imageHeight =
        (rotation == 90 || rotation == 270)
            ? absoluteImageSize.width
            : absoluteImageSize.height;
    double scaleX = widgetSize.width / imageWidth;
    double scaleY = widgetSize.height / imageHeight;
    double screenX = x * scaleX;
    double screenY = y * scaleY;
    if (isFront) screenX = widgetSize.width - screenX;
    return Offset(screenX, screenY);
  }

  @override
  bool shouldRepaint(covariant PosePainter oldDelegate) {
    return oldDelegate.pose != pose ||
        oldDelegate.imageSize != imageSize ||
        oldDelegate.widgetSize != widgetSize;
  }
}
