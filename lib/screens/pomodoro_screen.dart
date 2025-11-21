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
            if (vm.selectedTaskId == null)
               const Text("Er du klar til en pause?"),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              vm.completeWorkSession(false);
            },
            child: const Text("Nej, ikke endnu"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              vm.completeWorkSession(true);
            },
            child: const Text("Ja, færdig!"),
          ),
        ],
      ),
    ).then((_) {
      if (mounted) setState(() => _isDialogShowing = false);
    });
  }

  void _showCustomTimeDialog(BuildContext context, AppViewModel vm) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Sæt tid (minutter)"),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(hintText: "F.eks. 60", suffixText: "min"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuller")),
          ElevatedButton(
            onPressed: () {
              final int? minutes = int.tryParse(controller.text);
              if (minutes != null && minutes > 0) {
                vm.setDuration(minutes);
                Navigator.pop(context);
              }
            }, 
            child: const Text("Sæt"),
          ),
        ],
      ),
    );
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

    final currentMinutes = vm.pomodoroDurationTotal ~/ 60;
    final isCustomSelected = ![10, 20, 30].contains(currentMinutes);
    
    final timerColor = vm.isOnBreak ? Colors.green[400] : theme.colorScheme.primary;
    final statusText = vm.isOnBreak 
        ? (vm.pomodoroDurationTotal > 600 ? "LANG PAUSE" : "PAUSE")
        : "FOKUS";

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          if (!vm.isTimerRunning && !vm.isOnBreak) ...[
            Text("VÆLG VARIGHED", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[500], letterSpacing: 1.2)),
            const SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _TimeChip(label: "10", isSelected: currentMinutes == 10, onTap: () => vm.setDuration(10)),
                const SizedBox(width: 12),
                _TimeChip(label: "20", isSelected: currentMinutes == 20, onTap: () => vm.setDuration(20)),
                const SizedBox(width: 12),
                _TimeChip(label: "30", isSelected: currentMinutes == 30, onTap: () => vm.setDuration(30)),
                const SizedBox(width: 12),
                _TimeChip(label: "Custom", isSelected: isCustomSelected, onTap: () => _showCustomTimeDialog(context, vm)),
              ],
            ),
            const SizedBox(height: 40),
          ],

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
            height: 280,
            width: 280,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: vm.progress,
                  strokeWidth: 18,
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
                        fontSize: 56, 
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (!vm.isOnBreak && vm.selectedTaskObj != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: theme.colorScheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                        child: Text(vm.selectedTaskObj!.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, color: theme.colorScheme.primary, fontWeight: FontWeight.w600)),
                      )
                    else if (vm.isOnBreak)
                       Text("Træk vejret dybt...", style: TextStyle(color: Colors.green[700], fontWeight: FontWeight.w500)),
                    if (!vm.isOnBreak && vm.selectedTaskObj == null)
                      Text("Frit fokus", style: TextStyle(color: Colors.grey[500])),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),

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

          const SizedBox(height: 30),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!vm.isOnBreak)
                FloatingActionButton.large(
                  heroTag: 'timer_control',
                  onPressed: vm.isTimerRunning ? vm.stopTimer : vm.startTimer,
                  backgroundColor: vm.isTimerRunning ? Colors.orangeAccent : theme.colorScheme.primary,
                  elevation: 5,
                  child: Icon(vm.isTimerRunning ? Icons.pause : Icons.play_arrow_rounded, color: Colors.white, size: 40),
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
                const SizedBox(width: 20),
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

class _TimeChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  const _TimeChip({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.primary : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? Colors.transparent : (isDark ? Colors.white12 : Colors.grey.shade200)),
          boxShadow: isSelected ? [BoxShadow(color: theme.colorScheme.primary.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 4))] : [],
        ),
        child: Text(label, style: TextStyle(color: isSelected ? Colors.white : theme.colorScheme.onSurface, fontWeight: FontWeight.bold)),
      ),
    );
  }
}