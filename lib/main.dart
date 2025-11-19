import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'models.dart';
import 'repository.dart';
import 'viewmodel.dart';

void main() {
  final taskRepository = MockTaskRepository();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppViewModel(taskRepository)),
      ],
      child: const GenDoApp(),
    ),
  );
}

class GenDoApp extends StatelessWidget {
  const GenDoApp({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AppViewModel>();
    const primaryColor = Color(0xFF6C63FF);
    final textTheme = GoogleFonts.poppinsTextTheme();

    return MaterialApp(
      title: 'GenDo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        textTheme: textTheme,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryColor,
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: const Color(0xFFF4F6F8),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          iconTheme: IconThemeData(color: Colors.black87),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        textTheme: textTheme.apply(bodyColor: Colors.white, displayColor: Colors.white),
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryColor,
          brightness: Brightness.dark,
          surface: const Color(0xFF1E1E2C),
        ),
        scaffoldBackgroundColor: const Color(0xFF121212),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          iconTheme: IconThemeData(color: Colors.white),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF2A2A3D),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          hintStyle: TextStyle(color: Colors.grey[500]),
        ),
      ),
      themeMode: vm.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 1;
  
  final List<Widget> _screens = [
    const PomodoroScreen(),
    const GenUiCenterScreen(),
    const TodoListScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AppViewModel>();
    final isDark = vm.isDarkMode;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Tranen vises foran "GenDo" i toppen
            SvgPicture.asset('assets/gendo_logo.svg', height: 28),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("GenDo", style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 20, color: isDark ? Colors.white : Colors.black87)),
                Text("AI Powered To Do", style: GoogleFonts.poppins(fontWeight: FontWeight.w400, fontSize: 10, color: theme.colorScheme.primary)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
            onPressed: () => vm.toggleTheme(!isDark),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(child: IndexedStack(index: _currentIndex, children: _screens)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        backgroundColor: theme.colorScheme.surface,
        indicatorColor: theme.colorScheme.primary.withOpacity(0.2),
        elevation: 0,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.timer_outlined), selectedIcon: Icon(Icons.timer), label: 'Fokus'),
          NavigationDestination(icon: Icon(Icons.auto_awesome_outlined), selectedIcon: Icon(Icons.auto_awesome), label: 'GenDo'),
          NavigationDestination(icon: Icon(Icons.check_circle_outline), selectedIcon: Icon(Icons.check_circle), label: 'Opgaver'),
        ],
      ),
    );
  }
}

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
          ElevatedButton(onPressed: () {
            final int? minutes = int.tryParse(controller.text);
            if (minutes != null && minutes > 0) {
              vm.setDuration(minutes);
              Navigator.pop(context);
            }
          }, child: const Text("Sæt")),
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

class GenUiCenterScreen extends StatefulWidget {
  const GenUiCenterScreen({super.key});
  @override
  State<GenUiCenterScreen> createState() => _GenUiCenterScreenState();
}

class _GenUiCenterScreenState extends State<GenUiCenterScreen> {
  final TextEditingController _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AppViewModel>();
    final theme = Theme.of(context);
    final isDark = vm.isDarkMode;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // HER HAR JEG INDSAT TRANEN I STEDET FOR DET GAMLE IKON
          SvgPicture.asset('assets/gendo_logo.svg', height: 80),
          const SizedBox(height: 20),
          Text("Hvad vil du opnå?", style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text("Beskriv dit mål, så nedbryder AI det til handlinger.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[500])),
          const SizedBox(height: 30),
          TextField(
            controller: _controller,
            style: TextStyle(color: theme.colorScheme.onSurface),
            decoration: InputDecoration(
              hintText: "F.eks. 'Lær at spille guitar'",
              filled: true,
              fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.all(20),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              onPressed: vm.isLoading ? null : () {
                if (_controller.text.isNotEmpty) {
                  vm.generatePlanFromAI(_controller.text);
                  _controller.clear();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Plan genereret!")));
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 4,
                shadowColor: theme.colorScheme.primary.withOpacity(0.4),
              ),
              child: vm.isLoading 
                ? const CircularProgressIndicator(color: Colors.white) 
                : const Text("Generer Plan", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }
}

class TodoListScreen extends StatelessWidget {
  const TodoListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AppViewModel>();
    final theme = Theme.of(context);
    final isDark = vm.isDarkMode;

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
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? Colors.white10 : Colors.transparent),
                  boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: IconButton(
                    icon: Icon(task.isCompleted ? Icons.check_circle : Icons.circle_outlined),
                    color: task.isCompleted ? Colors.green : Colors.grey,
                    onPressed: () => vm.toggleTask(task.id),
                  ),
                  title: Text(
                    task.title, 
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: task.isCompleted ? Colors.grey : theme.colorScheme.onSurface,
                      decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                    )
                  ),
                  subtitle: Text(task.category, style: TextStyle(fontSize: 12, color: theme.colorScheme.primary.withOpacity(0.7))),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                    onPressed: () => vm.deleteTask(task.id),
                  ),
                ),
              );
            },
          ),
    );
  }

  void _showAddDialog(BuildContext context, AppViewModel vm) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Ny Opgave"),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: TextField(
          controller: controller, 
          autofocus: true,
          decoration: const InputDecoration(hintText: "Hvad skal laves?"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuller")),
          ElevatedButton(onPressed: () {
            if (controller.text.isNotEmpty) {
              vm.addTask(controller.text);
              Navigator.pop(context);
            }
          }, child: const Text("Tilføj")),
        ],
      ),
    );
  }
}