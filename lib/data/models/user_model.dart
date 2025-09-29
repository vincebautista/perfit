class UserModel {
  final String uid;
  final String fullname;
  final bool assessmentDone;
  final String? activeFitnessPlan;
  final String? pendingWorkout;

  UserModel({
    required this.uid,
    required this.fullname,
    required this.assessmentDone,
    this.activeFitnessPlan,
    this.pendingWorkout,
  });
}
