import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_profile.dart'; // Husk import

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
      // Dette er sikkert, da vi kan bruge Firestore Rules til at sige at 
      // kun ejeren må redigere, men andre må læse (for at se navnet på lister).
      await _db.collection('users').doc(newUser.uid).set(newUser.toMap());
      
    } catch (e) {
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }
  
  // Opdater password (hvis brugeren vil ændre det senere)
  Future<void> updatePassword(String newPassword) async {
    if (currentUser != null) {
      await currentUser!.updatePassword(newPassword);
    }
  }
}