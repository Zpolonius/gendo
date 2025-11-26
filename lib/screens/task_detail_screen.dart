import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models.dart';
import '../viewmodel.dart';
import '../widgets/priority_selector.dart';
import '../widgets/date_selector.dart';
import '../widgets/repeat_selector.dart'; // NY IMPORT

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
    DateTime? selectedDate = currentTask.dueDate;
    TaskPriority selectedPriority = currentTask.priority;
    String selectedListId = currentTask.listId;
    TaskRepeat selectedRepeat = currentTask.repeat; // Load eksisterende værdi

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
                  
                  DropdownButtonFormField<String>(
                    value: selectedListId,
                    decoration: const InputDecoration(labelText: "Liste"),
                    items: vm.lists.map((list) => DropdownMenuItem(
                      value: list.id,
                      child: Text(list.title),
                    )).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => selectedListId = val);
                    },
                  ),
                  
                  const SizedBox(height: 15),
                  PrioritySelector(
                    initialPriority: selectedPriority,
                    onChanged: (val) => setState(() => selectedPriority = val),
                  ),
                  const SizedBox(height: 15),
                  
                  // Dato og Gentagelse
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: DateSelector(
                          selectedDate: selectedDate,
                          onDateChanged: (date) => setState(() => selectedDate = date),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: RepeatSelector(
                          initialRepeat: selectedRepeat,
                          onChanged: (val) => setState(() => selectedRepeat = val),
                        ),
                      ),
                    ],
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
                      description: descController.text,
                      dueDate: selectedDate,
                      priority: selectedPriority,
                      repeat: selectedRepeat, // Gemmer ny gentagelse
                      listId: selectedListId,
                    );
                    vm.updateTaskDetails(updatedTask, oldListId: currentTask.listId);
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

  void _showDeleteDialog(BuildContext context, AppViewModel vm) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Slet Opgave?"),
        content: const Text("Er du sikker på, at du vil slette denne opgave? Det kan ikke fortrydes."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Annuller")),
          TextButton(
            onPressed: () {
              vm.deleteTask(widget.taskId);
              Navigator.pop(ctx); 
              Navigator.pop(context);
            }, 
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Slet"),
          ),
        ],
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
    final isDark = theme.brightness == Brightness.dark;
    
    final dateFormatter = DateFormat('EEE, d MMM yyyy');
    final vm = context.watch<AppViewModel>();
    
    // Find opgaven - hvis slettet, brug initialTask for at undgå crash før pop
    final task = vm.allTasks.firstWhere((t) => t.id == widget.taskId, orElse: () => widget.initialTask);
    String listName = "Ukendt liste";
    try {
      listName = vm.lists.firstWhere((l) => l.id == task.listId).title;
    } catch (e) { }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        actions: [
          IconButton(
            tooltip: task.isCompleted ? "Genåbn opgave" : "Marker som færdig",
            icon: Icon(
              task.isCompleted ? Icons.check_circle : Icons.check_circle_outline,
              color: task.isCompleted ? Colors.green : Colors.grey,
              size: 28,
            ),
            onPressed: () => vm.toggleTask(task.id),
          ),
          const SizedBox(width: 8),
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
              child: const Text("LUK"),
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
                  if (task.isCompleted)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check, size: 16, color: Colors.green),
                          const SizedBox(width: 8),
                          Text("Udført", style: TextStyle(color: Colors.green[700], fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),

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
                          decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                          decorationColor: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  
                  Row(
                    children: [
                      Icon(Icons.list, size: 18, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Text(listName, style: TextStyle(fontSize: 14, color: Colors.grey[600], fontWeight: FontWeight.w500)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  Row(
                    children: [
                      Chip(
                        avatar: Icon(Icons.pending_actions_outlined, size: 16, color: _getPriorityColor(task.priority)),
                        label: Text(task.priority.name.toUpperCase()),
                        backgroundColor: _getPriorityColor(task.priority).withOpacity(0.1),
                        labelStyle: TextStyle(color: _getPriorityColor(task.priority), fontWeight: FontWeight.bold),
                        side: BorderSide.none,
                      ),
                      
                      // VIS GENTAGELSE CHIP HVIS AKTIV
                      if (task.repeat != TaskRepeat.never) ...[
                        const SizedBox(width: 8),
                        Chip(
                          avatar: const Icon(Icons.repeat, size: 16, color: Colors.blue),
                          label: Text(_getRepeatText(task.repeat)),
                          backgroundColor: Colors.blue.withOpacity(0.1),
                          labelStyle: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
                          side: BorderSide.none,
                        ),
                      ]
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

  String _getRepeatText(TaskRepeat r) {
    switch(r) {
      case TaskRepeat.daily: return "DAGLIGT";
      case TaskRepeat.weekly: return "UGENTLIGT";
      case TaskRepeat.monthly: return "MÅNEDLIGT";
      default: return "";
    }
  }
}