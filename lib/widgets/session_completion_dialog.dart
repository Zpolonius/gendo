import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import '../models.dart'; // Sikrer adgang til TodoTask copyWith
import '../viewmodels/app_view_model.dart';

class SessionCompletionDialog extends StatefulWidget {
  final AppViewModel vm;

  const SessionCompletionDialog({super.key, required this.vm});

  @override
  State<SessionCompletionDialog> createState() => _SessionCompletionDialogState();
}

class _SessionCompletionDialogState extends State<SessionCompletionDialog> {
  late ConfettiController _confettiController;
  final TextEditingController _stepController = TextEditingController();
  
  // Bruges kun til opgaver UDEN steps
  bool _manualCompletionStatus = false;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));
    
    if (widget.vm.selectedTaskObj != null) {
      _manualCompletionStatus = widget.vm.selectedTaskObj!.isCompleted;
    }
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _stepController.dispose();
    super.dispose();
  }

  void _triggerConfetti() {
    _confettiController.play();
  }

  /// Håndterer "Vælg alle" funktionalitet
  void _toggleAllSteps(bool makeAllCompleted, TodoTask task) {
    // 1. Opret opdaterede steps
    final updatedSteps = task.steps.map((step) {
      return step.copyWith(isCompleted: makeAllCompleted);
    }).toList();

    // 2. Opret opdateret task objekt
    final updatedTask = task.copyWith(
      isCompleted: makeAllCompleted,
      steps: updatedSteps
    );

    // 3. Send én samlet opdatering til ViewModel (Optimistic Update sker automatisk i VM)
    widget.vm.updateTaskDetails(updatedTask);

    // 4. Feedback
    if (makeAllCompleted) {
      _triggerConfetti();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final task = widget.vm.selectedTaskObj;
    final breaksEnabled = widget.vm.pomodoroSettings.enableBreaks;

    // Logik: Er opgaven færdig?
    bool isTaskDone = _manualCompletionStatus;
    bool hasSteps = task != null && task.steps.isNotEmpty;

    if (hasSteps) {
      // Hvis vi har steps, styres status 100% af om alle steps er done
      isTaskDone = task!.steps.every((s) => s.isCompleted);
    }

    // SCENARIE 1: Ingen valgt opgave
    if (task == null) {
      return AlertDialog(
        title: const Text("Godt arbejde!"),
        content: Text(breaksEnabled 
          ? "Tiden er gået. Er du klar til en pause?" 
          : "Sessionen er slut. Klar til den næste?"
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Luk"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Ja, videre"),
          ),
        ],
      );
    }

    // SCENARIE 2: Opgave valgt
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        AlertDialog(
          title: Text("Session slut: ${task.title}", style: const TextStyle(fontSize: 18)),
          scrollable: true,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Hvor langt nåede du?", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),

              // --- STEPS LISTE ---
              if (!hasSteps)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Text("Ingen delopgaver. Tilføj en nedenfor, hvis du vil logge fremskridt.", 
                    style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12, color: Colors.grey)),
                )
              else
                ...task.steps.map((step) => CheckboxListTile(
                  title: Text(
                    step.title,
                    style: TextStyle(
                      decoration: step.isCompleted ? TextDecoration.lineThrough : null,
                      color: step.isCompleted ? Colors.grey : null,
                      fontSize: 14,
                    ),
                  ),
                  value: step.isCompleted,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  onChanged: (val) async {
                    final allStepsNowDone = await widget.vm.toggleTaskStep(task.id, step.id);
                    if (allStepsNowDone) {
                       _triggerConfetti();
                    }
                    setState(() {});
                  },
                )),

              const SizedBox(height: 10),

              // --- QUICK ADD STEP ---
              TextField(
                controller: _stepController,
                decoration: InputDecoration(
                  hintText: "+ Tilføj det, du nåede...",
                  hintStyle: const TextStyle(fontSize: 13),
                  isDense: true,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.add, size: 20),
                    onPressed: () {
                      if (_stepController.text.isNotEmpty) {
                        widget.vm.addTaskStep(task.id, _stepController.text);
                        _stepController.clear();
                        setState(() {});
                      }
                    },
                  ),
                ),
                onSubmitted: (val) {
                  if (val.isNotEmpty) {
                    widget.vm.addTaskStep(task.id, val);
                    _stepController.clear();
                    setState(() {});
                  }
                },
              ),
              
              const SizedBox(height: 20),
              
              // --- COMPLETE TASK CHECKBOX (NU MED "VÆLG ALLE" LOGIK) ---
              Container(
                decoration: BoxDecoration(
                  color: isTaskDone ? Colors.green.withOpacity(0.1) : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                  border: isTaskDone ? Border.all(color: Colors.green) : null,
                ),
                child: CheckboxListTile(
                  title: const Text("Hele opgaven er færdig!", style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: hasSteps 
                    ? const Text("Markerer alle delopgaver som udført", style: TextStyle(fontSize: 10, color: Colors.grey)) 
                    : null,
                  value: isTaskDone,
                  activeColor: Colors.green,
                  onChanged: (val) {
                    bool newValue = val ?? false;
                    
                    if (hasSteps) {
                      // 1. Bulk update af alle steps
                      _toggleAllSteps(newValue, task);
                    } else {
                      // 2. Manuel update (hvis ingen steps)
                      setState(() {
                        _manualCompletionStatus = newValue;
                      });
                      if (newValue) _triggerConfetti();
                    }
                  },
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, isTaskDone);
              },
              child: const Text("Luk"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, isTaskDone);
              },
              child: const Text("Videre"),
            ),
          ],
        ),
        
        Padding(
          padding: const EdgeInsets.only(top: 20),
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            colors: const [Colors.green, Colors.blue, Colors.pink, Colors.orange, Colors.purple],
          ),
        ),
      ],
    );
  }
}