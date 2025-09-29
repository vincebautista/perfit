class ExerciseMetricsModel {
  final String name;
  final int sets;
  final int rest;

  ExerciseMetricsModel({
    required this.name,
    required this.sets,
    required this.rest,
  });

  static ExerciseMetricsModel parseExercise(Map<String, dynamic> json) {
    if (json.containsKey("reps")) {
      return RepsExercise(
        name: json["name"],
        sets: json["sets"],
        rest: json["rest"],
        reps: json["reps"],
      );
    } else {
      return TimeExercise(
        name: json["name"],
        sets: json["sets"],
        rest: json["rest"],
        duration: json["duration"],
      );
    }
  }

  @override
  String toString() => 'Exercise(name: $name, sets: $sets, rest: $rest)';
}

class RepsExercise extends ExerciseMetricsModel {
  final int reps;

  RepsExercise({
    required super.name,
    required super.sets,
    required super.rest,
    required this.reps,
  });

  @override
  String toString() =>
      'RepsExercise(name: $name, sets: $sets, rest: $rest, reps: $reps)';
}

class TimeExercise extends ExerciseMetricsModel {
  final int duration;

  TimeExercise({
    required super.name,
    required super.sets,
    required super.rest,
    required this.duration,
  });

  @override
  String toString() =>
      'TimeExercise(name: $name, sets: $sets, rest: $rest, duration: $duration)';
}
