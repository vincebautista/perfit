import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class PlankFormCorrection {
  /// True once the plank has stabilized in a good position for a short time.
  bool isHolding = false;

  String feedback = "";
  Color feedbackColor = Colors.green;

  double? _previousTorsoAngle;
  double? _previousHipAngle;
  double? _previousShoulderAngle;
  double _torsoDrift = 0;
  double _hipDrift = 0;
  double _shoulderDrift = 0;

  /// Main entry point – call each frame with the current pose landmarks.
  void handleFormCorrection(List<PoseLandmark> landmarks) {
    String feedback = "";
    Color feedbackColor = Colors.green;

    // Index landmarks by type for easier access.
    final map = <PoseLandmarkType, PoseLandmark>{
      for (final l in landmarks) l.type: l,
    };

    final requiredTypes = <PoseLandmarkType>[
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.rightShoulder,
      PoseLandmarkType.leftElbow,
      PoseLandmarkType.rightElbow,
      PoseLandmarkType.leftHip,
      PoseLandmarkType.rightHip,
      PoseLandmarkType.leftKnee,
      PoseLandmarkType.rightKnee,
      PoseLandmarkType.leftAnkle,
      PoseLandmarkType.rightAnkle,
    ];

    if (requiredTypes.any((t) => map[t] == null)) {
      this.feedback = "Make sure your full body is visible to the camera.";
      this.feedbackColor = Colors.orange;
      return;
    }

    final leftShoulder = map[PoseLandmarkType.leftShoulder]!;
    final rightShoulder = map[PoseLandmarkType.rightShoulder]!;
    final leftElbow = map[PoseLandmarkType.leftElbow]!;
    final rightElbow = map[PoseLandmarkType.rightElbow]!;
    final leftHip = map[PoseLandmarkType.leftHip]!;
    final rightHip = map[PoseLandmarkType.rightHip]!;
    final leftKnee = map[PoseLandmarkType.leftKnee]!;
    final rightKnee = map[PoseLandmarkType.rightKnee]!;
    final leftAnkle = map[PoseLandmarkType.leftAnkle]!;
    final rightAnkle = map[PoseLandmarkType.rightAnkle]!;

    // --- Required angles (general spec) ---
    double kneeAngleLeft = calculateAngle(leftHip, leftKnee, leftAnkle);
    double kneeAngleRight = calculateAngle(rightHip, rightKnee, rightAnkle);
    double hipAngleLeft = calculateAngle(leftShoulder, leftHip, leftKnee);
    double hipAngleRight = calculateAngle(rightShoulder, rightHip, rightKnee);

    // Torso alignment: shoulder–hip line vs horizontal.
    double torsoAngle = _torsoAngleFromHorizontal(
      leftShoulder,
      rightShoulder,
      leftHip,
      rightHip,
    );

    // Elbow angles (forearm plank).
    // Initialize elbow angles with a neutral value; will be updated if wrists exist.
    double elbowAngleLeft = 90;
    double elbowAngleRight = 90;

    // Shoulder stacking: vertical angle of shoulder relative to elbow and hip.
    double shoulderAngle =
        (calculateAngle(leftElbow, leftShoulder, leftHip) +
            calculateAngle(rightElbow, rightShoulder, rightHip)) /
        2;

    double hipAngle = (hipAngleLeft + hipAngleRight) / 2;

    // For this implementation, elbows are bent to about 90° – use elbow‑shoulder‑hip
    // as general elbow metric; knees included only for stability / redundancy.
    // Recompute elbow angles correctly using wrists for completeness if present.
    if (map[PoseLandmarkType.leftWrist] != null &&
        map[PoseLandmarkType.rightWrist] != null) {
      final leftWrist = map[PoseLandmarkType.leftWrist]!;
      final rightWrist = map[PoseLandmarkType.rightWrist]!;
      elbowAngleLeft = calculateAngle(leftShoulder, leftElbow, leftWrist);
      elbowAngleRight = calculateAngle(rightShoulder, rightElbow, rightWrist);
    }

    // --- Stability gating ---
    final stable = _updateStability(torsoAngle, hipAngle, shoulderAngle);
    if (!stable) {
      this.feedback = "Hold still briefly to get accurate plank feedback.";
      this.feedbackColor = Colors.orange;
      return;
    }

    // --- Biomechanics checks ---
    final errors = <String>[];

    // 1. Torso alignment (neutral back).
    if (torsoAngle < 165 || torsoAngle > 180) {
      errors.add(
        "Keep your back flat—aim for a straight line from shoulders to hips.",
      );
    }

    // 2. Hip alignment vs torso.
    if (hipAngle < torsoAngle - 10) {
      errors.add(
        "Your hips are sagging—gently lift them to line up with your torso.",
      );
    } else if (hipAngle > torsoAngle + 10) {
      errors.add("Your hips are piking—lower them to form a straight line.");
    }

    // 3. Shoulders drifting forward/backward (stacking).
    if (shoulderAngle < 70 || shoulderAngle > 100) {
      errors.add(
        "Stack shoulders over elbows—don’t lean too far forward or back.",
      );
    }

    // 4. Elbow angles (forearm plank range 80°–100°).
    if (elbowAngleLeft < 80 ||
        elbowAngleLeft > 100 ||
        elbowAngleRight < 80 ||
        elbowAngleRight > 100) {
      errors.add("Keep elbows at roughly 90° under the shoulders.");
    }

    // Basic symmetry check on legs so knees aren’t wildly uneven.
    if ((kneeAngleLeft - kneeAngleRight).abs() > 20) {
      errors.add("Balance both legs evenly—avoid twisting the lower body.");
    }

    // --- Holding-state detection ---
    final inGoodRange =
        errors.isEmpty &&
        torsoAngle >= 165 &&
        torsoAngle <= 180 &&
        (hipAngle - torsoAngle).abs() <= 10 &&
        shoulderAngle >= 70 &&
        shoulderAngle <= 100 &&
        elbowAngleLeft >= 80 &&
        elbowAngleLeft <= 100 &&
        elbowAngleRight >= 80 &&
        elbowAngleRight <= 100;

    if (inGoodRange) {
      // Once stable pose is good, consider the plank as "holding".
      isHolding = true;
    }

    if (errors.isNotEmpty) {
      feedback = errors.first;
      feedbackColor = Colors.red;
    } else {
      feedback =
          isHolding
              ? "Great plank—hold this position!"
              : "Good position—settle in and hold.";
    }

    this.feedback = feedback;
    this.feedbackColor = feedbackColor;
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
    return math.atan2(torso.dy.abs(), torso.dx.abs() + 1e-6) * 180 / math.pi;
  }

  bool _updateStability(
    double torsoAngle,
    double hipAngle,
    double shoulderAngle,
  ) {
    if (_previousTorsoAngle != null) {
      final delta = (torsoAngle - _previousTorsoAngle!).abs();
      _torsoDrift = _torsoDrift * 0.7 + delta * 0.3;
    }
    if (_previousHipAngle != null) {
      final delta = (hipAngle - _previousHipAngle!).abs();
      _hipDrift = _hipDrift * 0.7 + delta * 0.3;
    }
    if (_previousShoulderAngle != null) {
      final delta = (shoulderAngle - _previousShoulderAngle!).abs();
      _shoulderDrift = _shoulderDrift * 0.7 + delta * 0.3;
    }

    _previousTorsoAngle = torsoAngle;
    _previousHipAngle = hipAngle;
    _previousShoulderAngle = shoulderAngle;

    // Conservative thresholds for a “steady” static hold.
    return _torsoDrift < 4 && _hipDrift < 4 && _shoulderDrift < 4;
  }
}
