import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../viewmodels/calendar_viewmodel.dart';
import '../models.dart';

class MonthCalendarWidget extends StatefulWidget {
  final DateTime initialDate;
  final Function(DateTime) onDateSelected;

  const MonthCalendarWidget({
    super.key, 
    required this.initialDate,
    required this.onDateSelected,
  });

  @override
  State<MonthCalendarWidget> createState() => _MonthCalendarWidgetState();
}

class _MonthCalendarWidgetState extends State<MonthCalendarWidget> {
  late DateTime _focusedMonth;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _focusedMonth = widget.initialDate;
    // Vi bruger en høj start index ligesom i dagsvisningen for at kunne swipe tilbage
    _pageController = PageController(initialPage: 1000); 
  }

  @override
  void didUpdateWidget(covariant MonthCalendarWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!DateUtils.isSameMonth(widget.initialDate, _focusedMonth)) {
        // Hvis udefra kommende dato ændrer sig markant (ny måned), opdaterer vi viewet
        // Det er komplekst at synke PageView perfekt her uden at genberegne index, 
        // så for nu lader vi brugeren styre måneden internt i denne widget, 
        // medmindre vi implementerer fuld state-sync.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        _buildWeekDays(context),
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              final diff = index - 1000;
              setState(() {
                _focusedMonth = DateTime(
                  widget.initialDate.year, 
                  widget.initialDate.month + diff, 
                  1
                );
              });
            },
            itemBuilder: (context, index) {
              final diff = index - 1000;
              final monthDate = DateTime(
                widget.initialDate.year, 
                widget.initialDate.month + diff, 
                1
              );
              return _MonthGrid(
                month: monthDate, 
                onDateTap: widget.onDateSelected
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut),
          ),
          Text(
            DateFormat('MMMM yyyy').format(_focusedMonth).toUpperCase(),
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekDays(BuildContext context) {
    final weekDays = ['M', 'T', 'O', 'T', 'F', 'L', 'S'];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: weekDays.map((d) => Text(d, style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).disabledColor))).toList(),
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  final DateTime month;
  final Function(DateTime) onDateTap;

  const _MonthGrid({required this.month, required this.onDateTap});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CalendarViewModel>();
    
    // Beregn dage
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    final firstDayOfMonth = DateTime(month.year, month.month, 1);
    final int weekdayOffset = firstDayOfMonth.weekday - 1; // Man=1 -> index 0

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 0.8,
      ),
      itemCount: daysInMonth + weekdayOffset,
      itemBuilder: (context, index) {
        if (index < weekdayOffset) {
          return const SizedBox.shrink(); // Tomme pladser før d. 1.
        }
        
        final day = index - weekdayOffset + 1;
        final date = DateTime(month.year, month.month, day);
        final isToday = DateUtils.isSameDay(date, DateTime.now());
        
        final entries = vm.getEntriesForDate(date);

        return InkWell(
          onTap: () => onDateTap(date),
          borderRadius: BorderRadius.circular(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 30, height: 30,
                alignment: Alignment.center,
                decoration: isToday ? const BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle) : null,
                child: Text(
                  "$day",
                  style: TextStyle(
                    color: isToday ? Colors.white : Theme.of(context).colorScheme.onSurface,
                    fontWeight: isToday ? FontWeight.bold : FontWeight.normal
                  ),
                ),
              ),
              const SizedBox(height: 4),
              // Dots indikatorer
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: entries.take(3).map((e) {
                   return Container(
                     width: 4, height: 4,
                     margin: const EdgeInsets.symmetric(horizontal: 1),
                     decoration: BoxDecoration(
                       color: e.isTask ? e.color.withOpacity(0.5) : e.color, // Task = lidt lysere
                       shape: e.isTask ? BoxShape.circle : BoxShape.rectangle, // Task = cirkel, Event = firkant (hvis vi vil)
                       borderRadius: e.isTask ? null : BorderRadius.circular(1),
                     ),
                   );
                }).toList(),
              )
            ],
          ),
        );
      },
    );
  }
}
