import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models.dart';

class TaskCard extends StatelessWidget {
  final TodoTask task;
  final VoidCallback onTap;
  final VoidCallback onToggle;
  final bool compact;

  const TaskCard({
    super.key,
    required this.task, 
    required this.onTap, 
    required this.onToggle, 
    this.compact = false,
  });

  Color _getPriorityColor(TaskPriority p) {
    switch(p) {
      case TaskPriority.high: return Colors.redAccent;
      case TaskPriority.medium: return Colors.orangeAccent;
      case TaskPriority.low: return Colors.greenAccent;
    }
  }

  // NY HJÆLPEMETODE: Håndterer visning af dato og steps i subtitle
  Widget? _buildSubtitle(TodoTask task, DateFormat dateFormatter) {
    final hasDate = task.dueDate != null;
    // Vi tjekker om listen af steps eksisterer og ikke er tom
    final hasSteps = task.steps.isNotEmpty;

    // Hvis hverken dato eller steps findes, returner null (ingen subtitle)
    if (!hasDate && !hasSteps) return null;

    // Udregn antal færdige steps
    final completedSteps = task.steps.where((s) => s.isCompleted).length;

    return Padding(
      padding: const EdgeInsets.only(top: 4.0),
      child: Row(
        children: [
          // 1. Vis Dato hvis den findes
          if (hasDate) ...[
            Icon(Icons.calendar_today, size: 12, color: Colors.grey[500]),
            const SizedBox(width: 4),
            Text(
              dateFormatter.format(task.dueDate!),
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
          ],

          // 2. Vis mellemrum hvis vi har BÅDE dato og steps
          if (hasDate && hasSteps) const SizedBox(width: 12),

          // 3. Vis Steps indikator hvis steps findes
          if (hasSteps) ...[
            Icon(Icons.checklist_rtl_rounded, size: 14, color: Colors.grey[500]),
            const SizedBox(width: 4),
            Text(
              "$completedSteps/${task.steps.length}",
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dateFormatter = DateFormat('dd/MM');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: compact ? EdgeInsets.zero : const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: compact ? Colors.transparent : theme.colorScheme.surface,
          border: compact 
              ? Border(bottom: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade200))
              : Border.all(color: isDark ? Colors.white10 : Colors.transparent),
          borderRadius: compact ? BorderRadius.circular(0) : BorderRadius.circular(16),
          boxShadow: (!compact && !isDark) ? [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))] : [],
        ),
        child: ListTile(
          contentPadding: EdgeInsets.symmetric(horizontal: compact ? 8 : 16, vertical: compact ? 0 : 12),
          
          // LEADING: PRIORITETS INDIKATOR
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _getPriorityColor(task.priority).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.pending_actions_outlined, color: _getPriorityColor(task.priority), size: 20),
          ),

          title: Text(
            task.title, 
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: task.isCompleted ? Colors.grey : theme.colorScheme.onSurface,
              decoration: task.isCompleted ? TextDecoration.lineThrough : null,
            )
          ),
          
          // HER ER ÆNDRINGEN: Vi bruger nu vores hjælpemetode
          subtitle: _buildSubtitle(task, dateFormatter),
          
          // TRAILING: TJEKBOKS
          trailing: IconButton(
            icon: Icon(task.isCompleted ? Icons.check_circle : Icons.circle_outlined),
            color: task.isCompleted ? Colors.green : Colors.grey,
            onPressed: onToggle,
          ),
        ),
      ),
    );
  }
}