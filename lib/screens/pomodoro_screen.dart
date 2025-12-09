import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:confetti/confetti.dart';

import '../widgets/session_completion_dialog.dart'; 
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

  // Confetti controller
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

  // --- OPGAVE VÆLGER MENU (Bottom Sheet) ---
  void _showTaskPicker(BuildContext context, AppViewModel vm) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))
      ),
      builder: (ctx) {
        final activeTasks = vm.allTasks.where((t) => !t.isCompleted).toList();
        
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Vælg Fokus", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 10),
              
              // Mulighed 1: Frit Fokus
              ListTile(
                leading: const Icon(Icons.center_focus_strong, color: Colors.blueAccent),
                title: const Text("Frit fokus (Ingen opgave)"),
                onTap: () {
                  vm.setSelectedTask(null);
                  Navigator.pop(ctx);
                },
                trailing: vm.selectedTaskId == null ? const Icon(Icons.check, color: Colors.blue) : null,
              ),
              const Divider(),
              
              // Mulighed 2: Liste af opgaver
              if (activeTasks.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text("Ingen aktive opgaver fundet.", style: TextStyle(color: Colors.grey)),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: activeTasks.length,
                    itemBuilder: (ctx, i) {
                      final task = activeTasks[i];
                      final isSelected = vm.selectedTaskId == task.id;
                      
                      // Find listens navn for kontekst
                      String listName = "";
                      try {
                         final list = vm.lists.firstWhere((l) => l.id == task.listId);
                         listName = list.title;
                      } catch(e) { listName = "Ukendt liste"; }

                      return ListTile(
                        leading: const Icon(Icons.radio_button_unchecked, color: Colors.grey),
                        title: Text(task.title, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                        subtitle: Text(
                          listName,
                          style: TextStyle(fontSize: 12, color: Colors.grey[600])
                        ),
                        trailing: isSelected ? const Icon(Icons.check, color: Colors.green) : null,
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
void _handleTaskCompletion(AppViewModel vm) async {
    final task = vm.selectedTaskObj;
    
    if (task == null) return;
    _confettiController.play();
    // Tjek om der er steps
    bool hasSteps = task.steps.isNotEmpty;

    if (hasSteps) {
      // Hvis der er steps, vis SessionCompletionDialog først
      // Denne widget styrer selv at gemme steps når man trykker "Gem/Luk"
      await showDialog(
        context: context,
        builder: (ctx) => SessionCompletionDialog(
          task: task,
          onSave: (updatedTask) {
             vm.updateTaskDetails(updatedTask); 
          }, vm: vm
        ),
      );
    }

    // Når dialogen er lukket (eller hvis der ingen steps var), spørg om næste træk
    if (mounted) {
      _showNextMoveDialog(context, vm);
    }
  }

  // 2. Dialogen der spørger: Pause eller Ny Opgave?
  void _showNextMoveDialog(BuildContext context, AppViewModel vm) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text("Opgave fuldført!"),
        content: const Text(
          "Godt arbejde! Du har stadig tid tilbage på uret.\n\nVil du fortsætte fokus på en ny opgave, eller tage en pause nu?",
        ),
        actions: [
          // MULIGHED A: GÅ TIL PAUSE
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              vm.completeWorkSession(true); // Afslutter og går til pause
            },
            child: const Text("Hold pause"),
          ),
          
          // MULIGHED B: FORTSÆT MED NY OPGAVE
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              vm.completeTaskEarly(); // Markerer færdig, fjerner valg, lader ur køre
            },
            child: const Text("Vælg ny opgave"),
          ),
        ],
      ),
    );
  }
  void _showCompletionDialog(BuildContext context, AppViewModel vm, {bool isManualTrigger = false}) {
    final breaksEnabled = vm.pomodoroSettings.enableBreaks;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text("Godt gået!"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Vis kun "Tiden er gået" hvis det ikke er manuelt triggeret
            if (!isManualTrigger)
              const Text("Tiden er gået."),
            
            const SizedBox(height: 10),
            
            if (vm.selectedTaskId != null)
              Text("Blev du færdig med '${vm.selectedTaskObj?.title}'?", style: const TextStyle(fontWeight: FontWeight.bold)),
            
            const SizedBox(height: 20),
            
            if (breaksEnabled)
               const Text("Vil du starte pausen nu?"),
            if (!breaksEnabled)
               const Text("Klar til næste session?"),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              // Hvis det var manuelt, og man siger "Nej" til pausen, fortsætter man bare (men opgaven markeres færdig)
              // Her antager vi dog "Nej" knappen i denne kontekst betyder "Nej, jeg er ikke færdig" eller "Luk dialog"
              // Men for at matche "Samme muligheder":
              
              if (isManualTrigger) {
                 // Brugeren vil IKKE starte pause, men har markeret opgaven som færdig via knappen.
                 // Vi skal markere opgaven som færdig, men lade timeren køre.
                 vm.completeTaskEarly(); 
              } else {
                 vm.completeWorkSession(false); // Tiden er gået, men opgaven ikke færdig
              }
            },
            child: Text(isManualTrigger ? "Fortsæt fokus" : "Nej"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              // "Ja, videre" -> Marker færdig og start pause
              vm.completeWorkSession(true);
            },
            child: const Text("Ja, start pause!"),
          ),
        ],
      ),
    ).then((_) {
      if (mounted) setState(() => _isDialogShowing = false);
    });
  }
  // Genbruges hvis man afslutter manuelt
  void _showNextTaskSelector(BuildContext context, AppViewModel vm) {
     // Vi kan genbruge _showTaskPicker logikken eller lave en specifik "hvad nu" dialog.
     // For at holde det simpelt bruger vi _showTaskPicker her også, 
     // eller du kan indsætte din tidligere _showNextTaskSelector her hvis du vil have "Pause" knappen med.
     _showTaskPicker(context, vm);
  }

  String _formatTime(int seconds) {
    final minutes = (seconds / 60).floor();
    final remSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AppViewModel>();
    final theme = Theme.of(context);
    final isDark = vm.isDarkMode;
    
    final timerColor = vm.isOnBreak ? Colors.green[400] : theme.colorScheme.primary;
    final statusText = vm.isOnBreak 
        ? (vm.pomodoroDurationTotal > 600 ? "LANG PAUSE" : "PAUSE")
        : "FOKUS";

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
                    // Timer Cirkel
                    CircularProgressIndicator(
                      value: vm.progress,
                      strokeWidth: 20,
                      backgroundColor: isDark ? Colors.white10 : Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(timerColor!),
                      strokeCap: StrokeCap.round,
                    ),
                    
                    // --- CENTRALT INDHOLD (NU KLIKBART) ---
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
                        
                        // Her er logikken ændret:
                        if (!vm.isOnBreak)
                          InkWell(
                            onTap: () => _showTaskPicker(context, vm),
                            borderRadius: BorderRadius.circular(20),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                child: vm.selectedTaskObj != null
                                  ? Container(
                                      key: ValueKey(vm.selectedTaskId),
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primary.withOpacity(0.1), 
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: theme.colorScheme.primary.withOpacity(0.3))
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Flexible(
                                            child: Text(
                                              vm.selectedTaskObj!.title, 
                                              maxLines: 1, 
                                              overflow: TextOverflow.ellipsis, 
                                              style: TextStyle(
                                                fontSize: 16, 
                                                color: theme.colorScheme.primary, 
                                                fontWeight: FontWeight.w600
                                              )
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Icon(Icons.arrow_drop_down, color: theme.colorScheme.primary)
                                        ],
                                      ),
                                    )
                                  : Row(
                                      mainAxisSize: MainAxisSize.min,
                                      key: const ValueKey("FritFokus"),
                                      children: [
                                        Text("Frit fokus", style: TextStyle(color: Colors.grey[500], fontSize: 16)),
                                        const SizedBox(width: 4),
                                        Icon(Icons.edit, size: 14, color: Colors.grey[400]),
                                      ],
                                    ),
                              ),
                            ),
                          )
                        else if (vm.isOnBreak)
                           Text("Træk vejret dybt...", style: TextStyle(color: Colors.green[700], fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Dropdown boksen er fjernet herfra!
              const SizedBox(height: 60), 
        
              // --- CONTROLS ---
              Padding(
                padding: const EdgeInsets.only(bottom: 40, left: 24, right: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    
                    // FÆRDIG KNAP
                    if (!vm.isOnBreak && vm.selectedTaskObj != null) 
                      FloatingActionButton(
                        heroTag: 'task_complete',
                        onPressed: ()  {
                         _handleTaskCompletion(vm);
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
        
        // Confetti Overlay
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
      ],
    );
  }
}