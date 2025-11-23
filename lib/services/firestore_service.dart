import 'package:cloud_firestore/cloud_firestore.dart';
import '../models.dart';
import '../models/todo_list.dart';
import '../repository.dart';

class FirestoreService implements TaskRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _userId;

  FirestoreService(this._userId);

  CollectionReference get _listsCollection => _db.collection('lists');
  DocumentReference get _userDoc => _db.collection('users').doc(_userId);

  // --- HER RETTER DU STANDARD KATEGORIERNE ---
  // Disse vil altid blive vist for alle brugere.
  static const List<String> _defaultCategories = [
    'Generelt',
    'Arbejde',
    'Personlig',
    'Studie',
    'Indkøb',
    'Udvikling'
  ];

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
    } else {
      // Gem invitation hvis bruger ikke findes
      await _listsCollection.doc(listId).update({'pendingEmails': FieldValue.arrayUnion([email])});
    }
  }

  @override
  Future<void> checkPendingInvites(String email) async {
    final snapshot = await _listsCollection.where('pendingEmails', arrayContains: email).get();
    for (var doc in snapshot.docs) {
      await doc.reference.update({
        'memberIds': FieldValue.arrayUnion([_userId]),
        'pendingEmails': FieldValue.arrayRemove([email])
      });
    }
  }

  @override
  Future<void> removeUserFromList(String listId, String userIdToRemove) async {}

  // --- TASKS ---

  @override
  Future<List<TodoTask>> getTasks(String listId) async {
    final snapshot = await _listsCollection.doc(listId).collection('tasks').get();
    return snapshot.docs.map((doc) {
      return TodoTask.fromMap(doc.data()).copyWith(listId: listId); 
    }).toList();
  }

  @override
  Future<void> addTask(TodoTask task) async {
    if (task.listId.isEmpty) return;
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

  // --- KATEGORIER (SMART MERGE) ---

  @override
  Future<List<String>> getCategories() async {
    try {
      final doc = await _userDoc.get();
      
      // Vi bruger et Set for automatisk at undgå dubletter
      // Start med vores standard kategorier
      Set<String> allCategories = {..._defaultCategories};

      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        
        // Hent brugerens egne kategorier (hvis de findes)
        if (data.containsKey('customCategories')) {
          final custom = List<String>.from(data['customCategories']);
          allCategories.addAll(custom);
        }
        // Bagudkompatibilitet (hvis vi tidligere brugte 'categories' feltet)
        else if (data.containsKey('categories')) {
           final old = List<String>.from(data['categories']);
           allCategories.addAll(old);
        }
      }
      
      return allCategories.toList();

    } catch (e) {
      print("Fejl ved hentning af kategorier: $e");
      return _defaultCategories; // Fallback til standard hvis nettet fejler
    }
  }

  @override
  Future<void> addCategory(String category) async {
    // Hvis kategorien allerede er en standard, behøver vi ikke gemme den
    if (_defaultCategories.contains(category)) return;

    // Gem i 'customCategories' på brugeren
    await _userDoc.set({
      'customCategories': FieldValue.arrayUnion([category])
    }, SetOptions(merge: true));
  }

  // --- THEME & SETTINGS ---

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