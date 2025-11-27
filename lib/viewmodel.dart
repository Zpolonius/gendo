import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'models.dart';
import 'models/todo_list.dart';
import 'repository.dart';
import 'services/notification_service.dart';
import 'mixins/recurring_task_handler.dart'; // HUSK IMPORT

enum TimerStatus { idle, working, finishedWork, onBreak }

class AppViewModel extends ChangeNotifier with RecurringTaskHandler {
  TaskRepository _repository;
  final NotificationService _notificationService = NotificationService();
  
  // --- STATE ---
  List<TodoList> _lists = [];
  String? _activeListId;
  final Map<String, List<TodoTask>> _tasksByList = {};
  List<String> _categories = [];
  
  bool _isLoading = false;
  bool _isDarkMode = false;
  bool _showCompleted = true; 
  
  // --- POMODORO ---
  PomodoroSettings _pomodoroSettings = PomodoroSettings(); 
  int _pomodoroDurationTotal = 25 * 60;
  int _pomodoroTimeLeft = 25 * 60;
  Timer? _timer;
  TimerStatus _timerStatus = TimerStatus.idle;
  int _sessionsCompleted = 0;
  String? _selectedTaskId;

  AppViewModel(this._repository, NotificationService notificationService) {
    _notificationService.init();
    loadData();
  }

  void updateRepository(TaskRepository repository) {
    _repository = repository;
    loadData();
  }

  // --- GETTERS TIL MIXIN OG UI ---
  // Disse skal være public for at Mixin kan se dem
  @override
  TaskRepository get repository => _repository;
  
  @override
  NotificationService get notificationService => _notificationService;
  
  @override
  Map<String, List<TodoTask>> get tasksByList => _tasksByList;

  List<TodoList> get lists => _lists;
  String? get activeListId => _activeListId;
  List<TodoTask> get allTasks => _tasksByList.values.expand((x) => x).toList();
  
  List<TodoTask> get currentTasks {
    if (_activeListId == null) return [];
    final tasks = _tasksByList[_activeListId!] ?? [];
    if (_showCompleted) return tasks;
    return tasks.where((t) => !t.isCompleted).toList();
  }

  bool get isDarkMode => _isDarkMode;
  bool get showCompleted => _showCompleted; 
  List<String> get categories => _categories;
  PomodoroSettings get pomodoroSettings => _pomodoroSettings;
  bool get isLoading => _isLoading;
  int get pomodoroTimeLeft => _pomodoroTimeLeft;
  int get pomodoroDurationTotal => _pomodoroDurationTotal;
  bool get isTimerRunning => _timer != null && _timer!.isActive;
  TimerStatus get timerStatus => _timerStatus;
  String? get selectedTaskId => _selectedTaskId;
  int get sessionsCompleted => _sessionsCompleted;
  bool get isOnBreak => _timerStatus == TimerStatus.onBreak;
  
  TodoTask? get selectedTaskObj {
    if (_selectedTaskId == null) return null;
    try {
      return allTasks.firstWhere((t) => t.id == _selectedTaskId);
    } catch (e) {
      return null;
    }
  }
  
  double get progress => _pomodoroDurationTotal == 0 ? 0 : 1.0 - (_pomodoroTimeLeft / _pomodoroDurationTotal);

  // --- DATA LOADING ---

