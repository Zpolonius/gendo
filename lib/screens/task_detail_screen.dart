import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:confetti/confetti.dart'; 
import '../models.dart';
import '../viewmodel.dart';


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
  
  // Confetti Controller
  late ConfettiController _confettiController;
  
  // Vi holder styr på midlertidige ændringer i state
  late TaskPriority _currentPriority;
  late DateTime? _currentDueDate;
  late String _currentListId;

  @override
  void initState() {
    super.initState();
    // Initialiser Confetti
    _confettiController = ConfettiController(duration: const Duration(seconds: 1));

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
    _confettiController.dispose();
    super.dispose();
  }

  // 3. Hjælpefunktion til at gemme ændringer
  void _saveChanges(BuildContext context) {
    final vm = Provider.of<AppViewModel>(context, listen: false);
    
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

    if (updatedTask != currentTask) {
        vm.updateTaskDetails(updatedTask, oldListId: widget.initialTask.listId);
    }
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

  // Dialog til at tilføje et nyt step
  void _showAddStepDialog(BuildContext context, AppViewModel vm, TodoTask task) {
    final stepController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Ny Delopgave"),
        content: TextField(
          controller: stepController,
          autofocus: true,
          decoration: const InputDecoration(hintText: "Hvad skal gøres?"),
          onSubmitted: (_) {
             // Tillad at trykke 'Enter' for at gemme
             if (stepController.text.isNotEmpty) {
                final newStep = TaskStep(
                  id: DateTime.now().millisecondsSinceEpoch.toString(), 
                  title: stepController.text
                );
                final updatedTask = task.copyWith(steps: [...task.steps, newStep]);
                vm.updateTaskDetails(updatedTask);
                Navigator.pop(ctx);
             }
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Annuller")),
          ElevatedButton(
            onPressed: () {
              if (stepController.text.isNotEmpty) {
                final newStep = TaskStep(
                  id: DateTime.now().millisecondsSinceEpoch.toString(), 
                  title: stepController.text
                );
                final updatedTask = task.copyWith(steps: [...task.steps, newStep]);
                vm.updateTaskDetails(updatedTask);
                Navigator.pop(ctx);
              }
            }, 
            child: const Text("Tilføj")
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
    
    // Hent task (safe)
    final task = vm.allTasks.firstWhere((t) => t.id == widget.taskId, orElse: () => widget.initialTask);
    
    // Beregn Progress for Steps
    int totalSteps = task.steps.length;
    int completedSteps = task.steps.where((s) => s.isCompleted).length;
    double progress = totalSteps == 0 ? 0 : completedSteps / totalSteps;

    // Opdater controllere hvis opgaven ændres udefra men KUN hvis vi ikke har fokus
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
      canPop: true,
      onPopInvoked: (didPop) {
        if (didPop) _saveChanges(context);
      },
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () {
             _saveChanges(context); 
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
              onPressed: () {
                 if (!task.isCompleted) _confettiController.play(); // Fest hvis man færdiggør hele opgaven
                 vm.toggleTask(task.id);
              },
            ),
            const SizedBox(width: 8),
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
              // --- HOVEDINDHOLD ---
              SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // TITEL
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
                        border: InputBorder.none, 
                        hintText: "Opgavens titel...",
                        contentPadding: EdgeInsets.zero,
                      ),
                      maxLines: null,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _titleFocus.unfocus(),
                    ),
                    
                    const SizedBox(height: 10),
                    
                    // LISTE INFO
                    Row(
                      children: [
                        Icon(Icons.list, size: 18, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Text(listName, style: TextStyle(fontSize: 14, color: Colors.grey[600], fontWeight: FontWeight.w500)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    
                    // PRIORITET
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                              setState(() {
                                  if (_currentPriority == TaskPriority.low) _currentPriority = TaskPriority.medium;
                                  else if (_currentPriority == TaskPriority.medium) _currentPriority = TaskPriority.high;
                                  else _currentPriority = TaskPriority.low;
                              });
                              _saveChanges(context);
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

                    // DATO
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

                    // NOTATER
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
                        maxLines: null, 
                        keyboardType: TextInputType.multiline,
                      ),
                    ),
                    
                    const SizedBox(height: 30),

                    // --- STEPS / DELOPGAVER SECTION ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("DELOPGAVER", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[500], letterSpacing: 1.2)),
                        if (totalSteps > 0)
                          Text("$completedSteps / $totalSteps", style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Progress Bar (Grøn)
                    if (totalSteps > 0) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                          // Ændret til altid at være grøn som ønsket
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.green), 
                          minHeight: 8,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Liste af Steps
                    ...task.steps.asMap().entries.map((entry) {
                      int index = entry.key;
                      TaskStep step = entry.value;
                      
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
                        ),
                        child: ListTile(
                          // Tjekboks til at fuldføre step
                          leading: Checkbox(
                            value: step.isCompleted,
                            activeColor: Colors.green,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                            onChanged: (val) {
                              if (val == null) return;
                              
                              List<TaskStep> newSteps = List.from(task.steps);
                              newSteps[index] = step.copyWith(isCompleted: val);
                              
                              // Check om ALLE er færdige nu -> Konfetti!
                              if (val == true && newSteps.every((s) => s.isCompleted)) {
                                  _confettiController.play();
                              }

                              final updatedTask = task.copyWith(steps: newSteps);
                              vm.updateTaskDetails(updatedTask);
                            },
                          ),
                          title: Text(
                            step.title,
                            style: TextStyle(
                              decoration: step.isCompleted ? TextDecoration.lineThrough : null,
                              color: step.isCompleted ? Colors.grey : theme.colorScheme.onSurface,
                            ),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                            onPressed: () {
                              List<TaskStep> newSteps = List.from(task.steps);
                              newSteps.removeAt(index);
                              vm.updateTaskDetails(task.copyWith(steps: newSteps));
                            },
                          ),
                        ),
                      );
                    }).toList(),

                    // Tilføj nyt step knap
                    InkWell(
                      onTap: () => _showAddStepDialog(context, vm, task),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.withOpacity(0.5), style: BorderStyle.solid),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add, size: 20, color: Colors.grey[600]),
                            const SizedBox(width: 8),
                            Text("Tilføj delopgave", style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 100),
                  ],
                ),
              ),

              // --- CONFETTI WIDGET ---
              // Placeret øverst i stacken så den tegnes ovenpå alt andet
              Align(
                alignment: Alignment.topCenter,
                child: ConfettiWidget(
                  confettiController: _confettiController,
                  blastDirectionality: BlastDirectionality.explosive, // Spreder sig til alle sider
                  shouldLoop: false, 
                  colors: const [Colors.green, Colors.blue, Colors.pink, Colors.orange, Colors.purple],
                ),
              ),

              // --- START KNAP ---
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