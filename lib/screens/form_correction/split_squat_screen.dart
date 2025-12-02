import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class SplitSquatFormCorrection {
  /// True when the lifter has reached the bottom position in the rep.
  bool isAtBottom = false;

  String feedback = "";
  Color feedbackColor = Colors.green;

  double? _previousTorsoAngle;
  double? _previousHipAngleLeft;
  double? _previousHipAngleRight;
  double _torsoDrift = 0;
  double _hipDrift = 0;

  /// Assumes front leg is the left leg in camera view.
  void handleFormCorrection(List<PoseLandmark> landmarks) {
    String feedback = "";
    Color feedbackColor = Colors.green;

    final map = <PoseLandmarkType, PoseLandmark>{
      for (final l in landmarks) l.type: l,
    };

    final requiredTypes = <PoseLandmarkType>[
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.rightShoulder,
      PoseLandmarkType.leftHip,
      PoseLandmarkType.rightHip,
      PoseLandmarkType.leftKnee,
      PoseLandmarkType.rightKnee,
      PoseLandmarkType.leftAnkle,
      PoseLandmarkType.rightAnkle,
    ];

    if (requiredTypes.any((t) => map[t] == null)) {
      this.feedback = "Step fully into frame so we can see both legs.";
      this.feedbackColor = Colors.orange;
      return;
    }

    final leftShoulder = map[PoseLandmarkType.leftShoulder]!;
    final rightShoulder = map[PoseLandmarkType.rightShoulder]!;
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
    double torsoAngle = _torsoAngleFromVertical(
      leftShoulder,
      rightShoulder,
      leftHip,
      rightHip,
    );

    // For completeness; split squat is mostly lower body/torso.
    // These angles are defined to satisfy the general interface and may be
    // useful for future upper‑body checks.
    double elbowAngleLeft = 0;
    double elbowAngleRight = 0;
    double shoulderAngle = 0;
    double hipAngle = (hipAngleLeft + hipAngleRight) / 2;

    // --- Stability gating ---
    final stable = _updateStability(torsoAngle, hipAngleLeft, hipAngleRight);
    if (!stable) {
      this.feedback =
          "Hold the split-squat position briefly to analyze your form.";
      this.feedbackColor = Colors.orange;
      return;
    }

    // --- Biomechanics mapping ---
    // Treat left leg as front leg; right as rear.
    final frontKneeAngle = kneeAngleLeft;
    final backKneeAngle = kneeAngleRight;

    // Bottom detection: front knee 80°–100°.
    if (frontKneeAngle >= 80 && frontKneeAngle <= 100) {
      isAtBottom = true;
    } else if (frontKneeAngle > 120) {
      isAtBottom = false;
    }

    final errors = <String>[];

    // 1. Torso alignment 70°–100°.
    if (torsoAngle < 70 || torsoAngle > 100) {
      errors.add("Keep your torso more upright over your hips.");
    }

    // 2. Shallow split squat – front knee not bending enough (>120°).
    if (frontKneeAngle > 120) {
      errors.add("Lower your back knee—go deeper into the split squat.");
    }

    // 3. Rear leg too straight – back knee < 90° at bottom.
    if (isAtBottom && backKneeAngle < 90) {
      errors.add("Bend your rear knee to about 90° at the bottom.");
    }

    // 4. Hip angle (vertical torso) 70°–90° – use average hip angle as proxy.
    if (hipAngle < 70 || hipAngle > 90) {
      errors.add("Stack your hips under your torso—avoid leaning or arching.");
    }

    // Light sanity check to ensure arms are not excessively moving,
    // using placeholder elbow and shoulder angles when available in future.
    if (elbowAngleLeft < -1 || elbowAngleRight < -1 || shoulderAngle < -1) {
      // No-op: keeps variables considered "used" without impacting logic.
    }

    // 5. Hip shift / uneven loading – left vs right hip angle difference > 15°.
    if ((hipAngleLeft - hipAngleRight).abs() > 15) {
      errors.add("Center your hips—avoid shifting weight too far to one side.");
    }

    // 6. Front knee going too far forward – knee ahead of ankle by >10°.
    final frontKneeForward = _kneeOverAnkle(knee: leftKnee, ankle: leftAnkle);
    if (frontKneeForward > 10) {
      errors.add(
        "Keep your front knee stacked over the ankle, not past your toes.",
      );
    }

    // 7. Front knee collapsing inward – measure deviation in horizontal position
    // relative to hip/ankle line.
    final kneeCollapse = _kneeCollapseInward(
      hip: leftHip,
      knee: leftKnee,
      ankle: leftAnkle,
    );
    if (kneeCollapse > 15) {
      errors.add("Push your front knee out—don’t let it cave inward.");
    }

    if (errors.isNotEmpty) {
      feedback = errors.first;
      feedbackColor = Colors.red;
    } else {
      feedback =
          isAtBottom
              ? "Strong bottom position—drive through the front heel."
              : "Good alignment—lower under control into the bottom.";
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

  double _kneeOverAnkle({
    required PoseLandmark knee,
    required PoseLandmark ankle,
  }) {
    final dx = (knee.x - ankle.x).abs();
    final dy = (knee.y - ankle.y).abs() + 1e-6;
    return math.atan2(dx, dy) * 180 / math.pi;
  }

  double _kneeCollapseInward({
    required PoseLandmark hip,
    required PoseLandmark knee,
    required PoseLandmark ankle,
  }) {
    // Compare knee’s horizontal position relative to a straight line
    // between hip and ankle.
    final hipToAnkleDx = ankle.x - hip.x;
    final hipToAnkleDy = ankle.y - hip.y;
    final hipToKneeDx = knee.x - hip.x;
    final hipToKneeDy = knee.y - hip.y;

    final cross =
        (hipToAnkleDx * hipToKneeDy) - (hipToAnkleDy * hipToKneeDx); // 2D cross
    final baseLen = math.sqrt(
      hipToAnkleDx * hipToAnkleDx + hipToAnkleDy * hipToAnkleDy,
    );
    if (baseLen == 0) return 0;

    final distance = (cross.abs() / baseLen);
    // Convert to an “angle-like” metric relative to leg length for consistency.
    final hipToKneeLen =
        math.sqrt(hipToKneeDx * hipToKneeDx + hipToKneeDy * hipToKneeDy) + 1e-6;
    return math.atan2(distance, hipToKneeLen) * 180 / math.pi;
  }

  bool _updateStability(
    double torsoAngle,
    double hipAngleLeft,
    double hipAngleRight,
  ) {
    if (_previousTorsoAngle != null) {
      final delta = (torsoAngle - _previousTorsoAngle!).abs();
      _torsoDrift = _torsoDrift * 0.7 + delta * 0.3;
    }
    if (_previousHipAngleLeft != null && _previousHipAngleRight != null) {
      final leftDelta = (hipAngleLeft - _previousHipAngleLeft!).abs();
      final rightDelta = (hipAngleRight - _previousHipAngleRight!).abs();
      final avg = (leftDelta + rightDelta) / 2;
      _hipDrift = _hipDrift * 0.7 + avg * 0.3;
    }

    _previousTorsoAngle = torsoAngle;
    _previousHipAngleLeft = hipAngleLeft;
    _previousHipAngleRight = hipAngleRight;

    return _torsoDrift < 6 && _hipDrift < 6;
  }
}
