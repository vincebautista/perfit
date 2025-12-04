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
import 'package:perfit/widgets/walk_animation.dart';

class CurlUpScreen extends StatefulWidget {
  const CurlUpScreen({super.key});

  @override
  State<CurlUpScreen> createState() => _CurlUpScreenState();
}

enum ExerciseStage { distanceCheck, gestureDetection, formCorrection }

class _CurlUpScreenState extends State<CurlUpScreen> {
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
  int _rightCurlCount = 0;
  int _rightCorrectCount = 0;
  int _rightWrongCount = 0;
  List<String> _feedback = [];
  List<String> _allFeedbacks = [];

  bool _rightStartedDown = false;
  bool _rightReachedUp = false;
  double _rightMinElbowAngleDuringRep = 180.0;
  double _rightMaxShoulderAngleDuringRep = 0.0;

  // Thresholds
  final double _maxAllowedShoulderMovement = 60.0;
  final double _downThreshold = 165.0;
  final double _upThreshold = 50.0;
  final double _shoulderBySideThreshold = 45.0;
  final double _wristToShoulderTopRatio = 0.45;

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

    final rightShoulder = landmarks[PoseLandmarkType.rightShoulder];
    final rightElbow = landmarks[PoseLandmarkType.rightElbow];
    final rightWrist = landmarks[PoseLandmarkType.rightWrist];
    final rightHip = landmarks[PoseLandmarkType.rightHip];

    if (rightShoulder != null && rightElbow != null && rightWrist != null) {
      final s = Offset(rightShoulder.x, rightShoulder.y);
      final e = Offset(rightElbow.x, rightElbow.y);
      final w = Offset(rightWrist.x, rightWrist.y);

      final double elbowAngle = _calculateAngle(s, e, w);
      final bool canCheckShoulder = rightHip != null;

      final double shoulderAngle =
          canCheckShoulder
              ? _calculateAngle(Offset(rightHip.x, rightHip.y), s, e)
              : 0.0;

      double torsoLenRight =
          rightHip != null ? _distance(s, Offset(rightHip.x, rightHip.y)) : 1.0;

      final double wristShoulderNorm =
          _distance(w, s) / (torsoLenRight > 0 ? torsoLenRight : 1.0);

      final bool reachedTopByProximity =
          wristShoulderNorm <= _wristToShoulderTopRatio;

      final bool reachedTopByAngle = elbowAngle <= _upThreshold;

      final bool isArmUp = reachedTopByAngle && reachedTopByProximity;

      final bool upperArmBySide =
          !canCheckShoulder || (shoulderAngle < _shoulderBySideThreshold);

      final bool isArmDown = (elbowAngle >= _downThreshold) && upperArmBySide;

      _rightMinElbowAngleDuringRep = math.min(
        _rightMinElbowAngleDuringRep,
        elbowAngle,
      );

      if (_rightStartedDown && canCheckShoulder) {
        _rightMaxShoulderAngleDuringRep = math.max(
          _rightMaxShoulderAngleDuringRep,
          shoulderAngle,
        );
      }

      if (!_rightStartedDown && elbowAngle >= _downThreshold)
        _rightStartedDown = true;

      if (_rightStartedDown && !_rightReachedUp && elbowAngle <= 160.0)
        _rightReachedUp = true;

      if (_rightStartedDown && _rightReachedUp && isArmDown) {
        _rightCurlCount++;

        bool isCorrect = true;
        String correction = "";

        if (_rightMaxShoulderAngleDuringRep > _maxAllowedShoulderMovement) {
          isCorrect = false;
          correction = "Too much shoulder movement";
        }

        if (_rightMinElbowAngleDuringRep > _upThreshold) {
          isCorrect = false;
          correction = "Under-bending.";
        } else if (_rightMinElbowAngleDuringRep < 15) {
          isCorrect = false;
          correction = "Over-bending";
        }

        if (isCorrect) {
          _rightCorrectCount++;
          _lastRepCorrect = true;
          _allFeedbacks.add("Correct form!");
        } else {
          _rightWrongCount++;
          _feedback.add("Rep $_rightCurlCount: $correction");
          _allFeedbacks.add(correction);
          _lastRepCorrect = false;
        }

        _rightStartedDown = false;
        _rightReachedUp = false;
        _rightMinElbowAngleDuringRep = 180.0;
        _rightMaxShoulderAngleDuringRep = 0.0;

        if (_rightCurlCount >= 5) {
          await _cameraService.controller?.stopImageStream();
          if (!mounted) return;

          await Future.delayed(const Duration(seconds: 1));

          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder:
                  (_) => ExerciseSummaryScreen(
                    correct: _rightCorrectCount,
                    wrong: _rightWrongCount,
                    feedbacks: _allFeedbacks,
                  ),
            ),
          );
        }
      }
    }
  }

  double _distance(Offset a, Offset b) =>
      math.sqrt(math.pow(a.dx - b.dx, 2) + math.pow(a.dy - b.dy, 2));

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
      return const Scaffold(body: Center(child: WalkAnimation()));
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
      appBar: AppBar(title: const Text("Curl Up Exercise")),
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

                // if (_lastPose != null && _cameraImageSize != null)
                //   LayoutBuilder(
                //     builder: (context, constraints) {
                //       final widgetSize = Size( constraints.maxWidth, constraints.maxHeight, );
                //       final controller = _cameraService.controller!;
                //       final sensorOrientation =  controller.description.sensorOrientation;
                //       final isFront = controller.description.lensDirection ==CameraLensDirection.front;

                //       return CustomPaint(
                //         painter: PosePainter(
                //           pose: _lastPose!,
                //           imageSize:  _cameraImageSize!, // original frame size (width,height)
                //           widgetSize:  widgetSize, // original frame size the area that CameraPreview occupies
                //           sensorOrientation: sensorOrientation,
                //           isFrontCamera: isFront,
                //         ),
                //         size: widgetSize,
                //       );
                //     },
                //   ),
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
                          "$_rightCorrectCount",
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
                          "$_rightWrongCount",
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

