import 'package:cloud_firestore/cloud_firestore.dart';
import '../models.dart';
import '../models/todo_list.dart'; // Husk denne
import '../repository.dart';

class FirestoreService implements TaskRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _userId;

  FirestoreService(this._userId);

  CollectionReference get _listsCollection => _db.collection('lists');
  DocumentReference get _userDoc => _db.collection('users').doc(_userId);

  // --- LISTER ---
  @override
  Future<List<TodoList>> getLists() async {
    final snapshot = await _listsCollection.where('memberIds', arrayContains: _userId).get();
    return snapshot.docs.map((doc) => TodoList.fromMap(doc.data() as Map<String, dynamic>)).toList();
  }

  @override
  Future<void> createList(TodoList list) async {
    final members = [...list.memberIds];
    if (!members.contains(_userId)) members.add(_userId);
    final listData = list.toMap();
    listData['memberIds'] = members;
    await _listsCollection.doc(list.id).set(listData);
  }

  @override
  Future<void> deleteList(String listId) async {
    final doc = await _listsCollection.doc(listId).get();
    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['ownerId'] == _userId) {
        await _listsCollection.doc(listId).delete();
      }
    }
  }

  @override
  Future<void> inviteUserByEmail(String listId, String email) async {
    final userSnapshot = await _db.collection('users').where('email', isEqualTo: email).limit(1).get();
    if (userSnapshot.docs.isNotEmpty) {
      final userIdToInvite = userSnapshot.docs.first.id;
      await _listsCollection.doc(listId).update({'memberIds': FieldValue.arrayUnion([userIdToInvite])});
    }
  }

  @override
  Future<void> removeUserFromList(String listId, String userIdToRemove) async {
     // Implementer logik hvis nødvendigt
  }

  // --- TASKS (Med List ID) ---
  @override
  Future<List<TodoTask>> getTasks(String listId) async {
    final snapshot = await _listsCollection.doc(listId).collection('tasks').get();
    return snapshot.docs.map((doc) {
      var task = TodoTask.fromMap(doc.data());
      return task.copyWith(listId: listId); 
    }).toList();
  }

  @override
  Future<void> addTask(TodoTask task) async {
    if (task.listId.isEmpty) return; // Fejlhåndtering
    await _listsCollection.doc(task.listId).collection('tasks').doc(task.id).set(task.toMap());
  }

  @override
  Future<void> updateTask(TodoTask task) async {
    if (task.listId.isEmpty) return;
    await _listsCollection.doc(task.listId).collection('tasks').doc(task.id).update(task.toMap());
  }

  @override
  Future<void> deleteTask(String listId, String taskId) async {
    await _listsCollection.doc(listId).collection('tasks').doc(taskId).delete();
  }

  // --- ANDET ---
  @override
  Future<List<String>> getCategories() async {
    final doc = await _userDoc.get();
    if (doc.exists && doc.data() != null) {
      final data = doc.data() as Map<String, dynamic>;
      if (data.containsKey('categories')) return List<String>.from(data['categories']);
    }
    return ['Generelt', 'Arbejde', 'Personlig', 'Studie', 'Dev', 'QA']; 
  }

  @override
  Future<void> addCategory(String category) async {
    await _userDoc.set({'categories': FieldValue.arrayUnion([category])}, SetOptions(merge: true));
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

  @override
  Future<PomodoroSettings> getPomodoroSettings() async {
    final doc = await _userDoc.get();
    if (doc.exists && (doc.data() as Map<String, dynamic>).containsKey('pomodoroSettings')) {
      return PomodoroSettings.fromMap((doc.data() as Map<String, dynamic>)['pomodoroSettings']);
    }
    return PomodoroSettings();
  }

  @override
  Future<void> updatePomodoroSettings(PomodoroSettings settings) async {
    await _userDoc.set({'pomodoroSettings': settings.toMap()}, SetOptions(merge: true));
  }
}