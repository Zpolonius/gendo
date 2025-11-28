import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
// import 'package:gendo/firebase_options.dart'; // Aktiver denne hvis du har filen

import 'repository.dart';
import 'viewmodels/app_view_model.dart'; // Peger på din fil i roden af lib eller viewmodels mappe
import 'services/auth_service.dart';
import 'services/firestore_service.dart';
import 'services/notification_service.dart'; 
import 'screens/login_screen.dart';
import 'widgets/app_drawer.dart'; 

import 'screens/pomodoro_screen.dart';
import 'screens/todo_list_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // Hvis du har genereret firebase options:
    // await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    await Firebase.initializeApp(); 
  } catch (e) {
    debugPrint("Firebase init error: $e");
  }

  final notificationService = NotificationService();
  await notificationService.init();
  
  runApp(GenDoApp(notificationService: notificationService));
}

class GenDoApp extends StatelessWidget {
  final NotificationService notificationService;

  const GenDoApp({super.key, required this.notificationService});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // 1. Auth Service
        Provider<AuthService>(create: (_) => AuthService()),
        
        // 2. Notification Service
        Provider<NotificationService>.value(value: notificationService),
        
        // 3. User Stream - FIX: initialData forhindrer flash af login-skærm
        StreamProvider<User?>(
          create: (context) => context.read<AuthService>().user,
          initialData: FirebaseAuth.instance.currentUser, 
        ),

        // 4. AppViewModel - Forbinder User og Repository
        ChangeNotifierProxyProvider<User?, AppViewModel>(
          create: (_) => AppViewModel(
            MockTaskRepository(), 
            notificationService,
            user: FirebaseAuth.instance.currentUser
          ),
          update: (_, user, viewModel) {
            // Hvis viewModel ikke findes endnu, opret den
            final vm = viewModel ?? AppViewModel(
              MockTaskRepository(), 
              notificationService,
              user: user
            );
            
            // Opdater altid brugeren i BaseViewModel
            vm.updateUser(user);

            // Skift repository logik
            if (user != null) {
              // Tjek om vi allerede bruger FirestoreService for at undgå unødvendige reloads
              if (vm.repository is! FirestoreService) {
                 debugPrint("User logged in: Switching to FirestoreService");
                 vm.updateRepository(FirestoreService(user.uid));
              }
            } else {
              if (vm.repository is! MockTaskRepository) {
                 debugPrint("User logged out: Switching to MockTaskRepository");
                 vm.updateRepository(MockTaskRepository());
              }
            }
            return vm;
          },
        ),
      ],
      child: const GenDoMaterialApp(),
    );
  }
}

class GenDoMaterialApp extends StatelessWidget {
  const GenDoMaterialApp({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AppViewModel>(); // Lytter på theme changes via ThemeMixin
    
    // Farver og Tema opsætning
    final primaryColor = const Color(0xFF6C63FF);
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
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: const Color(0xFFF4F6F8),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0.0,
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
          surface: const Color(0xFF1E1E2C),
        ),
        scaffoldBackgroundColor: const Color(0xFF121212),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0.0,
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
      
      // Styret af ThemeMixin
      themeMode: vm.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<User?>();
    
    // Fordi vi bruger initialData i main.dart, vil 'user' være sat med det samme,
    // hvis man tidligere har logget ind.
    if (user != null) {
      return const MainScreen();
    } else {
      return const LoginScreen();
    }
  }
}

// ... Din MainScreen kode forbliver uændret ...
// Jeg antager du har MainScreen defineret længere nede i filen eller importeret
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 1;
  
  void _switchTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    context.watch<AppViewModel>();
    final theme = Theme.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final List<Widget> screens = [
      const PomodoroScreen(),
      TodoListScreen(onSwitchTab: _switchTab),
    ];

    return Scaffold(
      endDrawer: const AppDrawer(),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
             // Sikrer at logoet findes, ellers viser vi ikon
            Image.asset('assets/gendo_logo.png', height: 28, errorBuilder: (c,o,s) => Icon(Icons.check_circle, color: theme.primaryColor)),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("GenDo", style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 20, color: isDark ? Colors.white : Colors.black87)),
                Text("Next Gen To Do", style: GoogleFonts.poppins(fontWeight: FontWeight.w400, fontSize: 10, color: theme.colorScheme.primary)),
              ],
            ),
          ],
        ),
      ),
      body: SafeArea(child: IndexedStack(index: _currentIndex, children: screens)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _switchTab,
        backgroundColor: theme.colorScheme.surface,
        indicatorColor: theme.colorScheme.primary,
        elevation: 0.0,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.timer_outlined), selectedIcon: Icon(Icons.timer), label: 'Fokus'),
          NavigationDestination(icon: Icon(Icons.check_circle_outline), selectedIcon: Icon(Icons.check_circle), label: 'Opgaver'),
        ],
      ),
    );
  }
}