  Future<void> loadData() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && user.email != null) {
        await _repository.checkPendingInvites(user.email!);
      }

      final results = await Future.wait([
        _repository.getLists(),
        _repository.getCategories(),
        _repository.getThemePreference(),
        _repository.getPomodoroSettings(),
      ]);
      
      _lists = results[0] as List<TodoList>;
      _categories = results[1] as List<String>;
      _isDarkMode = results[2] as bool;
      _pomodoroSettings = results[3] as PomodoroSettings;

      if (_activeListId == null && _lists.isNotEmpty) {
        _activeListId = _lists.first.id;
      }

      for (var list in _lists) {
        final tasks = await _repository.getTasks(list.id);
        _tasksByList[list.id] = tasks;
      }

      if (_timerStatus == TimerStatus.idle) {
        _pomodoroDurationTotal = _pomodoroSettings.workDurationMinutes * 60;
        _pomodoroTimeLeft = _pomodoroDurationTotal;
      }

    } catch (e) {
      print("Fejl ved load: $e");
    }
    
    _isLoading = false;
    notifyListeners();
  }

  // --- LISTER ---

  void setActiveList(String listId) {
    _activeListId = listId;
    notifyListeners();
  }

  void toggleListShowCompleted() {
    _showCompleted = !_showCompleted;
    notifyListeners();
  }

  Future<void> createList(String title) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final newList = TodoList(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      ownerId: user.uid,
      memberIds: [user.uid],
      createdAt: DateTime.now(),
    );

    await _repository.createList(newList);
    _lists.add(newList);
    _tasksByList[newList.id] = []; 
    _activeListId = newList.id; 
    notifyListeners();
  }

  Future<void> inviteUser(String listId, String email) async {
    await _repository.inviteUserByEmail(listId, email);
  }

  Future<List<Map<String, String>>> getListMembers(String listId) async {
    try {
      final list = _lists.firstWhere((l) => l.id == listId);
      return await _repository.getMembersDetails(list.memberIds);
    } catch (e) {
      return [];
    }
  }

  Future<void> removeMember(String listId, String userId) async {
    await _repository.removeUserFromList(listId, userId);
    await loadData(); 
  }

  Future<void> deleteList(String listId) async {
    await _repository.deleteList(listId);
    _lists.removeWhere((l) => l.id == listId);
    _tasksByList.remove(listId);
    if (_activeListId == listId) {
      _activeListId = _lists.isNotEmpty ? _lists.first.id : null;
    }
    notifyListeners();
  }

  // --- OPGAVER ---

  Future<String> addTask(String title, {String category = 'Generelt', String description = '', TaskPriority priority = TaskPriority.medium, DateTime? dueDate, String? listId, TaskRepeat repeat = TaskRepeat.never}) async {
    final targetListId = listId ?? _activeListId;
    if (targetListId == null) return '';

    if (!_categories.contains(category)) await addNewCategory(category);
    
    final newId = DateTime.now().millisecondsSinceEpoch.toString();
    final newTask = TodoTask(
      id: newId,
      title: title,
      category: category,
      description: description,
      priority: priority,
      dueDate: dueDate,
      repeat: repeat, 
      createdAt: DateTime.now(),
      listId: targetListId, 
    );

    await _repository.addTask(newTask);
    if (_tasksByList[targetListId] == null) _tasksByList[targetListId] = [];
    _tasksByList[targetListId]!.add(newTask);
    
    if (dueDate != null) {
      await scheduleTaskNotification(
        id: newTask.hashCode, 
        title: "Deadline: $title",
        body: description.isNotEmpty ? description : "Husk din opgave!",
        scheduledDate: dueDate,
      );
    }

    notifyListeners();
    
    return newId;
  }

  Future<void> scheduleTaskNotification({required int id, required String title, required String body, required DateTime scheduledDate}) async {
    await _notificationService.scheduleTaskNotification(
      id: id,
      title: title,
      body: body,
      scheduledDate: scheduledDate,
    );
  }

  Future<void> toggleTask(String taskId) async {
    for (var listId in _tasksByList.keys) {
      final index = _tasksByList[listId]!.indexWhere((t) => t.id == taskId);
      if (index != -1) {
        var task = _tasksByList[listId]![index];
        
        // BRUGER NU MIXIN TIL GENTAGELSE
        if (!task.isCompleted && task.repeat != TaskRepeat.never) {
          await handleRecurringTaskCompletion(task, listId, index);
        } else {
          final updatedTask = task.copyWith(isCompleted: !task.isCompleted);
          await _repository.updateTask(updatedTask);
          _tasksByList[listId]![index] = updatedTask;
          
          if (updatedTask.isCompleted) {
            _notificationService.cancelNotification(updatedTask.hashCode);
          } else if (updatedTask.dueDate != null && updatedTask.dueDate!.isAfter(DateTime.now())) {
             scheduleTaskNotification(
              id: updatedTask.hashCode,
              title: "Deadline: ${updatedTask.title}",
              body: updatedTask.description,
              scheduledDate: updatedTask.dueDate!,
            );
          }
        }
        
        notifyListeners();
        return;
      }
    }
  }
  // ... inde i AppViewModel ...

  // Tilføj et nyt step til en opgave
  Future<void> addTaskStep(String taskId, String stepTitle) async {
    final task = allTasks.firstWhere((t) => t.id == taskId);
    final newStep = TaskStep(
      id: DateTime.now().millisecondsSinceEpoch.toString(), // Simpel ID generering
      title: stepTitle,
    );
    
    // Opret en ny liste af steps (husk immutability)
    final updatedSteps = List<TaskStep>.from(task.steps)..add(newStep);
    
    final updatedTask = task.copyWith(steps: updatedSteps);
    await updateTaskDetails(updatedTask);
  }

  // Toggle status på et step
  // Returnerer true hvis ALLE steps nu er færdige (til confetti trigger)
  Future<bool> toggleTaskStep(String taskId, String stepId) async {
    final task = allTasks.firstWhere((t) => t.id == taskId);
    
    final updatedSteps = task.steps.map((step) {
      if (step.id == stepId) {
        return TaskStep(
          id: step.id, 
          title: step.title, 
          isCompleted: !step.isCompleted
        );
      }
      return step;
    }).toList();

    final updatedTask = task.copyWith(steps: updatedSteps);
    await updateTaskDetails(updatedTask);

    // Tjek om alle steps er færdige
    return updatedSteps.isNotEmpty && updatedSteps.every((s) => s.isCompleted);
  }

  // Slet et step
  Future<void> deleteTaskStep(String taskId, String stepId) async {
    final task = allTasks.firstWhere((t) => t.id == taskId);
    final updatedSteps = task.steps.where((s) => s.id != stepId).toList();
    
    final updatedTask = task.copyWith(steps: updatedSteps);
    await updateTaskDetails(updatedTask);
  }
  // Bemærk: _handleRecurringTaskCompletion er fjernet herfra, da den nu ligger i Mixin'en.

  Future<void> updateTaskDetails(TodoTask task, {String? oldListId}) async {
    _notificationService.cancelNotification(task.hashCode); 
    if (task.dueDate != null && !task.isCompleted && task.dueDate!.isAfter(DateTime.now())) {
       await scheduleTaskNotification(
        id: task.hashCode,
        title: "Deadline: ${task.title}",
        body: task.description,
        scheduledDate: task.dueDate!,
      );
    }

    if (oldListId != null && oldListId != task.listId) {
      await _repository.deleteTask(oldListId, task.id);
      await _repository.addTask(task);
      
      if (_tasksByList.containsKey(oldListId)) {
        _tasksByList[oldListId]!.removeWhere((t) => t.id == task.id);
      }
      if (_tasksByList[task.listId] == null) _tasksByList[task.listId] = [];
      _tasksByList[task.listId]!.add(task);

    } else {
      await _repository.updateTask(task);
      final list = _tasksByList[task.listId];
      if (list != null) {
        final index = list.indexWhere((t) => t.id == task.id);
        if (index != -1) {
          list[index] = task;
        }
      }
    }
    notifyListeners();
  }

  Future<void> deleteTask(String taskId) async {
    String? listIdFound;
    TodoTask? taskToDelete;

    for (var entry in _tasksByList.entries) {
      try {
        taskToDelete = entry.value.firstWhere((t) => t.id == taskId);
        listIdFound = entry.key;
        break;
      } catch (e) {
        continue;
      }
    }
    
    if (listIdFound != null && taskToDelete != null) {
      await _repository.deleteTask(listIdFound, taskId);
      _tasksByList[listIdFound]!.removeWhere((t) => t.id == taskId);
      
      _notificationService.cancelNotification(taskToDelete.hashCode);

      if (_selectedTaskId == taskId) _selectedTaskId = null;
      notifyListeners();
    }
  }
  
  // --- KATEGORIER & THEME ---

  Future<void> addNewCategory(String category) async { 
    if (category.trim().isEmpty) return; 
    await _repository.addCategory(category); 
    if (!_categories.contains(category)) { 
      _categories.add(category); 
      notifyListeners(); 
    } 
  }

  void toggleTheme(bool isDark) { 
    _isDarkMode = isDark; 
    notifyListeners(); 
    _repository.updateThemePreference(isDark); 
  }

  Future<void> generatePlanFromAI(String prompt) async { 
    _isLoading = true; 
    notifyListeners(); 
    await Future.delayed(const Duration(seconds: 2)); 
    List<String> suggestions = ["Research: $prompt", "Planlægning: $prompt", "Udførsel: $prompt"]; 
    for (var taskTitle in suggestions) { 
      await addTask(taskTitle, category: 'AI Genereret'); 
    } 
    _isLoading = false; 
    notifyListeners(); 
  }

  // --- POMODORO LOGIC ---

  void setSelectedTask(String? taskId) { _selectedTaskId = taskId; notifyListeners(); }
  
  void setDuration(int minutes) { 
    if (isTimerRunning) stopTimer(); 
    _pomodoroDurationTotal = minutes * 60; 
    _pomodoroTimeLeft = _pomodoroDurationTotal; 
    _timerStatus = TimerStatus.idle; 
    notifyListeners(); 
  }
  
  void startTimer() { 
    if (_timer != null) return; 
    if (_timerStatus == TimerStatus.idle) _timerStatus = TimerStatus.working; 
    
    notifyListeners(); 
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) { 
      if (_pomodoroTimeLeft > 0) { 
        _pomodoroTimeLeft--; 
      } else { 
        stopTimer(); 
        _handleTimerComplete(); 
      } 
      notifyListeners(); 
    }); 
  }
  
  void stopTimer() { _timer?.cancel(); _timer = null; notifyListeners(); }
  
  void resetTimer() { 
    stopTimer(); 
    _pomodoroDurationTotal = _pomodoroSettings.workDurationMinutes * 60; 
    _pomodoroTimeLeft = _pomodoroDurationTotal; 
    _timerStatus = TimerStatus.idle; 
    notifyListeners(); 
  }
  
  void _handleTimerComplete() { 
    if (_timerStatus == TimerStatus.working) { 
      _timerStatus = TimerStatus.finishedWork; 
      
      _notificationService.showNotification(
        id: 888, 
        title: "Tiden er gået! 🍅", 
        body: "Godt klaret! Tag en pause eller start en ny session."
      );

    } else if (_timerStatus == TimerStatus.onBreak) { 
      resetTimer(); 
      _notificationService.showNotification(
        id: 889, 
        title: "Pausen er slut! ☕️", 
        body: "Klar til at arbejde igen?"
      );
    } 
  }
  
  void completeWorkSession(bool isTaskDone) { 
    if (isTaskDone && _selectedTaskId != null) { 
       toggleTask(_selectedTaskId!);
       _selectedTaskId = null; 
    } 
    _sessionsCompleted++; 
    if (!_pomodoroSettings.enableBreaks) { resetTimer(); return; }
    int breakMinutes = 10; 
    if (_pomodoroSettings.enableLongBreaks && _sessionsCompleted % 3 == 0) breakMinutes = 30;
    startBreak(breakMinutes); 
  }

  Future completeTaskAndContinue() async {
    if (_selectedTaskId != null) {
      toggleTask(_selectedTaskId!);
      _selectedTaskId = null; 
      notifyListeners();
    }
  }
  
  void startBreak(int minutes) { 
    _pomodoroDurationTotal = minutes * 60; 
    _pomodoroTimeLeft = _pomodoroDurationTotal; 
    _timerStatus = TimerStatus.onBreak; 
    startTimer(); 
    notifyListeners(); 
  }
  
  void skipBreak() { resetTimer(); }
  
  void updateSettings(PomodoroSettings newSettings) async { 
    _pomodoroSettings = newSettings; 
    await _repository.updatePomodoroSettings(newSettings); 
    if (!isTimerRunning && _timerStatus == TimerStatus.idle) { 
      _pomodoroDurationTotal = _pomodoroSettings.workDurationMinutes * 60; 
      _pomodoroTimeLeft = _pomodoroDurationTotal; 
    } 
    notifyListeners(); 
  }
}