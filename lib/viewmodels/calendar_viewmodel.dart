import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models.dart';
import '../models/calendar_event.dart'; // Husk at importere den nye model
import '../viewmodel.dart';

enum TimeGranularity { hours, days, weeks, months }

class CalendarViewModel extends ChangeNotifier {
  final AppViewModel _appViewModel;
  
  // --- STATE ---
  DateTime _focusedTime = DateTime.now();
  TimeGranularity _granularity = TimeGranularity.hours;
  double _wheelRotation = 0.0;
  bool _isScrollingFast = false;
  Timer? _velocityResetTimer;

  // Data Containers
  List<CalendarEvent> _events = [];

  CalendarViewModel(this._appViewModel) {
    _loadMockEvents(); // Forbereder UI til Google Kalender data
  }

  // Getters
  DateTime get focusedTime => _focusedTime;
  TimeGranularity get granularity => _granularity;
  double get wheelRotation => _wheelRotation;
  
  List<TodoTask> get visibleTasks => _getVisibleTasks();
  List<CalendarEvent> get visibleEvents => _events; // I fremtiden filtrerer vi også disse

  // --- DATA LOGIK ---

  void _loadMockEvents() {
    // Dette simulerer data fra Google Kalender
    final now = DateTime.now();
    _events = [
      CalendarEvent(
        id: '1', 
        title: 'Møde med Marketing', 
        start: now.subtract(const Duration(hours: 1)), 
        end: now.add(const Duration(minutes: 30)),
        color: Colors.blueAccent
      ),
      CalendarEvent(
        id: '2', 
        title: 'Frokost', 
        start: now.add(const Duration(hours: 2)), 
        end: now.add(const Duration(hours: 3)),
        color: Colors.orangeAccent
      ),
      CalendarEvent(
        id: '3', 
        title: 'Deep Work Block', 
        start: now.add(const Duration(hours: 4)), 
        end: now.add(const Duration(hours: 6)),
        color: Colors.purpleAccent
      ),
    ];
    notifyListeners();
  }

  List<TodoTask> _getVisibleTasks() {
    // Vi filtrerer tasks groft for performance
    final allTasks = _appViewModel.allTasks;
    return allTasks.where((t) {
      if (t.dueDate == null) return false;
      // Vis kun tasks inden for +/- 60 dage af fokus
      final diff = t.dueDate!.difference(_focusedTime).inDays.abs();
      return diff < 60; 
    }).toList();
  }

  // --- INTERAKTION & FYSIK ---

  void updateScroll(double deltaPixels) {
    _wheelRotation += deltaPixels * 0.01;

    // Velocity Zoom: Hvis man scroller hurtigt, flytter tiden sig hurtigere
    double velocityMultiplier = 1.0;
    if (deltaPixels.abs() > 15) { 
      velocityMultiplier = 3.0; // 3x hastighed ved hurtige svirp
    }

    final int secondsToAdd = (-deltaPixels * _getSensitivity() * velocityMultiplier).round();
    _focusedTime = _focusedTime.add(Duration(seconds: secondsToAdd));

    _handleHaptics(secondsToAdd);
    notifyListeners();
  }

  void toggleGranularity() {
    HapticFeedback.mediumImpact();
    switch (_granularity) {
      case TimeGranularity.hours: _granularity = TimeGranularity.days; break;
      case TimeGranularity.days: _granularity = TimeGranularity.weeks; break;
      case TimeGranularity.weeks: _granularity = TimeGranularity.months; break;
      case TimeGranularity.months: _granularity = TimeGranularity.hours; break;
    }
    notifyListeners();
  }

  void jumpToNow() {
    _focusedTime = DateTime.now();
    _wheelRotation = 0;
    HapticFeedback.lightImpact();
    notifyListeners();
  }

  // --- PRIVATE HJÆLPERE ---

  int _getSensitivity() {
    // Sekunder pr. pixel scroll
    switch (_granularity) {
      case TimeGranularity.hours: return 60;       // 1 px = 1 min
      case TimeGranularity.days: return 60 * 30;   // 1 px = 30 min
      case TimeGranularity.weeks: return 60 * 60 * 6; 
      case TimeGranularity.months: return 60 * 60 * 24; 
    }
  }
  
  DateTime _lastHapticTime = DateTime.now();
  void _handleHaptics(int secondsChanged) {
    // Undgå at vibrere for ofte (max hver 50ms)
    if (DateTime.now().difference(_lastHapticTime).inMilliseconds > 50) {
       HapticFeedback.selectionClick();
       _lastHapticTime = DateTime.now();
    }
  }
}