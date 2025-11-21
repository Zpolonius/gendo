import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'models.dart';
import 'models/todo_list.dart';
import 'repository.dart';

enum TimerStatus { idle, working, finishedWork, onBreak }

class AppViewModel extends ChangeNotifier {
  TaskRepository _repository;
  
  // --- STATE ---
  List<TodoList> _lists = [];
  String? _activeListId;
  Map<String, List<TodoTask>> _tasksByList = {};
  List<String> _categories = [];
  
  bool _isLoading = false;
  bool _isDarkMode = false;
  
  // --- POMODORO STATE ---
  PomodoroSettings _pomodoroSettings = PomodoroSettings(); 
  
  // Vi bruger ikke længere _currentWorkDuration, da vi har settings
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
  List<TodoList> get lists => _lists;
  String? get activeListId => _activeListId;
  List<TodoTask> get allTasks => _tasksByList.values.expand((x) => x).toList();
  List<TodoTask> get currentTasks => _activeListId != null ? (_tasksByList[_activeListId!] ?? []) : [];

  bool get isDarkMode => _isDarkMode;
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

      // Sæt tiden korrekt ved opstart
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

  Future<void> addTask(String title, {String category = 'Generelt', String description = '', TaskPriority priority = TaskPriority.medium, DateTime? dueDate}) async {
    if (_activeListId == null) return;

    if (!_categories.contains(category)) await addNewCategory(category);
    
    final newTask = TodoTask(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      category: category,
      description: description,
      priority: priority,
      dueDate: dueDate,
      createdAt: DateTime.now(),
      listId: _activeListId!, 
    );

    await _repository.addTask(newTask);
    if (_tasksByList[_activeListId!] == null) _tasksByList[_activeListId!] = [];
    _tasksByList[_activeListId!]!.add(newTask);
    notifyListeners();
  }

  Future<void> toggleTask(String taskId) async {
    for (var listId in _tasksByList.keys) {
      final index = _tasksByList[listId]!.indexWhere((t) => t.id == taskId);
      if (index != -1) {
        var task = _tasksByList[listId]![index];
        final updatedTask = task.copyWith(isCompleted: !task.isCompleted);
        await _repository.updateTask(updatedTask);
        _tasksByList[listId]![index] = updatedTask;
        notifyListeners();
        return;
      }
    }
  }

  Future<void> updateTaskDetails(TodoTask task) async {
    await _repository.updateTask(task);
    final list = _tasksByList[task.listId];
    if (list != null) {
      final index = list.indexWhere((t) => t.id == task.id);
      if (index != -1) {
        list[index] = task;
        notifyListeners();
      }
    }
  }

  Future<void> deleteTask(String taskId) async {
    String? listIdFound;
    for (var entry in _tasksByList.entries) {
      if (entry.value.any((t) => t.id == taskId)) {
        listIdFound = entry.key;
        break;
      }
    }
    if (listIdFound != null) {
      await _repository.deleteTask(listIdFound, taskId);
      _tasksByList[listIdFound]!.removeWhere((t) => t.id == taskId);
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
    // VIGTIGT: Brug settings som "default", da vi ikke har _currentWorkDuration mere
    _pomodoroDurationTotal = _pomodoroSettings.workDurationMinutes * 60; 
    _pomodoroTimeLeft = _pomodoroDurationTotal; 
    _timerStatus = TimerStatus.idle; 
    notifyListeners(); 
  }
  
  // Hvis du stadig har brug for manuel setDuration (til test etc.), opdaterer den bare settings midlertidigt
  void setDuration(int minutes) {
    if (isTimerRunning) stopTimer();
    _pomodoroDurationTotal = minutes * 60;
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
       toggleTask(_selectedTaskId!);
       _selectedTaskId = null; 
    } 
    _sessionsCompleted++; 
    if (!_pomodoroSettings.enableBreaks) { resetTimer(); return; }
    int breakMinutes = 5; 
    if (_pomodoroSettings.enableLongBreaks && _sessionsCompleted % 3 == 0) breakMinutes = 15;
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
  
  void updateSettings(PomodoroSettings newSettings) async { 
    _pomodoroSettings = newSettings; 
    await _repository.updatePomodoroSettings(newSettings); 
    
    // Hvis timeren er idle, opdater tiden med det samme
    if (!isTimerRunning && _timerStatus == TimerStatus.idle) { 
      _pomodoroDurationTotal = _pomodoroSettings.workDurationMinutes * 60; 
      _pomodoroTimeLeft = _pomodoroDurationTotal; 
    } 
    notifyListeners(); 
  }
}