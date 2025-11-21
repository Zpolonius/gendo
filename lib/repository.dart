import 'dart:async';
import 'models.dart';
import 'models/todo_list.dart'; // Husk at inkludere denne hvis du bruger TodoList

// Interface: Definerer HVAD vi kan gøre (kontrakt)
abstract class TaskRepository {
  // Opgaver (Nu med listId support)
  Future<List<TodoTask>> getTasks(String listId);
  Future<void> addTask(TodoTask task);
  Future<void> updateTask(TodoTask task);
  Future<void> deleteTask(String listId, String taskId);
  
  // Lister (NYT)
  Future<List<TodoList>> getLists();
  Future<void> createList(TodoList list);
  Future<void> deleteList(String listId);
  Future<void> inviteUserByEmail(String listId, String email);
  Future<void> removeUserFromList(String listId, String userIdToRemove);

  // Kategorier
  Future<List<String>> getCategories();
  Future<void> addCategory(String category);

  // Tema (Disse manglede i interfacet)
  Future<bool> getThemePreference();
  Future<void> updateThemePreference(bool isDarkMode);

  // Pomodoro Indstillinger (Disse manglede også)
  Future<PomodoroSettings> getPomodoroSettings();
  Future<void> updatePomodoroSettings(PomodoroSettings settings);
}

// Mock Implementation
class MockTaskRepository implements TaskRepository {
  // Mock data til lister
  List<TodoList> _lists = [
    TodoList(
      id: 'list1', 
      title: 'Min Første Liste', 
      ownerId: 'mock_user', 
      memberIds: ['mock_user'], 
      createdAt: DateTime.now()
    )
  ];

  final List<TodoTask> _tasks = [
    TodoTask(
      id: '1', 
      title: 'Opsæt Flutter projekt', 
      category: 'Dev', 
      description: 'Husk at inkludere Provider.',
      priority: TaskPriority.high,
      createdAt: DateTime.now(),
      listId: 'list1' // Koblet til listen
    ),
  ];
  
  final List<String> _categories = ['Generelt', 'Arbejde', 'Personlig'];
  bool _isDarkMode = false;
  PomodoroSettings _pomodoroSettings = PomodoroSettings();

  // --- TASKS ---
  @override
  Future<List<TodoTask>> getTasks(String listId) async {
    await Future.delayed(const Duration(milliseconds: 400));
    return _tasks.where((t) => t.listId == listId).toList();
  }

  @override
  Future<void> addTask(TodoTask task) async => _tasks.add(task);
  
  @override
  Future<void> updateTask(TodoTask task) async {
    final index = _tasks.indexWhere((t) => t.id == task.id);
    if (index != -1) _tasks[index] = task;
  }

  @override
  Future<void> deleteTask(String listId, String taskId) async {
    _tasks.removeWhere((t) => t.id == taskId);
  }
  
  // --- LISTER ---
  @override
  Future<List<TodoList>> getLists() async => List.from(_lists);
  @override
  Future<void> createList(TodoList list) async => _lists.add(list);
  @override
  Future<void> deleteList(String listId) async => _lists.removeWhere((l) => l.id == listId);
  @override
  Future<void> inviteUserByEmail(String listId, String email) async {} // Mock gør intet
  @override
  Future<void> removeUserFromList(String listId, String userIdToRemove) async {}

  // --- KATEGORIER ---
  @override
  Future<List<String>> getCategories() async => List.from(_categories);
  @override
  Future<void> addCategory(String category) async {
    if (!_categories.contains(category)) _categories.add(category);
  }

  // --- TEMA ---
  @override
  Future<bool> getThemePreference() async => _isDarkMode;
  @override
  Future<void> updateThemePreference(bool isDarkMode) async {
    _isDarkMode = isDarkMode;
  }

  // --- POMODORO ---
  @override
  Future<PomodoroSettings> getPomodoroSettings() async => _pomodoroSettings;
  @override
  Future<void> updatePomodoroSettings(PomodoroSettings settings) async {
    _pomodoroSettings = settings;
  }
}