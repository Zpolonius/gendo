import 'dart:async';
import '../base_view_model.dart';
import '../../models.dart';
import 'task_mixin.dart'; // Nødvendig for at kunne kalde toggleTask

enum TimerStatus { idle, working, finishedWork, onBreak }

/// Håndterer Pomodoro Timer logik.
/// Afhænger af TaskMixin for at kunne markere valgte opgaver som færdige.
mixin PomodoroMixin on BaseViewModel, TaskMixin {
  
  // State
  PomodoroSettings _pomodoroSettings = PomodoroSettings(); 
  int _pomodoroDurationTotal = 25 * 60;
  int _pomodoroTimeLeft = 25 * 60;
  Timer? _timer;
  TimerStatus _timerStatus = TimerStatus.idle;
  int _sessionsCompleted = 0;
  String? _selectedTaskId;

  // Getters
  PomodoroSettings get pomodoroSettings => _pomodoroSettings;
  int get pomodoroTimeLeft => _pomodoroTimeLeft;
  int get pomodoroDurationTotal => _pomodoroDurationTotal;
  bool get isTimerRunning => _timer != null && _timer!.isActive;
  TimerStatus get timerStatus => _timerStatus;
  String? get selectedTaskId => _selectedTaskId;
  int get sessionsCompleted => _sessionsCompleted;
  bool get isOnBreak => _timerStatus == TimerStatus.onBreak;
  
  double get progress => _pomodoroDurationTotal == 0 ? 0 : 1.0 - (_pomodoroTimeLeft / _pomodoroDurationTotal);

  TodoTask? get selectedTaskObj {
    if (_selectedTaskId == null) return null;
    try {
      // allTasks kommer fra TaskMixin
      return allTasks.firstWhere((t) => t.id == _selectedTaskId);
    } catch (e) {
      return null;
    }
  }

  // --- INITIALIZERS ---

  Future<void> loadPomodoroData() async {
    try {
      _pomodoroSettings = await repository.getPomodoroSettings();
      
      // Hvis timeren ikke kører, opdater varigheden til de gemte indstillinger
      if (_timerStatus == TimerStatus.idle) {
        _pomodoroDurationTotal = _pomodoroSettings.workDurationMinutes * 60;
        _pomodoroTimeLeft = _pomodoroDurationTotal;
      }
    } catch (e) {
      handleError(e);
    }
  }

  // --- LOGIC ---

  void setSelectedTask(String? taskId) { 
    _selectedTaskId = taskId; 
    notifyListeners(); 
  }
  
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
  
  void stopTimer() { 
    _timer?.cancel(); 
    _timer = null; 
    notifyListeners(); 
  }
  
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
    } else if (_timerStatus == TimerStatus.onBreak) { 
      resetTimer(); 
    } 
  }
  
  void completeWorkSession(bool isTaskDone) { 
    if (isTaskDone && _selectedTaskId != null) { 
       // Kalder toggleTask fra TaskMixin
       toggleTask(_selectedTaskId!);
       _selectedTaskId = null; 
    } 
    _sessionsCompleted++; 
    
    if (!_pomodoroSettings.enableBreaks) { 
      resetTimer(); 
      return; 
    }
    
    int breakMinutes = 10; // Default kort pause
    // Check om det skal være en lang pause
    if (_pomodoroSettings.enableLongBreaks && _sessionsCompleted % 3 == 0) {
      breakMinutes = 30; // Lang pause hver 3. gang (eksempelvis)
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
  
  void skipBreak() { 
    resetTimer(); 
  }
  
  void updateSettings(PomodoroSettings newSettings) async { 
    _pomodoroSettings = newSettings; 
    await repository.updatePomodoroSettings(newSettings); 
    
    if (!isTimerRunning && _timerStatus == TimerStatus.idle) { 
      _pomodoroDurationTotal = _pomodoroSettings.workDurationMinutes * 60; 
      _pomodoroTimeLeft = _pomodoroDurationTotal; 
    } 
    notifyListeners(); 
  }
}