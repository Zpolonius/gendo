import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Global nøgle til at vise SnackBars fra ViewModels uden BuildContext
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

class ErrorService {
  // Vis en fejlbesked til brugeren
  static void show(dynamic error, {StackTrace? stackTrace}) {
    // 1. Log fejlen til konsollen (eller Crashlytics i fremtiden)
    debugPrint("🛑 FEJL: $error");
    if (stackTrace != null) debugPrint("Stack: $stackTrace");

    // 2. Oversæt fejlen til dansk
    String message = _getUserFriendlyMessage(error);

    // 3. Vis SnackBar via vores globale nøgle
    rootScaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // Hjælper til at oversætte tekniske fejl
  static String _getUserFriendlyMessage(dynamic error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'user-not-found':
          return 'Vi kunne ikke finde en bruger med den email.';
        case 'wrong-password':
          return 'Forkert password. Prøv igen.';
        case 'email-already-in-use':
          return 'Denne email er allerede i brug.';
        case 'network-request-failed':
          return 'Tjek din internetforbindelse.';
        case 'invalid-email':
          return 'Email-adressen er ikke gyldig.';
        default:
          return 'Login fejl: ${error.message}';
      }
    } else if (error.toString().contains("SocketException") || error.toString().contains("Network")) {
      return "Ingen internetforbindelse. Prøv igen senere.";
    }
    
    // Fallback for ukendte fejl
    return "Der skete en uventet fejl. Prøv igen.";
  }
}