// class PosePainter extends CustomPainter {
//   final Pose pose;
//   final Size imageSize; // camera image size (width,height) from frames
//   final Size widgetSize; // size of the paint area (passed in paint)
//   final int sensorOrientation; // controller.description.sensorOrientation
//   final bool
//   isFrontCamera; // controller.description.lensDirection == CameraLensDirection.front

//   PosePainter({
//     required this.pose,
//     required this.imageSize,
//     required this.widgetSize,
//     required this.sensorOrientation,
//     required this.isFrontCamera,
//   });

//   // paint style
//   final Paint _bonePaint =
//       Paint()
//         ..color = Colors.greenAccent
//         ..strokeWidth = 4
//         ..strokeCap = StrokeCap.round;

//   final Paint _landmarkPaint =
//       Paint()
//         ..color = Colors.greenAccent
//         ..style = PaintingStyle.fill;

//   @override
//   void paint(Canvas canvas, Size size) {
//     // Compute mapping constants
//     // 1) determine effective image size after applying rotation
//     final int rotation = (sensorOrientation % 360);
//     final bool rotated = rotation == 90 || rotation == 270;
//     final double imageW = rotated ? imageSize.height : imageSize.width;
//     final double imageH = rotated ? imageSize.width : imageSize.height;

//     // 2) compute scale used by CameraPreview (BoxFit.cover semantics)
//     final double scale = math.max(
//       widgetSize.width / imageW,
//       widgetSize.height / imageH,
//     );

//     final double scaledImageW = imageW * scale;
//     final double scaledImageH = imageH * scale;

//     // 3) compute letterbox offset (center crop)
//     final double dx = (widgetSize.width - scaledImageW) / 2;
//     final double dy = (widgetSize.height - scaledImageH) / 2;

//     Offset transformLandmark(PoseLandmark lm) {
//       // landmark coordinates are in original camera image coordinate system
//       double x = lm.x;
//       double y = lm.y;

//       // existing rotation mapping (kept as is for correct scaling/position)
//       double rx, ry;
//       final int rotation = sensorOrientation % 360;
//       switch (rotation) {
//         case 0:
//           rx = x;
//           ry = y;
//           break;
//         case 90:
//           rx = y;
//           ry = imageSize.width - x;
//           break;
//         case 180:
//           rx = imageSize.width - x;
//           ry = imageSize.height - y;
//           break;
//         case 270:
//           rx = imageSize.height - y;
//           ry = x;
//           break;
//         default:
//           rx = x;
//           ry = y;
//       }

//       // after rotation, apply front camera mirroring
//       final double mappedImageW =
//           (rotation == 90 || rotation == 270)
//               ? imageSize.height
//               : imageSize.width;
//       if (isFrontCamera) {
//         rx = mappedImageW - rx;
//       }

//       // --- NEW: rotate skeleton back by -90 degrees around the center ---
//       final double centerX = mappedImageW / 2;
//       final double centerY =
//           ((rotation == 90 || rotation == 270)
//               ? imageSize.width
//               : imageSize.height) /
//           2;

//       // translate to origin
//       double tempX = rx - centerX;
//       double tempY = ry - centerY;

//       // apply -90° rotation
//       double rotatedX = tempX * 0 - tempY * 1; // cos(-90)=0, sin(-90)=-1
//       double rotatedY = tempX * 1 + tempY * 0; // cos(-90)=0, sin(-90)=-1

//       // translate back
//       rx = rotatedX + centerX;
//       ry = rotatedY + centerY;

//       // scale to widget and add crop offset
//       final double scale = math.max(
//         widgetSize.width / mappedImageW,
//         widgetSize.height /
//             ((rotation == 90 || rotation == 270)
//                 ? imageSize.width
//                 : imageSize.height),
//       );

//       final double dx = (widgetSize.width - mappedImageW * scale) / 2;
//       final double dy =
//           (widgetSize.height -
//               ((rotation == 90 || rotation == 270)
//                       ? imageSize.width
//                       : imageSize.height) *
//                   scale) /
//           2;

//       final double widgetX = rx * scale + dx;
//       final double widgetY = ry * scale + dy;

//       return Offset(widgetX, widgetY);
//     }

//     // helper to get landmark safely
//     Offset? lmPos(PoseLandmarkType t) {
//       final lm = pose.landmarks[t];
//       return lm == null ? null : transformLandmark(lm);
//     }

//     // draw bones (example set)
//     List<List<PoseLandmarkType>> bones = [
//       [PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder],
//       [PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow],
//       [PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist],
//       [PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow],
//       [PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist],
//       [PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip],
//       [PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip],
//       [PoseLandmarkType.leftHip, PoseLandmarkType.rightHip],
//       [PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee],
//       [PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle],
//       [PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee],
//       [PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle],
//     ];

//     for (var b in bones) {
//       final s = lmPos(b[0]);
//       final e = lmPos(b[1]);
//       if (s != null && e != null) {
//         canvas.drawLine(s, e, _bonePaint);
//       }
//     }

//     // draw landmarks
//     for (var lm in pose.landmarks.values) {
//       final p = transformLandmark(lm);
//       canvas.drawCircle(p, 6, _landmarkPaint);
//     }
//   }

//   @override
//   bool shouldRepaint(covariant PosePainter old) => true;
// }
