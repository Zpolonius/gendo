import 'package:flutter/material.dart';

class CalendarEvent {
  final String id;
  final String title;
  final DateTime start;
  final DateTime end;
  final Color color;
  final bool isAllDay;

  CalendarEvent({
    required this.id,
    required this.title,
    required this.start,
    required this.end,
    this.color = const Color(0xFF4285F4), // Google Blue som default
    this.isAllDay = false,
  });
}