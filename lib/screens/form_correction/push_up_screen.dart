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

  // --- NEW: Variables for Skeleton Overlay ---
  Pose? _currentPose;
  Size _inputImageSize = Size.zero;
  // -----------------------------------------

  ExerciseStage currentStage = ExerciseStage.distanceCheck;

  String distanceStatus = "Checking distance...";
  String handsStatus = "Raise your right hand above the head";
  String countdownStatus = "";
  int countdown = 3;

  // Form correction variables
  int _pushUpCount = 0;
  int _correctCount = 0;
  int _wrongCount = 0;
  List<String> _feedback = [];

  bool _lastRepCorrect = true;
  bool _startedDown = false;
  bool _reachedUp = false;
  double _minElbowAngleDuringRep = 180.0;

  Pose? _lastPose;
  Size? _cameraImageSize;

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
                  feedbacks: _feedback,
                ),
          ),
        );
      },
    );

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
      return;
    }

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

    final kneeDiff = (kneeAngleLeft - kneeAngleRight).abs();
    final hipDiff = (hipAngleLeft - hipAngleRight).abs();

    if (kneeDiff > 25 || hipDiff > 25) {
      return;
    }

    const downMin = 80.0;
    const downMax = 100.0;
    const upMin = 160.0;

    final atBottom = elbowAngleRight >= downMin && elbowAngleRight <= downMax;
    final atTop = elbowAngleRight >= upMin;

    bool formGood = true;
    String correction = "";

    if (hipAngle < torsoAngle - 15) {
      formGood = false;
      correction = "Lift hips slightly.";
    } else if (hipAngle > torsoAngle + 15) {
      formGood = false;
      correction = "Lower hips (no piking).";
    }

    if (formGood && (torsoAngle < 150 || torsoAngle > 190)) {
      formGood = false;
      correction = "Keep torso straight.";
    }

    final flareAngleRight = _calculateAngle(
      Offset(rightElbow.x, rightElbow.y),
      Offset(rightShoulder.x, rightShoulder.y),
      Offset(rightWrist.x, rightWrist.y),
    );
    if (formGood && flareAngleRight < 45) {
      formGood = false;
      correction = "Don't flare elbows.";
    }

    _minElbowAngleDuringRep = math.min(
      _minElbowAngleDuringRep,
      elbowAngleRight,
    );

    if (!_startedDown && atTop) {
      _startedDown = true;
    }
    if (_startedDown && !_reachedUp && atBottom) {
      _reachedUp = true;
    }

    if (_startedDown && _reachedUp && atTop) {
      _pushUpCount++;

      if (!formGood ||
          _minElbowAngleDuringRep < downMin ||
          _minElbowAngleDuringRep > downMax) {
        _wrongCount++;
        if (_minElbowAngleDuringRep > downMax) correction = "Go lower (90°)";
        if (_minElbowAngleDuringRep < downMin) correction = "Don't go too low";

        _feedback.add("Rep $_pushUpCount: $correction");
        _lastRepCorrect = false;
      } else {
        _correctCount++;
        _feedback.add("Good Pushup!");
        _lastRepCorrect = true;
      }

      _startedDown = false;
      _reachedUp = false;
      _minElbowAngleDuringRep = 180.0;

      if (_pushUpCount >= 5) {
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
        displayMessage =
            countdownStatus.isNotEmpty ? countdownStatus : handsStatus;
        if (displayMessage.toLowerCase().contains("raise")) {
          bgColor = AppColors.red;
        } else if (displayMessage.toLowerCase().contains("detected") ||
            displayMessage.toLowerCase().contains("complete")) {
          bgColor = AppColors.green;
        } else {
          bgColor = AppColors.primary;
        }
        break;

      case ExerciseStage.formCorrection:
        if (_feedback.isNotEmpty) {
          displayMessage = _feedback.last;
          if (displayMessage.contains("Rep") &&
              !displayMessage.contains("Good")) {
            bgColor = _lastRepCorrect ? AppColors.green : AppColors.red;
          } else if (displayMessage.contains("Good")) {
            bgColor = AppColors.green;
          } else {
            bgColor = AppColors.primary;
          }
        } else {
          displayMessage = "Perform 5 Push Ups";
          bgColor = AppColors.primary;
        }
        break;
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Push Up Exercise")),
      body: Column(
        children: [
          // 1. Top Message Banner
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

          // 2. Camera Area
          Expanded(
            child: Stack(
              children: [
                CameraPreview(_cameraService.controller!),

                // --- NEW: Skeleton Overlay Painter ---
                // Draws landmarks on top of the camera stream
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
                            _feedback.isNotEmpty
                                ? (_lastRepCorrect
                                    ? AppColors.green
                                    : AppColors.red)
                                : AppColors.primary;
                      }

                      return CustomPaint(
                        painter: PosePainter(
                          pose: _lastPose!, // use _currentPose
                          imageSize: _cameraImageSize!, // use _inputImageSize
                          widgetSize: widgetSize,
                          sensorOrientation: sensorOrientation,
                          isFrontCamera: isFront,
                          skeletonColor: skeletonColor,
                        ),
                        size: widgetSize,
                      );
                    },
                  ),

                // -------------------------------------

                // Corner Overlay
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

          // 3. Stats Card
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

// --- NEW: PosePainter Class ---
// Draws the skeleton overlay using detected landmarks
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
    final paint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4.0
          ..color = skeletonColor; // Skeleton color

    final pointPaint =
        Paint()
          ..style = PaintingStyle.fill
          ..color = skeletonColor; // Joint color

    // Loop through all landmarks to draw connections
    // Define the skeletal connections (pairs of landmarks)
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

    // Draw Connections
    for (final connection in connections) {
      final startLandmark = pose.landmarks[connection[0]];
      final endLandmark = pose.landmarks[connection[1]];

      if (startLandmark != null && endLandmark != null) {
        final startOffset = _translate(
          startLandmark.x,
          startLandmark.y,
          imageSize,
          widgetSize,
          sensorOrientation,
          isFrontCamera,
        );
        final endOffset = _translate(
          endLandmark.x,
          endLandmark.y,
          imageSize,
          widgetSize,
          sensorOrientation,
          isFrontCamera,
        );

        canvas.drawLine(startOffset, endOffset, paint);
      }
    }

    // Draw Landmarks (Dots)
    pose.landmarks.forEach((_, landmark) {
      final offset = _translate(
        landmark.x,
        landmark.y,
        imageSize,
        widgetSize,
        sensorOrientation,
        isFrontCamera,
      );
      canvas.drawCircle(offset, 5, pointPaint);
    });
  }

  /// Helper to map camera coordinates to screen coordinates
  Offset _translate(
    double x,
    double y,
    Size absoluteImageSize,
    Size widgetSize,
    int rotation,
    bool isFront,
  ) {
    // We swap width and height for the image if the rotation is 90 or 270
    // (portrait mode usually implies this swap relative to sensor)
    final double imageWidth =
        (rotation == 90 || rotation == 270)
            ? absoluteImageSize.height
            : absoluteImageSize.width;
    final double imageHeight =
        (rotation == 90 || rotation == 270)
            ? absoluteImageSize.width
            : absoluteImageSize.height;

    // Calculate scale factors
    double scaleX = widgetSize.width / imageWidth;
    double scaleY = widgetSize.height / imageHeight;

    // Depending on fit, you might want to use the same scale for both to maintain aspect ratio
    // But usually CameraPreview fills the screen, so we stretch slightly or crop.
    // For simplicity, we scale independently to fit the widget bounds.

    double screenX = x * scaleX;
    double screenY = y * scaleY;

    // If using front camera, mirror the X axis
    if (isFront) {
      screenX = widgetSize.width - screenX;
    }

    return Offset(screenX, screenY);
  }

  @override
  bool shouldRepaint(covariant PosePainter oldDelegate) {
    return oldDelegate.pose != pose ||
        oldDelegate.imageSize != imageSize ||
        oldDelegate.widgetSize != widgetSize;
  }
}
// ------------------------------

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
