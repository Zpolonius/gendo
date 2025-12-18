import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models.dart';
import '../viewmodel.dart';
import 'dart:ui' as ui;
import '../viewmodels/calendar_viewmodel.dart';
import '../widgets/calendar_item.dart';
import 'task_detail_screen.dart';

import '../widgets/month_calendar.dart'; // Import Month Widget

class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProxyProvider<AppViewModel, CalendarViewModel>(
      create: (context) => CalendarViewModel(context.read<AppViewModel>()),
      update: (context, appVm, calendarVm) => calendarVm ?? CalendarViewModel(appVm),
      child: const _CalendarScaffold(),
    );
  }
}

class _CalendarScaffold extends StatefulWidget {
  const _CalendarScaffold();

  @override
  State<_CalendarScaffold> createState() => _CalendarScaffoldState();
}

class _CalendarScaffoldState extends State<_CalendarScaffold> {
  late PageController _pageController;
  final int _initialPage = 10000;
  bool _isMonthView = false; // State til at styre visning

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _initialPage);
  }
  
  // ... Dispose ...

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CalendarViewModel>();
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        // Kun vis titel hvis vi er i dagsvisning (Månedsvisning har sin egen header)
        title: !_isMonthView ? Text(
          DateFormat('MMMM yyyy').format(vm.selectedDate), 
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ) : null,
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
        foregroundColor: theme.colorScheme.onSurface,
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.today),
            onPressed: () {
               vm.jumpToToday();
               setState(() {
                  _isMonthView = false;
               });
               // Reset også page controller hvis vi går til dagsvisning
               if (_pageController.hasClients) {
                 _pageController.jumpToPage(_initialPage);
               }
            },
            tooltip: "Gå til i dag",
          ),
          IconButton(
            // Skift ikon baseret på view
            icon: Icon(_isMonthView ? Icons.view_day : Icons.calendar_view_month),
            onPressed: () {
              setState(() {
                _isMonthView = !_isMonthView;
              });
            },
          )
        ],
      ),
      body: _isMonthView 
        ? MonthCalendarWidget(
            initialDate: vm.selectedDate,
            onDateSelected: (date) {
               // 1. Opdater valgte dato
               vm.setDate(date); // Opdater ViewModel
               
               // 2. Skift tilbage til dagsvisning
               setState(() => _isMonthView = false);
               
               // 3. Beregn korrekt page index for at synkronisere PageView
               // _initialPage (10000) svarer til "I dag"
               final now = DateTime.now();
               final today = DateTime(now.year, now.month, now.day);
               final target = DateTime(date.year, date.month, date.day);
               final diffDays = target.difference(today).inDays;
               
               // Vi skal sikre at controlleren er attached før vi jumper
               // Da vi lige har sat _isMonthView til false, rebuildes widget treeet nu.
               // Vi bruger addPostFrameCallback eller bare delay for at lade PageView bygge først,
               // men PageView er direkte i body, så den bør være der. 
               // Men da jumpToPage kræver at viewet er bygget, gør vi det sådan her:
               WidgetsBinding.instance.addPostFrameCallback((_) {
                 if (_pageController.hasClients) {
                    _pageController.jumpToPage(_initialPage + diffDays);
                 }
               });
            },
          )
        : PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              final diff = index - _initialPage;
              final newDate = DateTime.now().add(Duration(days: diff));
              if (!DateUtils.isSameDay(newDate, vm.selectedDate)) {
                 vm.setDate(newDate);
              }
            },
            itemBuilder: (context, index) {
              final diff = index - _initialPage;
              final date = DateTime.now().add(Duration(days: diff));
              return _DayView(date: date);
            },
          ),
    );
  }
}

class _DayView extends StatefulWidget {
  final DateTime date;
  
  const _DayView({required this.date});

  @override
  State<_DayView> createState() => _DayViewState();
}

class _DayViewState extends State<_DayView> {
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    // Start scroll på kl 08:00 (8 timer * 60 pixels = 480.0)
    _scrollController = ScrollController(initialScrollOffset: 480.0);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Vi spørger ViewModel om entries for denne specifikke dag
    final vm = context.watch<CalendarViewModel>();
    
    final isSelectedDay = DateUtils.isSameDay(widget.date, vm.selectedDate);
    
    final allDayEntries = vm.allDayEntriesForDay;
    
