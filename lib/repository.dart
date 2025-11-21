import 'dart:async';
import 'models.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Interface: Definerer HVAD vi kan gøre (kontrakt)
abstract class TaskRepository {
  // Opgaver
  Future<List<TodoTask>> getTasks();
  Future<void> addTask(TodoTask task);
  Future<void> updateTask(TodoTask task);
  Future<void> deleteTask(String id);
  
  // Kategorier
  Future<List<String>> getCategories();
  Future<void> addCategory(String category);

  // Tema (Disse manglede i din version)
  Future<bool> getThemePreference();
  Future<void> updateThemePreference(bool isDarkMode);
}

// Mock Implementation
class MockTaskRepository implements TaskRepository {
  final List<TodoTask> _tasks = [
    TodoTask(
      id: '1', 
      title: 'Opsæt Flutter projekt', 
      category: 'Dev', 
      description: 'Husk at inkludere Provider og Google Fonts i pubspec.yaml.',
      priority: TaskPriority.high,
      createdAt: DateTime.now()
    ),
    TodoTask(
      id: '2', 
      title: 'Test GenDo Dark Mode', 
      category: 'QA', 
      description: 'Tjek kontrasten på den lilla farve i dark mode. Den skal være blid for øjnene.',
      priority: TaskPriority.medium,
      dueDate: DateTime.now().add(const Duration(days: 2)),
      createdAt: DateTime.now()
    ),
    TodoTask(
      id: '3', 
      title: 'Køb snacks til kodning', 
      category: 'Personlig', 
      isCompleted: true, 
      priority: TaskPriority.low,
      createdAt: DateTime.now()
    ),
  ];

  final List<String> _categories = [
    'Generelt',
    'Arbejde',
    'Personlig',
    'Studie',
    'Dev',
    'QA',
  ];

  bool _isDarkMode = false; // Mock state for tema

  @override
  Future<List<TodoTask>> getTasks() async {
    await Future.delayed(const Duration(milliseconds: 400));
    return List.from(_tasks);
  }

  @override
  Future<void> addTask(TodoTask task) async {
    _tasks.add(task);
  }

  @override
  Future<void> updateTask(TodoTask task) async {
    final index = _tasks.indexWhere((t) => t.id == task.id);
    if (index != -1) {
      _tasks[index] = task;
    }
  }

  @override
  Future<void> deleteTask(String id) async {
    _tasks.removeWhere((t) => t.id == id);
  }

  @override
  Future<List<String>> getCategories() async {
    return List.from(_categories);
  }

  @override
  Future<void> addCategory(String category) async {
    if (!_categories.contains(category)) {
      _categories.add(category);
    }
  }

  // Implementering af tema metoder i Mock
  @override
  Future<bool> getThemePreference() async {
    return _isDarkMode;
  }

  @override
  Future<void> updateThemePreference(bool isDarkMode) async {
    _isDarkMode = isDarkMode;
  }
}

// (Valgfrit: Hvis du stadig har FirestoreTaskRepository i denne fil, skal den også opdateres, 
// men da du bruger firestore_service.dart nu, er denne klasse teknisk set overflødig her. 
// Jeg opdaterer den dog for en sikkerheds skyld, så filen er fejlfri).
class FirestoreTaskRepository implements TaskRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _userId;

  FirestoreTaskRepository(this._userId);

  CollectionReference<Map<String, dynamic>> get _tasksCollection =>
      _firestore.collection('users').doc(_userId).collection('tasks');
  
  DocumentReference get _userDoc => _firestore.collection('users').doc(_userId);

  @override
  Future<List<TodoTask>> getTasks() async {
    final snapshot = await _tasksCollection.get();
    return snapshot.docs.map((doc) => TodoTask.fromMap(doc.data())).toList();
  }

  @override
  Future<void> addTask(TodoTask task) async {
    await _tasksCollection.doc(task.id).set(task.toMap());
  }

  @override
  Future<void> updateTask(TodoTask task) async {
    await _tasksCollection.doc(task.id).update(task.toMap());
  }

  @override
  Future<void> deleteTask(String id) async {
    await _tasksCollection.doc(id).delete();
  }

  @override
  Future<List<String>> getCategories() async {
    final doc = await _userDoc.get();
    if (doc.exists && doc.data() != null) {
      final data = doc.data() as Map<String, dynamic>;
      if (data.containsKey('categories')) {
        return List<String>.from(data['categories']);
      }
    }
    return ['Generelt', 'Arbejde', 'Personlig', 'Studie', 'Dev', 'QA'];
  }

  @override
  Future<void> addCategory(String category) async {
    await _userDoc.set({
      'categories': FieldValue.arrayUnion([category])
    }, SetOptions(merge: true));
  }

  @override
  Future<bool> getThemePreference() async {
    final doc = await _userDoc.get();
    if (doc.exists && (doc.data() as Map<String, dynamic>).containsKey('isDarkMode')) {
      return (doc.data() as Map<String, dynamic>)['isDarkMode'] as bool;
    }
    return false;
  }

  @override
  Future<void> updateThemePreference(bool isDarkMode) async {
    await _userDoc.set({'isDarkMode': isDarkMode}, SetOptions(merge: true));
  }
}