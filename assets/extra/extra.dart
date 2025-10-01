// import 'dart:math' as math;
// import 'dart:typed_data';
// import 'package:camera/camera.dart';
// import 'package:flutter/foundation.dart';
// import 'package:flutter/material.dart';
// import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

// class TestMediapipeScreen extends StatefulWidget {
//   const TestMediapipeScreen({super.key});

//   @override
//   State<TestMediapipeScreen> createState() => _TestMediapipeScreenState();
// }

// class _TestMediapipeScreenState extends State<TestMediapipeScreen> {
//   CameraController? _cameraController;
//   late Future<void> _initializeControllerFuture;
//   late final PoseDetector _poseDetector;
//   bool _isBusy = false;
//   List<Pose> _poses = [];
//   Size? _cameraImageSize;

//   int _leftCurlCount = 0;
//   int _rightCurlCount = 0;

//   String _leftState = 'down';
//   String _rightState = 'down';

//   bool _leftStartedDown = false;
//   bool _rightStartedDown = false;

//   bool _leftReachedFullUp = false;
//   bool _rightReachedFullUp = false;

//   int _leftDownFrameCount = 0;
//   int _leftUpFrameCount = 0;
//   int _rightDownFrameCount = 0;
//   int _rightUpFrameCount = 0;
//   final int _requiredStableFrames = 3;

//   double _leftMaxShoulderAngleDuringRep = 0.0;
//   double _rightMaxShoulderAngleDuringRep = 0.0;
//   final double _maxAllowedShoulderMovement = 40.0;

//   final double _downThreshold = 165.0;
//   final double _upThreshold = 55.0;
//   final double _shoulderBySideThreshold = 45.0;
//   final double _wristToShoulderTopRatio = 0.45;

//   @override
//   void initState() {
//     super.initState();
//     _poseDetector = PoseDetector(
//       options: PoseDetectorOptions(mode: PoseDetectionMode.stream),
//     );
//     WidgetsBinding.instance.addPostFrameCallback((_) => _initializeCamera());
//   }

//   double _distance(Offset a, Offset b) =>
//       math.sqrt((a.dx - b.dx) * (a.dx - b.dx) + (a.dy - b.dy) * (a.dy - b.dy));

//   Future<void> _initializeCamera() async {
//     final cameras = await availableCameras();
//     final camera = cameras.firstWhere(
//       (cam) => cam.lensDirection == CameraLensDirection.front,
//     );

//     _cameraController = CameraController(
//       camera,
//       ResolutionPreset.medium,
//       enableAudio: false,
//       imageFormatGroup: ImageFormatGroup.yuv420,
//     );

//     _initializeControllerFuture = _cameraController!.initialize();
//     await _initializeControllerFuture;

//     _cameraController!.startImageStream(_processCameraImage);
//     setState(() {});
//   }

//   Future<void> _processCameraImage(CameraImage image) async {
//     if (_isBusy) return;
//     _isBusy = true;

//     try {
//       final inputImage = _cameraImageToInputImage(
//         image,
//         _cameraController!.description.sensorOrientation,
//       );

//       final poses = await _poseDetector.processImage(inputImage);

//       debugPrint('Detected ${poses.length} pose(s)');

//       if (poses.isNotEmpty) {
//         final firstPose = poses.first;
//         final landmarks = firstPose.landmarks;

//         final leftShoulder = landmarks[PoseLandmarkType.leftShoulder];
//         final leftElbow = landmarks[PoseLandmarkType.leftElbow];
//         final leftWrist = landmarks[PoseLandmarkType.leftWrist];
//         final leftHip = landmarks[PoseLandmarkType.leftHip];

//         final rightShoulder = landmarks[PoseLandmarkType.rightShoulder];
//         final rightElbow = landmarks[PoseLandmarkType.rightElbow];
//         final rightWrist = landmarks[PoseLandmarkType.rightWrist];
//         final rightHip = landmarks[PoseLandmarkType.rightHip];

