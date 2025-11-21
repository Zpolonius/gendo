import 'dart:async';
import 'models.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

abstract class TaskRepository {
  Future<List<TodoTask>> getTasks();
  Future<void> addTask(TodoTask task);
  Future<void> updateTask(TodoTask task);
  Future<void> deleteTask(String id);
  
  // Nye metoder til kategorier
  Future<List<String>> getCategories();
  Future<void> addCategory(String category);
}

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

  // Standard kategorier (Genetiske/Defaults)
  final List<String> _categories = [
    'Generelt',
    'Arbejde',
    'Personlig',
    'Studie',
    'Dev',
    'QA',
  ];

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

  // Implementering af kategorier
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
}

class FirestoreTaskRepository implements TaskRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _userId;

  FirestoreTaskRepository(this._userId);

  CollectionReference<Map<String, dynamic>> get _tasksCollection =>
      _firestore.collection('users').doc(_userId).collection('tasks');

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
    // For simplicity, we can store categories in a separate document or collection.
    // Here, we'll just return a default list + any unique categories found in tasks.
    // A more robust solution would be to have a 'categories' collection.
    final snapshot = await _tasksCollection.get();
    final tasks = snapshot.docs.map((doc) => TodoTask.fromMap(doc.data())).toList();
    final taskCategories = tasks.map((t) => t.category).toSet();
    
    final defaultCategories = {
      'Generelt',
      'Arbejde',
      'Personlig',
      'Studie',
      'Dev',
      'QA',
    };
    
    return {...defaultCategories, ...taskCategories}.toList();
  }

  @override
  Future<void> addCategory(String category) async {
    // In this simple implementation, adding a category doesn't need to do anything 
    // explicit if we just derive them from tasks. 
    // However, to persist unused categories, we'd need a separate collection.
    // For now, we'll leave it as a no-op or implement a proper category store later.
  }
}