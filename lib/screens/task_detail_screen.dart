import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models.dart';
import '../viewmodel.dart';
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
  late TextEditingController _titleController;
  late TextEditingController _notesController;
  final FocusNode _titleFocus = FocusNode();
  final FocusNode _notesFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTask.title);
    _notesController = TextEditingController(text: widget.initialTask.description);

    _titleFocus.addListener(() {
      if (!_titleFocus.hasFocus) {
        _saveTitle();
      }
    });

    _notesFocus.addListener(() {
      if (!_notesFocus.hasFocus) {
        _saveNotes();
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    _titleFocus.dispose();
    _notesFocus.dispose();
    super.dispose();
  }

  void _saveTitle() {
    if (!mounted) return;
    final vm = context.read<AppViewModel>();
    final task = _getTask(vm);
    if (task.title != _titleController.text && _titleController.text.isNotEmpty) {
      vm.updateTaskDetails(task.copyWith(title: _titleController.text));
    }
  }

  void _saveNotes() {
    if (!mounted) return;
    final vm = context.read<AppViewModel>();
    final task = _getTask(vm);
    if (task.description != _notesController.text) {
      vm.updateTaskDetails(task.copyWith(description: _notesController.text));
    }
  }

  TodoTask _getTask(AppViewModel vm) {
    return vm.allTasks.firstWhere((t) => t.id == widget.taskId, orElse: () => widget.initialTask);
  }

  Color _getPriorityColor(TaskPriority p) {
    switch(p) {
      case TaskPriority.high: return Colors.redAccent;
      case TaskPriority.medium: return Colors.orangeAccent;
      case TaskPriority.low: return Colors.greenAccent;
    }
  }

  // --- NY HJÆLPEFUNKTION: Tekst til TaskRepeat ---
  String _getRepeatText(TaskRepeat repeat) {
    switch (repeat) {
      case TaskRepeat.never: return "Ingen gentagelse";
      case TaskRepeat.daily: return "Hver dag";
      case TaskRepeat.weekly: return "Hver uge";
      case TaskRepeat.monthly: return "Hver måned";
    }
  }

  void _changeList(BuildContext context, AppViewModel vm, TodoTask task) async {
    final primaryColor = Theme.of(context).colorScheme.primary;
    
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Flyt til liste", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              ...vm.lists.map((list) => ListTile(
                leading: Icon(Icons.list, color: list.id == task.listId ? primaryColor : Colors.grey),
                title: Text(list.title),
                trailing: list.id == task.listId ? const Icon(Icons.check, color: Colors.green) : null,
                onTap: () {
                  if (list.id != task.listId) {
                    vm.updateTaskDetails(task.copyWith(listId: list.id), oldListId: task.listId);
                  }
                  Navigator.pop(ctx);
                },
              )),
            ],
          ),
        );
      }
    );
  }

  void _changePriority(BuildContext context, AppViewModel vm, TodoTask task) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Vælg Prioritet", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              ...TaskPriority.values.map((p) => ListTile(
                leading: Icon(Icons.flag, color: _getPriorityColor(p)),
                title: Text(p.name.toUpperCase()),
                trailing: p == task.priority ? const Icon(Icons.check, color: Colors.green) : null,
                onTap: () {
                  vm.updateTaskDetails(task.copyWith(priority: p));
                  Navigator.pop(ctx);
                },
              )),
            ],
          ),
        );
      }
    );
  }

  // --- NY FUNKTION: Ændre TaskRepeat ---
  void _changeRepeat(BuildContext context, AppViewModel vm, TodoTask task) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Gentagelse", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              ...TaskRepeat.values.map((r) => ListTile(
                leading: Icon(
                  Icons.repeat, 
                  color: r == task.repeat ? Theme.of(context).colorScheme.primary : Colors.grey
                ),
                title: Text(_getRepeatText(r)),
                trailing: r == task.repeat ? const Icon(Icons.check, color: Colors.green) : null,
                onTap: () {
                  // Opdaterer task med den nye 'repeat' værdi
                  vm.updateTaskDetails(task.copyWith(repeat: r));
                  Navigator.pop(ctx);
                },
              )),
            ],
          ),
        );
      }
    );
  }

  void _changeDate(BuildContext context, AppViewModel vm, TodoTask task) async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: task.dueDate ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 2)),
    );

    if (pickedDate != null) {
      vm.updateTaskDetails(task.copyWith(dueDate: pickedDate));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final dateFormatter = DateFormat('EEE, d MMM yyyy');
    final vm = context.watch<AppViewModel>();
    
    final task = _getTask(vm);
    
    if (!_titleFocus.hasFocus && _titleController.text != task.title) {
      _titleController.text = task.title;
    }
    if (!_notesFocus.hasFocus && _notesController.text != task.description) {
      _notesController.text = task.description;
    }

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

                  // --- TITEL ---
                  Hero(
                    tag: 'task_${task.id}',
                    child: Material(
                      type: MaterialType.transparency,
                      child: TextFormField(
                        controller: _titleController,
                        focusNode: _titleFocus,
                        style: GoogleFonts.poppins(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                          decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                          decorationColor: Colors.grey,
                        ),
                        decoration: const InputDecoration.collapsed(
                          hintText: "Opgavetitel",
                        ),
                        maxLines: null,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) {
                          _titleFocus.unfocus();
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  
                  // --- LISTE ---
                  InkWell(
                    onTap: () => _changeList(context, vm, task),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.list, size: 18, color: Colors.grey[600]),
                          const SizedBox(width: 8),
                          Text(listName, style: TextStyle(fontSize: 14, color: Colors.grey[600], fontWeight: FontWeight.w500)),
                          const SizedBox(width: 4),
                          Icon(Icons.arrow_drop_down, size: 18, color: Colors.grey[600]), 
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // --- PRIORITET ---
                  Row(
                    children: [
                      InkWell(
                        onTap: () => _changePriority(context, vm, task),
                        borderRadius: BorderRadius.circular(20),
                        child: Chip(
                          avatar: Icon(Icons.pending_actions_outlined, size: 16, color: _getPriorityColor(task.priority)),
                          label: Text(task.priority.name.toUpperCase()),
                          backgroundColor: _getPriorityColor(task.priority).withOpacity(0.1),
                          labelStyle: TextStyle(color: _getPriorityColor(task.priority), fontWeight: FontWeight.bold),
                          side: BorderSide.none,
                          deleteIcon: const Icon(Icons.arrow_drop_down, size: 18), 
                          onDeleted: () => _changePriority(context, vm, task), 
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),

                  // --- DEADLINE ---
                  InkWell(
                    onTap: () => _changeDate(context, vm, task),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_month_outlined, color: Colors.grey[500]),
                          const SizedBox(width: 10),
                          Text(
                            task.dueDate != null 
                              ? "Deadline: ${dateFormatter.format(task.dueDate!)}"
                              : "Sæt deadline",
                            style: TextStyle(
                              fontSize: 16, 
                              color: task.dueDate != null ? Colors.grey[600] : theme.colorScheme.primary
                            ),
                          ),
                          if (task.dueDate == null) ...[
                             const SizedBox(width: 4),
                             Icon(Icons.add_circle_outline, size: 16, color: theme.colorScheme.primary),
                          ]
                        ],
                      ),
                    ),
                  ),
                  
                  // --- GENTAGELSE (REPEAT) - IMPLEMENTERET MED TaskRepeat ---
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () => _changeRepeat(context, vm, task),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        children: [
                          Icon(
                            Icons.repeat, 
                            color: task.repeat != TaskRepeat.never ? theme.colorScheme.primary : Colors.grey[500]
                          ),
                          const SizedBox(width: 10),
                          Text(
                            task.repeat != TaskRepeat.never
                              ? _getRepeatText(task.repeat)
                              : "Tilføj gentagelse",
                            style: TextStyle(
                              fontSize: 16, 
                              color: task.repeat != TaskRepeat.never ? theme.colorScheme.primary : Colors.grey[600]
                            ),
                          ),
                           if (task.repeat == TaskRepeat.never) ...[
                             const SizedBox(width: 4),
                             Icon(Icons.add_circle_outline, size: 16, color: theme.colorScheme.primary),
                          ]
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // --- NOTATER ---
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
                    child: TextFormField(
                      controller: _notesController,
                      focusNode: _notesFocus,
                      style: TextStyle(fontSize: 16, height: 1.5, color: theme.colorScheme.onSurface.withOpacity(0.8)),
                      decoration: const InputDecoration.collapsed(
                        hintText: "Tryk her for at tilføje noter...",
                      ),
                      maxLines: null, 
                      keyboardType: TextInputType.multiline,
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