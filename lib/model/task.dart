class Task {
  final int id;
  final int userId;
  final String title;
  final bool completed;

  Task({
    required this.id,
    required this.userId,
    required this.title,
    required this.completed,
  });

  // Convert JSON to Task object
  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'] ?? 0,
      userId: json['userId'] ?? 0,
      title: json['title'] ?? '',
      completed: json['completed'] ?? false,
    );
  }

  // Convert Task object to JSON
  Map<String, dynamic> toJson() {
    return {'id': id, 'userId': userId, 'title': title, 'completed': completed};
  }

  // Create a copy with updated fields
  Task copyWith({int? id, int? userId, String? title, bool? completed}) {
    return Task(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      completed: completed ?? this.completed,
    );
  }
}
