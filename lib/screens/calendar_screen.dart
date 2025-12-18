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
  
  // Vi starter PageController på en høj index (f.eks. 10000) for at kunne swipe tilbage i tid
  // Index 10000 = I dag
  final int _initialPage = 10000;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _initialPage);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CalendarViewModel>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Synkroniser PageView med ViewModel hvis dato ændres udefra (f.eks. "I dag" knap)
    // Bemærk: Dette er lidt tricky med dublex-binding, så vi gør det simpelt:
    // PageView styrer primært datoen ved swipe.
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          DateFormat('MMMM yyyy').format(vm.selectedDate), // F.eks. "December 2025"
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
        foregroundColor: theme.colorScheme.onSurface,
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.today),
            onPressed: () {
               vm.jumpToToday();
               _pageController.jumpToPage(_initialPage);
            },
            tooltip: "Gå til i dag",
          ),
          IconButton(
            icon: const Icon(Icons.calendar_view_month),
            onPressed: () {
              // TODO: Implement Month View (Fase 3)
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Månedsvisning kommer snart!")));
            },
          )
        ],
      ),
      body: PageView.builder(
        controller: _pageController,
        onPageChanged: (index) {
          final diff = index - _initialPage;
          final newDate = DateTime.now().add(Duration(days: diff));
          // Undgå loop hvis vm allerede har datoen
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

class _DayView extends StatelessWidget {
  final DateTime date;
  
  const _DayView({required this.date});

  @override
  Widget build(BuildContext context) {
    // Vi spørger ViewModel om entries for denne specifikke dag
    // Bemærk: Vi bør ideelt set pass date til viewmodel, men her tager vi den valgte.
    // Fordi PageView renderer side-paneler præ-emptivt, kan dette give fejl hvis vi kun kigger på vm.selectedDate.
    // Men for simpelthedens skyld antager vi at vm.selectedDate opdateres hurtigt, ELLER (bedre):
    // Vi flytter logikken "getRenderedEntries" ind i et helper-mix, men for nu:
    
    final vm = context.watch<CalendarViewModel>();
    
    // Hack: Hvis denne widget ikke er for den valgte dag, så vis bare gitteret (optimering + undgå glitch)
    // Eller bedre: Vi burde have en metode `getEntriesFor(date)` i VM.
    // Da vi ikke har refaktureret VM til at give entries per dato-argument, bruger vi VM's selectedDate data.
    // Dette betyder animationen kan se lidt sjov ud (indhold shifter mens man swiper). 
    // Det er acceptabelt for Fase 2 start.
    
    final isSelectedDay = DateUtils.isSameDay(date, vm.selectedDate);
    
    return Column(
      children: [
        // 1. Dato Header (Man 18)
        Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          child: Column(
            children: [
              Text(DateFormat('EEEE').format(date).toUpperCase(), style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: isSelectedDay && DateUtils.isSameDay(date, DateTime.now()) 
                  ? const BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle) 
                  : null,
                child: Text(
                  "${date.day}", 
                  style: TextStyle(
                    fontSize: 20, 
                    fontWeight: FontWeight.bold,
                    color: (isSelectedDay && DateUtils.isSameDay(date, DateTime.now())) ? Colors.white : null
                  )
                ),
              ),
            ],
          ),
        ),
        
        // 2. Tidslinje Scroll
        Expanded(
          child: SingleChildScrollView(
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
                   if (DateUtils.isSameDay(date, DateTime.now()))
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