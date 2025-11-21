import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DateSelector extends StatelessWidget {
  final DateTime? selectedDate;
  final Function(DateTime?) onDateChanged;

  const DateSelector({super.key, required this.selectedDate, required this.onDateChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dateFormatter = DateFormat('dd/MM/yyyy');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Deadline (Valgfri)", 
          style: TextStyle(
            fontSize: 12, 
            fontWeight: FontWeight.bold, 
            color: theme.colorScheme.onSurface.withOpacity(0.6)
          )
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: selectedDate ?? DateTime.now(),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                );
                if (picked != null) {
                  onDateChanged(picked);
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: isDark ? Colors.white24 : Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.calendar_today, size: 16, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      selectedDate == null ? "Vælg dato" : dateFormatter.format(selectedDate!),
                      style: TextStyle(
                        color: selectedDate == null 
                            ? theme.colorScheme.onSurface.withOpacity(0.5) 
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (selectedDate != null) ...[
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.clear, size: 20),
                onPressed: () => onDateChanged(null),
                tooltip: "Fjern dato",
              )
            ]
          ],
        ),
      ],
    );
  }
}