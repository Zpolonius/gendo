import 'dart:async';
import 'models.dart';

// Interface: Definerer HVAD vi kan gøre (kontrakt)
// Denne klasse kender intet til Firebase - kun ren Dart kode.
abstract class TaskRepository {
  // Opgaver
  Future<List<TodoTask>> getTasks();
  Future<void> addTask(TodoTask task);
  Future<void> updateTask(TodoTask task);
  Future<void> deleteTask(String id);
  
  // Kategorier
  Future<List<String>> getCategories();
  Future<void> addCategory(String category);

  // Tema
  Future<bool> getThemePreference();
  Future<void> updateThemePreference(bool isDarkMode);

  // Pomodoro Indstillinger
  Future<PomodoroSettings> getPomodoroSettings();
  Future<void> updatePomodoroSettings(PomodoroSettings settings);
}

// Mock Implementation: Bruges når brugeren ikke er logget ind
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
      description: 'Tjek kontrasten på den lilla farve i dark mode.',
      priority: TaskPriority.medium,
      dueDate: DateTime.now().add(const Duration(days: 2)),
      createdAt: DateTime.now()
    ),
  ];
  
  final List<String> _categories = ['Generelt', 'Arbejde', 'Personlig', 'Studie', 'Dev', 'QA'];
  bool _isDarkMode = false;
  PomodoroSettings _pomodoroSettings = PomodoroSettings(); // Default settings

  @override
  Future<List<TodoTask>> getTasks() async {
    await Future.delayed(const Duration(milliseconds: 400));
    return List.from(_tasks);
  }

  @override
  Future<void> addTask(TodoTask task) async => _tasks.add(task);
  
  @override
  Future<void> updateTask(TodoTask task) async {
    final index = _tasks.indexWhere((t) => t.id == task.id);
    if (index != -1) _tasks[index] = task;
  }

  @override
  Future<void> deleteTask(String id) async => _tasks.removeWhere((t) => t.id == id);

  @override
  Future<List<String>> getCategories() async => List.from(_categories);

  @override
  Future<void> addCategory(String category) async {
    if (!_categories.contains(category)) _categories.add(category);
  }

  @override
  Future<bool> getThemePreference() async => _isDarkMode;

  @override
  Future<void> updateThemePreference(bool isDarkMode) async {
    _isDarkMode = isDarkMode;
  }

  @override
  Future<PomodoroSettings> getPomodoroSettings() async {
    return _pomodoroSettings;
  }

  @override
  Future<void> updatePomodoroSettings(PomodoroSettings settings) async {
    _pomodoroSettings = settings;
  }
}