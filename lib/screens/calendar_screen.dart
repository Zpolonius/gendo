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

class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Opretter CalendarViewModel og injecter AppViewModel
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
          // 1. Tidslinjen
          Positioned.fill(
            child: CustomPaint(
              painter: TimelinePainter(
                focusedTime: calVm.focusedTime,
                granularity: calVm.granularity,
                tasks: calVm.visibleTasks,
                events: calVm.visibleEvents,
                textColor: isDark ? Colors.white : Colors.black87,
                lineColor: isDark ? Colors.white24 : Colors.black12,
              ),
            ),
          ),
          
          // 2. "NU" Indikatoren (Center Linje)
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
          
          // 3. Info HUD (Dato & Zoom)
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

          // 4. Thumb Wheel Controller
          Positioned(
            bottom: 60,
            right: 0,
            child: ThumbWheelWidget(
              rotation: calVm.wheelRotation,
              onTap: calVm.toggleGranularity,
              onScroll: calVm.updateScroll,
            ),
          ),
          
          // 5. Reset knap
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
}

class TimelinePainter extends CustomPainter {
  final DateTime focusedTime;
  final TimeGranularity granularity;
  final List<TodoTask> tasks;
  final List<CalendarEvent> events;
  final Color textColor;
  final Color lineColor;

  TimelinePainter({
    required this.focusedTime,
    required this.granularity,
    required this.tasks,
    required this.events,
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
    // Juster steps baseret på zoom for at undgå clutter
    if (granularity == TimeGranularity.months) pixelsPerStep = 40.0;
    
    int stepsToRender = (size.height / pixelsPerStep).ceil() + 2; 

    // Loop gennem steps (både fortid og fremtid ift. skærmens midte)
    for (int i = -stepsToRender; i <= stepsToRender; i++) {
      double yPos = centerY + (i * pixelsPerStep);
      DateTime stepTime = _addSteps(focusedTime, i);
      
      // 1. Tegn Tids-gitter
      canvas.drawLine(Offset(40, yPos), Offset(60, yPos), linePaint);
      
      String label = _getLabel(stepTime);
      textPainter.text = TextSpan(text: label, style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 12));
      textPainter.layout();
      textPainter.paint(canvas, Offset(5, yPos - textPainter.height / 2));

      // 2. Tegn EVENTS (Venstre side)
      // Tjekker om events overlapper dette tidspunkt
      for (var event in events) {
        if (_isEventCovering(event, stepTime, pixelsPerStep)) {
           _drawEventBlock(canvas, yPos, event, pixelsPerStep);
        }
      }

      // 3. Tegn TASKS (Højre side)
      for (var task in tasks) {
        if (task.dueDate != null && _isSameSlot(task.dueDate!, stepTime)) {
           _drawTaskDot(canvas, yPos, task, size.width);
        }
      }
    }
  }

  // Hjælpere til tegning

  void _drawEventBlock(Canvas canvas, double y, CalendarEvent event, double stepHeight) {
    // Vi tegner en simpel farvet blok til venstre for tidslinjen
    final paint = Paint()..color = event.color.withOpacity(0.3);
    
    // Vi tegner den 200px bred, startende fra venstre kant (minus lidt padding)
    // Bemærk: En rigtig robust løsning ville beregne præcis start/slut Y-koordinater for eventet,
    // men her tegner vi "per step" hvilket er fint til visualisering.
    final rect = Rect.fromLTWH(70, y - (stepHeight/2) + 2, 120, stepHeight - 4);
    
    // Kun tegn en gang pr. "blok" - dette er en simpel visualisering. 
    // Hvis vi vil have titlen med, skal vi tjekke om vi er tæt på "start" tiden.
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(4)), paint);
    
    // Tegn titel hvis vi er tæt på start-tiden
    double diffMinutes = event.start.difference(focusedTime).inMinutes.abs().toDouble(); // Grov logik
    // En bedre logik er at tjekke om y er tæt på centerY og eventet er aktivt, eller bare tegne teksten i midten af blokken.
    // For nu: Tegn lille indikator.
    canvas.drawRect(Rect.fromLTWH(70, y - (stepHeight/2) + 2, 4, stepHeight - 4), Paint()..color = event.color);
  }

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

  bool _isEventCovering(CalendarEvent event, DateTime stepTime, double stepHeight) {
    // Simpel collision check: Er stepTime inden for event start/slut?
    // Vi bruger en lille buffer for ikke at tegne i "hullerne" hvis granulatiten er grov
    return stepTime.isAfter(event.start.subtract(const Duration(minutes: 1))) && 
           stepTime.isBefore(event.end.add(const Duration(minutes: 1)));
  }

  @override
  bool shouldRepaint(TimelinePainter old) => 
    old.focusedTime != focusedTime || old.granularity != granularity || old.tasks != tasks || old.events != events;
}