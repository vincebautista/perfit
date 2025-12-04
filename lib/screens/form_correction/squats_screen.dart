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

  // --- ADDED BY AI: State for Skeleton Overlay ---
  Pose? _lastPose;
  Size? _cameraImageSize; // Raw resolution of the camera sensor
  InputImageRotation? _imageRotation; // Rotation of the image
  // ----------------------------------------------

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

  // To track UI color state
  bool _lastRepCorrect = true;

  bool _rightStartedDown = false;
  bool _rightReachedUp = false;
  double _rightMinElbowAngleDuringRep =
      180.0; // Variable reused for knee tracking

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

    // --- ADDED BY AI: Capture Image Metadata for Painter ---
    _cameraImageSize ??= Size(image.width.toDouble(), image.height.toDouble());

    final sensorOrientation =
        _cameraService.controller!.description.sensorOrientation;
    _imageRotation ??=
        InputImageRotationValue.fromRawValue(sensorOrientation) ??
        InputImageRotation.rotation0deg;
    // -----------------------------------------------------

    try {
      final inputImage = _cameraImageToInputImage(image, sensorOrientation);

      final poses = await _poseService.detectPoses(inputImage);

      // If no pose detected, clear the last pose so the skeleton disappears
      if (poses.isEmpty) {
        _lastPose = null;
        return;
      }

      final pose = poses.first;

      // --- ADDED BY AI: Update Pose for UI ---
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
      return;
    }

    // --- SQUAT LOGIC START ---

    // Angles
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

    // Torso from vertical (upright between 70°–100°).
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
        math.atan2(torsoVec.dx.abs(), torsoVec.dy.abs() + 1e-6) * 180 / math.pi;

    // Stability: both legs should move similarly.
    final kneeDiff = (kneeAngleLeft - kneeAngleRight).abs();
    final hipDiff = (hipAngleLeft - hipAngleRight).abs();
    if (kneeDiff > 25 || hipDiff > 25) {
      return;
    }

    // Depth states based on average knee angle.
    final avgKnee = (kneeAngleLeft + kneeAngleRight) / 2;
    const depthMin = 80.0;
    const depthMax = 110.0;
    const shallowThresh = 140.0;
    final atBottom = avgKnee >= depthMin && avgKnee <= depthMax;
    final atTop = avgKnee >= shallowThresh;

    bool formGood = true;
    String correction = "";

    // 1. Torso too far forward/back.
    if (torsoAngle < 70 || torsoAngle > 100) {
      formGood = false;
      correction = "Keep chest up.";
    }

    // 2. Hip angle – avoid excessive lean.
    if (formGood && (hipAngle < 70 || hipAngle > 110)) {
      formGood = false;
      correction = "Stay relatively upright.";
    }

    // 3. Knee tracking – knees not too far past toes.
    final leftKneeForward = _kneeOverAnkle(
      Offset(leftKnee.x, leftKnee.y),
      Offset(leftAnkle.x, leftAnkle.y),
    );
    final rightKneeForward = _kneeOverAnkle(
      Offset(rightKnee.x, rightKnee.y),
      Offset(rightAnkle.x, rightAnkle.y),
    );
    if (formGood && (leftKneeForward > 15 || rightKneeForward > 15)) {
      formGood = false;
      correction = "Knees too far forward.";
    }

    // 4. Hip shift – left vs right hip angle.
    if (formGood && (hipAngleLeft - hipAngleRight).abs() > 15) {
      formGood = false;
      correction = "Don't shift weight to one side.";
    }

    // Rep state-machine.
    _rightMinElbowAngleDuringRep = math.min(
      _rightMinElbowAngleDuringRep,
      avgKnee,
    );

    if (!_rightStartedDown && atTop) {
      _rightStartedDown = true;
    }
    if (_rightStartedDown && !_rightReachedUp && atBottom) {
      _rightReachedUp = true;
    }

    if (_rightStartedDown && _rightReachedUp && atTop) {
      _squatCount++;

      if (!formGood || !atBottom) {
        _wrongCount++;
        _lastRepCorrect = false;

        String finalFeedback =
            correction.isNotEmpty ? correction : "Squat deeper (80°–110°)";

        _feedback.add("Rep $_squatCount: $finalFeedback");
      } else {
        _correctCount++;
        _lastRepCorrect = true;
        _feedback.add("Correct form!");
      }

      // Reset
      _rightStartedDown = false;
      _rightReachedUp = false;
      _rightMinElbowAngleDuringRep = 180.0;

      if (_squatCount >= 5) {
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

  double _kneeOverAnkle(Offset knee, Offset ankle) {
    final dx = (knee.dx - ankle.dx).abs();
    final dy = (knee.dy - ankle.dy).abs() + 1e-6;
    return math.atan2(dx, dy) * 180 / math.pi;
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
        if (_feedback.isNotEmpty) {
          displayMessage = _feedback.last;
          // Use the result of the last rep to determine color
          bgColor = _lastRepCorrect ? AppColors.green : AppColors.red;
        } else {
          displayMessage = "Start your Squats!";
          bgColor = AppColors.primary;
        }
        break;
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Squats Exercise")),
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

                // --- ADDED BY AI: Pose Skeleton Overlay ---
                // LayoutBuilder ensures we get the exact display size of the camera preview
                // to correctly scale the skeleton landmarks.
                if (_lastPose != null &&
                    _cameraImageSize != null &&
                    _imageRotation != null)
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final widgetSize = Size(
                        constraints.maxWidth,
                        constraints.maxHeight,
                      );
                      final controller = _cameraService.controller!;
                      final isFront =
                          controller.description.lensDirection ==
                          CameraLensDirection.front;

                      return CustomPaint(
                        painter: PosePainter(
                          pose: _lastPose!,
                          imageSize: _cameraImageSize!,
                          widgetSize: widgetSize,
                          rotation: _imageRotation!,
                          isFrontCamera: isFront,
                        ),
                        size: widgetSize,
                      );
                    },
                  ),

                // ------------------------------------------
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

// --- ADDED BY AI: Pose Painter Class ---
// Responsible for translating ML Kit coordinates to Screen coordinates
// and drawing the skeleton.
class PosePainter extends CustomPainter {
  final Pose pose;
  final Size imageSize;
  final Size widgetSize;
  final InputImageRotation rotation;
  final bool isFrontCamera;

  PosePainter({
    required this.pose,
    required this.imageSize,
    required this.widgetSize,
    required this.rotation,
    required this.isFrontCamera,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Paints for different parts
    final whitePaint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.0
          ..color = Colors.white;

    final leftPaint =
        Paint()
          ..style = PaintingStyle.fill
          ..color = const Color.fromRGBO(255, 138, 0, 1); // Orange for left

    final rightPaint =
        Paint()
          ..style = PaintingStyle.fill
          ..color = const Color.fromRGBO(0, 217, 245, 1); // Cyan for right

    // Define connections (Bone structure)
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
        final start = _translateX(
          startLandmark.x,
          startLandmark.y,
          imageSize,
          widgetSize,
          rotation,
          isFrontCamera,
        );
        final end = _translateX(
          endLandmark.x,
          endLandmark.y,
          imageSize,
          widgetSize,
          rotation,
          isFrontCamera,
        );
        canvas.drawLine(start, end, whitePaint);
      }
    }

    // Draw Landmarks
    pose.landmarks.forEach((_, landmark) {
      final point = _translateX(
        landmark.x,
        landmark.y,
        imageSize,
        widgetSize,
        rotation,
        isFrontCamera,
      );

      if (landmark.type.name.toLowerCase().contains('left')) {
        canvas.drawCircle(point, 5, leftPaint);
      } else if (landmark.type.name.toLowerCase().contains('right')) {
        canvas.drawCircle(point, 5, rightPaint);
      } else {
        canvas.drawCircle(point, 5, whitePaint..style = PaintingStyle.fill);
      }
    });
  }

  // Helper method to translate coordinates
  Offset _translateX(
    double x,
    double y,
    Size absoluteImageSize,
    Size screenWidgetSize,
    InputImageRotation rotation,
    bool isFront,
  ) {
    // 1. Determine if we need to swap width/height based on rotation
    // Mobile sensors are landscape, but screen is portrait.
    final bool isPortrait =
        rotation == InputImageRotation.rotation90deg ||
        rotation == InputImageRotation.rotation270deg;

    final double imageWidth =
        isPortrait ? absoluteImageSize.height : absoluteImageSize.width;
    final double imageHeight =
        isPortrait ? absoluteImageSize.width : absoluteImageSize.height;

    // 2. Calculate scale factors (Cover)
    double scaleX = screenWidgetSize.width / imageWidth;
    double scaleY = screenWidgetSize.height / imageHeight;
    final double scale = math.max(scaleX, scaleY);

    // 3. Center the image (Offset)
    final double scaledImageWidth = imageWidth * scale;
    final double scaledImageHeight = imageHeight * scale;
    final double offsetX = (scaledImageWidth - screenWidgetSize.width) / 2;
    final double offsetY = (scaledImageHeight - screenWidgetSize.height) / 2;

    // 4. Transform coordinates
    double finalX = x * scale - offsetX;
    double finalY = y * scale - offsetY;

    // 5. Mirror X for front camera (Selfie view)
    if (isFront) {
      finalX = screenWidgetSize.width - finalX;
    }

    return Offset(finalX, finalY);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
