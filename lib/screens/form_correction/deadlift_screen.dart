import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class DeadliftFormCorrection {
  bool isLiftStarted = false;

  String feedback = "";
  Color feedbackColor = Colors.green;

  double? _setupTorsoAngle;
  double? _previousTorsoAngle;
  double? _previousHipAngle;
  double? _previousKneeAngle;
  double _torsoDrift = 0;
  double _hipDrift = 0;

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
      PoseLandmarkType.leftFootIndex,
      PoseLandmarkType.rightFootIndex,
    ];

    if (requiredTypes.any((type) => map[type] == null)) {
      this.feedback =
          "Step fully into frame so we can see hips, knees and feet.";
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
    final leftFoot = map[PoseLandmarkType.leftFootIndex]!;
    final rightFoot = map[PoseLandmarkType.rightFootIndex]!;

    // Required angles.
    double kneeAngleLeft = calculateAngle(leftHip, leftKnee, leftAnkle);
    double kneeAngleRight = calculateAngle(rightHip, rightKnee, rightAnkle);
    double hipAngleLeft = calculateAngle(leftShoulder, leftHip, leftKnee);
    double hipAngleRight = calculateAngle(rightShoulder, rightHip, rightKnee);
    double torsoAngle = _torsoAngleFromVertical(
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

    final avgKneeAngle = (kneeAngleLeft + kneeAngleRight) / 2;

    _setupTorsoAngle ??= torsoAngle;

    final poseStable = _updateStability(torsoAngle, hipAngle);
    if (!poseStable) {
      this.feedback = "Hold the setup for a second so we can lock in angles.";
      this.feedbackColor = Colors.orange;
      return;
    }

    _detectLiftStart(hipAngle, torsoAngle);

    final List<String> errors = [];

    if (torsoAngle < 30 || torsoAngle > 55) {
      errors.add(
        "Maintain a 30°–45° torso lean; avoid rounding or overextending.",
      );
    } else if (_setupTorsoAngle != null &&
        (torsoAngle - _setupTorsoAngle!).abs() > 10) {
      errors.add("Keep your back neutral—limit torso change to ±10°.");
    }

    if (!isLiftStarted && (avgKneeAngle < 90 || avgKneeAngle > 120)) {
      errors.add("Dial in setup: knees should be 90°–120°.");
    }

    if (!isLiftStarted && hipAngle > 100) {
      errors.add("Hinge more at the hips to load the posterior chain.");
    }

    if (_previousHipAngle != null &&
        _previousKneeAngle != null &&
        (hipAngle - _previousHipAngle!) > 8 &&
        avgKneeAngle > 110) {
      errors.add("Drive with the legs—hips are shooting up too soon.");
    }

    final shinAngleLeft = _verticalStackAngle(leftKnee, leftAnkle, leftFoot);
    final shinAngleRight = _verticalStackAngle(
      rightKnee,
      rightAnkle,
      rightFoot,
    );
    if (shinAngleLeft > 10 || shinAngleRight > 10) {
      errors.add("Keep shins more vertical—knees are drifting past toes.");
    }

    final barDrift = _barPathAngle(
      leftWrist,
      rightWrist,
      leftAnkle,
      rightAnkle,
    );
    if (barDrift > 15) {
      errors.add("Keep the bar over mid-foot; pull it back toward the shins.");
    }

    if (elbowAngleLeft < 165 || elbowAngleRight < 165) {
      errors.add("Keep arms straight—no elbow bend during the pull.");
    }

    if (shoulderAngle > 70) {
      errors.add("Pack the shoulders down to keep lats engaged.");
    }

    if (errors.isNotEmpty) {
      feedback = errors.first;
      feedbackColor = Colors.red;
    } else {
      feedback = "Strong pull—maintain that brace.";
    }

    this.feedback = feedback;
    this.feedbackColor = feedbackColor;

    _previousHipAngle = hipAngle;
    _previousKneeAngle = avgKneeAngle;
    _previousTorsoAngle = torsoAngle;
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

  double _torsoAngleFromVertical(
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
    return math.atan2(torso.dx.abs(), torso.dy.abs() + 1e-6) * 180 / math.pi;
  }

  double _verticalStackAngle(
    PoseLandmark knee,
    PoseLandmark ankle,
    PoseLandmark foot,
  ) {
    final dx = (knee.x - ankle.x).abs();
    final dy = (knee.y - ankle.y).abs() + 1e-6;
    final kneeToToeDx = (knee.x - foot.x).abs();
    final kneeToToeDy = (knee.y - foot.y).abs() + 1e-6;
    final shinAngle = math.atan2(dx, dy) * 180 / math.pi;
    final kneeToeAngle = math.atan2(kneeToToeDx, kneeToToeDy) * 180 / math.pi;
    return math.max(shinAngle, kneeToeAngle);
  }

  double _barPathAngle(
    PoseLandmark leftWrist,
    PoseLandmark rightWrist,
    PoseLandmark leftAnkle,
    PoseLandmark rightAnkle,
  ) {
    final wristX = (leftWrist.x + rightWrist.x) / 2;
    final wristY = (leftWrist.y + rightWrist.y) / 2;
    final ankleX = (leftAnkle.x + rightAnkle.x) / 2;
    final ankleY = (leftAnkle.y + rightAnkle.y) / 2;
    final dx = (wristX - ankleX).abs();
    final dy = (wristY - ankleY).abs() + 1e-6;
    return math.atan2(dx, dy) * 180 / math.pi;
  }

  bool _updateStability(double torsoAngle, double hipAngle) {
    if (_previousTorsoAngle != null) {
      final delta = (torsoAngle - _previousTorsoAngle!).abs();
      _torsoDrift = _torsoDrift * 0.7 + delta * 0.3;
    }
    if (_previousHipAngle != null) {
      final delta = (hipAngle - _previousHipAngle!).abs();
      _hipDrift = _hipDrift * 0.7 + delta * 0.3;
    }
    return _torsoDrift < 6 && _hipDrift < 8;
  }

  void _detectLiftStart(double hipAngle, double torsoAngle) {
    if (isLiftStarted) return;
    if (_previousHipAngle == null || _previousTorsoAngle == null) return;

    final hipDelta = hipAngle - _previousHipAngle!;
    final torsoDelta = _previousTorsoAngle! - torsoAngle;
    if (hipDelta > 5 && torsoDelta > -2) {
      isLiftStarted = true;
      _setupTorsoAngle = _previousTorsoAngle;
    }
  }
}