import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'repository.dart';
import 'viewmodel.dart';
import 'services/auth_service.dart';
import 'services/firestore_service.dart';
import 'screens/login_screen.dart';
import 'widgets/app_drawer.dart'; 

import 'screens/pomodoro_screen.dart';
import 'screens/todo_list_screen.dart';
import 'screens/gen_ui_screen.dart';


// import 'firebase_options.dart'; // SIKR DIG AT DENNE FIL ER OPRETTET MED 'flutterfire configure'

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Vi prøver at initialisere Firebase. Hvis det fejler (f.eks. manglende config), fanger vi det.
  try {
    // await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    await Firebase.initializeApp(); 
  } catch (e) {
    print("Firebase Init Error: $e");
    // Appen vil stadig køre, men med Mock data indtil Firebase er fixet
  }

  runApp(const GenDoApp());
}

class GenDoApp extends StatelessWidget {
  const GenDoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthService>(create: (_) => AuthService()),
        StreamProvider<User?>(
          create: (context) => context.read<AuthService>().user,
          initialData: null,
        ),
        ChangeNotifierProxyProvider<User?, AppViewModel>(
          create: (_) => AppViewModel(MockTaskRepository()),
          update: (_, user, viewModel) {
            if (user != null) {
              viewModel!.updateRepository(FirestoreService(user.uid));
            } else {
              viewModel!.updateRepository(MockTaskRepository());
            }
            return viewModel;
          },
        ),
      ],
      // Flyttet Consumer/Builder herned for at sikre at theme opdateres
      child: const GenDoMaterialApp(),
    );
  }
}

class GenDoMaterialApp extends StatelessWidget {
  const GenDoMaterialApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Vi lytter nu på VM her for at opdatere temaet live
    final vm = context.watch<AppViewModel>();
    
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
      
      // Bruger valget fra ViewModel (som nu hentes fra Firebase)
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
    // Simpel auth check. Hvis Firebase init fejlede, er user null, og vi ser LoginScreen.
    if (user != null) {
      return const MainScreen();
    } else {
      return const LoginScreen();
    }
  }
}

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
    final vm = context.watch<AppViewModel>();
    final isDark = vm.isDarkMode;
    final theme = Theme.of(context);

    final List<Widget> screens = [
      const PomodoroScreen(),
      const GenUiScreen(),
      TodoListScreen(onSwitchTab: _switchTab),
    ];

    return Scaffold(
      // ÆNDRING: 'endDrawer' placerer menuen i højre side
      endDrawer: const AppDrawer(),
      
      appBar: AppBar(
        // Vi fjerner actions (ikonerne), da Flutter automatisk viser hamburger-menuen
        // i højre side, når vi bruger endDrawer.
        automaticallyImplyLeading: false, // Fjerner tilbage-pil/venstre menu
        
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/gendo_logo.png', height: 28),
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
          NavigationDestination(icon: Icon(Icons.auto_awesome_outlined), selectedIcon: Icon(Icons.auto_awesome), label: 'GenDo'),
          NavigationDestination(icon: Icon(Icons.check_circle_outline), selectedIcon: Icon(Icons.check_circle), label: 'Opgaver'),
        ],
      ),
    );
  }
}