import 'dart:async';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class GestureService {
  bool _handsUp = false;
  Timer? _countdownTimer;
  int remainingSeconds = 0;
  bool _countdownRunning = false;

  bool get countdownRunning => _countdownRunning;

  DateTime? _handsUpStart;
  final int holdMilliseconds = 1000; // 1-second hold

  /// Returns true if hands are above head
  /// and updates hold and countdown progress.
  bool update(
    Pose pose, {
    required int startCountdown,
    Function(double)? onHoldProgress, // 0.0 to 1.0
    Function? onHandsUpDetected,
    Function? onCountdownTick,
    Function? onCountdownComplete,
  }) {
    final landmarks = pose.landmarks;
    final nose = landmarks[PoseLandmarkType.nose];
    final rightWrist = landmarks[PoseLandmarkType.rightWrist];

    if (nose == null || rightWrist == null) {
      _handsUpStart = null;
      if (!_countdownRunning) _handsUp = false;
      if (onHoldProgress != null) onHoldProgress(0.0);
      return false;
    }

    final handsAreUp = rightWrist.y < nose.y;

    // Before countdown starts, track 1-second hold
    if (!_countdownRunning) {
      if (handsAreUp) {
        if (_handsUpStart == null) _handsUpStart = DateTime.now();
        final heldDuration =
            DateTime.now().difference(_handsUpStart!).inMilliseconds;
        final progress = (heldDuration / holdMilliseconds).clamp(0.0, 1.0);
        if (onHoldProgress != null) onHoldProgress(progress);

        if (heldDuration >= holdMilliseconds) {
          // Hand held for 1 second → start countdown
          _handsUp = true;
          _countdownRunning = true;
          if (onHandsUpDetected != null) onHandsUpDetected();
          _startCountdown(
            startSeconds: startCountdown,
            onTick: onCountdownTick,
            onComplete: () {
              _countdownRunning = false;
              if (onCountdownComplete != null) onCountdownComplete();
            },
          );
        }
      } else {
        // Hand dropped before 1 second → reset
        _handsUpStart = null;
        _handsUp = false;
        if (onHoldProgress != null) onHoldProgress(0.0);
      }
    }

    return handsAreUp;
  }

  void _startCountdown({
    required int startSeconds,
    Function? onTick,
    Function? onComplete,
  }) {
    remainingSeconds = startSeconds;
    _countdownTimer?.cancel();

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      remainingSeconds--;

      if (onTick != null) onTick(remainingSeconds);

      if (remainingSeconds <= 0) {
        _countdownTimer?.cancel();
        if (onComplete != null) onComplete();
      }
    });
  }

  void reset() {
    _handsUp = false;
    _handsUpStart = null;
    remainingSeconds = 0;
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _countdownRunning = false;
  }
}