//         if (leftShoulder != null && leftElbow != null && leftWrist != null) {
//           final s = Offset(leftShoulder.x, leftShoulder.y);
//           final e = Offset(leftElbow.x, leftElbow.y);
//           final w = Offset(leftWrist.x, leftWrist.y);

//           final double elbowAngle = _calculateAngle(s, e, w);

//           final bool canCheckLeftShoulder = leftHip != null;
//           final double leftShoulderAngle =
//               canCheckLeftShoulder
//                   ? _calculateAngle(Offset(leftHip!.x, leftHip.y), s, e)
//                   : 0.0;
//           double torsoLenLeft = 0.0;
//           if (leftHip != null) {
//             torsoLenLeft = _distance(s, Offset(leftHip.x, leftHip.y));
//           } else if (rightShoulder != null) {
//             torsoLenLeft = _distance(
//               s,
//               Offset(rightShoulder.x, rightShoulder.y),
//             );
//           } else {
//             torsoLenLeft =
//                 ((_cameraImageSize?.width ?? 1.0) +
//                     (_cameraImageSize?.height ?? 1.0)) /
//                 2.0;
//           }

//           final double wristShoulderNormLeft =
//               _distance(w, s) / (torsoLenLeft > 0 ? torsoLenLeft : 1.0);
//           final bool reachedTopByProximityLeft =
//               wristShoulderNormLeft <= _wristToShoulderTopRatio;
//           final bool reachedTopByAngleLeft = elbowAngle <= _upThreshold;
//           final bool isArmUpLeft =
//               reachedTopByAngleLeft && reachedTopByProximityLeft;

//           final bool upperArmBySideLeft =
//               !canCheckLeftShoulder ||
//               (leftShoulderAngle < _shoulderBySideThreshold);
//           final bool isArmDownLeft =
//               (elbowAngle >= _downThreshold) && upperArmBySideLeft;

//           if (isArmDownLeft) {
//             _leftDownFrameCount++;
//             _leftUpFrameCount = 0;
//           } else if (isArmUpLeft) {
//             _leftUpFrameCount++;
//             _leftDownFrameCount = 0;
//           } else {
//             _leftDownFrameCount = 0;
//             _leftUpFrameCount = 0;
//           }

//           if (_leftStartedDown && canCheckLeftShoulder) {
//             _leftMaxShoulderAngleDuringRep = math.max(
//               _leftMaxShoulderAngleDuringRep,
//               leftShoulderAngle,
//             );
//           }
//           if (_leftUpFrameCount >= _requiredStableFrames) {
//             if (_leftState == 'down' && _leftStartedDown) {
//               _leftState = 'up';
//               _leftReachedFullUp = true;
//               _leftMaxShoulderAngleDuringRep =
//                   canCheckLeftShoulder ? leftShoulderAngle : 0.0;
//             }
//           }

//           if (_leftDownFrameCount >= _requiredStableFrames) {
//             if (_leftState == 'up' && _leftStartedDown && _leftReachedFullUp) {
//               if (_leftMaxShoulderAngleDuringRep <=
//                   _maxAllowedShoulderMovement) {
//                 _leftCurlCount++;
//                 debugPrint('✅ Left full rep counted: $_leftCurlCount');
//               } else {
//                 debugPrint(
//                   '⚠️ Left rep rejected due shoulder movement: ${_leftMaxShoulderAngleDuringRep.toStringAsFixed(1)}',
//                 );
//               }
//               // reset per-rep trackers
//               _leftReachedFullUp = false;
//               _leftMaxShoulderAngleDuringRep = 0.0;
//               _leftStartedDown = false;
//             }
//             _leftState = 'down';
//             _leftStartedDown = true;
//           }

//           // debug
//           debugPrint(
//             'L elbow: ${elbowAngle.toStringAsFixed(1)}, L wristNorm: ${wristShoulderNormLeft.toStringAsFixed(2)}, L downFrames: $_leftDownFrameCount, upFrames: $_leftUpFrameCount, reachedTop:$_leftReachedFullUp',
//           );
//         }

