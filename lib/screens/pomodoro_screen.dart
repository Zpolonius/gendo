import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../viewmodel.dart';

class PomodoroScreen extends StatefulWidget {
  const PomodoroScreen({super.key});

  @override
  State<PomodoroScreen> createState() => _PomodoroScreenState();
}

class _PomodoroScreenState extends State<PomodoroScreen> {
  late AppViewModel _vm;
  bool _isDialogShowing = false;

  @override
  void initState() {
    super.initState();
    _vm = Provider.of<AppViewModel>(context, listen: false);
    _vm.addListener(_onVmChanged);
  }

  @override
  void dispose() {
    _vm.removeListener(_onVmChanged);
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

  void _showCompletionDialog(BuildContext context, AppViewModel vm) {
    setState(() => _isDialogShowing = true);
    // Hvis pauser er slået fra i indstillinger, spørger vi ikke om "pause", men bare om opgaven er færdig.
    final breaksEnabled = vm.pomodoroSettings.enableBreaks;
    
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Chips er fjernet for et renere look!
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
            height: 300, // Lidt større nu hvor vi har plads
            width: 300,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: vm.progress,
                  strokeWidth: 20, // Tykkere ring
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
                        fontSize: 64, // Større tekst
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (!vm.isOnBreak && vm.selectedTaskObj != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(color: theme.colorScheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
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
                  value: vm.selectedTaskId,
                  isExpanded: true,
                  dropdownColor: theme.colorScheme.surface,
                  hint: Text("Vælg en opgave at fokusere på", style: TextStyle(color: Colors.grey[500])),
                  items: [
                    DropdownMenuItem(value: null, child: Text("Ingen specifik opgave", style: TextStyle(color: theme.colorScheme.onSurface))),
                    ...vm.tasks.where((t) => !t.isCompleted).map((task) => DropdownMenuItem(value: task.id, child: Text(task.title, style: TextStyle(color: theme.colorScheme.onSurface)))).toList(),
                  ],
                  onChanged: (id) => vm.setSelectedTask(id),
                ),
              ),
            ),

          const SizedBox(height: 40),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!vm.isOnBreak)
                FloatingActionButton.large(
                  heroTag: 'timer_control',
                  onPressed: vm.isTimerRunning ? vm.stopTimer : vm.startTimer,
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

              if (!vm.isOnBreak) ...[
                const SizedBox(width: 30),
                FloatingActionButton(
                  heroTag: 'timer_reset',
                  onPressed: vm.resetTimer,
                  backgroundColor: theme.colorScheme.surface,
                  elevation: 2,
                  child: Icon(Icons.refresh_rounded, color: theme.colorScheme.onSurface),
                ),
              ]
            ],
          ),
        ],
      ),
    );
  }
}