import 'package:cloud_firestore/cloud_firestore.dart';
import '../models.dart';
import '../repository.dart';

class FirestoreService implements TaskRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _userId;

  FirestoreService(this._userId);

  // Collection reference
  CollectionReference get _tasksCollection => _db.collection('users').doc(_userId).collection('tasks');
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
    final snapshot = await _tasksCollection.get();
    return snapshot.docs.map((doc) {
      return TodoTask.fromMap(doc.data() as Map<String, dynamic>);
    }).toList();
  }

  // --- CATEGORIES ---

  @override
  Future<List<String>> getCategories() async {
    final doc = await _userDoc.get();
    if (doc.exists && doc.data() != null) {
      final data = doc.data() as Map<String, dynamic>;
      if (data.containsKey('categories')) {
        return List<String>.from(data['categories']);
      }
    }
    // Default categories if none exist
    return ['Generelt', 'Arbejde', 'Personlig', 'Studie', 'Dev', 'QA']; 
  }

  @override
  Future<void> addCategory(String category) async {
    await _userDoc.set({
      'categories': FieldValue.arrayUnion([category])
    }, SetOptions(merge: true));
  }
}
