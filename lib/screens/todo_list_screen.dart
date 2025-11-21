import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models.dart';
import '../viewmodel.dart';
import 'task_detail_screen.dart';
import '../widgets/category_selector.dart';
import '../widgets/priority_selector.dart';
import '../widgets/date_selector.dart';

class TodoListScreen extends StatelessWidget {
  final Function(int) onSwitchTab; 
  
  const TodoListScreen({super.key, required this.onSwitchTab});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AppViewModel>();
    final theme = Theme.of(context);

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        heroTag: 'add_task_btn',
        onPressed: () => _showAddDialog(context, vm),
        backgroundColor: theme.colorScheme.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: vm.tasks.isEmpty 
        ? Center(child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.checklist_rtl_rounded, size: 64, color: Colors.grey[300]),
              const SizedBox(height: 16),
              Text("Ingen opgaver endnu", style: TextStyle(color: Colors.grey[500])),
            ],
          ))
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: vm.tasks.length,
            itemBuilder: (ctx, i) {
              final task = vm.tasks[i];
              return TaskCard(
                task: task, 
                onTap: () => _openTaskDetail(context, task, vm),
                onToggle: () => vm.toggleTask(task.id),
                onDelete: () => vm.deleteTask(task.id),
              );
            },
          ),
    );
  }

  void _openTaskDetail(BuildContext context, TodoTask task, AppViewModel vm) {
    Navigator.push(
      context, 
      MaterialPageRoute(
        builder: (_) => TaskDetailScreen(
          taskId: task.id, 
          initialTask: task,
          onStartTask: () {
            vm.setSelectedTask(task.id);
            Navigator.pop(context);
            onSwitchTab(0); 
          },
        )
      )
    );
  }

  void _showAddDialog(BuildContext context, AppViewModel vm) {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    String selectedCategory = 'Generelt';
    DateTime? selectedDate;
    TaskPriority selectedPriority = TaskPriority.medium;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder( 
        builder: (context, setState) {
          return AlertDialog(
            title: const Text("Ny Opgave"),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: titleController, 
                    autofocus: true,
                    decoration: const InputDecoration(labelText: "Titel", hintText: "Hvad skal laves?"),
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
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuller")),
              ElevatedButton(onPressed: () {
                if (titleController.text.isNotEmpty) {
                  vm.addTask(
                    titleController.text,
                    category: selectedCategory,
                    description: descController.text,
                    dueDate: selectedDate, 
                    priority: selectedPriority,
                  );
                  Navigator.pop(context);
                }
              }, child: const Text("Tilføj")),
            ],
          );
        }
      ),
    );
  }
}

class TaskCard extends StatelessWidget {
  final TodoTask task;
  final VoidCallback onTap;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const TaskCard({
    super.key,
    required this.task, 
    required this.onTap, 
    required this.onToggle, 
    required this.onDelete
  });

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
    final dateFormatter = DateFormat('dd/MM');

    return GestureDetector(
      onTap: onTap,
      child: Hero(
        tag: 'task_${task.id}',
        child: Material(
          type: MaterialType.transparency,
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? Colors.white10 : Colors.transparent),
              boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              leading: IconButton(
                icon: Icon(task.isCompleted ? Icons.check_circle : Icons.circle_outlined),
                color: task.isCompleted ? Colors.green : Colors.grey,
                onPressed: onToggle,
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
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getPriorityColor(task.priority).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          task.priority.name.toUpperCase(),
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _getPriorityColor(task.priority)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(task.category, style: TextStyle(fontSize: 12, color: theme.colorScheme.primary.withOpacity(0.7))),
                      if (task.dueDate != null) ...[
                        const Spacer(),
                        Icon(Icons.calendar_today, size: 12, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Text(
                          dateFormatter.format(task.dueDate!),
                          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                        ),
                      ]
                    ],
                  ),
                ],
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                onPressed: onDelete,
              ),
            ),
          ),
        ),
      ),
    );
  }
}