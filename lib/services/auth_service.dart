import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_profile.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Stream of auth changes
  Stream<User?> get user => _auth.authStateChanges();

  // Current user
  User? get currentUser => _auth.currentUser;

  // Sign in
  Future<UserCredential> signInWithEmailAndPassword(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(email: email, password: password);
    } catch (e) {
      rethrow;
    }
  }

  // Register (UDVIDET MED PROFIL DATA)
  Future<void> registerWithProfile({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String phoneNumber,
    required String country,
    String? company,
  }) async {
    try {
      // 1. Opret brugeren i det sikre Auth system (håndterer password)
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email, 
        password: password
      );
      
      // 2. Opret profil-objekt
      final newUser = UserProfile(
        uid: result.user!.uid,
        email: email,
        firstName: firstName,
        lastName: lastName,
        phoneNumber: phoneNumber,
        country: country,
        company: company,
        createdAt: DateTime.now(),
      );

      // 3. Gem de personlige data i Firestore under 'users' kollektionen
      await _db.collection('users').doc(newUser.uid).set(newUser.toMap());
      
    } catch (e) {
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }
  
  // Opdater password
  Future<void> updatePassword(String newPassword) async {
    if (currentUser != null) {
      await currentUser!.updatePassword(newPassword);
    }
  }

  // Slet konto (Kræver password for sikkerhed - Re-authentication)
  Future<void> deleteAccount(String password) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) return;

    try {
      // 1. Re-autentificer brugeren (Sikkerhedskrav fra Firebase før sletning)
      AuthCredential credential = EmailAuthProvider.credential(
        email: user.email!, 
        password: password
      );
      
      await user.reauthenticateWithCredential(credential);

      // 2. Slet brugeren fra Authentication systemet
      // Bemærk: Selve data-oprydningen i Firestore bør ske FØR dette kald (i UI logikken)
      await user.delete();
    } catch (e) {
      rethrow;
    }
  }
}