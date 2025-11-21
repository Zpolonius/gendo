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

  // --- STATE: POMODORO & SETTINGS ---
  PomodoroSettings _pomodoroSettings = PomodoroSettings(); // Gemmer indstillingerne her
  
  int _pomodoroDurationTotal = 25 * 60;
  int _pomodoroTimeLeft = 25 * 60;
  Timer? _timer;
  
  TimerStatus _timerStatus = TimerStatus.idle;
  int _sessionsCompleted = 0;
  String? _selectedTaskId; 

  AppViewModel(this._repository) {
    loadData();
  }

  void updateRepository(TaskRepository repository) {
    _repository = repository;
    loadData(); 
  }

  // Getters
  bool get isDarkMode => _isDarkMode;
  List<TodoTask> get tasks => _tasks;
  List<String> get categories => _categories;
  PomodoroSettings get pomodoroSettings => _pomodoroSettings; // Getter til UI
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

  // --- ACTIONS: DATA, THEME & SETTINGS ---

  Future<void> loadData() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      final results = await Future.wait([
        _repository.getTasks(),
        _repository.getCategories(),
        _repository.getThemePreference(), 
        _repository.getPomodoroSettings(), // Hent indstillinger
      ]);
      
      _tasks = results[0] as List<TodoTask>;
      _categories = results[1] as List<String>;
      _isDarkMode = results[2] as bool; 
      _pomodoroSettings = results[3] as PomodoroSettings;

      // Opdater timerens standardtid baseret på indstillingerne
      if (_timerStatus == TimerStatus.idle) {
        _pomodoroDurationTotal = _pomodoroSettings.workDurationMinutes * 60;
        _pomodoroTimeLeft = _pomodoroDurationTotal;
      }
      
    } catch (e) {
      print("Fejl ved load af data: $e");
    }
    
    _isLoading = false;
    notifyListeners();
  }

  // Opdatering af indstillinger fra Settings-skærmen
  Future<void> updateSettings(PomodoroSettings newSettings) async {
    _pomodoroSettings = newSettings;
    await _repository.updatePomodoroSettings(newSettings);
    
    // Hvis timeren ikke kører, opdater tiden med det samme
    if (!isTimerRunning && _timerStatus == TimerStatus.idle) {
      _pomodoroDurationTotal = _pomodoroSettings.workDurationMinutes * 60;
      _pomodoroTimeLeft = _pomodoroDurationTotal;
    }
    notifyListeners();
  }

  void toggleTheme(bool isDark) {
    _isDarkMode = isDark;
    notifyListeners(); 
    _repository.updateThemePreference(isDark); 
  }

  Future<void> addNewCategory(String category) async {
    if (category.trim().isEmpty) return;
    await _repository.addCategory(category);
    if (!_categories.contains(category)) {
      _categories.add(category);
      notifyListeners();
    }
  }

  // ... (Resten af task metoder som addTask, updateTask osv. er uændrede)
  Future<void> addTask(String title, {String category = 'Generelt', String description = '', TaskPriority priority = TaskPriority.medium, DateTime? dueDate}) async {
    if (!_categories.contains(category)) await addNewCategory(category);
    final newTask = TodoTask(id: DateTime.now().millisecondsSinceEpoch.toString(), title: title, category: category, description: description, priority: priority, dueDate: dueDate, createdAt: DateTime.now());
    await _repository.addTask(newTask);
    _tasks.add(newTask);
    notifyListeners();
  }
  Future<void> updateTaskDetails(TodoTask task) async { await _repository.updateTask(task); final index = _tasks.indexWhere((t) => t.id == task.id); if (index != -1) { _tasks[index] = task; notifyListeners(); } }
  Future<void> toggleTask(String id) async { final index = _tasks.indexWhere((t) => t.id == id); if (index != -1) { final task = _tasks[index]; final updatedTask = task.copyWith(isCompleted: !task.isCompleted); await _repository.updateTask(updatedTask); _tasks[index] = updatedTask; notifyListeners(); } }
  Future<void> deleteTask(String id) async { await _repository.deleteTask(id); _tasks.removeWhere((t) => t.id == id); if (_selectedTaskId == id) _selectedTaskId = null; notifyListeners(); }
  Future<void> generatePlanFromAI(String prompt) async { _isLoading = true; notifyListeners(); await Future.delayed(const Duration(seconds: 2)); List<String> suggestions = ["Research: $prompt", "Planlægning: $prompt", "Udførsel: $prompt"]; for (var taskTitle in suggestions) { await addTask(taskTitle, category: 'AI Genereret'); } _isLoading = false; notifyListeners(); }

  // --- POMODORO LOGIC (OPDATERET MED SETTINGS) ---
  
  void setSelectedTask(String? taskId) { _selectedTaskId = taskId; notifyListeners(); }
  
  // Denne metode er teknisk set ikke nødvendig længere hvis vi fjerner custom tid, 
  // men vi beholder den hvis du vil understøtte "quick override" senere.
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
    // Brug indstillingen som standard
    _pomodoroDurationTotal = _pomodoroSettings.workDurationMinutes * 60; 
    _pomodoroTimeLeft = _pomodoroDurationTotal; 
    _timerStatus = TimerStatus.idle; 
    notifyListeners(); 
  }
  
  void _handleTimerComplete() { 
    if (_timerStatus == TimerStatus.working) { 
      _timerStatus = TimerStatus.finishedWork; 
    } else if (_timerStatus == TimerStatus.onBreak) { 
      resetTimer(); 
    } 
  }
  
  void completeWorkSession(bool isTaskDone) { 
    if (isTaskDone && _selectedTaskId != null) { 
      final index = _tasks.indexWhere((t) => t.id == _selectedTaskId); 
      if (index != -1 && !_tasks[index].isCompleted) toggleTask(_selectedTaskId!); 
      _selectedTaskId = null; 
    } 
    _sessionsCompleted++; 
    
    // --- NY LOGIK FOR PAUSER ---
    if (!_pomodoroSettings.enableBreaks) {
      // Hvis pauser er slået fra, hop direkte tilbage til start
      resetTimer();
      return;
    }

    int breakMinutes = 10; // Default kort pause
    
    // Tjek for lang pause (hver 3. gang), men kun hvis lange pauser er slået til
    if (_pomodoroSettings.enableLongBreaks && _sessionsCompleted % 3 == 0) {
      breakMinutes = 30;
    }
    
    startBreak(breakMinutes); 
  }
  
  void startBreak(int minutes) { 
    _pomodoroDurationTotal = minutes * 60; 
    _pomodoroTimeLeft = _pomodoroDurationTotal; 
    _timerStatus = TimerStatus.onBreak; 
    startTimer(); 
    notifyListeners(); 
  }
  
  void skipBreak() { resetTimer(); }
}