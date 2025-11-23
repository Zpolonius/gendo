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

  static const List<String> _defaultCategories = [
    'Generelt', 'Arbejde', 'Personlig', 'Studie', 'Indkøb',
  ];

  // --- REPARATION AF DATA (NY) ---
  @override
  Future<void> ensureUserDocument(String email) async {
    // Tjek om dokumentet findes
    final doc = await _userDoc.get();
    if (!doc.exists) {
      // Hvis det mangler, opret det!
      await _userDoc.set({
        'email': email,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      }, SetOptions(merge: true));
      print("Reparerede bruger-dokument for $email");
    }
  }

  // --- MEDLEMS DETALJER (ROBUST) ---
  @override
  Future<List<Map<String, String>>> getMembersDetails(List<String> memberIds) async {
    if (memberIds.isEmpty) return [];
    
    List<Map<String, String>> members = [];
    
    for (var id in memberIds) {
      try {
        final doc = await _db.collection('users').doc(id).get();
        
        // Tjek om vi fandt data
        if (doc.exists && doc.data() != null && doc.data()!['email'] != null) {
          members.add({
            'id': id,
            'email': doc.data()!['email'] as String,
          });
        } else {
          // FALLBACK: Hvis profilen mangler, vis ID'et i stedet for at skjule medlemmet
          members.add({
            'id': id,
            'email': 'Bruger uden profil (ID: ${id.substring(0, 5)}...)',
          });
        }
      } catch (e) {
        print("Fejl ved opslag af $id: $e");
      }
    }
    return members;
  }

  // ... (Resten af filen skal være uændret fra før. Kopier venligst dine eksisterende metoder ind herunder) ...
  
  // For at koden virker komplet her, indsætter jeg de korte versioner, 
  // men du bør bruge den fulde version fra vores tidligere trin hvis du har lavet ændringer.

  @override Future<List<TodoList>> getLists() async {
    final snapshot = await _listsCollection.where('memberIds', arrayContains: _userId).get();
    return snapshot.docs.map((doc) => TodoList.fromMap(doc.data() as Map<String, dynamic>)).toList();
  }
  @override Future<void> createList(TodoList list) async {
    final members = [...list.memberIds];
    if (!members.contains(_userId)) members.add(_userId);
    final listData = list.toMap();
    listData['memberIds'] = members;
    await _listsCollection.doc(list.id).set(listData);
  }
  @override Future<void> deleteList(String listId) async {
    final doc = await _listsCollection.doc(listId).get();
    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['ownerId'] == _userId) await _listsCollection.doc(listId).delete();
    }
  }
  @override Future<void> inviteUserByEmail(String listId, String email) async {
    final userSnapshot = await _db.collection('users').where('email', isEqualTo: email).limit(1).get();
    if (userSnapshot.docs.isNotEmpty) {
      final userIdToInvite = userSnapshot.docs.first.id;
      await _listsCollection.doc(listId).update({'memberIds': FieldValue.arrayUnion([userIdToInvite])});
    } else {
      await _listsCollection.doc(listId).update({'pendingEmails': FieldValue.arrayUnion([email])});
    }
  }
  @override Future<void> checkPendingInvites(String email) async {
    final snapshot = await _listsCollection.where('pendingEmails', arrayContains: email).get();
    for (var doc in snapshot.docs) {
      await doc.reference.update({
        'memberIds': FieldValue.arrayUnion([_userId]),
        'pendingEmails': FieldValue.arrayRemove([email])
      });
    }
  }
  @override Future<void> removeUserFromList(String listId, String userIdToRemove) async {
     final doc = await _listsCollection.doc(listId).get();
     if (!doc.exists) return;
     final data = doc.data() as Map<String, dynamic>;
     final ownerId = data['ownerId'];
     if (ownerId == _userId || userIdToRemove == _userId) {
        if (userIdToRemove == ownerId) throw Exception("Ejeren kan ikke forlade listen");
        await _listsCollection.doc(listId).update({'memberIds': FieldValue.arrayRemove([userIdToRemove])});
     } else {
       throw Exception("Kun ejeren kan fjerne medlemmer");
     }
  }
  @override Future<List<TodoTask>> getTasks(String listId) async {
    final snapshot = await _listsCollection.doc(listId).collection('tasks').get();
    return snapshot.docs.map((doc) => TodoTask.fromMap(doc.data()).copyWith(listId: listId)).toList();
  }
  @override Future<void> addTask(TodoTask task) async {
    if (task.listId.isEmpty) return;
    await _listsCollection.doc(task.listId).collection('tasks').doc(task.id).set(task.toMap());
  }
  @override Future<void> updateTask(TodoTask task) async {
    if (task.listId.isEmpty) return;
    await _listsCollection.doc(task.listId).collection('tasks').doc(task.id).update(task.toMap());
  }
  @override Future<void> deleteTask(String listId, String taskId) async {
    await _listsCollection.doc(listId).collection('tasks').doc(taskId).delete();
  }
  @override Future<List<String>> getCategories() async {
    try {
      final doc = await _userDoc.get();
      Set<String> allCategories = {..._defaultCategories};
      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        if (data.containsKey('customCategories')) {
          allCategories.addAll(List<String>.from(data['customCategories']));
        } else if (data.containsKey('categories')) {
           allCategories.addAll(List<String>.from(data['categories']));
        }
      }
      return allCategories.toList();
    } catch (e) { return _defaultCategories; }
  }
  @override Future<void> addCategory(String category) async {
    if (_defaultCategories.contains(category)) return;
    await _userDoc.set({'customCategories': FieldValue.arrayUnion([category])}, SetOptions(merge: true));
  }
  @override Future<bool> getThemePreference() async {
    final doc = await _userDoc.get();
    if (doc.exists && (doc.data() as Map<String, dynamic>).containsKey('isDarkMode')) {
      return (doc.data() as Map<String, dynamic>)['isDarkMode'] as bool;
    }
    return false;
  }
  @override Future<void> updateThemePreference(bool isDarkMode) async {
    await _userDoc.set({'isDarkMode': isDarkMode}, SetOptions(merge: true));
  }
  @override Future<PomodoroSettings> getPomodoroSettings() async {
    final doc = await _userDoc.get();
    if (doc.exists && (doc.data() as Map<String, dynamic>).containsKey('pomodoroSettings')) {
      return PomodoroSettings.fromMap((doc.data() as Map<String, dynamic>)['pomodoroSettings']);
    }
    return PomodoroSettings();
  }
  @override Future<void> updatePomodoroSettings(PomodoroSettings settings) async {
    await _userDoc.set({'pomodoroSettings': settings.toMap()}, SetOptions(merge: true));
  }
}