    return Column(
      children: [
        // 1. Dato Header
        Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          // ... (Dato header kode - bevares ved at pakke det ind eller kopiere, men her indsætter jeg det hele for kontekst)
          child: Column(
            children: [
              Text(DateFormat('EEEE').format(widget.date).toUpperCase(), style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: isSelectedDay && DateUtils.isSameDay(widget.date, DateTime.now()) 
                  ? const BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle) 
                  : null,
                child: Text(
                  "${widget.date.day}", 
                  style: TextStyle(
                    fontSize: 20, 
                    fontWeight: FontWeight.bold,
                    color: (isSelectedDay && DateUtils.isSameDay(widget.date, DateTime.now())) ? Colors.white : null
                  )
                ),
              ),
            ],
          ),
        ),
        
        // 1.5 All Day Sektion (Ny)
        if (isSelectedDay && allDayEntries.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Theme.of(context).dividerColor.withOpacity(0.05),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("HELE DAGEN", style: TextStyle(fontSize: 10, color: Theme.of(context).disabledColor, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                ...allDayEntries.map((entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: CalendarItemWidget(
                    entry: entry,
                    onTap: () {
                         if (entry.isTask) {
                           final task = (entry as TaskEntry).task;
                           Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => TaskDetailScreen(taskId: task.id, initialTask: task, onStartTask: (){})
                           ));
                         } else {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(entry.title)));
                         }
                    }
                  ),
                )),
              ],
            ),
          ),
        
        // 2. Tidslinje Scroll
        Expanded(
          child: SingleChildScrollView(
            controller: _scrollController, // Bruger vores controller med initial offset
            physics: const BouncingScrollPhysics(),
            child: SizedBox(
               height: 24 * 60.0, // 60px per time = 1440px total højde
               child: Stack(
                 children: [
                   // Baggrunds-gitter
                   CustomPaint(
                     painter: _DayGridPainter(lineColor: Theme.of(context).dividerColor),
                     size: const Size(double.infinity, 1440),
                   ),
                   
                   // Events (Kun hvis det er den valgte dag, for nu)
                   if (isSelectedDay)
                     ...vm.getRenderedEntriesForDay(60.0).map((renderEntry) {
                        return Positioned.fromRect(
                          rect: renderEntry.rect,
                          child: CalendarItemWidget(
                            entry: renderEntry.entry,
                            onTap: () {
                               if (renderEntry.entry.isTask) {
                                 final task = (renderEntry.entry as TaskEntry).task;
                                 Navigator.of(context).push(MaterialPageRoute(
                                    builder: (_) => TaskDetailScreen(taskId: task.id, initialTask: task, onStartTask: (){})
                                 ));
                               } else {
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(renderEntry.entry.title)));
                               }
                            },
                          ),
                        );
                     }),
                     
                   // Current Time Indicator (Hvis i dag)
                   if (DateUtils.isSameDay(widget.date, DateTime.now()))
                     const _CurrentTimeIndicator()
                 ],
               ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DayGridPainter extends CustomPainter {
  final Color lineColor;
  final double hourHeight = 60.0;

  _DayGridPainter({required this.lineColor});

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()..color = lineColor.withOpacity(0.2)..strokeWidth = 1.0;
    final textPainter = TextPainter(textDirection: ui.TextDirection.ltr);

    for (int i = 0; i < 24; i++) {
      final y = i * hourHeight;
      
      // Tid tekst (kl 13:00)
      final timeText = '${i.toString().padLeft(2, '0')}:00';
      textPainter.text = TextSpan(text: timeText, style: TextStyle(color: lineColor.withOpacity(0.5), fontSize: 12));
      textPainter.layout();
      textPainter.paint(canvas, Offset(8, y - textPainter.height / 2));
      
      // Linje
      canvas.drawLine(Offset(50, y), Offset(size.width, y), linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CurrentTimeIndicator extends StatelessWidget {
  const _CurrentTimeIndicator();

  @override
  Widget build(BuildContext context) {
    // Placering baseret på nuværende tid
    final now = TimeOfDay.now();
    final top = (now.hour * 60.0) + (now.minute);

    return Positioned(
      top: top,
      left: 50,
      right: 0,
      child: Row(
        children: [
          Container(
            width: 8, height: 8,
            decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
          ),
          Expanded(child: Container(height: 1, color: Colors.redAccent)),
        ],
      ),
    );
  }
}