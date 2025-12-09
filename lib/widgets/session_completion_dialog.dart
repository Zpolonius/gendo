import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:confetti/confetti.dart';
import '../viewmodels/app_view_model.dart';

class SessionCompletionDialog extends StatefulWidget {
  final TodoTask task;
  final Function(TodoTask) onSave;
  final AppViewModel vm;

  const SessionCompletionDialog({super.key, required this.vm, required this.task, required this.onSave});

  @override
  State<SessionCompletionDialog> createState() => _SessionCompletionDialogState();
}

class _SessionCompletionDialogState extends State<SessionCompletionDialog> {
  late ConfettiController _confettiController;
  final TextEditingController _stepController = TextEditingController();
  bool _isTaskCompletedLocally = false;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));
    
    // Tjek om opgaven allerede var markeret som færdig
    if (widget.vm.selectedTaskObj != null) {
      _isTaskCompletedLocally = widget.vm.selectedTaskObj!.isCompleted;
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final task = widget.vm.selectedTaskObj;
    final breaksEnabled = widget.vm.pomodoroSettings.enableBreaks;

    // SCENARIE 1: Ingen valgt opgave (Simpel dialog)
    if (task == null) {
      return AlertDialog(
        title: const Text("Godt arbejde!"),
        content: Text(breaksEnabled 
          ? "Tiden er gået. Er du klar til en pause?" 
          : "Sessionen er slut. Klar til den næste?"
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context, false); // Returner false (ikke færdig/luk)
            },
            child: const Text("Luk"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context, true); // Returner true (videre)
            },
            child: const Text("Ja, videre"),
          ),
        ],
      );
    }

    // SCENARIE 2: Opgave valgt (Vis steps og muligheder)
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
              if (task.steps.isEmpty)
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
                    // Optimistic update via ViewModel
                    final allStepsDone = await widget.vm.toggleTaskStep(task.id, step.id);
                    if (allStepsDone || (val == true)) {
                       // Lille konfetti hvis man afslutter et step (valgfrit: kun ved alle steps)
                       _triggerConfetti();
                    }
                    setState(() {}); // Opdater UI
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
              
              // --- COMPLETE TASK CHECKBOX ---
              Container(
                decoration: BoxDecoration(
                  color: _isTaskCompletedLocally ? Colors.green.withOpacity(0.1) : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                  border: _isTaskCompletedLocally ? Border.all(color: Colors.green) : null,
                ),
                child: CheckboxListTile(
                  title: const Text("Hele opgaven er færdig!", style: TextStyle(fontWeight: FontWeight.bold)),
                  value: _isTaskCompletedLocally,
                  activeColor: Colors.green,
                  onChanged: (val) {
                    setState(() {
                      _isTaskCompletedLocally = val ?? false;
                    });
                    if (_isTaskCompletedLocally) {
                      _triggerConfetti();
                    }
                  },
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                // Brugeren er færdig med sessionen, men måske ikke opgaven
                Navigator.pop(context, _isTaskCompletedLocally);
              },
              child: const Text("Luk"),
            ),
            ElevatedButton(
              onPressed: () {
                // Bekræft valg og gå til pause/næste
                Navigator.pop(context, _isTaskCompletedLocally);
              },
              child: const Text("Videre"),
            ),
          ],
        ),
        
        // --- CONFETTI OVERLAY ---
        Padding(
          padding: const EdgeInsets.only(top: 20), // Juster så den ikke dækker titlen helt
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