//         // ---- PROCESS RIGHT ARM (same logic mirrored) ----
//         if (rightShoulder != null && rightElbow != null && rightWrist != null) {
//           final s = Offset(rightShoulder.x, rightShoulder.y);
//           final e = Offset(rightElbow.x, rightElbow.y);
//           final w = Offset(rightWrist.x, rightWrist.y);

//           final double elbowAngle = _calculateAngle(s, e, w);

//           final bool canCheckRightShoulder = rightHip != null;
//           final double rightShoulderAngle =
//               canCheckRightShoulder
//                   ? _calculateAngle(Offset(rightHip!.x, rightHip.y), s, e)
//                   : 0.0;

//           double torsoLenRight = 0.0;
//           if (rightHip != null) {
//             torsoLenRight = _distance(s, Offset(rightHip.x, rightHip.y));
//           } else if (leftShoulder != null) {
//             torsoLenRight = _distance(
//               s,
//               Offset(leftShoulder.x, leftShoulder.y),
//             );
//           } else {
//             torsoLenRight =
//                 ((_cameraImageSize?.width ?? 1.0) +
//                     (_cameraImageSize?.height ?? 1.0)) /
//                 2.0;
//           }

//           final double wristShoulderNormRight =
//               _distance(w, s) / (torsoLenRight > 0 ? torsoLenRight : 1.0);
//           final bool reachedTopByProximityRight =
//               wristShoulderNormRight <= _wristToShoulderTopRatio;
//           final bool reachedTopByAngleRight = elbowAngle <= _upThreshold;
//           final bool isArmUpRight =
//               reachedTopByAngleRight && reachedTopByProximityRight;

//           final bool upperArmBySideRight =
//               !canCheckRightShoulder ||
//               (rightShoulderAngle < _shoulderBySideThreshold);
//           final bool isArmDownRight =
//               (elbowAngle >= _downThreshold) && upperArmBySideRight;

//           if (isArmDownRight) {
//             _rightDownFrameCount++;
//             _rightUpFrameCount = 0;
//           } else if (isArmUpRight) {
//             _rightUpFrameCount++;
//             _rightDownFrameCount = 0;
//           } else {
//             _rightDownFrameCount = 0;
//             _rightUpFrameCount = 0;
//           }

//           if (_rightStartedDown && canCheckRightShoulder) {
//             _rightMaxShoulderAngleDuringRep = math.max(
//               _rightMaxShoulderAngleDuringRep,
//               rightShoulderAngle,
//             );
//           }

//           if (_rightUpFrameCount >= _requiredStableFrames) {
//             if (_rightState == 'down' && _rightStartedDown) {
//               _rightState = 'up';
//               _rightReachedFullUp = true;
//               _rightMaxShoulderAngleDuringRep =
//                   canCheckRightShoulder ? rightShoulderAngle : 0.0;
//             }
//           }

//           if (_rightDownFrameCount >= _requiredStableFrames) {
//             if (_rightState == 'up' &&
//                 _rightStartedDown &&
//                 _rightReachedFullUp) {
//               if (_rightMaxShoulderAngleDuringRep <=
//                   _maxAllowedShoulderMovement) {
//                 _rightCurlCount++;
//                 debugPrint('✅ Right full rep counted: $_rightCurlCount');
//               } else {
//                 debugPrint(
//                   '⚠️ Right rep rejected due shoulder movement: ${_rightMaxShoulderAngleDuringRep.toStringAsFixed(1)}',
//                 );
//               }
//               _rightReachedFullUp = false;
//               _rightMaxShoulderAngleDuringRep = 0.0;
//               _rightStartedDown = false;
//             }
//             _rightState = 'down';
//             _rightStartedDown = true;
//           }

//           // debug
//           debugPrint(
//             'R elbow: ${elbowAngle.toStringAsFixed(1)}, R wristNorm: ${wristShoulderNormRight.toStringAsFixed(2)}, R downFrames: $_rightDownFrameCount, upFrames: $_rightUpFrameCount, reachedTop: $_rightReachedFullUp',
//           );
//         }
//       }

