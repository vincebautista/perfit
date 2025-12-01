import 'dart:math';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class DistanceService {
  final _smoothingWindow = <double>[];
  final int maxSamples = 5;

  // Average human shoulder width in cm (you can adjust)
  static const double realShoulderWidthCm = 40.0;

  // Focal length approximation in pixels (depends on camera)
  static const double focalLengthPx = 500; // you may need to calibrate

  double euclidean(PoseLandmark a, PoseLandmark b) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    return sqrt(dx * dx + dy * dy);
  }

  /// Compute approximate distance in cm from the camera using shoulders
  double computeSmoothedDistance(Pose pose) {
    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];

    if (leftShoulder == null || rightShoulder == null) {
      return 0.0; // can't compute
    }

    // Pixel width between shoulders
    final shoulderWidthPx = euclidean(leftShoulder, rightShoulder);

    // Distance from camera in cm using pinhole camera formula
    final distanceCm = (realShoulderWidthCm * focalLengthPx) / shoulderWidthPx;

    // Smoothing
    _smoothingWindow.add(distanceCm);
    if (_smoothingWindow.length > maxSamples) {
      _smoothingWindow.removeAt(0);
    }

    return _smoothingWindow.reduce((a, b) => a + b) / _smoothingWindow.length;
  }
}
