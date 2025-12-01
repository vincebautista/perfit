import 'dart:math' as math;
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:perfit/screens/exercise_summary_screen.dart';

class TestMediapipeScreen extends StatefulWidget {
  const TestMediapipeScreen({super.key});

  @override
  State<TestMediapipeScreen> createState() => _TestMediapipeScreenState();
}

class _TestMediapipeScreenState extends State<TestMediapipeScreen> {
  CameraController? _cameraController;
  late Future<void> _initializeControllerFuture;
  late final PoseDetector _poseDetector;
  bool _isBusy = false;
  Size? _cameraImageSize;

  int _rightCurlCount = 0;
  int _rightCorrectCount = 0;
  int _rightWrongCount = 0;
  List<String> _feedback = [];

  bool _rightStartedDown = false;
  bool _rightReachedUp = false;

  double _rightMinElbowAngleDuringRep = 180.0;
  double _rightMaxShoulderAngleDuringRep = 0.0;

  final double _maxAllowedShoulderMovement = 60.0;
  final double _downThreshold = 165.0;
  final double _upThreshold = 50.0;
  final double _shoulderBySideThreshold = 45.0;
  final double _wristToShoulderTopRatio = 0.45;

  Pose? _lastPose;

  @override
  void initState() {
    super.initState();
    _poseDetector = PoseDetector(
      options: PoseDetectorOptions(mode: PoseDetectionMode.stream),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _initializeCamera());
  }

  double _distance(Offset a, Offset b) =>
      math.sqrt((a.dx - b.dx) * (a.dx - b.dx) + (a.dy - b.dy) * (a.dy - b.dy));

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    final camera = cameras.firstWhere(
      (cam) => cam.lensDirection == CameraLensDirection.front,
    );

    _cameraController = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    _initializeControllerFuture = _cameraController!.initialize();
    await _initializeControllerFuture;

    _cameraController!.startImageStream(_processCameraImage);
    setState(() {});
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (_isBusy) return;
    _isBusy = true;

