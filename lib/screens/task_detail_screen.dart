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
  // 1. Opret Controllere og FocusNodes til Inline Editing
  late TextEditingController _titleController;
  late TextEditingController _descController;
  final FocusNode _titleFocus = FocusNode();
  final FocusNode _descFocus = FocusNode();
  
  // Vi holder styr på midlertidige ændringer i state
  late TaskPriority _currentPriority;
  late DateTime? _currentDueDate;
  late String _currentListId;

  @override
  void initState() {
    super.initState();
    // Initialiser med data fra opgaven
    _titleController = TextEditingController(text: widget.initialTask.title);
    _descController = TextEditingController(text: widget.initialTask.description);
    _currentPriority = widget.initialTask.priority;
    _currentDueDate = widget.initialTask.dueDate;
    _currentListId = widget.initialTask.listId;

    // 2. Lyt på fokus-ændringer for at gemme automatisk ("Auto-save")
    _titleFocus.addListener(() {
      if (!_titleFocus.hasFocus) _saveChanges(context);
    });
    _descFocus.addListener(() {
      if (!_descFocus.hasFocus) _saveChanges(context);
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _titleFocus.dispose();
    _descFocus.dispose();
    super.dispose();
  }

  // 3. Hjælpefunktion til at gemme ændringer
  void _saveChanges(BuildContext context) {
    final vm = Provider.of<AppViewModel>(context, listen: false);
    
    // Find den aktuelle version af opgaven for at sikre vi ikke overskriver med gamle data
    // (Hvis den ikke findes i listen, bruger vi initialTask som fallback)
    TodoTask currentTask;
    try {
        currentTask = vm.allTasks.firstWhere((t) => t.id == widget.taskId);
    } catch (e) {
        currentTask = widget.initialTask;
    }

    final updatedTask = currentTask.copyWith(
      title: _titleController.text,
      description: _descController.text,
      priority: _currentPriority,
      dueDate: _currentDueDate,
      listId: _currentListId,
    );

    // Gem kun hvis der rent faktisk er ændringer
    if (updatedTask != currentTask) {
        vm.updateTaskDetails(updatedTask, oldListId: widget.initialTask.listId);
    }
  }

  // ... (Slet dialog og _getPriorityColor beholdes uændret)
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
    
    final task = vm.allTasks.firstWhere((t) => t.id == widget.taskId, orElse: () => widget.initialTask);
    
    // Opdater controllere hvis opgaven ændres udefra (f.eks. via sync) men KUN hvis vi ikke har fokus
    if (!_titleFocus.hasFocus && _titleController.text != task.title) {
        _titleController.text = task.title;
    }
    if (!_descFocus.hasFocus && _descController.text != task.description) {
        _descController.text = task.description;
    }

    String listName = "Ukendt liste";
    try {
      listName = vm.lists.firstWhere((l) => l.id == task.listId).title;
    } catch (e) { }

    return PopScope(
      // Sikr at vi gemmer, når brugeren trykker "Tilbage" på telefonen (Android gesture)
      canPop: true,
      onPopInvoked: (didPop) {
        if (didPop) _saveChanges(context);
      },
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () {
             _saveChanges(context); // Gem også ved pil-tilbage klik
             Navigator.pop(context);
          }),
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
            // "Slet" knap flyttet herop i stedet for Edit, da vi nu redigerer direkte
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent), 
              onPressed: () => _showDeleteDialog(context, vm),
            ), 
            const SizedBox(width: 16),
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
                    // --- TITEL FELT (Inline Edit) ---
                    TextField(
                      controller: _titleController,
                      focusNode: _titleFocus,
                      style: GoogleFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                        decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none, // Ingen kant, så det ligner tekst
                        hintText: "Opgavens titel...",
                        contentPadding: EdgeInsets.zero,
                      ),
                      maxLines: null,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) {
                          _titleFocus.unfocus(); // Gemmer via listeneren
                      },
                    ),
                    
                    const SizedBox(height: 10),
                    
                    // --- LISTE NAVN (Stadig read-only eller evt. dropdown) ---
                    // For simplicitet beholder vi den som info, men man kunne lave en DropdownButton her
                    Row(
                      children: [
                        Icon(Icons.list, size: 18, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Text(listName, style: TextStyle(fontSize: 14, color: Colors.grey[600], fontWeight: FontWeight.w500)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    
                    // --- PRIORITET (Klikbar) ---
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                              // Simpel cyklus gennem prioriteter ved tryk
                              setState(() {
                                  if (_currentPriority == TaskPriority.low) _currentPriority = TaskPriority.medium;
                                  else if (_currentPriority == TaskPriority.medium) _currentPriority = TaskPriority.high;
                                  else _currentPriority = TaskPriority.low;
                              });
                              _saveChanges(context); // Gem med det samme
                          },
                          child: Chip(
                            avatar: Icon(Icons.pending_actions_outlined, size: 16, color: _getPriorityColor(_currentPriority)),
                            label: Text(_currentPriority.name.toUpperCase()),
                            backgroundColor: _getPriorityColor(_currentPriority).withOpacity(0.1),
                            labelStyle: TextStyle(color: _getPriorityColor(_currentPriority), fontWeight: FontWeight.bold),
                            side: BorderSide.none,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text("(Tryk for at ændre)", style: TextStyle(fontSize: 10, color: Colors.grey)),
                      ],
                    ),
                    const SizedBox(height: 30),

                    // --- DATO (Klikbar) ---
                    InkWell(
                      onTap: () async {
                          final picked = await showDatePicker(
                              context: context,
                              initialDate: _currentDueDate ?? DateTime.now(),
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (picked != null) {
                              setState(() => _currentDueDate = picked);
                              _saveChanges(context);
                          }
                      },
                      child: Row(
                        children: [
                          Icon(Icons.calendar_month_outlined, color: _currentDueDate != null ? theme.colorScheme.primary : Colors.grey[500]),
                          const SizedBox(width: 10),
                          Text(
                            _currentDueDate != null 
                                ? "Deadline: ${dateFormatter.format(_currentDueDate!)}"
                                : "Sæt deadline",
                            style: TextStyle(
                                fontSize: 16, 
                                color: _currentDueDate != null ? theme.colorScheme.primary : Colors.grey[600],
                                fontWeight: _currentDueDate != null ? FontWeight.w600 : FontWeight.normal
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),

                    // --- NOTATER (Inline Edit) ---
                    Text("NOTATER", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[500], letterSpacing: 1.2)),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
                      ),
                      child: TextField(
                        controller: _descController,
                        focusNode: _descFocus,
                        style: TextStyle(fontSize: 16, height: 1.5, color: theme.colorScheme.onSurface.withOpacity(0.8)),
                        decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText: "Tryk her for at tilføje noter...",
                        ),
                        maxLines: null, // Gør at den vokser automatisk
                        keyboardType: TextInputType.multiline,
                      ),
                    ),
                    
                    const SizedBox(height: 100),
                  ],
                ),
              ),

              // ... (Gå i gang knap uændret) ...
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
      ),
    );
  }
}