//       setState(() {
//         _poses = poses;
//         _cameraImageSize = Size(
//           image.width.toDouble(),
//           image.height.toDouble(),
//         );
//       });
//     } catch (e) {
//       debugPrint('Pose detection error: $e');
//     } finally {
//       _isBusy = false;
//     }
//   }

//   InputImage _cameraImageToInputImage(CameraImage image, int rotation) {
//     // Convert YUV420 to NV21
//     final int width = image.width;
//     final int height = image.height;
//     final uvRowStride = image.planes[1].bytesPerRow;
//     final uvPixelStride = image.planes[1].bytesPerPixel!;

//     final nv21 = Uint8List(width * height * 3 ~/ 2);

//     // Copy Y plane
//     for (int i = 0; i < height; i++) {
//       nv21.setRange(
//         i * width,
//         (i + 1) * width,
//         image.planes[0].bytes,
//         i * image.planes[0].bytesPerRow,
//       );
//     }

//     // Copy UV plane
//     int uvIndex = 0;
//     for (int i = 0; i < height ~/ 2; i++) {
//       for (int j = 0; j < width ~/ 2; j++) {
//         final u = image.planes[1].bytes[i * uvRowStride + j * uvPixelStride];
//         final v = image.planes[2].bytes[i * uvRowStride + j * uvPixelStride];
//         nv21[width * height + uvIndex++] = v;
//         nv21[width * height + uvIndex++] = u;
//       }
//     }

//     final inputImage = InputImage.fromBytes(
//       bytes: nv21,
//       metadata: InputImageMetadata(
//         size: Size(width.toDouble(), height.toDouble()),
//         rotation:
//             InputImageRotationValue.fromRawValue(rotation) ??
//             InputImageRotation.rotation0deg,
//         format: InputImageFormat.nv21,
//         bytesPerRow: image.planes[0].bytesPerRow,
//       ),
//     );

//     return inputImage;
//   }

//   @override
//   void dispose() {
//     _cameraController?.dispose();
//     _poseDetector.close();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     if (_cameraController == null || !_cameraController!.value.isInitialized) {
//       return const Scaffold(body: Center(child: CircularProgressIndicator()));
//     }

//     return Scaffold(
//       appBar: AppBar(title: const Text('Pose Detector Test')),
//       body: FutureBuilder(
//         future: _initializeControllerFuture,
//         builder: (context, snapshot) {
//           if (snapshot.connectionState == ConnectionState.done) {
//             return LayoutBuilder(
//               builder: (context, constraints) {
//                 final screenWidth = constraints.maxWidth;
//                 final screenHeight = constraints.maxHeight;

//                 return Stack(
//                   children: [
//                     SizedBox(
//                       width: screenWidth,
//                       height: screenHeight,
//                       child: CameraPreview(_cameraController!),
//                     ),
//                     if (_cameraImageSize != null)
//                       CustomPaint(
//                         size: Size(screenWidth, screenHeight),
//                         painter: PosePainter(
//                           poses: _poses,
//                           imageSize: _cameraImageSize!,
//                           widgetSize: Size(screenWidth, screenHeight),
//                           isFrontCamera:
//                               _cameraController!.description.lensDirection ==
//                               CameraLensDirection.front,
//                         ),
//                       ),
//                     Positioned(
//                       top: 20,
//                       left: 20,
//                       child: Container(
//                         padding: const EdgeInsets.symmetric(
//                           horizontal: 12,
//                           vertical: 8,
//                         ),
//                         decoration: BoxDecoration(
//                           color: Colors.black54,
//                           borderRadius: BorderRadius.circular(8),
//                         ),
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Text(
//                               "Left: $_leftCurlCount",
//                               style: const TextStyle(
//                                 color: Colors.white,
//                                 fontSize: 18,
//                                 fontWeight: FontWeight.bold,
//                               ),
//                             ),
//                             const SizedBox(height: 6),
//                             Text(
//                               "Right: $_rightCurlCount",
//                               style: const TextStyle(
//                                 color: Colors.white,
//                                 fontSize: 18,
//                                 fontWeight: FontWeight.bold,
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                     ),
//                   ],
//                 );
//               },
//             );
//           } else {
//             return const Center(child: CircularProgressIndicator());
//           }
//         },
//       ),
//     );
//   }

