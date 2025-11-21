import 'package:cloud_firestore/cloud_firestore.dart';
import '../models.dart';
import '../repository.dart';

class FirestoreService implements TaskRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _userId;

  FirestoreService(this._userId);

  // Vi gemmer opgaver i en under-collection
  CollectionReference get _tasksCollection => _db.collection('users').doc(_userId).collection('tasks');
  
  // Vi gemmer indstillinger (tema, kategorier, pomodoro) direkte på bruger-dokumentet
  DocumentReference get _userDoc => _db.collection('users').doc(_userId);

  // --- TASKS ---

  @override
  Future<void> addTask(TodoTask task) async {
    await _tasksCollection.doc(task.id).set(task.toMap());
  }

  @override
  Future<void> updateTask(TodoTask task) async {
    await _tasksCollection.doc(task.id).update(task.toMap());
  }

  @override
  Future<void> deleteTask(String taskId) async {
    await _tasksCollection.doc(taskId).delete();
  }

  @override
  Future<List<TodoTask>> getTasks() async {
    try {
      final snapshot = await _tasksCollection.get();
      return snapshot.docs.map((doc) {
        return TodoTask.fromMap(doc.data() as Map<String, dynamic>);
      }).toList();
    } catch (e) {
      print("Fejl ved hentning af opgaver: $e");
      return [];
    }
  }

  // --- CATEGORIES ---

  @override
  Future<List<String>> getCategories() async {
    try {
      final doc = await _userDoc.get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        if (data.containsKey('categories')) {
          return List<String>.from(data['categories']);
        }
      }
    } catch (e) {
      print("Fejl ved hentning af kategorier: $e");
    }
    // Default kategorier hvis intet findes
    return ['Generelt', 'Arbejde', 'Personlig', 'Studie', 'Dev', 'QA']; 
  }

  @override
  Future<void> addCategory(String category) async {
    await _userDoc.set({
      'categories': FieldValue.arrayUnion([category])
    }, SetOptions(merge: true));
  }

  // --- THEME SYNC ---

  @override
  Future<bool> getThemePreference() async {
    try {
      final doc = await _userDoc.get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        if (data.containsKey('isDarkMode')) {
          return data['isDarkMode'] as bool;
        }
      }
    } catch (e) {
      print("Fejl ved hentning af tema: $e");
    }
    return false; // Default: Light mode
  }

  @override
  Future<void> updateThemePreference(bool isDarkMode) async {
    await _userDoc.set({
      'isDarkMode': isDarkMode
    }, SetOptions(merge: true));
  }

  // --- POMODORO SETTINGS ---

  @override
  Future<PomodoroSettings> getPomodoroSettings() async {
    try {
      final doc = await _userDoc.get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        if (data.containsKey('pomodoroSettings')) {
          return PomodoroSettings.fromMap(data['pomodoroSettings']);
        }
      }
    } catch (e) {
      print("Fejl ved hentning af indstillinger: $e");
    }
    return PomodoroSettings(); // Returner default settings hvis intet gemt
  }

  @override
  Future<void> updatePomodoroSettings(PomodoroSettings settings) async {
    await _userDoc.set({
      'pomodoroSettings': settings.toMap()
    }, SetOptions(merge: true));
  }
}