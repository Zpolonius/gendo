import 'dart:async';
import 'package:flutter/material.dart';
import 'models.dart';
import 'repository.dart';

// Enum til at styre timerens tilstand
enum TimerStatus { idle, working, finishedWork, onBreak }

class AppViewModel extends ChangeNotifier {
  final TaskRepository _repository;
  
  // --- STATE: THEME ---
  bool _isDarkMode = false;

  // --- STATE: OPGAVER ---
  List<TodoTask> _tasks = [];
  bool _isLoading = false;

  // --- STATE: POMODORO ---
  static const int defaultWorkMinutes = 20;
  
  // Vi gemmer den valgte arbejdstid separat, så vi kan vende tilbage til den efter en pause
  int _currentWorkDuration = defaultWorkMinutes * 60; 
  
  int _pomodoroDurationTotal = defaultWorkMinutes * 60;
  int _pomodoroTimeLeft = defaultWorkMinutes * 60;
  Timer? _timer;
  
  // Status tracking
  TimerStatus _timerStatus = TimerStatus.idle;
  int _sessionsCompleted = 0;
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

  // --- ACTIONS: THEME & TASKS ---

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
    await Future.delayed(const Duration(seconds: 2));
    
    List<String> suggestions = [
      "Research: $prompt",
      "Planlægning: $prompt",
      "Udførsel: $prompt",
    ];
    
    for (var taskTitle in suggestions) {
      await addTask(taskTitle, category: 'AI Genereret');
    }
    _isLoading = false;
    notifyListeners();
  }

  // --- LOGIK: POMODORO & BREAKS ---

  void setSelectedTask(String? taskId) {
    _selectedTaskId = taskId;
    notifyListeners();
  }

  void setDuration(int minutes) {
    if (isTimerRunning) stopTimer();
    
    // Opdaterer både den nuværende timer OG standarden for arbejde
    _currentWorkDuration = minutes * 60;
    _pomodoroDurationTotal = _currentWorkDuration;
    _pomodoroTimeLeft = _currentWorkDuration;
    
    _timerStatus = TimerStatus.idle;
    notifyListeners();
  }

  void startTimer() {
    if (_timer != null) return;
    
    // Hvis vi starter fra idle, så sæt status til working (medmindre vi allerede er i gang med en pause)
    if (_timerStatus == TimerStatus.idle) {
      _timerStatus = TimerStatus.working;
    }
    
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

  void stopTimer() {
    _timer?.cancel();
    _timer = null;
    notifyListeners();
  }

  void resetTimer() {
    stopTimer();
    // Reset til den senest valgte arbejdstid (ikke altid 20 min, men det brugeren har valgt)
    _pomodoroDurationTotal = _currentWorkDuration; 
    _pomodoroTimeLeft = _pomodoroDurationTotal;
    _timerStatus = TimerStatus.idle;
    notifyListeners();
  }

  void _handleTimerComplete() {
    if (_timerStatus == TimerStatus.working) {
      // Arbejde færdig -> Vis dialog
      _timerStatus = TimerStatus.finishedWork;
    } else if (_timerStatus == TimerStatus.onBreak) {
      // Pause færdig -> Reset til arbejde (bruger _currentWorkDuration)
      resetTimer(); 
    }
  }

  void completeWorkSession(bool isTaskDone) {
    if (isTaskDone && _selectedTaskId != null) {
      final index = _tasks.indexWhere((t) => t.id == _selectedTaskId);
      if (index != -1 && !_tasks[index].isCompleted) {
        toggleTask(_selectedTaskId!);
      }
      _selectedTaskId = null;
    }

    _sessionsCompleted++;

    // Bestem pause længde (10 min normalt, 30 min hver 3. gang)
    int breakMinutes = (_sessionsCompleted % 3 == 0) ? 30 : 10;
    
    startBreak(breakMinutes);
  }

  void startBreak(int minutes) {
    // Her ændrer vi kun _pomodoroDurationTotal midlertidigt, vi rører ikke _currentWorkDuration
    _pomodoroDurationTotal = minutes * 60;
    _pomodoroTimeLeft = _pomodoroDurationTotal;
    _timerStatus = TimerStatus.onBreak;
    startTimer();
    notifyListeners();
  }

  void skipBreak() {
    resetTimer(); // Hopper direkte ud af pausen og tilbage til den valgte arbejdstid
  }
}