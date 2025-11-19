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
    
    // Definer tekst-tema (Google Fonts)
    final textTheme = GoogleFonts.poppinsTextTheme();

    return MaterialApp(
      title: 'GenDo',
      debugShowCheckedModeBanner: false,
      
      // Light Theme
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        textTheme: textTheme,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryColor,
          // background parameter fjernet da den er deprecated
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

      // Dark Theme
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        textTheme: textTheme.apply(bodyColor: Colors.white, displayColor: Colors.white),
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryColor,
          brightness: Brightness.dark,
          // background parameter fjernet da den er deprecated
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
            SvgPicture.asset(
              'assets/gendo_logo.svg', 
              height: 28,
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "GenDo", 
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600, 
                    fontSize: 20,
                    color: isDark ? Colors.white : Colors.black87
                  )
                ),
                Text(
                  "AI Powered To Do", 
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w400, 
                    fontSize: 10,
                    color: theme.colorScheme.primary
                  )
                ),
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

// --- SCREEN 1: POMODORO ---
class PomodoroScreen extends StatelessWidget {
  const PomodoroScreen({super.key});

  String _formatTime(int seconds) {
    final minutes = (seconds / 60).floor();
    final remSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remSeconds.toString().padLeft(2, '0')}';
  }

  // Hjælpefunktion til at vise dialogen for brugerdefineret tid
  void _showCustomTimeDialog(BuildContext context, AppViewModel vm) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Sæt tid (minutter)"),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: "F.eks. 60",
            suffixText: "min",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Annuller"),
          ),
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

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AppViewModel>();
    final theme = Theme.of(context);
    final isDark = vm.isDarkMode;

    // Check om den nuværende tid er en af standarderne, for at vide om "Custom" skal være valgt
    final currentMinutes = vm.pomodoroDurationTotal ~/ 60;
    final isCustomSelected = ![15, 25, 45].contains(currentMinutes);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          if (!vm.isTimerRunning) ...[
            Text("SESSION LENGTH", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[500], letterSpacing: 1.2)),
            const SizedBox(height: 15),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _TimeChip(label: "15", isSelected: currentMinutes == 15, onTap: () => vm.setDuration(15)),
                  const SizedBox(width: 12),
                  _TimeChip(label: "25", isSelected: currentMinutes == 25, onTap: () => vm.setDuration(25)),
                  const SizedBox(width: 12),
                  _TimeChip(label: "45", isSelected: currentMinutes == 45, onTap: () => vm.setDuration(45)),
                  const SizedBox(width: 12),
                  _TimeChip(
                    label: "Custom", 
                    isSelected: isCustomSelected, 
                    onTap: () => _showCustomTimeDialog(context, vm),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
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
                  valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
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
                    if (vm.selectedTaskObj != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          vm.selectedTaskObj!.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 14, color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
                        ),
                      )
                    else
                      Text("Frit fokus", style: TextStyle(color: Colors.grey[500])),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),

          if (!vm.isTimerRunning)
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
                    ...vm.tasks.where((t) => !t.isCompleted).map((task) {
                      return DropdownMenuItem(
                        value: task.id,
                        child: Text(task.title, style: TextStyle(color: theme.colorScheme.onSurface)),
                      );
                    }).toList(),
                  ],
                  onChanged: (id) => vm.setSelectedTask(id),
                ),
              ),
            ),

          const SizedBox(height: 30),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FloatingActionButton.large(
                heroTag: 'timer_control',
                onPressed: vm.isTimerRunning ? vm.stopTimer : vm.startTimer,
                backgroundColor: vm.isTimerRunning ? Colors.orangeAccent : theme.colorScheme.primary,
                elevation: 5,
                child: Icon(vm.isTimerRunning ? Icons.pause : Icons.play_arrow_rounded, color: Colors.white, size: 40),
              ),
              const SizedBox(width: 20),
              FloatingActionButton(
                heroTag: 'timer_reset',
                onPressed: vm.resetTimer,
                backgroundColor: theme.colorScheme.surface,
                elevation: 2,
                child: Icon(Icons.refresh_rounded, color: theme.colorScheme.onSurface),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TimeChip extends StatelessWidget {
  final String label; // Ændret fra int til String for at støtte "Custom" tekst
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
          border: Border.all(
            color: isSelected ? Colors.transparent : (isDark ? Colors.white12 : Colors.grey.shade200)
          ),
          boxShadow: isSelected ? [BoxShadow(color: theme.colorScheme.primary.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 4))] : [],
        ),
        child: Text(
          label, 
          style: TextStyle(
            color: isSelected ? Colors.white : theme.colorScheme.onSurface, 
            fontWeight: FontWeight.bold
          )
        ),
      ),
    );
  }
}

// --- SCREEN 2: GEN DO (AI) ---
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

// --- SCREEN 3: TO-DO LIST ---
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