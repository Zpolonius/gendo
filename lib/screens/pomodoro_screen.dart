import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:confetti/confetti.dart';

import '../viewmodel.dart';
import '../services/notification_service.dart'; 
import '../viewmodels/app_view_model.dart';

class PomodoroScreen extends StatefulWidget {
  const PomodoroScreen({super.key});

  @override
  State<PomodoroScreen> createState() => _PomodoroScreenState();
}

class _PomodoroScreenState extends State<PomodoroScreen> {
  late AppViewModel _vm;
  bool _isDialogShowing = false;

  //confetti controller til fuldført opgave

  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _vm = Provider.of<AppViewModel>(context, listen: false);
    _vm.addListener(_onVmChanged);
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));
  }

  @override
  void dispose() {
    _vm.removeListener(_onVmChanged);
    _confettiController.dispose();
    super.dispose();
  }

  void _onVmChanged() {
    if (_vm.timerStatus == TimerStatus.finishedWork && !_isDialogShowing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_isDialogShowing) {
          _showCompletionDialog(context, _vm);
        }
      });
    }
  }
  
  // ... (Resten af dialog metoderne er uændrede - kopier dem fra forrige version)
  void _showCompletionDialog(BuildContext context, AppViewModel vm) {
    setState(() => _isDialogShowing = true);
    final breaksEnabled = vm.pomodoroSettings.enableBreaks;
    //dialog ved tid gået, mulighed for at færdige gøre tid.
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text("Godt gået!"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Tiden er gået."),
            const SizedBox(height: 10),
            if (vm.selectedTaskId != null)
              Text("Blev du færdig med '${vm.selectedTaskObj?.title}'?", style: const TextStyle(fontWeight: FontWeight.bold)),
            if (vm.selectedTaskId == null && breaksEnabled)
               const Text("Er du klar til en pause?"),
            if (vm.selectedTaskId == null && !breaksEnabled)
               const Text("Klar til næste session?"),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              vm.completeWorkSession(false);
            },
            child: const Text("Nej"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (vm.selectedTaskId != null){
                _confettiController.play();
              }
              vm.completeWorkSession(true);
            },
            child: const Text("Ja, videre!"),
          ),
        ],
      ),
    ).then((_) {
      if (mounted) setState(() => _isDialogShowing = false);
    });
  }

  void _showNextTaskSelector(BuildContext context, AppViewModel vm) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))
      ),
      builder: (ctx) {
        final availableTasks = vm.allTasks.where((t) => !t.isCompleted).toList();
        
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Hvad vil du nu?", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 10),
              ListTile(
                leading: const Icon(Icons.coffee_outlined, color: Colors.brown),
                title: const Text("Tag en pause nu"),
                onTap: () {
                  vm.startBreak(5); 
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: const Icon(Icons.center_focus_strong, color: Colors.blueAccent),
                title: const Text("Fri fokus (Ingen opgave)"),
                subtitle: const Text("Fortsæt timeren uden en specifik opgave"),
                onTap: () {
                  vm.setSelectedTask(null);
                  Navigator.pop(ctx);
                },
              ),
              const Divider(),
              if (availableTasks.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text("Ingen flere opgaver på listen! 🎉", style: TextStyle(color: Colors.grey)),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: availableTasks.length,
                    itemBuilder: (ctx, i) {
                      final task = availableTasks[i];
                      return ListTile(
                        leading: const Icon(Icons.radio_button_unchecked, color: Colors.grey),
                        title: Text(task.title),
                        subtitle: Text(
                          vm.lists.firstWhere((l) => l.id == task.listId, orElse: () => vm.lists.first).title,
                          style: TextStyle(fontSize: 12, color: Colors.grey[600])
                        ),
                        onTap: () {
                          vm.setSelectedTask(task.id); 
                          Navigator.pop(ctx); 
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      }
    );
  }

  String _formatTime(int seconds) {
    final minutes = (seconds / 60).floor();
    final remSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remSeconds.toString().padLeft(2, '0')}';
  }

  // ... (Resten af build metoden)

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AppViewModel>();
    final theme = Theme.of(context);
    final isDark = vm.isDarkMode;
    
    final timerColor = vm.isOnBreak ? Colors.green[400] : theme.colorScheme.primary;
    final statusText = vm.isOnBreak 
        ? (vm.pomodoroDurationTotal > 600 ? "LANG PAUSE" : "PAUSE")
        : "FOKUS";

    final activeTasks = vm.allTasks.where((t) => !t.isCompleted).toList();

    String? validSelectedTaskId = vm.selectedTaskId;
    if (validSelectedTaskId != null && !activeTasks.any((t) => t.id == validSelectedTaskId)) {
      validSelectedTaskId = null;
    }

    return Stack(
      alignment: Alignment.topCenter,
      children: [
        SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 20),
      
            if (vm.isOnBreak) ...[
               Container(
                 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                 decoration: BoxDecoration(
                   color: Colors.green.withOpacity(0.1),
                   borderRadius: BorderRadius.circular(20),
                 ),
                 child: Text(statusText, style: TextStyle(color: Colors.green[700], fontWeight: FontWeight.bold, letterSpacing: 1.5)),
               ),
               const SizedBox(height: 20),
            ],
      
            SizedBox(
              height: 300,
              width: 300,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: vm.progress,
                    strokeWidth: 20,
                    backgroundColor: isDark ? Colors.white10 : Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(timerColor!),
                    strokeCap: StrokeCap.round,
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _formatTime(vm.pomodoroTimeLeft),
                        style: GoogleFonts.roboto(
                          fontSize: 64,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (!vm.isOnBreak && vm.selectedTaskObj != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(color: theme.colorScheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                          child: Text(vm.selectedTaskObj!.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 16, color: theme.colorScheme.primary, fontWeight: FontWeight.w600)),
                        )
                      else if (vm.isOnBreak)
                         Text("Træk vejret dybt...", style: TextStyle(color: Colors.green[700], fontWeight: FontWeight.w500)),
                      if (!vm.isOnBreak && vm.selectedTaskObj == null)
                        Text("Frit fokus", style: TextStyle(color: Colors.grey[500], fontSize: 16)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 60),
      
            // OPGAVE VÆLGER
            if (!vm.isTimerRunning && !vm.isOnBreak)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: validSelectedTaskId,
                    isExpanded: true,
                    itemHeight: null,
                    dropdownColor: theme.colorScheme.surface,
                    hint: Text("Vælg en opgave at fokusere på", style: TextStyle(color: Colors.grey[500])),
                    items: [
                      DropdownMenuItem(
                        value: null, 
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Text("Ingen specifik opgave", style: TextStyle(color: theme.colorScheme.onSurface)),
                        )
                      ),
                      ...activeTasks.map((task) {
                        String listName = "Ukendt liste";
                        try {
                          final list = vm.lists.firstWhere((l) => l.id == task.listId);
                          listName = list.title;
                        } catch (e) { }
      
                        return DropdownMenuItem(
                          value: task.id,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(task.title, style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
                                Text(listName, style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.5), fontSize: 12, fontStyle: FontStyle.italic)),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                    onChanged: (id) => vm.setSelectedTask(id),
                  ),
                ),
              ),
      
            const SizedBox(height: 40),
      
            // --- CONTROLS --- under timer
            Padding(
              padding: const EdgeInsets.only(bottom: 40, left: 24, right: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!vm.isOnBreak && vm.selectedTaskObj != null) 
                    FloatingActionButton(
                      heroTag: 'task_complete',
                      onPressed: () async {
                        _confettiController.play();
                         vm.completeWorkSession(true);
                        if (context.mounted) _showNextTaskSelector(context, vm);
                      },
                      backgroundColor: Colors.green, 
                      elevation: 2,
                      child: const Icon(Icons.check, color: Colors.white),
                    )
                  else if (!vm.isOnBreak)
                    const SizedBox(width: 56),
      
                  const SizedBox(width: 20),
      
                  // PLAY/PAUSE
                  if (!vm.isOnBreak)
                    FloatingActionButton.large(
                      heroTag: 'timer_control',
                      onPressed: () {
                        // UX: Spørg om tilladelse når man starter timeren, hvis man ikke allerede har gjort det
                        if (!vm.isTimerRunning) {
                          context.read<NotificationService>().requestPermissions();
                        }
                        vm.isTimerRunning ? vm.stopTimer() : vm.startTimer();
                      },
                      backgroundColor: vm.isTimerRunning ? Colors.orangeAccent : theme.colorScheme.primary,
                      elevation: 5,
                      child: Icon(vm.isTimerRunning ? Icons.pause : Icons.play_arrow_rounded, color: Colors.white, size: 48),
                    ),
                  
                  if (vm.isOnBreak)
                    ElevatedButton.icon(
                      onPressed: vm.skipBreak,
                      icon: const Icon(Icons.skip_next),
                      label: const Text("Luk Pause"),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.green[700],
                      ),
                    ),
      
                  const SizedBox(width: 20),
      
                  // RESET
                  if (!vm.isOnBreak)
                    FloatingActionButton(
                      heroTag: 'timer_reset',
                      onPressed: vm.resetTimer,
                      backgroundColor: theme.colorScheme.surface,
                      elevation: 2,
                      child: Icon(Icons.refresh_rounded, color: theme.colorScheme.onSurface),
                    )
                  else 
                    const SizedBox(width: 56),
                ],
              ),
            ),
          ],
        ),
      ),
       ConfettiWidget(
          confettiController: _confettiController,
          blastDirection: pi / 2, // Retning: nedad
          maxBlastForce: 5, // Hastighed
          minBlastForce: 2,
          emissionFrequency: 0.05,
          numberOfParticles: 20, // Mængde af confetti
          gravity: 0.1,
          shouldLoop: false,
          colors: const [
            Colors.green,
            Colors.blue,
            Colors.pink,
            Colors.orange,
            Colors.purple,
          ], 
        ),
    ]);
  }
}