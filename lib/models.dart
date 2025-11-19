enum TaskPriority { low, medium, high }

class TodoTask {
  final String id;
  final String title;
  final String category;
  final String description; // Ny: Notater/Beskrivelse
  final DateTime? dueDate;  // Ny: Deadline
  final TaskPriority priority; // Ny: Prioritet
  bool isCompleted;
  final DateTime createdAt;

  TodoTask({
    required this.id,
    required this.title,
    this.category = 'Generelt',
    this.description = '',
    this.dueDate,
    this.priority = TaskPriority.medium,
    this.isCompleted = false,
    required this.createdAt,
  });

  TodoTask copyWith({
    String? id,
    String? title,
    String? category,
    String? description,
    DateTime? dueDate,
    TaskPriority? priority,
    bool? isCompleted,
    DateTime? createdAt,
  }) {
    return TodoTask(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      description: description ?? this.description,
      dueDate: dueDate ?? this.dueDate,
      priority: priority ?? this.priority,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}