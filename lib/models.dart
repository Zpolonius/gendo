enum TaskPriority { low, medium, high }

class TodoTask {
  final String id;
  final String title;
  final String category;
  final String description;
  final DateTime? dueDate;
  final TaskPriority priority;
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

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'category': category,
      'description': description,
      'dueDate': dueDate?.millisecondsSinceEpoch,
      'priority': priority.index,
      'isCompleted': isCompleted,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  factory TodoTask.fromMap(Map<String, dynamic> map) {
    return TodoTask(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      category: map['category'] ?? 'Generelt',
      description: map['description'] ?? '',
      dueDate: map['dueDate'] != null ? DateTime.fromMillisecondsSinceEpoch(map['dueDate']) : null,
      priority: TaskPriority.values[map['priority'] ?? 1],
      isCompleted: map['isCompleted'] ?? false,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] ?? DateTime.now().millisecondsSinceEpoch),
    );
  }
}

// --- NY MODEL: POMODORO SETTINGS ---
class PomodoroSettings {
  final int workDurationMinutes;
  final bool enableBreaks;
  final bool enableLongBreaks;

  PomodoroSettings({
    this.workDurationMinutes = 25,
    this.enableBreaks = true,
    this.enableLongBreaks = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'workDurationMinutes': workDurationMinutes,
      'enableBreaks': enableBreaks,
      'enableLongBreaks': enableLongBreaks,
    };
  }

  factory PomodoroSettings.fromMap(Map<String, dynamic> map) {
    return PomodoroSettings(
      workDurationMinutes: map['workDurationMinutes'] ?? 25,
      enableBreaks: map['enableBreaks'] ?? true,
      enableLongBreaks: map['enableLongBreaks'] ?? true,
    );
  }
}