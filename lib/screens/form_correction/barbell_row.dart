import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:io'; // Needed for Platform checks if necessary

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

  // --- ADDED: Track Pose, Size, and Rotation for the Painter ---
  Pose? _lastPose;
  Size? _cameraImageSize; // Raw size of the image from the camera sensor
  InputImageRotation? _imageRotation; // Rotation of the camera image
  // -----------------------------------------------------------

  ExerciseStage currentStage = ExerciseStage.distanceCheck;

  String distanceStatus = "Checking distance...";
  String handsStatus = "Raise your right hand above the head";
  String countdownStatus = "";
  int countdown = 3;

  // Form correction variables
  int _rowCount = 0;
  int _correctCount = 0;
  int _wrongCount = 0;
  List<String> _feedbackList = [];

  bool _startedRep = false;
  bool isAtTop = false;
  double _previousTorsoAngle = 0.0;
  double _torsoAngleVariance = 0.0;

  String _currentFeedback = "";
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

    // --- ADDED: Capture image metadata for alignment ---
    _cameraImageSize ??= Size(image.width.toDouble(), image.height.toDouble());

    final sensorOrientation =
        _cameraService.controller!.description.sensorOrientation;
    _imageRotation ??=
        InputImageRotationValue.fromRawValue(sensorOrientation) ??
        InputImageRotation.rotation0deg;
    // --------------------------------------------------

    try {
      final inputImage = _cameraImageToInputImage(image, sensorOrientation);

      final poses = await _poseService.detectPoses(inputImage);
      if (poses.isEmpty) {
        // Clear pose if none detected so overlay disappears
        _lastPose = null;
        return;
      }

      final pose = poses.first;
      _lastPose = pose; // Trigger repaint

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
                  feedbacks: _feedbackList,
                ),
          ),
        );
      },
    );

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
      _currentFeedback = "Ensure all body parts are visible";
      _lastRepCorrect = false;
      return;
    }

    // --- BARBELL ROW LOGIC ---

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
      _currentFeedback = "Please ensure both arms are visible";
      _lastRepCorrect = false;
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

    // Form error detection
    List<String> errors = [];

    // 1. Rounded back check
    if (torsoAngle < 40 || torsoAngle > 80) {
      errors.add("Keep back straight");
    }
    // Check torso wobble
    if (_torsoAngleVariance > 15) {
      errors.add("Stabilize torso");
    }

    // 2. Insufficient hip hinge
    if (hipAngle > 100) {
      errors.add("Hinge more at hips");
    }

    // 3. Elbows not pulling correctly
    if (isAtTop && (avgElbowAngle < 70 || avgElbowAngle > 110)) {
      errors.add("Pull elbows to 90°");
    }

    // 4. Shrugging (Shoulder Elevation)
    final shoulderElevation = (avgShoulder.dy - avgHip.dy).abs();
    final torsoLength = math.sqrt(
      (avgShoulder.dx - avgHip.dx) * (avgShoulder.dx - avgHip.dx) +
          (avgShoulder.dy - avgHip.dy) * (avgShoulder.dy - avgHip.dy),
    );
    if (torsoLength > 0) {
      final elevationRatio = shoulderElevation / torsoLength;
      if (elevationRatio > 0.3 && isAtTop) {
        errors.add("Don't shrug shoulders");
      }
    }

    // Set Live Feedback Logic
    if (errors.isNotEmpty) {
      _currentFeedback = errors.join(". ");
      _lastRepCorrect = false;
    } else {
      if (isAtTop) {
        _currentFeedback = "Squeeze back! Good form.";
        _lastRepCorrect = true;
      } else {
        _currentFeedback = "Pull barbell up";
        _lastRepCorrect = true;
      }
    }

    // Rep counting logic
    if (!_startedRep && avgElbowAngle > 150) {
      _startedRep = true;
      _torsoAngleVariance = 0.0;
    }

    // Complete rep when returning to starting position
    if (_startedRep && isAtTop && avgElbowAngle > 150) {
      _rowCount++;

      if (errors.isEmpty) {
        _correctCount++;
        _feedbackList.add("Correct form!");
        _lastRepCorrect = true;
      } else {
        _wrongCount++;
        _feedbackList.add("Rep $_rowCount: ${errors.join(", ")}");
        _lastRepCorrect = false;
      }

      // Reset for next rep
      _startedRep = false;
      _torsoAngleVariance = 0.0;

      // Stop after 5 reps
      if (_rowCount >= 5) {
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
          displayMessage = "Start Rowing!";
          bgColor = AppColors.primary;
        }
        break;
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Barbell Row")),
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

                // --- MODIFIED: Added Pose Painting Logic with LayoutBuilder ---
                // We ensure we have a pose, image size, and rotation before drawing
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
                          lastRepCorrect: _lastRepCorrect,
                        ),
                        size: widgetSize,
                      );
                    },
                  ),

                // ---------------------------------------------
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

