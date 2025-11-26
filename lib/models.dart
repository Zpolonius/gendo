// lib/models.dart

enum TaskPriority { low, medium, high }

// --- TASK STEP MODEL -
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

// --- TODO TASK MODEL ---
class TodoTask {
  final String id;
  final String title;
  final String category;
  final String description;
  final DateTime? dueDate;
  final TaskPriority priority;
  final bool isCompleted; // Rettelse: Gjort final for immutability
  final DateTime createdAt;
  final String listId;
  final int timeSpent;
  final List<TaskStep> steps; // NYT FELT: Listen af delopgaver

  TodoTask({
    required this.id,
    required this.title,
    this.category = 'Generelt',
    this.description = '',
    this.dueDate,
    this.priority = TaskPriority.low,
    this.isCompleted = false,
    required this.createdAt,
    this.listId = '',
    this.timeSpent = 0,
    this.steps = const [], // Default tom liste
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
    String? listId,
    int? timeSpent,
    List<TaskStep>? steps, // Mulighed for at opdatere steps
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
      listId: listId ?? this.listId,
      timeSpent: timeSpent ?? this.timeSpent,
      steps: steps ?? this.steps, // Beholder eksisterende steps hvis null
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
      'listId': listId,
      'timeSpent': timeSpent,
      // Konverterer listen af TaskStep objekter til en liste af Maps for Firebase
      'steps': steps.map((x) => x.toMap()).toList(), 
    };
  }

  factory TodoTask.fromMap(Map<String, dynamic> map) {
    return TodoTask(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      category: map['category'] ?? 'Generelt',
      description: map['description'] ?? '',
      dueDate: map['dueDate'] != null ? DateTime.fromMillisecondsSinceEpoch(map['dueDate']) : null,
      priority: TaskPriority.values[map['priority'] ?? 0], // Rettelse: 0 matcher low (default)
      isCompleted: map['isCompleted'] ?? false,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] ?? DateTime.now().millisecondsSinceEpoch),
      listId: map['listId'] ?? '',
      timeSpent: map['timeSpent'] ?? 0,
      // Konverterer listen fra Firebase (List<dynamic>) tilbage til List<TaskStep>
      steps: map['steps'] != null 
          ? List<TaskStep>.from(map['steps']?.map((x) => TaskStep.fromMap(x)))
          : [],
    );
  }
}

// --- POMODORO SETTINGS ---
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