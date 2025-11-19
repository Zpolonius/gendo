import 'dart:async';
import 'models.dart';

abstract class TaskRepository {
  Future<List<TodoTask>> getTasks();
  Future<void> addTask(TodoTask task);
  Future<void> updateTask(TodoTask task);
  Future<void> deleteTask(String id);
  
  // Nye metoder til kategorier
  Future<List<String>> getCategories();
  Future<void> addCategory(String category);
}

class MockTaskRepository implements TaskRepository {
  final List<TodoTask> _tasks = [
    TodoTask(
      id: '1', 
      title: 'Opsæt Flutter projekt', 
      category: 'Dev', 
      description: 'Husk at inkludere Provider og Google Fonts i pubspec.yaml.',
      priority: TaskPriority.high,
      createdAt: DateTime.now()
    ),
    TodoTask(
      id: '2', 
      title: 'Test GenDo Dark Mode', 
      category: 'QA', 
      description: 'Tjek kontrasten på den lilla farve i dark mode. Den skal være blid for øjnene.',
      priority: TaskPriority.medium,
      dueDate: DateTime.now().add(const Duration(days: 2)),
      createdAt: DateTime.now()
    ),
    TodoTask(
      id: '3', 
      title: 'Køb snacks til kodning', 
      category: 'Personlig', 
      isCompleted: true, 
      priority: TaskPriority.low,
      createdAt: DateTime.now()
    ),
  ];

  // Standard kategorier (Genetiske/Defaults)
  final List<String> _categories = [
    'Generelt',
    'Arbejde',
    'Personlig',
    'Studie',
    'Dev',
    'QA',
  ];

  @override
  Future<List<TodoTask>> getTasks() async {
    await Future.delayed(const Duration(milliseconds: 400));
    return List.from(_tasks);
  }

  @override
  Future<void> addTask(TodoTask task) async {
    _tasks.add(task);
  }

  @override
  Future<void> updateTask(TodoTask task) async {
    final index = _tasks.indexWhere((t) => t.id == task.id);
    if (index != -1) {
      _tasks[index] = task;
    }
  }

  @override
  Future<void> deleteTask(String id) async {
    _tasks.removeWhere((t) => t.id == id);
  }

  // Implementering af kategorier
  @override
  Future<List<String>> getCategories() async {
    return List.from(_categories);
  }

  @override
  Future<void> addCategory(String category) async {
    if (!_categories.contains(category)) {
      _categories.add(category);
    }
  }
}