// --- REVISED: Robust Pose Painter for Correct Alignment ---
class PosePainter extends CustomPainter {
  final Pose pose;
  final Size imageSize;
  final Size widgetSize;
  final InputImageRotation rotation;
  final bool isFrontCamera;
  final bool lastRepCorrect;

  PosePainter({
    required this.pose,
    required this.imageSize,
    required this.widgetSize,
    required this.rotation,
    required this.isFrontCamera,
    required this.lastRepCorrect,
  });

  @override
  void paint(Canvas canvas, Size size) {
    Color bgColor;

    if (lastRepCorrect == true) {
      bgColor = AppColors.green;
    } else if (lastRepCorrect == true) {
      bgColor = AppColors.red;
    } else {
      bgColor = AppColors.primary;
    }

    // Styles
    final whitePaint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.0
          ..color = bgColor;

    final leftPaint =
        Paint()
          ..style = PaintingStyle.fill
          ..color = bgColor; // Orange for left

    final rightPaint =
        Paint()
          ..style = PaintingStyle.fill
          ..color = bgColor; // Cyan for right

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

    // Draw connections (Bones)
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

    // Draw landmarks (Joints)
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

  // Helper method to translate coordinates to screen
  Offset _translateX(
    double x,
    double y,
    Size absoluteImageSize,
    Size screenWidgetSize,
    InputImageRotation rotation,
    bool isFront,
  ) {
    // 1. Determine if we need to swap width/height.
    // In Portrait mode, the sensor image (landscape) is rotated 90 or 270 degrees.
    // However, ML Kit returns coordinates relative to the *upright* image.
    // So we treat the ML Kit X as Screen X and ML Kit Y as Screen Y,
    // but we must calculate the scale based on the "upright" image dimensions.

    // Check if rotation is 90 or 270 (Portrait orientations)
    final bool isPortrait =
        rotation == InputImageRotation.rotation90deg ||
        rotation == InputImageRotation.rotation270deg;

    // If portrait, the effective image width for scaling is the sensor height,
    // and effective height is sensor width.
    final double imageWidth =
        isPortrait ? absoluteImageSize.height : absoluteImageSize.width;
    final double imageHeight =
        isPortrait ? absoluteImageSize.width : absoluteImageSize.height;

    // 2. Calculate scale factors
    // We assume CameraPreview acts as BoxFit.cover (fills the screen).
    // We calculate the scale for width and height and take the MAX (to cover).
    double scaleX = screenWidgetSize.width / imageWidth;
    double scaleY = screenWidgetSize.height / imageHeight;

    // For BoxFit.cover, use the larger scale
    final double scale = math.max(scaleX, scaleY);

    // 3. Calculate offset to center the image (since it's cropped)
    // The "virtual" displayed image size
    final double scaledImageWidth = imageWidth * scale;
    final double scaledImageHeight = imageHeight * scale;

    // How much is cut off?
    final double offsetX = (scaledImageWidth - screenWidgetSize.width) / 2;
    final double offsetY = (scaledImageHeight - screenWidgetSize.height) / 2;

    // 4. Transform coordinates
    double finalX = x * scale - offsetX;
    double finalY = y * scale - offsetY;

    // 5. Mirror X for front camera
    if (isFront) {
      finalX = screenWidgetSize.width - finalX;
    }

    return Offset(finalX, finalY);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
