import 'dart:async';
// Nødvendig for DateTime og Widgets
import '../base_view_model.dart';
import '../../models.dart';
import 'task_mixin.dart';
import '../../services/notification_service.dart';



enum TimerStatus { idle, working, finishedWork, onBreak }

mixin PomodoroMixin on BaseViewModel, TaskMixin {
  
  final NotificationService _notificationService = NotificationService();

  // State
  PomodoroSettings _pomodoroSettings = PomodoroSettings(); 
  int _pomodoroDurationTotal = 25 * 60;
  int _pomodoroTimeLeft = 25 * 60;
  Timer? _timer;
  
  // NY: Holder styr på det faktiske sluttidspunkt
  DateTime? _timerEndTime; 
  
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
      return allTasks.firstWhere((t) => t.id == _selectedTaskId);
    } catch (e) {
      return null;
    }
  }

  // --- INITIALIZERS ---
// NY METODE: Afslut opgave men fortsæt timer
  Future<void> completeTaskEarly() async {
    if (_selectedTaskId != null) {
      // 1. Markér opgaven som færdig i databasen/listen
      await toggleTask(_selectedTaskId!);
      
      // 2. Fjern opgaven fra fokus, så timeren fortsætter i "Frit fokus"
      _selectedTaskId = null;
      
      // 3. Opdater UI
      notifyListeners();
    }
  }
  Future<void> loadPomodoroData() async {
    try {
      _pomodoroSettings = await repository.getPomodoroSettings();
      
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
  
  void startTimer() async { 
    if (_timer != null) return; 
    await _notificationService.requestPermissions();
    
    // Sæt status hvis vi starter fra idle
    if (_timerStatus == TimerStatus.idle) _timerStatus = TimerStatus.working; 
    
    // 1. Beregn hvornår tiden faktisk udløber (NU + resterende sekunder)
    _timerEndTime = DateTime.now().add(Duration(seconds: _pomodoroTimeLeft));
    
    // 2. Planlæg notifikationen til dette tidspunkt
    _scheduleCompletionNotification();

    notifyListeners(); 
    
    // 3. Start loopet der opdaterer UI
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) { 
      final now = DateTime.now();
      
      if (_timerEndTime != null && now.isBefore(_timerEndTime!)) {
        // Beregn resterende tid baseret på forskellen (Wall-clock)
        // Dette sikrer at tiden er korrekt selvom appen har været lukket
        _pomodoroTimeLeft = _timerEndTime!.difference(now).inSeconds;
      } else { 
        // Tiden er udløbet
        _pomodoroTimeLeft = 0;
        stopTimer(); 
        _handleTimerComplete(); 
      } 
      notifyListeners(); 
    }); 
  }
  
  void stopTimer() { 
    _timer?.cancel(); 
    _timer = null; 
    _timerEndTime = null; // Nulstil sluttidspunkt
    _notificationService.cancelAll(); // Fjern notifikationen hvis brugeren stopper manuelt
    notifyListeners(); 
  }
  
  void resetTimer() { 
    stopTimer(); 
    _pomodoroDurationTotal = _pomodoroSettings.workDurationMinutes * 60; 
    _pomodoroTimeLeft = _pomodoroDurationTotal; 
    _timerStatus = TimerStatus.idle; 
    notifyListeners(); 
  }

  // Hjælpefunktion til notifikationer
  void _scheduleCompletionNotification() {
    if (_timerEndTime == null) return;
    
    String title = _timerStatus == TimerStatus.working ? "Tiden er gået🎉!" : "Pausen er slut!🤗";
    String body = _timerStatus == TimerStatus.working 
        ? "Godt arbejde!🎉 Tag en pause eller fortsæt." 
        : "Klar til at fokusere igen?🦾";

    if (_selectedTaskId != null && _timerStatus == TimerStatus.working) {
      final task = selectedTaskObj;
      if (task != null) body = "Fik du lavet '${task.title}'?";
    }

    _notificationService.scheduleTimerNotification(
      id: 0,
      title: title,
      body: body,
      scheduledTime: _timerEndTime!,
    );
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
    
    if (!_pomodoroSettings.enableBreaks) { 
      resetTimer(); 
      return; 
    }
    
    int breakMinutes = 5; 
    if (_pomodoroSettings.enableLongBreaks && _sessionsCompleted % 3 == 0) {
      breakMinutes = 15; 
    }
    
    startBreak(breakMinutes); 
  }
  
  void startBreak(int minutes) { 
    _pomodoroDurationTotal = minutes * 60; 
    _pomodoroTimeLeft = _pomodoroDurationTotal; 
    _timerStatus = TimerStatus.onBreak; 
    
    // Start timeren (og dermed notifikations-logikken) for pausen
    startTimer(); 
    
    notifyListeners(); 
  }
  
  void skipBreak() { 
    resetTimer(); 
  }
  void completeWorkSessionWithChoice({required bool isTaskDone, required startBreak}) {
    // 1. Håndter opgaven
    if (isTaskDone && _selectedTaskId != null) {
       // Sikr dig at vi ikke toggler den tilbage til "ikke færdig", hvis den allerede er færdig
       // Men her antager vi at isTaskDone er den ØNSKEDE slut-status.
       // Da dialogen allerede har opdateret steps/task via optimistic updates, 
       // skal vi måske bare rydde selectionen her.
       
       // Hvis opgaven er færdig, fjerner vi den fra "Active Task" i timeren
       _selectedTaskId = null; 
    }
    
    _sessionsCompleted++;
    
    // 2. Håndter Pausevalg
    if (startBreak) {
      // Beregn pausetid
      int breakMinutes = 5; 
      if (_pomodoroSettings.enableLongBreaks && _sessionsCompleted % 3 == 0) {
        breakMinutes = 15;
      }
      startBreak(breakMinutes); // Omdøb evt. til din interne metode 'startBreak(minutes)'
    } else {
      // Ingen pause -> Nulstil timer til ny arbejds-session
      resetTimer(); 
    }
    
    notifyListeners();
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
