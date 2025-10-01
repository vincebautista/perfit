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
        name: json["name"] ?? 'Unknown',
        sets: parseNumber(json["sets"]),
        rest: parseNumber(json["rest"]),
        reps: parseNumber(json["reps"]),
      );
    } else {
      return TimeExercise(
        name: json["name"] ?? 'Unknown',
        sets: parseNumber(json["sets"]),
        rest: parseNumber(json["rest"]),
        duration: parseNumber(json["duration"]),
      );
    }
  }

  static int parseNumber(dynamic value) {
    if (value == null) return 0;
    final str = value.toString();
    final match = RegExp(r'\d+').firstMatch(str);
    if (match != null) {
      return int.tryParse(match.group(0)!) ?? 0;
    }
    return 0;
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
