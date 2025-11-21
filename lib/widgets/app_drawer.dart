import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../viewmodel.dart';
// Sikr dig at auth_service.dart ligger i en mappe kaldet 'services'
import '../services/auth_service.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AppViewModel>();
    final user = context.watch<User?>(); // Hent nuværende bruger
    final theme = Theme.of(context);
    final isDark = vm.isDarkMode;

    return Drawer(
      backgroundColor: theme.scaffoldBackgroundColor,
      child: Column(
        children: [
          // --- HEADER ---
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
            ),
            accountName: const Text(
              "Min Profil",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            accountEmail: Text(
              user?.email ?? 'Ingen email',
              style: const TextStyle(color: Colors.white70),
            ),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Text(
                (user?.email != null && user!.email!.isNotEmpty) 
                    ? user.email![0].toUpperCase() 
                    : "G",
                style: TextStyle(fontSize: 24, color: theme.colorScheme.primary),
              ),
            ),
          ),

          // --- MENU PUNKTER ---
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                ListTile(
                  leading: Icon(Icons.person_outline, color: theme.colorScheme.onSurface),
                  title: const Text("Profilindstillinger"),
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Kommer snart!")),
                    );
                  },
                ),
                
                ListTile(
                  leading: Icon(Icons.bar_chart_rounded, color: theme.colorScheme.onSurface),
                  title: const Text("Statistik"),
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Kommer snart!")),
                    );
                  },
                ),

                const Divider(),

                // --- DARK MODE SWITCH ---
                SwitchListTile(
                  title: const Text("Dark Mode"),
                  secondary: Icon(isDark ? Icons.dark_mode : Icons.light_mode, color: theme.colorScheme.onSurface),
                  value: isDark,
                  activeColor: theme.colorScheme.primary,
                  onChanged: (bool value) {
                    vm.toggleTheme(value);
                  },
                ),
              ],
            ),
          ),

          // --- LOG UD ---
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.redAccent),
            title: const Text("Log ud", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            onTap: () async {
              Navigator.pop(context); // Luk menuen først
              
              final authService = context.read<AuthService>();
              await authService.signOut();
            },
          ),
          
          SizedBox(height: MediaQuery.of(context).padding.bottom + 10),
        ],
      ),
    );
  }
}