    try {
      final inputImage = _cameraImageToInputImage(
        image,
        _cameraController!.description.sensorOrientation,
      );

      final poses = await _poseDetector.processImage(inputImage);

      if (poses.isNotEmpty) {
        final landmarks = poses.first.landmarks;
        _lastPose = poses.first;

        final rightShoulder = landmarks[PoseLandmarkType.rightShoulder];
        final rightElbow = landmarks[PoseLandmarkType.rightElbow];
        final rightWrist = landmarks[PoseLandmarkType.rightWrist];
        final rightHip = landmarks[PoseLandmarkType.rightHip];

        if (rightShoulder != null && rightElbow != null && rightWrist != null) {
          final s = Offset(rightShoulder.x, rightShoulder.y);
          final e = Offset(rightElbow.x, rightElbow.y);
          final w = Offset(rightWrist.x, rightWrist.y);

          final double elbowAngle = _calculateAngle(s, e, w);

          final bool canCheckRightShoulder = rightHip != null;
          final double rightShoulderAngle =
              canCheckRightShoulder
                  ? _calculateAngle(Offset(rightHip.x, rightHip.y), s, e)
                  : 0.0;

          double torsoLenRight =
              rightHip != null
                  ? _distance(s, Offset(rightHip.x, rightHip.y))
                  : 1.0;

          final double wristShoulderNormRight =
              _distance(w, s) / (torsoLenRight > 0 ? torsoLenRight : 1.0);
          final bool reachedTopByProximityRight =
              wristShoulderNormRight <= _wristToShoulderTopRatio;
          final bool reachedTopByAngleRight = elbowAngle <= _upThreshold;
          final bool isArmUpRight =
              reachedTopByAngleRight && reachedTopByProximityRight;

          final bool upperArmBySideRight =
              !canCheckRightShoulder ||
              (rightShoulderAngle < _shoulderBySideThreshold);
          final bool isArmDownRight =
              (elbowAngle >= _downThreshold) && upperArmBySideRight;

          // Track min elbow angle continuously
          _rightMinElbowAngleDuringRep = math.min(
            _rightMinElbowAngleDuringRep,
            elbowAngle,
          );

          // Track max shoulder movement if started down
          if (_rightStartedDown && canCheckRightShoulder) {
            _rightMaxShoulderAngleDuringRep = math.max(
              _rightMaxShoulderAngleDuringRep,
              rightShoulderAngle,
            );
          }

          // Start rep once elbow ≤ 160°
          if (!_rightStartedDown && elbowAngle >= _downThreshold) {
            _rightStartedDown = true;
          }
          if (_rightStartedDown && !_rightReachedUp && elbowAngle <= 160.0) {
            _rightReachedUp = true;
          }

          // Count rep when arm comes back down after starting
          if (_rightStartedDown && _rightReachedUp && isArmDownRight) {
            _rightCurlCount++;

            bool isCorrect = true;
            String correction = "";

            // Shoulder movement check
            if (_rightMaxShoulderAngleDuringRep > _maxAllowedShoulderMovement) {
              isCorrect = false;
              correction = "Too much shoulder movement";
            }

            // Elbow bending check
            if (_rightMinElbowAngleDuringRep > _upThreshold) {
              isCorrect = false;
              correction = "Under-bending";
            } else if (_rightMinElbowAngleDuringRep < 15) {
              isCorrect = false;
              correction = "Over-bending";
            }

            if (isCorrect) {
              _rightCorrectCount++;
              debugPrint(
                "✅ Correct rep ($_rightCorrectCount) | Min Elbow: ${_rightMinElbowAngleDuringRep.toStringAsFixed(1)} | Shoulder: ${_rightMaxShoulderAngleDuringRep.toStringAsFixed(1)}",
              );
            } else {
              _rightWrongCount++;
              _feedback.add("Rep $_rightCurlCount: $correction");
              debugPrint(
                "❌ Wrong rep ($_rightWrongCount) - $correction | Min Elbow: ${_rightMinElbowAngleDuringRep.toStringAsFixed(1)} | Shoulder: ${_rightMaxShoulderAngleDuringRep.toStringAsFixed(1)}",
              );
            }

            // Reset trackers for next rep
            _rightStartedDown = false;
            _rightReachedUp = false;
            _rightMinElbowAngleDuringRep = 180.0;
            _rightMaxShoulderAngleDuringRep = 0.0;

            // Stop after 5 reps
            if (_rightCurlCount >= 5) {
              await _cameraController?.stopImageStream();
              if (mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) => ExerciseSummaryScreen(
                          correct: _rightCorrectCount,
                          wrong: _rightWrongCount,
                          feedback: _feedback,
                        ),
                  ),
                );
              }
            }
          }
        }
      }

      setState(() {
        _cameraImageSize = Size(
          image.width.toDouble(),
          image.height.toDouble(),
        );
      });
    } catch (e) {
      debugPrint('Pose detection error: $e');
    } finally {
      _isBusy = false;
    }
  }

  InputImage _cameraImageToInputImage(CameraImage image, int rotation) {
    final int width = image.width;
    final int height = image.height;
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

  @override
  void dispose() {
    _cameraController?.dispose();
    _poseDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Right Arm Curl Counter')),
      body: FutureBuilder(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return Stack(
              children: [
                Positioned.fill(child: CameraPreview(_cameraController!)),

                // Draw circle over head
                if (_cameraImageSize != null && _lastPose != null)
                  CustomPaint(
                    size: Size.infinite,
                    painter: ScaledStickmanPainter(
                      lastPose: _lastPose!,
                      cameraImageSize: _cameraImageSize!,
                      isFrontCamera:
                          _cameraController!.description.lensDirection ==
                          CameraLensDirection.front,
                    ),
                  ),
                // Overlay rep counter
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
                    child: Text(
                      "Reps: $_rightCurlCount\n✅ $_rightCorrectCount | ❌ $_rightWrongCount",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            );
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }

  double _calculateAngle(Offset a, Offset b, Offset c) {
    final ab = Offset(a.dx - b.dx, a.dy - b.dy);
    final cb = Offset(c.dx - b.dx, c.dy - b.dy);
    final dot = (ab.dx * cb.dx + ab.dy * cb.dy);
    final magAB = math.sqrt(ab.dx * ab.dx + ab.dy * ab.dy);
    final magCB = math.sqrt(cb.dx * cb.dx + cb.dy * cb.dy);
    final cosine = dot / (magAB * magCB);
    return math.acos(cosine.clamp(-1.0, 1.0)) * (180 / math.pi);
  }
}

class ScaledStickmanPainter extends CustomPainter {
  final Pose lastPose;
  final Size cameraImageSize;
  final bool isFrontCamera;

  ScaledStickmanPainter({
    required this.lastPose,
    required this.cameraImageSize,
    this.isFrontCamera = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = Colors.red
          ..strokeWidth = 4.0
          ..style = PaintingStyle.stroke;

    // Helper: scale and flip
    Offset toCanvas(double x, double y) {
      double sx = x * size.width / cameraImageSize.width;
      double sy = y * size.height / cameraImageSize.height;
      if (isFrontCamera) sx = size.width - sx;
      return Offset(sx, sy);
    }

    // Extract key landmarks
    final nose = lastPose.landmarks[PoseLandmarkType.nose];
    final leftShoulder = lastPose.landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = lastPose.landmarks[PoseLandmarkType.rightShoulder];
    final leftElbow = lastPose.landmarks[PoseLandmarkType.leftElbow];
    final rightElbow = lastPose.landmarks[PoseLandmarkType.rightElbow];
    final leftWrist = lastPose.landmarks[PoseLandmarkType.leftWrist];
    final rightWrist = lastPose.landmarks[PoseLandmarkType.rightWrist];
    final leftHip = lastPose.landmarks[PoseLandmarkType.leftHip];
    final rightHip = lastPose.landmarks[PoseLandmarkType.rightHip];
    final leftKnee = lastPose.landmarks[PoseLandmarkType.leftKnee];
    final rightKnee = lastPose.landmarks[PoseLandmarkType.rightKnee];
    final leftAnkle = lastPose.landmarks[PoseLandmarkType.leftAnkle];
    final rightAnkle = lastPose.landmarks[PoseLandmarkType.rightAnkle];

    // Use shoulder width as scaling reference
    double bodyScale = 1.0;
    if (leftShoulder != null && rightShoulder != null) {
      final ls = Offset(leftShoulder.x, leftShoulder.y);
      final rs = Offset(rightShoulder.x, rightShoulder.y);
      bodyScale = ((ls - rs).distance).clamp(20, 200); // clamp for safety
    }

    // Draw head circle
    if (nose != null) {
      Offset headCenter = toCanvas(
        nose.x,
        nose.y - bodyScale * 0.5, // move proportional to body size
      );
      canvas.drawCircle(headCenter, bodyScale * 0.25, paint);
    }

    // Draw torso
    if (leftShoulder != null &&
        rightShoulder != null &&
        leftHip != null &&
        rightHip != null) {
      Offset ls = toCanvas(leftShoulder.x, leftShoulder.y);
      Offset rs = toCanvas(rightShoulder.x, rightShoulder.y);
      Offset lh = toCanvas(leftHip.x, leftHip.y);
      Offset rh = toCanvas(rightHip.x, rightHip.y);

      // midpoints for torso line
      Offset midShoulder = Offset((ls.dx + rs.dx) / 2, (ls.dy + rs.dy) / 2);
      Offset midHip = Offset((lh.dx + rh.dx) / 2, (lh.dy + rh.dy) / 2);

      canvas.drawLine(midShoulder, midHip, paint);
      canvas.drawLine(ls, rs, paint); // shoulders
      canvas.drawLine(lh, rh, paint); // hips
    }

    // Draw arms
    void drawArm(
      PoseLandmark? shoulder,
      PoseLandmark? elbow,
      PoseLandmark? wrist,
    ) {
      if (shoulder != null && elbow != null) {
        canvas.drawLine(
          toCanvas(shoulder.x, shoulder.y),
          toCanvas(elbow.x, elbow.y),
          paint,
        );
      }
      if (elbow != null && wrist != null) {
        canvas.drawLine(
          toCanvas(elbow.x, elbow.y),
          toCanvas(wrist.x, wrist.y),
          paint,
        );
      }
    }

    drawArm(leftShoulder, leftElbow, leftWrist);
    drawArm(rightShoulder, rightElbow, rightWrist);

    // Draw legs
    void drawLeg(PoseLandmark? hip, PoseLandmark? knee, PoseLandmark? ankle) {
      if (hip != null && knee != null) {
        canvas.drawLine(
          toCanvas(hip.x, hip.y),
          toCanvas(knee.x, knee.y),
          paint,
        );
      }
      if (knee != null && ankle != null) {
        canvas.drawLine(
          toCanvas(knee.x, knee.y),
          toCanvas(ankle.x, ankle.y),
          paint,
        );
      }
    }

    drawLeg(leftHip, leftKnee, leftAnkle);
    drawLeg(rightHip, rightKnee, rightAnkle);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
