import 'dart:async';
import 'package:flutter/material.dart';
import 'models.dart';
import 'repository.dart';

class AppViewModel extends ChangeNotifier {
  final TaskRepository _repository;
  
  // Theme State
  bool _isDarkMode = false;

  // Task State
  List<TodoTask> _tasks = [];
  bool _isLoading = false;

  // Pomodoro State
  static const int defaultTime = 25 * 60;
  int _pomodoroDurationTotal = defaultTime;
  int _pomodoroTimeLeft = defaultTime;
  Timer? _timer;
  bool _isTimerRunning = false;
  String? _selectedTaskId; 

  AppViewModel(this._repository) {
    loadTasks();
  }

  // Getters
  bool get isDarkMode => _isDarkMode;
  List<TodoTask> get tasks => _tasks;
  bool get isLoading => _isLoading;
  int get pomodoroTimeLeft => _pomodoroTimeLeft;
  int get pomodoroDurationTotal => _pomodoroDurationTotal;
  bool get isTimerRunning => _isTimerRunning;
  String? get selectedTaskId => _selectedTaskId;
  
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

  // --- Actions ---

  void toggleTheme(bool isDark) {
    _isDarkMode = isDark;
    notifyListeners();
  }

  Future<void> loadTasks() async {
    _isLoading = true;
    notifyListeners();
    _tasks = await _repository.getTasks();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> addTask(String title, {String category = 'Generelt'}) async {
    final newTask = TodoTask(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      category: category,
      createdAt: DateTime.now(),
    );
    await _repository.addTask(newTask);
    _tasks.add(newTask);
    notifyListeners();
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
    await Future.delayed(const Duration(seconds: 2)); // Mock AI delay
    
    List<String> suggestions = [
      "Research: $prompt",
      "Outline for $prompt",
      "Execution: $prompt",
    ];
    
    for (var taskTitle in suggestions) {
      await addTask(taskTitle, category: 'AI Generated');
    }
    _isLoading = false;
    notifyListeners();
  }

  // Pomodoro Actions
  void setSelectedTask(String? taskId) {
    _selectedTaskId = taskId;
    notifyListeners();
  }

  void setDuration(int minutes) {
    if (_isTimerRunning) stopTimer();
    _pomodoroDurationTotal = minutes * 60;
    _pomodoroTimeLeft = _pomodoroDurationTotal;
    notifyListeners();
  }

  void startTimer() {
    if (_timer != null) return;
    _isTimerRunning = true;
    notifyListeners();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_pomodoroTimeLeft > 0) {
        _pomodoroTimeLeft--;
      } else {
        stopTimer();
      }
      notifyListeners();
    });
  }

  void stopTimer() {
    _timer?.cancel();
    _timer = null;
    _isTimerRunning = false;
    notifyListeners();
  }

  void resetTimer() {
    stopTimer();
    _pomodoroTimeLeft = _pomodoroDurationTotal;
    notifyListeners();
  }
}