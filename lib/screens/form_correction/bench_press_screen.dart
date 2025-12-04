import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class BenchPressFormCorrection {
  /// Tracks when the lifter has reached the bottom portion of the rep.
  bool isAtBottom = false;

  /// Latest user-facing feedback string/color.
  String feedback = "";
  Color feedbackColor = Colors.green;

  double? _previousTorsoAngle;
  double? _previousElbowForStability;
  double? _previousElbowForDetection;
  double _torsoDrift = 0;
  double _elbowDrift = 0;
  bool _pendingLockoutCheck = false;

  /// Re-compute feedback for the current frame.
  void handleFormCorrection(List<PoseLandmark> landmarks) {
    String feedback = "";
    Color feedbackColor = Colors.green;

    final Map<PoseLandmarkType, PoseLandmark> map = {
      for (final landmark in landmarks) landmark.type: landmark,
    };

    final requiredTypes = <PoseLandmarkType>[
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.rightShoulder,
      PoseLandmarkType.leftElbow,
      PoseLandmarkType.rightElbow,
      PoseLandmarkType.leftWrist,
      PoseLandmarkType.rightWrist,
      PoseLandmarkType.leftHip,
      PoseLandmarkType.rightHip,
      PoseLandmarkType.leftKnee,
      PoseLandmarkType.rightKnee,
      PoseLandmarkType.leftAnkle,
      PoseLandmarkType.rightAnkle,
    ];

    if (requiredTypes.any((type) => map[type] == null)) {
      this.feedback = "Ensure your full body stays visible to the camera.";
      this.feedbackColor = Colors.orange;
      return;
    }

    final leftShoulder = map[PoseLandmarkType.leftShoulder]!;
    final rightShoulder = map[PoseLandmarkType.rightShoulder]!;
    final leftElbow = map[PoseLandmarkType.leftElbow]!;
    final rightElbow = map[PoseLandmarkType.rightElbow]!;
    final leftWrist = map[PoseLandmarkType.leftWrist]!;
    final rightWrist = map[PoseLandmarkType.rightWrist]!;
    final leftHip = map[PoseLandmarkType.leftHip]!;
    final rightHip = map[PoseLandmarkType.rightHip]!;
    final leftKnee = map[PoseLandmarkType.leftKnee]!;
    final rightKnee = map[PoseLandmarkType.rightKnee]!;
    final leftAnkle = map[PoseLandmarkType.leftAnkle]!;
    final rightAnkle = map[PoseLandmarkType.rightAnkle]!;

    // Required angle variables.
    double kneeAngleLeft = calculateAngle(leftHip, leftKnee, leftAnkle);
    double kneeAngleRight = calculateAngle(rightHip, rightKnee, rightAnkle);
    double hipAngleLeft = calculateAngle(leftShoulder, leftHip, leftKnee);
    double hipAngleRight = calculateAngle(rightShoulder, rightHip, rightKnee);
    double torsoAngle = _torsoAngleFromHorizontal(
      leftShoulder,
      rightShoulder,
      leftHip,
      rightHip,
    );
    double elbowAngleLeft = calculateAngle(leftShoulder, leftElbow, leftWrist);
    double elbowAngleRight = calculateAngle(
      rightShoulder,
      rightElbow,
      rightWrist,
    );
    double shoulderAngle =
        (calculateAngle(leftHip, leftShoulder, leftElbow) +
            calculateAngle(rightHip, rightShoulder, rightElbow)) /
        2;
    double hipAngle = (hipAngleLeft + hipAngleRight) / 2;

    final avgElbowAngle = (elbowAngleLeft + elbowAngleRight) / 2;
    final poseStable = _updateStability(torsoAngle, avgElbowAngle);
    if (!poseStable) {
      this.feedback = "Hold still briefly for accurate feedback.";
      this.feedbackColor = Colors.orange;
      return;
    }

    bool atBottom =
        _isWithin(elbowAngleLeft, 80, 100) &&
        _isWithin(elbowAngleRight, 80, 100);
    bool atTop = elbowAngleLeft >= 160 && elbowAngleRight >= 160;

    if (atBottom) {
      isAtBottom = true;
      _pendingLockoutCheck = true;
    }

    if (atTop) {
      if (!_pendingLockoutCheck) {
        feedback = "Lower the bar until elbows reach roughly 90°.";
        feedbackColor = Colors.red;
      } else {
        _pendingLockoutCheck = false;
        isAtBottom = false;
      }
    }

    // Checks for form faults.
    final flareAngleLeft = calculateAngle(leftElbow, leftShoulder, leftWrist);
    final flareAngleRight = calculateAngle(
      rightElbow,
      rightShoulder,
      rightWrist,
    );
    final wristStackLeft = _verticalStackAngle(leftWrist, leftElbow);
    final wristStackRight = _verticalStackAngle(rightWrist, rightElbow);

    final List<String> errors = [];

    if (flareAngleLeft < 45 || flareAngleRight < 45) {
      errors.add("Keep elbows ~45° from the torso to avoid flaring.");
    }

    if (shoulderAngle < 20 || shoulderAngle > 45) {
      errors.add("Pinch shoulder blades (20°–45°) to stay retracted.");
    }

    if (wristStackLeft > 10 || wristStackRight > 10) {
      errors.add("Stack wrists directly above elbows; bar is drifting.");
    }

    final legImbalance = (kneeAngleLeft - kneeAngleRight).abs();
    if (legImbalance > 20) {
      errors.add("Drive evenly through both feet to stay stable.");
    }

    if (hipAngle < 40) {
      errors.add("Keep hips glued to the bench—avoid excessive bridging.");
    }

    if (_pendingLockoutCheck &&
        !atTop &&
        !atBottom &&
        _previousElbowForDetection != null &&
        avgElbowAngle < _previousElbowForDetection! - 5) {
      errors.add("Press through until the elbows lock out (160°+).");
    }

    if (feedback.isEmpty && errors.isNotEmpty) {
      feedback = errors.first;
      feedbackColor = Colors.red;
    }

    if (feedback.isEmpty) {
      feedback = "Controlled press! Keep tempo steady.";
    }

    this.feedback = feedback;
    this.feedbackColor = feedbackColor;
    _previousElbowForDetection = avgElbowAngle;
  }

  double calculateAngle(PoseLandmark a, PoseLandmark b, PoseLandmark c) {
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

  double _torsoAngleFromHorizontal(
    PoseLandmark leftShoulder,
    PoseLandmark rightShoulder,
    PoseLandmark leftHip,
    PoseLandmark rightHip,
  ) {
    final shoulder = Offset(
      (leftShoulder.x + rightShoulder.x) / 2,
      (leftShoulder.y + rightShoulder.y) / 2,
    );
    final hip = Offset(
      (leftHip.x + rightHip.x) / 2,
      (leftHip.y + rightHip.y) / 2,
    );
    final torso = shoulder - hip;
    final angle =
        math.atan2(torso.dy.abs(), torso.dx.abs() + 1e-6) * 180 / math.pi;
    return angle;
  }

  double _verticalStackAngle(PoseLandmark upper, PoseLandmark lower) {
    final dx = (upper.x - lower.x).abs();
    final dy = (upper.y - lower.y).abs() + 1e-6;
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
    return _torsoDrift < 6 && _elbowDrift < 8;
  }

  bool _isWithin(double value, double min, double max) =>
      value >= min && value <= max;
}
