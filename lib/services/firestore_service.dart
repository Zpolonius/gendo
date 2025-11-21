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

  // --- STANDARD KATEGORIER (Disse findes altid) ---
  static const List<String> _defaultCategories = [
    'Generelt',
    'Arbejde',
    'Personlig',
    'Studie',
    'Hobby',
    'Haster',
  ];

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

  // --- KATEGORIER (SMART MERGE) ---

  @override
  Future<List<String>> getCategories() async {
    try {
      final doc = await _userDoc.get();
      List<String> customCategories = [];

      // 1. Prøv at hente brugerens egne kategorier fra Firebase
      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        // Vi leder efter feltet 'customCategories' nu
        if (data.containsKey('customCategories')) {
          customCategories = List<String>.from(data['customCategories']);
        }
        // Bagudkompatibilitet: Hvis vi tidligere brugte 'categories', så tjek det også
        else if (data.containsKey('categories')) {
          customCategories = List<String>.from(data['categories']);
        }
      }

      // 2. Flet Standard + Custom
      // Vi bruger et Set for at fjerne dubletter automatisk
      final combinedSet = {..._defaultCategories, ...customCategories};
      
      return combinedSet.toList();

    } catch (e) {
      print("Fejl ved hentning af kategorier: $e");
      // Hvis nettet fejler, har vi i det mindste standard kategorierne!
      return _defaultCategories; 
    }
  }

  @override
  Future<void> addCategory(String category) async {
    // Vi tilføjer kun til 'customCategories' listen i databasen
    // Standard kategorierne er hardcoded og skal ikke gemmes
    
    if (_defaultCategories.contains(category)) {
      return; // Gør intet hvis det allerede er en standard kategori
    }

    await _userDoc.set({
      'customCategories': FieldValue.arrayUnion([category])
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
    return PomodoroSettings(); 
  }

  @override
  Future<void> updatePomodoroSettings(PomodoroSettings settings) async {
    await _userDoc.set({
      'pomodoroSettings': settings.toMap()
    }, SetOptions(merge: true));
  }
}