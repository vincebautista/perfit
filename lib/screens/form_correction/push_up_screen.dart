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

  bool _startedDown = false;
  bool _reachedBottom = false;
  bool isBottom = false;
  double _minElbowAngleDuringRep =
      180.0; // Track minimum elbow angle for depth check
  bool _isAtTop = false; // Track if at top position
  bool _hitDepth = false;
  bool _hitLockout = false;
  bool _repHadError = false;

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

    // Get required landmarks for push-ups
    final leftShoulder = landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = landmarks[PoseLandmarkType.rightShoulder];
    final leftElbow = landmarks[PoseLandmarkType.leftElbow];
    final rightElbow = landmarks[PoseLandmarkType.rightElbow];
    final leftWrist = landmarks[PoseLandmarkType.leftWrist];
    final rightWrist = landmarks[PoseLandmarkType.rightWrist];
    final leftHip = landmarks[PoseLandmarkType.leftHip];
    final rightHip = landmarks[PoseLandmarkType.rightHip];

    // Verify all required landmarks exist
    if (leftShoulder == null ||
        rightShoulder == null ||
        leftElbow == null ||
        rightElbow == null ||
        leftWrist == null ||
        rightWrist == null ||
        leftHip == null ||
        rightHip == null) {
      feedback = "Please ensure all body parts are visible";
      feedbackColor = Colors.orange;
      return;
    }

    // Calculate angles
    // Elbow angles: shoulder-elbow-wrist
    double elbowAngleLeft = calculateAngle(leftShoulder, leftElbow, leftWrist);
    double elbowAngleRight = calculateAngle(
      rightShoulder,
      rightElbow,
      rightWrist,
    );
    final avgElbowAngle = (elbowAngleLeft + elbowAngleRight) / 2;

    // Shoulder angle: hip-shoulder-elbow (calculated per requirements)
    // ignore: unused_local_variable
    double shoulderAngleLeft = calculateAngle(leftHip, leftShoulder, leftElbow);
    // ignore: unused_local_variable
    double shoulderAngleRight = calculateAngle(
      rightHip,
      rightShoulder,
      rightElbow,
    );
    // ignore: unused_local_variable
    final avgShoulderAngle = (shoulderAngleLeft + shoulderAngleRight) / 2;

    // Elbow flaring angle: shoulder-elbow-wrist (to check if elbows are flaring out)
    double elbowFlareAngleLeft = calculateAngle(
      leftShoulder,
      leftElbow,
      leftWrist,
    );
    double elbowFlareAngleRight = calculateAngle(
      rightShoulder,
      rightElbow,
      rightWrist,
    );
    final avgElbowFlareAngle = (elbowFlareAngleLeft + elbowFlareAngleRight) / 2;

    // Hip angle: shoulder-hip-knee (but we'll use ankle as proxy for knee alignment)
    // For push-ups, we check hip alignment relative to shoulder-ankle line
    final leftAnkle = landmarks[PoseLandmarkType.leftAnkle];
    final rightAnkle = landmarks[PoseLandmarkType.rightAnkle];
    final bool hasAnkles = leftAnkle != null && rightAnkle != null;
    double hipAngle = 180.0; // Default
    if (hasAnkles) {
      final avgShoulder = Offset(
        (leftShoulder.x + rightShoulder.x) / 2,
        (leftShoulder.y + rightShoulder.y) / 2,
      );
      final avgHip = Offset(
        (leftHip.x + rightHip.x) / 2,
        (leftHip.y + rightHip.y) / 2,
      );
      final avgAnkle = Offset(
        (leftAnkle.x + rightAnkle.x) / 2,
        (leftAnkle.y + rightAnkle.y) / 2,
      );
      // Hip angle: angle between shoulder-hip and hip-ankle
      hipAngle = _calculateAngle(avgShoulder, avgHip, avgAnkle);
    }

    // Torso angle: shoulder-hip angle (should be close to 180° for straight back)
    final avgShoulderPos = Offset(
      (leftShoulder.x + rightShoulder.x) / 2,
      (leftShoulder.y + rightShoulder.y) / 2,
    );
    final avgHipPos = Offset(
      (leftHip.x + rightHip.x) / 2,
      (leftHip.y + rightHip.y) / 2,
    );
    // Calculate angle between shoulder-hip line and horizontal
    // Calculate shoulder-hip angle for back alignment check
    final shoulderHipAngle = _calculateAngle(
      avgShoulderPos,
      avgHipPos,
      Offset(avgHipPos.dx, avgHipPos.dy - 1), // Vertical reference
    );

    // Check if data is stable (both elbows have similar angles)
    final elbowAngleDiff = (elbowAngleLeft - elbowAngleRight).abs();
    if (elbowAngleDiff > 30) {
      feedback = "Please ensure both arms are visible";
      feedbackColor = Colors.orange;
      return;
    }

    // Detect if at bottom position (elbow angles in 80-100° range)
    isBottom = avgElbowAngle >= 80 && avgElbowAngle <= 100;

    // Detect if at top position (elbow angles > 160°)
    _isAtTop = avgElbowAngle > 160;

    if (!_startedDown && avgElbowAngle < 150) {
      _startedDown = true;
      _hitDepth = false;
      _hitLockout = false;
      _repHadError = false;
      _minElbowAngleDuringRep = avgElbowAngle;
    }

    if (_startedDown) {
      _minElbowAngleDuringRep = math.min(
        _minElbowAngleDuringRep,
        avgElbowAngle,
      );
      if (isBottom) {
        _hitDepth = true;
      }
      if (_isAtTop) {
        _hitLockout = true;
      }
    }

    // Initialize feedback
    feedback = "";
    feedbackColor = Colors.green;

    // Form error detection
    List<String> errors = [];

    // 1. Sagging hips: hipAngle < 160° (hips too low)
    if (hipAngle < 160) {
      errors.add("Keep your hips up - don't sag");
      feedbackColor = Colors.red;
    }

    // 2. Piking hips: hipAngle > 195° (hips too high)
    if (hipAngle > 195) {
      errors.add("Lower your hips - keep body straight");
      feedbackColor = Colors.red;
    }

    // 3. Elbows flaring: shoulder-elbow-wrist angle < 45° (elbows too wide)
    // The elbow flare angle should be larger (arms more vertical) for good form
    if (avgElbowFlareAngle < 45) {
      errors.add("Keep elbows closer to your body");
      feedbackColor = Colors.red;
    }

    // 4. Not reaching depth: elbow angles must reach 80-100° range
    if (_startedDown && !_hitDepth && avgElbowAngle < 140) {
      errors.add("Go deeper - lower your chest more");
      feedbackColor = Colors.red;
    }

    // 5. Not locking out: elbow angles must reach > 160° at top
    if (_reachedBottom && !_hitLockout && !_isAtTop && avgElbowAngle > 140) {
      errors.add("Fully extend your arms at the top");
      feedbackColor = Colors.red;
    }

    // 6. Back alignment: torso angle should be 165°-180°
    // For push-ups, we check if shoulder-hip line is straight (close to 180°)
    if (shoulderHipAngle < 165 || shoulderHipAngle > 195) {
      errors.add("Keep your back straight");
      feedbackColor = Colors.red;
    }

    // 7. Hip alignment relative to torso (hips should not deviate > 15°)
    if (hasAnkles) {
      final hipTorsoDeviation = (hipAngle - shoulderHipAngle).abs();
      if (hipTorsoDeviation > 15) {
        errors.add("Move your hips in line with your torso");
        feedbackColor = Colors.red;
      }
    }

    // Set feedback message
    if (errors.isEmpty) {
      if (isBottom) {
        feedback = "✅ Good form!";
      } else if (avgElbowAngle > 160) {
        feedback = "✅ Good form!";
      } else {
        feedback = "Continue push-up";
      }
    } else {
      feedback = errors.join(". ");
    }

    // Rep counting logic
    if (_startedDown && !_reachedBottom && isBottom) {
      _reachedBottom = true;
    }

    // Track if this rep has produced any issues
    if (_startedDown && errors.isNotEmpty) {
      _repHadError = true;
    }

    // Complete rep when returning to top position with lockout
    if (_startedDown && _reachedBottom && _isAtTop && _hitDepth) {
      _pushUpCount++;

      if (!_repHadError && _hitDepth && _hitLockout) {
        _correctCount++;
      } else {
        _wrongCount++;
        final issueMessage =
            errors.isNotEmpty
                ? errors.join(", ")
                : "Maintain full range of motion";
        _feedback.add("Rep $_pushUpCount: $issueMessage");
      }

      // Reset for next rep
      _startedDown = false;
      _reachedBottom = false;
      _hitDepth = false;
      _hitLockout = false;
      _repHadError = false;
      _minElbowAngleDuringRep = 180.0;

      // Stop after 5 reps
      if (_pushUpCount >= 5) {
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
                      "Reps: $_pushUpCount\n✅ $_correctCount | ❌ $_wrongCount",
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
