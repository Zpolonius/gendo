import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DateSelector extends StatelessWidget {
  final DateTime? selectedDate;
  final Function(DateTime?) onDateChanged;

  const DateSelector({
    super.key,
    required this.selectedDate,
    required this.onDateChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Vi bruger dansk locale til formateringen af teksten også
    final dateFormatter = DateFormat('dd/MM/yyyy', 'da_DK');

    // Tjek om datoen er i fortiden (før i dag ved midnat)
    bool isOverdue = false;
    if (selectedDate != null) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      // Hvis selectedDate er før i dag (kun dato sammenligning)
      if (selectedDate!.isBefore(today)) {
        isOverdue = true;
      }
    }

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
                // CTO NOTE: Vi bruger DateTime(2000) som start og DateTime(2100) som slut.
                // Vi sætter locale til 'da_DK' for at tvinge kalenderen til at starte på en Mandag.
                final picked = await showDatePicker(
                  context: context,
                  locale: const Locale('da', 'DK'), // <--- HER: Sætter dansk sprog og Mandag som start
                  initialDate: selectedDate ?? DateTime.now(),
                  firstDate: DateTime(2000), // Tillad historiske datoer
                  lastDate: DateTime(2100),  // Tillad datoer langt i fremtiden
                  builder: (context, child) {
                    // UI/UX: Tilpas kalenderens farver til temaet
                    return Theme(
                      data: theme.copyWith(
                        colorScheme: isDark 
                          ? const ColorScheme.dark(primary: Color(0xFF6C63FF), onPrimary: Colors.white, surface: Color(0xFF1E1E2C))
                          : const ColorScheme.light(primary: Color(0xFF6C63FF), onPrimary: Colors.white, surface: Colors.white),
                      ),
                      child: child!,
                    );
                  },
                );
                if (picked != null) {
                  // Vi sætter tiden til kl 23:59:59 for den valgte dag, 
                  // så den ikke står som "forfalden" midt på dagen.
                  final endOfDay = DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
                  onDateChanged(endOfDay);
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  // UI/UX: Hvis datoen er overskredet, giver vi den en rødlig kant
                  border: Border.all(
                    color: isOverdue 
                        ? Colors.redAccent.withOpacity(0.5) 
                        : (isDark ? Colors.white24 : Colors.grey.shade400)
                  ),
                  borderRadius: BorderRadius.circular(12),
                  color: isOverdue ? Colors.redAccent.withOpacity(0.05) : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.calendar_today, 
                      size: 16, 
                      color: isOverdue ? Colors.redAccent : theme.colorScheme.primary
                    ),
                    const SizedBox(width: 8),
                    Text(
                      selectedDate == null ? "Vælg dato" : dateFormatter.format(selectedDate!),
                      style: TextStyle(
                        color: selectedDate == null 
                            ? theme.colorScheme.onSurface.withOpacity(0.5) 
                            : (isOverdue ? Colors.redAccent : theme.colorScheme.onSurface),
                        fontWeight: isOverdue ? FontWeight.bold : FontWeight.normal,
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