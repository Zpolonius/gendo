import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';


import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../models/user_profile.dart';


class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Vi bruger State til at trigger reload efter redigering
  Future<UserProfile?>? _profileFuture;
  
  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  void _loadProfile() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        _profileFuture = FirestoreService(user.uid).getUserProfile();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Min Profil"),
        actions: [
          // Logout knap i appbar for hurtig adgang
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            tooltip: "Log ud",
            onPressed: () => context.read<AuthService>().signOut(),
          )
        ],
      ),
      body: FutureBuilder<UserProfile?>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (snapshot.hasError) {
            return Center(child: Text("Fejl: ${snapshot.error}"));
          }

          final profile = snapshot.data;

          if (profile == null) {
            return const Center(child: Text("Ingen profil fundet."));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // --- HEADER ---
                Center(
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                        child: Text(
                          profile.firstName.isNotEmpty ? profile.firstName[0].toUpperCase() : "?",
                          style: TextStyle(fontSize: 48, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold),
                        ),
                      ),
                      // Edit knap ved avatar
                      Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 3),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.edit, color: Colors.white, size: 20),
                          onPressed: () => _showEditProfileDialog(context, profile),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Center(
                  child: Column(
                    children: [
                      Text(
                        profile.fullName,
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      // E-mail fjernet herfra for at undgå dubletter/rod
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                
                // --- INFO KORT ---
                // E-mail tilføjet her som det første punkt
                _ProfileItem(icon: Icons.email, label: "Email", value: profile.email),
                _ProfileItem(icon: Icons.phone, label: "Telefon", value: profile.phoneNumber),
                _ProfileItem(icon: Icons.public, label: "Land", value: profile.country),
                if (profile.company != null && profile.company!.isNotEmpty)
                  _ProfileItem(icon: Icons.business, label: "Firma", value: profile.company!),
                
                const SizedBox(height: 40),
                
                // --- REDIGER KNAP ---
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _showEditProfileDialog(context, profile),
                    icon: const Icon(Icons.edit_note), 
                    label: const Text("Rediger Oplysninger"),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 20),

                // --- DANGER ZONE ---
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text("Danger Zone", style: TextStyle(color: Colors.red[300], fontWeight: FontWeight.bold, fontSize: 12)),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: () => _showDeleteConfirmation(context), 
                    icon: const Icon(Icons.delete_forever, color: Colors.red), 
                    label: const Text("Slet min konto", style: TextStyle(color: Colors.red)),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.red.withOpacity(0.05),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                )
              ],
            ),
          );
        },
      ),
    );
  }

  // --- DIALOG: REDIGER PROFIL ---
  void _showEditProfileDialog(BuildContext context, UserProfile profile) {
    final formKey = GlobalKey<FormState>();
    final firstNameCtrl = TextEditingController(text: profile.firstName);
    final lastNameCtrl = TextEditingController(text: profile.lastName);
    final phoneCtrl = TextEditingController(text: profile.phoneNumber);
    final countryCtrl = TextEditingController(text: profile.country);
    final companyCtrl = TextEditingController(text: profile.company ?? "");
    bool isUpdating = false;

    showDialog(
      context: context,
      barrierDismissible: false, // Forhindre at lukke ved et uheld
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text("Rediger Profil"),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(child: _buildEditField(firstNameCtrl, "Fornavn")),
                        const SizedBox(width: 10),
                        Expanded(child: _buildEditField(lastNameCtrl, "Efternavn")),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildEditField(phoneCtrl, "Telefon", type: TextInputType.phone),
                    const SizedBox(height: 16),
                    _buildEditField(countryCtrl, "Land"),
                    const SizedBox(height: 16),
                    _buildEditField(companyCtrl, "Firma (Valgfrit)", required: false),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isUpdating ? null : () => Navigator.pop(context),
                child: const Text("Annuller"),
              ),
              ElevatedButton(
                onPressed: isUpdating ? null : () async {
                  if (formKey.currentState!.validate()) {
                    setState(() => isUpdating = true);
                    try {
                      final updatedProfile = UserProfile(
                        uid: profile.uid,
                        email: profile.email, // Email kan ikke ændres her
                        firstName: firstNameCtrl.text.trim(),
                        lastName: lastNameCtrl.text.trim(),
                        phoneNumber: phoneCtrl.text.trim(),
                        country: countryCtrl.text.trim(),
                        company: companyCtrl.text.trim().isNotEmpty ? companyCtrl.text.trim() : null,
                        createdAt: profile.createdAt
                      );

                      // Opdater i Firestore
                      await FirestoreService(profile.uid).updateUserProfile(updatedProfile);
                      
                      if (mounted) {
                        Navigator.pop(context);
                        _loadProfile(); // Reload UI
                        ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text("Profil opdateret!")));
                      }
                    } catch (e) {
                      if (mounted) {
                        setState(() => isUpdating = false);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Fejl: $e")));
                      }
                    }
                  }
                },
                child: isUpdating 
                  ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text("Gem"),
              ),
            ],
          );
        }
      ),
    );
  }

  // --- DIALOG: SLET KONTO ---
  void _showDeleteConfirmation(BuildContext context) {
    final passwordCtrl = TextEditingController();
    bool isDeleting = false;
    String? errorMsg;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text("Slet Konto?"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "ADVARSEL: Dette vil permanent slette din konto, dine lister (som du ejer) og al data. Dette kan ikke fortrydes.",
                  style: TextStyle(color: Colors.red),
                ),
                const SizedBox(height: 20),
                const Text("Indtast din adgangskode for at bekræfte:"),
                const SizedBox(height: 10),
                TextField(
                  controller: passwordCtrl,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: "Adgangskode",
                    errorText: errorMsg,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isDeleting ? null : () => Navigator.pop(context),
                child: const Text("Fortryd"),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                onPressed: isDeleting ? null : () async {
                  if (passwordCtrl.text.isEmpty) {
                    setState(() => errorMsg = "Indtast venligst adgangskode");
                    return;
                  }

                  setState(() {
                    isDeleting = true;
                    errorMsg = null;
                  });

                  try {
                    final user = FirebaseAuth.instance.currentUser;
                    if (user == null) return;

                    // 1. Slet data i Firestore først (Right to be forgotten)
                    await FirestoreService(user.uid).deleteUserData();

                    // 2. Slet konto i Auth (Kræver Re-auth, som håndteres i AuthService)
                    // Vi bruger context.read da vi er i en dialog
                    await this.context.read<AuthService>().deleteAccount(passwordCtrl.text);

                    if (mounted) {
                      Navigator.pop(context); // Luk dialog
                      Navigator.of(this.context).popUntil((route) => route.isFirst); // Gå til root (Login)
                    }
                  } catch (e) {
                    if (mounted) {
                      setState(() {
                        isDeleting = false;
                        if (e.toString().contains('wrong-password')) {
                          errorMsg = "Forkert adgangskode";
                        } else {
                          errorMsg = "Der skete en fejl. Prøv igen.";
                        }
                      });
                    }
                  }
                },
                child: isDeleting 
                  ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text("SLET ALT"),
              ),
            ],
          );
        }
      ),
    );
  }

  Widget _buildEditField(TextEditingController controller, String label, {TextInputType? type, bool required = true}) {
    return TextFormField(
      controller: controller,
      keyboardType: type,
      decoration: InputDecoration(
        labelText: label,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      validator: (val) {
        if (required && (val == null || val.trim().isEmpty)) {
          return 'Påkrævet';
        }
        return null;
      },
    );
  }
}

// Genbrugelig info-række
class _ProfileItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ProfileItem({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              // Bruger surfaceContainerHighest for bedre kompatibilitet med Material 3, 
              // eller fallback til en grå farve hvis temaet driller.
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Theme.of(context).colorScheme.primary, size: 20),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }
}