
class TodoTask {
  final String id;
  final String title;
  final String category;
  bool isCompleted;
  final DateTime createdAt;

  TodoTask({
    required this.id,
    required this.title,
    this.category = 'Generelt',
    this.isCompleted = false,
    required this.createdAt,
  });

  TodoTask copyWith({
    String? id,
    String? title,
    String? category,
    bool? isCompleted,
    DateTime? createdAt,
  }) {
    return TodoTask(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}