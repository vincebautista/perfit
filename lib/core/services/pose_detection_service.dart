// services/pose_service.dart
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class PoseDetectionService {
  late PoseDetector _poseDetector;

  PoseDetectionService() {
    _poseDetector = PoseDetector(
      options: PoseDetectorOptions(model: PoseDetectionModel.accurate),
    );
  }

  Future<List<Pose>> detectPoses(InputImage image) {
    return _poseDetector.processImage(image);
  }

  void dispose() => _poseDetector.close();
}
