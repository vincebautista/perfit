import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:perfit/data/models/fitness_plan_model.dart';
import 'package:perfit/data/models/user_model.dart';

class FirebaseFirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> setUserData(UserModel user) {
    return _firestore.collection('users').doc(user.uid).set({
      'fullname': user.fullname,
      'assessmentDone': user.assessmentDone,
      'activeFitnessPlan': null,
      'pendingWorkoutPlan': null,
      'lastUpdatedDate': getTodayDateString(),
      'currentIntake': {"calories": 0, "protein": 0, "carbs": 0, "fat": 0},
    });
  }

  String getTodayDateString() {
    final now = DateTime.now();
    return "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
  }

  Future<DocumentSnapshot> getUserData(String uid) {
    return _firestore.collection('users').doc(uid).get();
  }

  Future<String> saveFitnessPlan(
    String uid,
    FitnessPlanModel fitnessPlan,
    List<Map<String, dynamic>> workouts,
  ) async {
    final planRef = await _firestore
        .collection('users')
        .doc(uid)
        .collection("fitnessPlan")
        .add(fitnessPlan.toMap());

    final planId = planRef.id;

    final workoutsCollection = planRef.collection("workouts");
    for (var workout in workouts) {
      await workoutsCollection.doc(workout["day"].toString()).set(workout);
    }

    await setActiveFitnessPlan(uid, planId);

    return planId;
  }

  Future<void> setActiveFitnessPlan(String uid, String id) {
    return _firestore.collection('users').doc(uid).update({
      'activeFitnessPlan': id,
    });
  }

  Future<void> setAssessmentDone(String uid, bool value) {
    return _firestore.collection('users').doc(uid).update({
      'assessmentDone': value,
    });
  }

  Future<String?> getActiveFitnessPlan(String uid) async {
    final user = await _firestore.collection("users").doc(uid).get();

    final data = user.data();

    if (data == null ||
        data["activeFitnessPlan"] == null ||
        data["activeFitnessPlan"].toString().isEmpty) {
      return null;
    }

    return data["activeFitnessPlan"];
  }

  Future<FitnessPlanModel?> getFitnessPlan(String uid, String planId) async {
    final docs =
        await _firestore
            .collection("users")
            .doc(uid)
            .collection("fitnessPlan")
            .doc(planId)
            .get();

    if (!docs.exists) {
      return null;
    }

    final data = docs.data();

    if (data == null) {
      return null;
    }

    return FitnessPlanModel.fromMap(data);
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> getWorkouts(
    String uid,
    String planId,
  ) async {
    final snapshot =
        await _firestore
            .collection('users')
            .doc(uid)
            .collection('fitnessPlan')
            .doc(planId)
            .collection('workouts')
            .orderBy('day')
            .get();
    return snapshot.docs;
  }

  Future<Map<String, String>> getExerciseStatuses(
    String uid,
    String planId,
  ) async {
    final workouts =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('fitnessPlan')
            .doc(planId)
            .collection('workouts')
            .get();

    final Map<String, String> statuses = {};

    for (var doc in workouts.docs) {
      final day = doc.id;
      final data = doc.data();
      final List<dynamic> exercises = data['exercises'] ?? [];

      for (final ex in exercises) {
        final name = ex['name'];
        final status = ex['status'] ?? 'pending';
        statuses["$day-$name"] = status;
      }
    }
    return statuses;
  }

  Future<void> markExerciseSkipped(
    String planId,
    String day,
    String exerciseName,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('fitnessPlan')
        .doc(planId)
        .collection('workouts')
        .doc(day);

    final snap = await docRef.get();

    if (!snap.exists) return;

    final data = snap.data()!;
    final List<dynamic> exercises = List.from(data['exercises'] ?? []);

    final idx = exercises.indexWhere((e) => e['name'] == exerciseName);

    if (idx != -1) {
      exercises[idx] = {...exercises[idx], 'status': 'skipped'};
    } else {
      exercises.add({'name': exerciseName, 'status': 'skipped'});
    }

    await docRef.update({'exercises': exercises});
  }

  Future<void> markExerciseCompleted(
    String planId,
    String day,
    String exerciseName, {
    Map<String, dynamic>? extraData,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('fitnessPlan')
        .doc(planId)
        .collection('workouts')
        .doc(day);

    final doc = await docRef.get();

    if (!doc.exists) return;

    List<dynamic> exercises = doc.data()?['exercises'] ?? [];

    List<Map<String, dynamic>> updatedExercises =
        exercises.map((e) => Map<String, dynamic>.from(e)).toList();

    final index = updatedExercises.indexWhere((e) => e['name'] == exerciseName);

    if (index != -1) {
      updatedExercises[index]['status'] = 'completed';
      if (extraData != null) {
        updatedExercises[index].addAll(extraData);
      }
    } else {
      updatedExercises.add({
        'name': exerciseName,
        'status': 'completed',
        ...?extraData,
      });
    }

    await docRef.update({'exercises': updatedExercises});
  }

  Future<void> updateWorkoutDayCompletion(String planId, int day) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final workoutDayRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('fitnessPlan')
        .doc(planId)
        .collection('workouts')
        .doc("$day");

    final doc = await workoutDayRef.get();
    if (!doc.exists) return;

    final data = doc.data()!;
    final List<dynamic> exercises = data['exercises'] ?? [];

    int finishedCount = exercises.where((e) => e['status'] != null).length;
    int totalExercises = exercises.length;

    if (finishedCount == totalExercises && totalExercises > 0) {
      await workoutDayRef.set({
        'day': day,
        'status': "completed",
        'dateCompleted': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print("🔥 Day $day marked as completed ✅");
    } else {
      print("Day $day not complete yet ($finishedCount/$totalExercises)");
    }
  }

  Future<void> incrementCurrentDay(String uid, String planId) async {
    final planRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('fitnessPlan')
        .doc(planId);

    await planRef.set(
      {'currentDay': FieldValue.increment(1)},
      SetOptions(merge: true),
    ); // merge ensures the rest of the document stays intact
  }

  Future<void> updateExerciseStatus(
    String userId,
    String planId,
    int day,
    String exerciseName,
    String status,
  ) async {
    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('fitnessPlan')
        .doc(planId)
        .collection('workouts')
        .doc("$day");

    await ref.set({
      'exercisesStatus': {exerciseName: status},
    }, SetOptions(merge: true));
  }

  Future<void> skipAllExercises(
    String planId,
    int day,
    List<dynamic> exercises,
  ) async {
    for (var ex in exercises) {
      await markExerciseSkipped(planId, day.toString(), ex['name']);
    }
  }
}
