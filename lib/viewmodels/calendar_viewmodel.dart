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
  DateTime _selectedDate = DateTime.now();
  // TimeGranularity _granularity = TimeGranularity.hours; // Ikke brugt i DayView pt
  
  // Data Containers
  List<CalendarEvent> _events = [];

  CalendarViewModel(this._appViewModel) {
    _loadMockEvents();
  }

  // Getters
  DateTime get selectedDate => _selectedDate;
  
  // --- ACTIONS ---

  void setDate(DateTime date) {
    _selectedDate = date;
    notifyListeners();
  }

  void nextDay() {
    _selectedDate = _selectedDate.add(const Duration(days: 1));
    notifyListeners();
  }

  void previousDay() {
    _selectedDate = _selectedDate.subtract(const Duration(days: 1));
    notifyListeners();
  }

  void jumpToToday() {
    _selectedDate = DateTime.now();
    notifyListeners();
  }

  // --- DATA LOGIK ---

  void _loadMockEvents() {
    final now = DateTime.now();
    // Hardcoded mock events til demo
    _events = [
      CalendarEvent(id: '1', title: 'Møde med Marketing', start: DateTime(now.year, now.month, now.day, 10, 0), end: DateTime(now.year, now.month, now.day, 11, 30), color: Colors.blueAccent),
      CalendarEvent(id: '2', title: 'Frokost', start: DateTime(now.year, now.month, now.day, 12, 0), end: DateTime(now.year, now.month, now.day, 12, 45), color: Colors.orangeAccent),
      CalendarEvent(id: '3', title: 'Deep Work', start: DateTime(now.year, now.month, now.day, 14, 0), end: DateTime(now.year, now.month, now.day, 16, 0), color: Colors.purpleAccent),
    ];
    notifyListeners();
  }

  // Unified Getter: Returnerer entries for den valgte dag
  List<CalendarEntry> get combinedEntriesForDay {
    // Filtrer events/tasks til KUN at være på _selectedDate
    
    List<CalendarEntry> dayEntries = [];
    
    // 1. Events
    for (var e in _events) {
      if (isSameDay(e.start, _selectedDate)) {
        dayEntries.add(EventEntry(e));
      }
    }
    
    // 2. Tasks
    final tasksWithDate = _appViewModel.allTasks.where((t) => t.dueDate != null && !t.isCompleted);
    for (var t in tasksWithDate) {
      if (isSameDay(t.dueDate!, _selectedDate)) {
        dayEntries.add(TaskEntry(t));
      }
    }
    
    return dayEntries;
  }
  
  bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  // --- RENDERING HELPERS ---

  List<RenderEntry> getRenderedEntriesForDay(double hourHeight) {
    // ... eksisterende kode ...
    final entries = combinedEntriesForDay;
    List<RenderEntry> rendered = [];
    
    for (var entry in entries) {
      if (entry.isAllDay) continue; 

      final startHour = entry.start.hour + (entry.start.minute / 60.0);
      final top = startHour * hourHeight;
      
      final durationMinutes = entry.end.difference(entry.start).inMinutes;
      final height = (durationMinutes / 60.0) * hourHeight;

      final left = 60.0; 
      final width = 250.0; 

      rendered.add(RenderEntry(
        entry: entry,
        rect: Rect.fromLTWH(left, top, width, height > 20 ? height : 20),
      ));
    }
    return rendered;
  }

  // Helper til Månedsvisning: Returnerer simple entry-data for en specifik dato
  // Bruges til at tegne små prikker (dots) i kalenderen
  List<CalendarEntry> getEntriesForDate(DateTime date) {
    List<CalendarEntry> dayEntries = [];
    
    for (var e in _events) {
      if (isSameDay(e.start, date)) {
        dayEntries.add(EventEntry(e));
      }
    }
    
    final tasksWithDate = _appViewModel.allTasks.where((t) => t.dueDate != null && !t.isCompleted);
    for (var t in tasksWithDate) {
      if (isSameDay(t.dueDate!, date)) {
        dayEntries.add(TaskEntry(t));
      }
    }
    return dayEntries;
  }
}
