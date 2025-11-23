import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // VIGTIGT: Tilføjet import

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Stream of auth changes
  Stream<User?> get user => _auth.authStateChanges();

  // Current user
  User? get currentUser => _auth.currentUser;

  // Sign in with email and password
  Future<UserCredential> signInWithEmailAndPassword(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(email: email, password: password);
    } catch (e) {
      rethrow;
    }
  }

  // Register with email and password (OPDATERET)
  Future<UserCredential> registerWithEmailAndPassword(String email, String password) async {
    try {
      // 1. Opret i Auth systemet
      UserCredential result = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      
      // 2. Opret straks dokument i Firestore så vi kan finde e-mailen senere
      await FirebaseFirestore.instance.collection('users').doc(result.user!.uid).set({
        'email': email,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      });
      
      return result;
    } catch (e) {
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }
}