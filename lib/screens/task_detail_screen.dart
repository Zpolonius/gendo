import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models.dart';
import '../viewmodel.dart';
import '../widgets/category_selector.dart';
import '../widgets/priority_selector.dart';
import '../widgets/date_selector.dart';

class TaskDetailScreen extends StatefulWidget {
  final String taskId;
  final TodoTask initialTask;
  final VoidCallback onStartTask;

  const TaskDetailScreen({super.key, required this.taskId, required this.initialTask, required this.onStartTask});

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  
  void _showEditDialog(BuildContext context, AppViewModel vm, TodoTask currentTask) {
    final titleController = TextEditingController(text: currentTask.title);
    final descController = TextEditingController(text: currentTask.description);
    String selectedCategory = currentTask.category;
    DateTime? selectedDate = currentTask.dueDate;
    TaskPriority selectedPriority = currentTask.priority;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text("Rediger Opgave"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: "Titel"),
                  ),
                  const SizedBox(height: 15),
                  CategorySelector(
                    initialCategory: selectedCategory,
                    onChanged: (val) => selectedCategory = val,
                  ),
                  const SizedBox(height: 15),
                  PrioritySelector(
                    initialPriority: selectedPriority,
                    onChanged: (val) => setState(() => selectedPriority = val),
                  ),
                  const SizedBox(height: 15),
                  DateSelector(
                    selectedDate: selectedDate,
                    onDateChanged: (date) => setState(() => selectedDate = date),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: descController,
                    decoration: const InputDecoration(labelText: "Noter/Beskrivelse"),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Annuller")),
              ElevatedButton(
                onPressed: () {
                  if (titleController.text.isNotEmpty) {
                    final updatedTask = currentTask.copyWith(
                      title: titleController.text,
                      category: selectedCategory,
                      description: descController.text,
                      dueDate: selectedDate,
                      priority: selectedPriority,
                    );
                    vm.updateTaskDetails(updatedTask);
                    Navigator.pop(ctx);
                  }
                },
                child: const Text("Gem"),
              ),
            ],
          );
        }
      ),
    );
  }

  Color _getPriorityColor(TaskPriority p) {
    switch(p) {
      case TaskPriority.high: return Colors.redAccent;
      case TaskPriority.medium: return Colors.orangeAccent;
      case TaskPriority.low: return Colors.greenAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dateFormatter = DateFormat('EEE, d MMM yyyy');
    
    final vm = context.watch<AppViewModel>();
    // Fallback til initialTask hvis opgaven slettes
    final task = vm.tasks.firstWhere((t) => t.id == widget.taskId, orElse: () => widget.initialTask);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined), 
            onPressed: () => _showEditDialog(context, vm, task)
          ), 
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.primary,
                textStyle: const TextStyle(fontWeight: FontWeight.bold),
              ),
              child: const Text("GEM"),
            ),
          )
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Hero(
                    tag: 'task_${task.id}',
                    child: Material(
                      type: MaterialType.transparency,
                      child: Text(
                        task.title,
                        style: GoogleFonts.poppins(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  Row(
                    children: [
                      Chip(
                        label: Text(task.category),
                        backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                        labelStyle: TextStyle(color: theme.colorScheme.primary),
                        side: BorderSide.none,
                      ),
                      const SizedBox(width: 10),
                      Chip(
                        avatar: Icon(Icons.flag, size: 16, color: _getPriorityColor(task.priority)),
                        label: Text(task.priority.name.toUpperCase()),
                        backgroundColor: _getPriorityColor(task.priority).withOpacity(0.1),
                        labelStyle: TextStyle(color: _getPriorityColor(task.priority), fontWeight: FontWeight.bold),
                        side: BorderSide.none,
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),

                  if (task.dueDate != null) ...[
                    Row(
                      children: [
                        Icon(Icons.calendar_month_outlined, color: Colors.grey[500]),
                        const SizedBox(width: 10),
                        Text(
                          "Deadline: ${dateFormatter.format(task.dueDate!)}",
                          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),
                  ],

                  Text("NOTATER", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[500], letterSpacing: 1.2)),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
                    ),
                    child: Text(
                      task.description.isEmpty ? "Ingen noter tilføjet." : task.description,
                      style: TextStyle(fontSize: 16, height: 1.5, color: theme.colorScheme.onSurface.withOpacity(0.8)),
                    ),
                  ),
                  
                  const SizedBox(height: 100),
                ],
              ),
            ),

            Positioned(
              left: 24,
              right: 24,
              bottom: 24,
              child: SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton.icon(
                  onPressed: widget.onStartTask,
                  icon: const Icon(Icons.play_arrow_rounded, size: 28),
                  label: const Text("GÅ I GANG", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    elevation: 5,
                    shadowColor: theme.colorScheme.primary.withOpacity(0.4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}