//   double _calculateAngle(Offset a, Offset b, Offset c) {
//     final ab = Offset(a.dx - b.dx, a.dy - b.dy);
//     final cb = Offset(c.dx - b.dx, c.dy - b.dy);

//     final dot = (ab.dx * cb.dx + ab.dy * cb.dy);
//     final magAB = math.sqrt(ab.dx * ab.dx + ab.dy * ab.dy);
//     final magCB = math.sqrt(cb.dx * cb.dx + cb.dy * cb.dy);

//     final cosine = dot / (magAB * magCB);
//     return math.acos(cosine.clamp(-1.0, 1.0)) * (180 / math.pi);
//   }
// }

// class PosePainter extends CustomPainter {
//   final List<Pose> poses;
//   final Size imageSize;
//   final Size widgetSize;
//   final bool isFrontCamera;

//   PosePainter({
//     required this.poses,
//     required this.imageSize,
//     required this.widgetSize,
//     this.isFrontCamera = true,
//   });

//   final List<List<PoseLandmarkType>> connections = [
//     [PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow],
//     [PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist],
//     [PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow],
//     [PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist],
//     [PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder],
//     [PoseLandmarkType.leftHip, PoseLandmarkType.rightHip],
//     [PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip],
//     [PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip],
//     [PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee],
//     [PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle],
//     [PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee],
//     [PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle],
//   ];

//   @override
//   void paint(Canvas canvas, Size size) {
//     final Paint landmarkPaint =
//         Paint()
//           ..color = Colors.green
//           ..style = PaintingStyle.fill
//           ..strokeWidth = 4;

//     final Paint linePaint =
//         Paint()
//           ..color = Colors.red
//           ..style = PaintingStyle.stroke
//           ..strokeWidth = 2;

//     double scaleX, scaleY, offsetX, offsetY;

//     final imageRatio = imageSize.width / imageSize.height;
//     final widgetRatio = widgetSize.width / widgetSize.height;

//     if (widgetRatio > imageRatio) {
//       scaleY = widgetSize.height / imageSize.height;
//       scaleX = scaleY;
//       offsetX = (widgetSize.width - imageSize.width * scaleX) / 2;
//       offsetY = 0;
//     } else {
//       scaleX = widgetSize.width / imageSize.width;
//       scaleY = scaleX;
//       offsetX = 0;
//       offsetY = (widgetSize.height - imageSize.height * scaleY) / 2;
//     }

//     double translateX(double x) => (x * scaleX) + offsetX;
//     double translateY(double y) => (y * scaleY) + offsetY;

//     for (final pose in poses) {
//       for (final connection in connections) {
//         final start = pose.landmarks[connection[0]];
//         final end = pose.landmarks[connection[1]];
//         if (start != null && end != null) {
//           double startX = translateX(start.x);
//           double startY = translateY(start.y);
//           double endX = translateX(end.x);
//           double endY = translateY(end.y);

//           if (isFrontCamera) {
//             startX = widgetSize.width - startX;
//             endX = widgetSize.width - endX;
//           }

//           canvas.drawLine(
//             Offset(startX, startY),
//             Offset(endX, endY),
//             linePaint,
//           );
//         }
//       }

//       for (final landmark in pose.landmarks.values) {
//         double x = translateX(landmark.x);
//         double y = translateY(landmark.y);

//         if (isFrontCamera) x = widgetSize.width - x;

//         canvas.drawCircle(Offset(x, y), 4, landmarkPaint);
//       }
//     }
//   }

//   @override
//   bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
// }
