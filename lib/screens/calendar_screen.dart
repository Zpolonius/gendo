import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;

import '../viewmodel.dart';
import '../models.dart';
import '../models/calendar_event.dart';
import '../viewmodels/calendar_viewmodel.dart';
import '../widgets/thumb_wheel_widget.dart';
import '../widgets/calendar_item.dart';
import '../screens/task_detail_screen.dart'; // Import for navigation

class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProxyProvider<AppViewModel, CalendarViewModel>(
      create: (context) => CalendarViewModel(context.read<AppViewModel>()),
      update: (context, appVm, calendarVm) => calendarVm ?? CalendarViewModel(appVm),
      child: const _CalendarBody(),
    );
  }
}

class _CalendarBody extends StatelessWidget {
  const _CalendarBody();

  @override
  Widget build(BuildContext context) {
    final calVm = context.watch<CalendarViewModel>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          // 1. Tidslinjen (Baggrund)
          Positioned.fill(
            child: CustomPaint(
              painter: TimelinePainter(
                focusedTime: calVm.focusedTime,
                granularity: calVm.granularity,
                tasks: calVm.visibleTasks, // TODO: Remove this from painter later
                textColor: isDark ? Colors.white : Colors.black87,
                lineColor: isDark ? Colors.white24 : Colors.black12,
              ),
            ),
          ),
          
          // 2. Events & Tasks (Widgets)
          ...calVm.renderedEntries.map((renderEntry) {
            return Positioned.fromRect(
              rect: renderEntry.rect,
              child: CalendarItemWidget(
                entry: renderEntry.entry,
                onTap: () {
                   if (renderEntry.entry.isTask) {
                     // Navigering til Task Detail
                     _openTaskDetail(context, (renderEntry.entry as TaskEntry).task);
                   } else {
                     ScaffoldMessenger.of(context).showSnackBar(
                       SnackBar(content: Text("Event: ${renderEntry.entry.title}"))
                     );
                   }
                },
              ),
            );
          }),

          // 3. "NU" Indikatoren (Center Linje) - bevares midlertidigt
          Positioned(
            top: MediaQuery.of(context).size.height / 2,
            left: 0,
            right: 0,
            child: Container(
              height: 2,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.redAccent.withOpacity(0.1), Colors.redAccent, Colors.transparent],
                  stops: const [0.0, 0.4, 1.0],
                ),
              ),
            ),
          ),
          
          // 4. Info HUD (Dato & Zoom)
          Positioned(
            top: 60,
            left: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('EEEE, d. MMMM').format(calVm.focusedTime),
                  style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color),
                ),
                Row(
                  children: [
                    Text(
                      DateFormat('HH:mm').format(calVm.focusedTime),
                      style: GoogleFonts.poppins(fontSize: 32, fontWeight: FontWeight.w300, color: theme.primaryColor),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        border: Border.all(color: theme.primaryColor),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        calVm.granularity.name.toUpperCase(),
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: theme.primaryColor),
                      ),
                    )
                  ],
                ),
              ],
            ),
          ),

          // 5. Thumb Wheel Controller
          Positioned(
            bottom: 60,
            right: 0,
            child: ThumbWheelWidget(
              rotation: calVm.wheelRotation,
              onTap: calVm.toggleGranularity,
              onScroll: calVm.updateScroll,
            ),
          ),
          
          // 6. Reset knap
          Positioned(
            bottom: 40,
            left: 20,
            child: FloatingActionButton.small(
              onPressed: calVm.jumpToNow,
              backgroundColor: theme.colorScheme.surface,
              child: Icon(Icons.my_location, color: theme.primaryColor),
            ),
          )
        ],
      ),
    );
  }

  void _openTaskDetail(BuildContext context, TodoTask task) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => TaskDetailScreen(
        taskId: task.id, 
        initialTask: task, 
        onStartTask: () => print("Start task from calendar: ${task.title}") // Placeholder 
      )
    )); 
  }
}

class TimelinePainter extends CustomPainter {
  final DateTime focusedTime;
  final TimeGranularity granularity;
  final List<TodoTask> tasks;
  // Events fjernet fra painter - håndteres nu af Widgets
  final Color textColor;
  final Color lineColor;

  TimelinePainter({
    required this.focusedTime,
    required this.granularity,
    required this.tasks,
    required this.textColor,
    required this.lineColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;
    final textPainter = TextPainter(textDirection: ui.TextDirection.ltr);
    final linePaint = Paint()..color = lineColor..strokeWidth = 1.0;
    
    // Konfiguration
    double pixelsPerStep = 60.0;
    if (granularity == TimeGranularity.months) pixelsPerStep = 40.0;
    
    int stepsToRender = (size.height / pixelsPerStep).ceil() + 2; 

    for (int i = -stepsToRender; i <= stepsToRender; i++) {
      double yPos = centerY + (i * pixelsPerStep);
      DateTime stepTime = _addSteps(focusedTime, i);
      
      // 1. Tegn Tids-gitter
      canvas.drawLine(Offset(40, yPos), Offset(60, yPos), linePaint);
      
      String label = _getLabel(stepTime);
      textPainter.text = TextSpan(text: label, style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 12));
      textPainter.layout();
      textPainter.paint(canvas, Offset(5, yPos - textPainter.height / 2));

      // 2. Events (Fjernet herfra)

      // 3. Tegn TASKS (Højre side)
      for (var task in tasks) {
        if (task.dueDate != null && _isSameSlot(task.dueDate!, stepTime)) {
           _drawTaskDot(canvas, yPos, task, size.width);
        }
      }
    }
  }

  // Hjælpere til tegning

  void _drawTaskDot(Canvas canvas, double y, TodoTask task, double screenWidth) {
     final paint = Paint()..color = Colors.redAccent;
     canvas.drawCircle(Offset(220, y), 5, paint); // Dot på højre side
     
     final textPainter = TextPainter(
       text: TextSpan(text: task.title, style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.w500)),
       textDirection: ui.TextDirection.ltr
     );
     textPainter.layout(maxWidth: screenWidth - 240);
     textPainter.paint(canvas, Offset(235, y - textPainter.height / 2));
  }

  // Dato Logik

  DateTime _addSteps(DateTime base, int steps) {
    switch (granularity) {
      case TimeGranularity.hours: return base.add(Duration(hours: steps));
      case TimeGranularity.days: return base.add(Duration(days: steps));
      case TimeGranularity.weeks: return base.add(Duration(days: steps * 7));
      case TimeGranularity.months: return DateTime(base.year, base.month + steps, base.day);
    }
  }

  String _getLabel(DateTime time) {
    switch (granularity) {
      case TimeGranularity.hours: return DateFormat('HH:00').format(time);
      case TimeGranularity.days: return DateFormat('E d').format(time);
      case TimeGranularity.weeks: return "Uge ${((time.day) / 7).ceil()}"; 
      case TimeGranularity.months: return DateFormat('MMM').format(time);
    }
  }
  
  bool _isSameSlot(DateTime t1, DateTime stepTime) {
    Duration diff = t1.difference(stepTime).abs();
    switch (granularity) {
      case TimeGranularity.hours: return diff.inMinutes < 30;
      case TimeGranularity.days: return diff.inHours < 12;
      case TimeGranularity.weeks: return diff.inDays < 3;
      case TimeGranularity.months: return diff.inDays < 15;
    }
  }

  @override
  bool shouldRepaint(TimelinePainter old) => 
    old.focusedTime != focusedTime || old.granularity != granularity || old.tasks != tasks;
}