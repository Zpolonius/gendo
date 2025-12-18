import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models.dart';
import '../models/calendar_event.dart';
import '../viewmodel.dart';

enum TimeGranularity { hours, days, weeks, months }

// --- UNIFIED MODELS ---
abstract class CalendarEntry {
  String get id;
  String get title;
  DateTime get start;
  DateTime get end;
  Color get color;
  bool get isAllDay;
  bool get isTask; 
}

class EventEntry extends CalendarEntry {
  final CalendarEvent event;
  EventEntry(this.event);
  
  @override String get id => event.id;
  @override String get title => event.title;
  @override DateTime get start => event.start;
  @override DateTime get end => event.end;
  @override Color get color => event.color;
  @override bool get isAllDay => event.isAllDay;
  @override bool get isTask => false;
}

class TaskEntry extends CalendarEntry {
  final TodoTask task;
  TaskEntry(this.task);

  @override String get id => task.id;
  @override String get title => task.title;
  
  // Tasks med tidspunkt får en default varighed på 1 time
  @override DateTime get start => task.dueDate!;
  @override DateTime get end => task.dueDate!.add(const Duration(hours: 1));
  
  // Tasks bruger prioritets-farver eller tema-farve
  @override Color get color {
     switch(task.priority) {
       case TaskPriority.high: return Colors.redAccent;
       case TaskPriority.medium: return Colors.orangeAccent;
       case TaskPriority.low: return Colors.greenAccent;
     }
  }
  
  // Hvis task ikke har tidspunkt (kun dato), er den All Day
  // Men her filtrerer vi kun tasks MED dueDate, så vi tjekker om den har tidskomponent
  @override bool get isAllDay {
     // En grov antagelse: Hvis tidspunkt er 00:00:00, er det nok en dato-only task
     return task.dueDate!.hour == 0 && task.dueDate!.minute == 0;
  }
  
  @override bool get isTask => true;
}

class RenderEntry {
  final CalendarEntry entry;
  final Rect rect; // Skærm-koordinater
  RenderEntry({required this.entry, required this.rect});
}


class CalendarViewModel extends ChangeNotifier {
  final AppViewModel _appViewModel;
  
  // --- STATE ---
  DateTime _focusedTime = DateTime.now();
  TimeGranularity _granularity = TimeGranularity.hours;
  // TODO: Fjern hjul-logik når viewet er opdateret
  double _wheelRotation = 0.0;
  
  // Data Containers
  List<CalendarEvent> _events = [];

  CalendarViewModel(this._appViewModel) {
    _loadMockEvents();
  }

  // Getters
  DateTime get focusedTime => _focusedTime;
  TimeGranularity get granularity => _granularity;
  double get wheelRotation => _wheelRotation;

  // --- DATA LOGIK ---

  void _loadMockEvents() {
    // Simulerer data
    final now = DateTime.now();
    _events = [
      CalendarEvent(id: '1', title: 'Møde med Marketing', start: now.subtract(const Duration(hours: 1)), end: now.add(const Duration(minutes: 30)), color: Colors.blueAccent),
      CalendarEvent(id: '2', title: 'Frokost', start: now.add(const Duration(hours: 2)), end: now.add(const Duration(hours: 3)), color: Colors.orangeAccent),
      CalendarEvent(id: '3', title: 'Deep Work Block', start: now.add(const Duration(hours: 4)), end: now.add(const Duration(hours: 6)), color: Colors.purpleAccent),
    ];
    notifyListeners();
  }

  // Unified Getter: Kombinerer Events og Tasks
  List<CalendarEntry> get combinedEntries {
    List<CalendarEntry> all = [];
    
    // 1. Add Events
    all.addAll(_events.map((e) => EventEntry(e)));
    
    // 2. Add Tasks (kun dem med dueDate)
    final tasksWithDate = _appViewModel.allTasks.where((t) => t.dueDate != null && !t.isCompleted);
    all.addAll(tasksWithDate.map((t) => TaskEntry(t)));
    
    return all;
  }

  // --- RENDERING HELPERS (Opdateret til CalendarEntry) ---

  List<RenderEntry> get renderedEntries {
    return _calculateLayout(combinedEntries, _focusedTime, _granularity);
  }

  List<RenderEntry> _calculateLayout(List<CalendarEntry> entries, DateTime focusTime, TimeGranularity granularity) {
    // TODO: Dette skal tilpasses den nye Grid-struktur (Fase 2).
    // For nu genbruger vi "Timeline" logikken så koden stadig compiler
    
    List<RenderEntry> rendered = [];
    final screenHeight = 800.0;
    final centerY = screenHeight / 2;
    double pixelsPerStep = 60.0;
    if (granularity == TimeGranularity.months) pixelsPerStep = 40.0;
    
    double getYForTime(DateTime time) {
      if (granularity == TimeGranularity.hours) {
        final diff = time.difference(focusTime);
        final steps = diff.inMinutes / 60.0;
        return centerY + (steps * pixelsPerStep);
      } else if (granularity == TimeGranularity.days) {
        final diff = time.difference(focusTime);
        final steps = diff.inHours / 24.0; 
        return centerY + (steps * pixelsPerStep);
      }
      return centerY;
    }

    for (var entry in entries) {
      // Skip "All Day" entries i tidslinjen (de skal i toppen senere)
      if (entry.isAllDay) continue;

      final startY = getYForTime(entry.start);
      final endY = getYForTime(entry.end);
      
      if (endY < -1000 || startY > 2000) continue;

      final height = (endY - startY).clamp(20.0, 2000.0);
      
      rendered.add(RenderEntry(
        entry: entry,
        // Vi bruger placeholders for X/Width indtil vi har kollisions-logik
        rect: Rect.fromLTWH(70, startY, 150, height), 
      ));
    }
    
    return rendered;
  }

  // --- ACTIONS ---

  void updateScroll(double deltaPixels) {
    // OLD WHEEL LOGIC (Beholdes midlertidigt for ikke at breake build)
    _wheelRotation += deltaPixels * 0.01;
    final int secondsToAdd = (-deltaPixels * 60).round();
    _focusedTime = _focusedTime.add(Duration(seconds: secondsToAdd));
    notifyListeners();
  }

  void toggleGranularity() {
    HapticFeedback.mediumImpact();
    // Simpel toggle for nu
    if (_granularity == TimeGranularity.hours) {
      _granularity = TimeGranularity.days; 
    } else {
       _granularity = TimeGranularity.hours;
    }
    notifyListeners();
  }

  void jumpToNow() {
    _focusedTime = DateTime.now();
    _wheelRotation = 0;
    HapticFeedback.lightImpact();
    notifyListeners();
  }
}