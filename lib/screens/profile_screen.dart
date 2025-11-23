import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_service.dart';
import '../models/user_profile.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    // Vi bruger FirestoreService direkte her for at hente profilen, 
    // da vi ikke har lagt profilen i ViewModel endnu (for at holde VM simpel).
    final firestoreService = FirestoreService(user!.uid);

    return Scaffold(
      appBar: AppBar(title: const Text("Min Profil")),
      body: FutureBuilder<UserProfile?>(
        future: firestoreService.getUserProfile(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (snapshot.hasError) {
            return Center(child: Text("Fejl: ${snapshot.error}"));
          }

          final profile = snapshot.data;

          if (profile == null) {
            return const Center(child: Text("Ingen profil fundet. (Oprettet før profil-system?)"));
          }

          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Center(
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                  child: Text(
                    profile.firstName[0].toUpperCase(),
                    style: TextStyle(fontSize: 40, color: Theme.of(context).colorScheme.primary),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: Text(
                  profile.fullName,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 40),
              
              _ProfileItem(icon: Icons.email, label: "Email", value: profile.email),
              _ProfileItem(icon: Icons.phone, label: "Telefon", value: profile.phoneNumber),
              _ProfileItem(icon: Icons.public, label: "Land", value: profile.country),
              if (profile.company != null && profile.company!.isNotEmpty)
                _ProfileItem(icon: Icons.business, label: "Firma", value: profile.company!),
              
              const SizedBox(height: 40),
              // Her kunne man tilføje en "Rediger Profil" knap senere
              Center(
                child: OutlinedButton.icon(
                  onPressed: () {
                     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Redigering kommer i næste version!")));
                  }, 
                  icon: const Icon(Icons.edit), 
                  label: const Text("Rediger Oplysninger")
                ),
              )
            ],
          );
        },
      ),
    );
  }
}

class _ProfileItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ProfileItem({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }
}