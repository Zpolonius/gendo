import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../viewmodels/calendar_viewmodel.dart';
// Note: We access CalendarEntry via the viewmodel file or need to export it. 
// Ideally models should be in their own file. Assuming CalendarEntry is in calendar_viewmodel or exposed.
// To be safe, we might need to import the file defining CalendarEntry if it's separate.
// Since I defined it IN calendar_viewmodel.dart in the previous step, I import that.

class CalendarItemWidget extends StatelessWidget {
  final CalendarEntry entry;
  final VoidCallback? onTap;

  const CalendarItemWidget({
    super.key,
    required this.entry,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isTask = entry.isTask;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: _getDecoration(isTask),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title Row
            Row(
              children: [
                if (isTask) ...[
                  // Task Indicator (Checkbox look)
                  Container(
                    width: 12, height: 12,
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: entry.color, width: 2),
                    ),
                  ),
                ],
                Expanded(
                  child: Text(
                    entry.title,
                    style: GoogleFonts.poppins(
                      color: isTask ? entry.color : Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            
            // Time (if tall enough)
            Flexible(
              child: Text(
                '${_formatTime(entry.start)} - ${_formatTime(entry.end)}',
                style: GoogleFonts.poppins(
                  color: isTask ? entry.color.withOpacity(0.8) : Colors.white.withOpacity(0.9),
                  fontWeight: FontWeight.w400,
                  fontSize: 9,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  BoxDecoration _getDecoration(bool isTask) {
    if (isTask) {
      // OUTLINE STYLE
      return BoxDecoration(
        color: entry.color.withOpacity(0.15), // Let baggrund
        border: Border.all(
          color: entry.color,
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(6),
      );
    } else {
      // SOLID STYLE
      return BoxDecoration(
        color: entry.color.withOpacity(0.9),
        borderRadius: BorderRadius.circular(6),
         boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 2,
            offset: const Offset(0, 2),
          ),
        ],
      );
    }
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}
