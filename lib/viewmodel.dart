import 'dart:async';
import 'package:flutter/material.dart';
import 'models.dart';
import 'repository.dart';

enum TimerStatus { idle, working, finishedWork, onBreak }

class AppViewModel extends ChangeNotifier {
  TaskRepository _repository;
  
  // --- STATE: THEME ---
  bool _isDarkMode = false;

  // --- STATE: OPGAVER & KATEGORIER ---
  List<TodoTask> _tasks = [];
  List<String> _categories = [];
  bool _isLoading = false;

  // --- STATE: POMODORO ---
  static const int defaultWorkMinutes = 20;
  int _currentWorkDuration = defaultWorkMinutes * 60; 
  int _pomodoroDurationTotal = defaultWorkMinutes * 60;
  int _pomodoroTimeLeft = defaultWorkMinutes * 60;
  Timer? _timer;
  
  TimerStatus _timerStatus = TimerStatus.idle;
  int _sessionsCompleted = 0;
  String? _selectedTaskId; 

  AppViewModel(this._repository) {
    loadData();
  }

  void updateRepository(TaskRepository repository) {
    _repository = repository;
    loadData(); // Hent data (og tema) igen når vi skifter bruger/repository
  }

  // Getters
  bool get isDarkMode => _isDarkMode;
  List<TodoTask> get tasks => _tasks;
  List<String> get categories => _categories;
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
      return _tasks.firstWhere((t) => t.id == _selectedTaskId);
    } catch (e) {
      return null;
    }
  }

  double get progress => _pomodoroDurationTotal == 0 
      ? 0 
      : 1.0 - (_pomodoroTimeLeft / _pomodoroDurationTotal);

  // --- ACTIONS: DATA & THEME ---

  Future<void> loadData() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      final results = await Future.wait([
        _repository.getTasks(),
        _repository.getCategories(),
        _repository.getThemePreference(), // Hent tema fra Firebase
      ]);
      
      _tasks = results[0] as List<TodoTask>;
      _categories = results[1] as List<String>;
      _isDarkMode = results[2] as bool; // Opdater lokalt state med gemt tema
      
    } catch (e) {
      print("Fejl ved load af data: $e");
    }
    
    _isLoading = false;
    notifyListeners();
  }

  // Opdateret toggle metode
  void toggleTheme(bool isDark) {
    _isDarkMode = isDark;
    notifyListeners(); // Opdater UI med det samme
    _repository.updateThemePreference(isDark); // Gem i baggrunden
  }

  Future<void> addNewCategory(String category) async {
    if (category.trim().isEmpty) return;
    await _repository.addCategory(category);
    if (!_categories.contains(category)) {
      _categories.add(category);
      notifyListeners();
    }
  }

  // ... (Resten af metoderne som addTask, timer logik osv. er uændrede)
  // Du skal blot beholde dem som de var i den forrige fil.
  // Jeg inkluderer de vigtigste her for kontekst:

  Future<void> addTask(String title, {
    String category = 'Generelt', 
    String description = '', 
    TaskPriority priority = TaskPriority.medium,
    DateTime? dueDate
  }) async {
    if (!_categories.contains(category)) {
      await addNewCategory(category);
    }
    final newTask = TodoTask(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      category: category,
      description: description,
      priority: priority,
      dueDate: dueDate,
      createdAt: DateTime.now(),
    );
    await _repository.addTask(newTask);
    _tasks.add(newTask);
    notifyListeners();
  }

  Future<void> updateTaskDetails(TodoTask task) async {
    await _repository.updateTask(task);
    final index = _tasks.indexWhere((t) => t.id == task.id);
    if (index != -1) {
      _tasks[index] = task;
      notifyListeners();
    }
  }

  Future<void> toggleTask(String id) async {
    final index = _tasks.indexWhere((t) => t.id == id);
    if (index != -1) {
      final task = _tasks[index];
      final updatedTask = task.copyWith(isCompleted: !task.isCompleted);
      await _repository.updateTask(updatedTask);
      _tasks[index] = updatedTask;
      notifyListeners();
    }
  }

  Future<void> deleteTask(String id) async {
    await _repository.deleteTask(id);
    _tasks.removeWhere((t) => t.id == id);
    if (_selectedTaskId == id) _selectedTaskId = null;
    notifyListeners();
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

  // --- POMODORO ---
  void setSelectedTask(String? taskId) { _selectedTaskId = taskId; notifyListeners(); }
  void setDuration(int minutes) { if (isTimerRunning) stopTimer(); _currentWorkDuration = minutes * 60; _pomodoroDurationTotal = _currentWorkDuration; _pomodoroTimeLeft = _currentWorkDuration; _timerStatus = TimerStatus.idle; notifyListeners(); }
  void startTimer() { if (_timer != null) return; if (_timerStatus == TimerStatus.idle) _timerStatus = TimerStatus.working; notifyListeners(); _timer = Timer.periodic(const Duration(seconds: 1), (timer) { if (_pomodoroTimeLeft > 0) { _pomodoroTimeLeft--; } else { stopTimer(); _handleTimerComplete(); } notifyListeners(); }); }
  void stopTimer() { _timer?.cancel(); _timer = null; notifyListeners(); }
  void resetTimer() { stopTimer(); _pomodoroDurationTotal = _currentWorkDuration; _pomodoroTimeLeft = _pomodoroDurationTotal; _timerStatus = TimerStatus.idle; notifyListeners(); }
  void _handleTimerComplete() { if (_timerStatus == TimerStatus.working) { _timerStatus = TimerStatus.finishedWork; } else if (_timerStatus == TimerStatus.onBreak) { resetTimer(); } }
  void completeWorkSession(bool isTaskDone) { if (isTaskDone && _selectedTaskId != null) { final index = _tasks.indexWhere((t) => t.id == _selectedTaskId); if (index != -1 && !_tasks[index].isCompleted) toggleTask(_selectedTaskId!); _selectedTaskId = null; } _sessionsCompleted++; int breakMinutes = (_sessionsCompleted % 3 == 0) ? 30 : 10; startBreak(breakMinutes); }
  void startBreak(int minutes) { _pomodoroDurationTotal = minutes * 60; _pomodoroTimeLeft = _pomodoroDurationTotal; _timerStatus = TimerStatus.onBreak; startTimer(); notifyListeners(); }
  void skipBreak() { resetTimer(); }
}