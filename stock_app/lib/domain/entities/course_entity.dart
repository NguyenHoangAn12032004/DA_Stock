class Lesson {
  final String id;
  final String title;
  final String duration;
  final String videoUrl;
  final String thumbnail;
  final bool isCompleted;

  Lesson({
    required this.id,
    required this.title,
    required this.duration,
    required this.videoUrl,
    required this.thumbnail,
    this.isCompleted = false,
  });

  factory Lesson.fromJson(Map<String, dynamic> json) {
    return Lesson(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      duration: json['duration'] ?? '',
      videoUrl: json['video_url'] ?? '',
      thumbnail: json['thumbnail'] ?? '',
      isCompleted: json['is_completed'] ?? false,
    );
  }
}

class Course {
  final String id; // Document ID (e.g., beginner)
  final String title;
  final String level;
  final String description;
  final List<Lesson> lessons;

  Course({
    required this.id,
    required this.title,
    required this.level,
    required this.description,
    required this.lessons,
  });

  factory Course.fromJson(String id, Map<String, dynamic> json) {
    var list = json['lessons'] as List? ?? [];
    List<Lesson> lessonsList = list.map((i) => Lesson.fromJson(i)).toList();

    return Course(
      id: id,
      title: json['title'] ?? '',
      level: json['level'] ?? '',
      description: json['description'] ?? '',
      lessons: lessonsList,
    );
  }
}
