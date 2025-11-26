enum TaskPriority { low, medium, high }

// ENUM: Gentagelsesfrekvens
enum TaskRepeat { never, daily, weekly, monthly }

// --- TASK STEP MODEL ---
class TaskStep {
  final String id;
  final String title;
  final bool isCompleted;

  TaskStep({
    required this.id, 
    required this.title, 
    this.isCompleted = false
  });

  // Konvertering til Firebase
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'isCompleted': isCompleted,
    };
  }

  factory TaskStep.fromMap(Map<String, dynamic> map) {
    return TaskStep(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      isCompleted: map['isCompleted'] ?? false,
    );
  }
  
  // CopyWith til immutable updates
  TaskStep copyWith({String? title, bool? isCompleted}) {
    return TaskStep(
      id: id,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}

class TodoTask {
  final String id;
  final String title;
  final String category;
  final String description;
  final DateTime? dueDate;
  final TaskPriority priority;
  final TaskRepeat repeat; // Gentagelse
  final bool isCompleted;
  final DateTime createdAt;
  final String listId;
  final List<TaskStep> steps; // Delopgaver

  TodoTask({
    required this.id,
    required this.title,
    this.category = 'Generelt',
    this.description = '',
    this.dueDate,
    this.priority = TaskPriority.medium,
    this.repeat = TaskRepeat.never,
    this.isCompleted = false,
    required this.createdAt,
    this.listId = '',
    this.steps = const [], // Default tom liste
  });

  TodoTask copyWith({
    String? id,
    String? title,
    String? category,
    String? description,
    DateTime? dueDate,
    TaskPriority? priority,
    TaskRepeat? repeat,
    bool? isCompleted,
    DateTime? createdAt,
    String? listId,
    List<TaskStep>? steps,
  }) {
    return TodoTask(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      description: description ?? this.description,
      dueDate: dueDate ?? this.dueDate,
      priority: priority ?? this.priority,
      repeat: repeat ?? this.repeat,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
      listId: listId ?? this.listId,
      steps: steps ?? this.steps,
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
      'repeat': repeat.index,
      'isCompleted': isCompleted,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'listId': listId,
      'steps': steps.map((x) => x.toMap()).toList(), // Serialiser steps
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
      repeat: map['repeat'] != null ? TaskRepeat.values[map['repeat']] : TaskRepeat.never,
      isCompleted: map['isCompleted'] ?? false,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] ?? DateTime.now().millisecondsSinceEpoch),
      listId: map['listId'] ?? '',
      // Deserialiser steps
      steps: map['steps'] != null 
          ? List<TaskStep>.from(map['steps']?.map((x) => TaskStep.fromMap(x)))
          : [],
    );
  }
}

// ... PomodoroSettings class forbliver uændret ...
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