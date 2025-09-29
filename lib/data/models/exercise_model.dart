class ExerciseModel {
  final String id;
  final String name;
  final List<String> video;
  final String image;
  final List<String> instructions;
  final String difficulty;
  final String type;
  final String targetBody;
  final String location;

  ExerciseModel({
    required this.id,
    required this.name,
    required this.video,
    required this.image,
    required this.instructions,
    required this.difficulty,
    required this.type,
    required this.targetBody,
    required this.location, 
  });
}
