import 'package:cloud_firestore/cloud_firestore.dart';
import '../models.dart';
import '../models/todo_list.dart';
import '../models/user_profile.dart';
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
  
  // --- HENT BRUGER PROFIL ---
  Future<UserProfile?> getUserProfile() async {
    final doc = await _userDoc.get();
    if (doc.exists && doc.data() != null) {
      return UserProfile.fromMap(doc.data() as Map<String, dynamic>, _userId);
    }
    return null;
  }
  
  // --- OPDATER PROFIL (REDIGERING) ---
  // Vi opdaterer kun de felter, der er tilladt at ændre i profilen
  Future<void> updateUserProfile(UserProfile updatedProfile) async {
    await _userDoc.update({
      'firstName': updatedProfile.firstName,
      'lastName': updatedProfile.lastName,
      'phoneNumber': updatedProfile.phoneNumber,
      'company': updatedProfile.company,
      'country': updatedProfile.country,
    });
  }

  // --- SLET AL BRUGERDATA (DATA CLEANUP) ---
  // Denne metode kaldes før Auth-sletning for at undgå "orphaned data"
  Future<void> deleteUserData() async {
    try {
      // 1. Hent alle lister brugeren er relateret til
      final lists = await getLists();
      
      for (var list in lists) {
        if (list.ownerId == _userId) {
          // Hvis brugeren ejer listen -> Slet hele listen og dens opgaver
          await deleteList(list.id);
        } else {
          // Hvis brugeren kun er medlem -> Fjern dem fra listen
          await removeUserFromList(list.id, _userId);
        }
      }

      // 2. Slet brugerens profil-dokument
      await _userDoc.delete();
      
    } catch (e) {
      // Log fejl, men lad os prøve at fortsætte eller kaste videre
      print("Fejl under sletning af brugerdata: $e");
      rethrow;
    }
  }

  // --- OPDATERET: SLET LISTE + TASKS ---
  // Firestore sletter IKKE subcollections (tasks) automatisk. Det skal vi gøre manuelt.
  @override 
  Future<void> deleteList(String listId) async {
    final docRef = _listsCollection.doc(listId);
    final doc = await docRef.get();
    
    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>;
      
      // Sikkerhedstjek: Kun ejeren må slette
      if (data['ownerId'] == _userId) {
        
        // 1. Slet alle tasks i sub-collection først (Batch write for performance)
        final tasksSnapshot = await docRef.collection('tasks').get();
        final batch = _db.batch();
        
        for (var taskDoc in tasksSnapshot.docs) {
          batch.delete(taskDoc.reference);
        }
        
        // Udfør task-sletning
        await batch.commit();

        // 2. Slet selve listen
        await docRef.delete();
      }
    }
  }

  // --- MEDLEMS DETALJER ---
  @override
  Future<List<Map<String, String>>> getMembersDetails(List<String> memberIds) async {
    if (memberIds.isEmpty) return [];
    
    List<Map<String, String>> members = [];
    
    for (var id in memberIds) {
      try {
        final doc = await _db.collection('users').doc(id).get();
        
        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          String displayName = data['email'] ?? 'Ukendt';
          
          if (data['firstName'] != null && data['lastName'] != null) {
            displayName = "${data['firstName']} ${data['lastName']}";
          }
          
          members.add({
            'id': id,
            'email': data['email'] as String,
            'displayName': displayName,
          });
        } else {
          members.add({
            'id': id,
            'email': 'Ukendt',
            'displayName': 'Bruger uden profil',
          });
        }
      } catch (e) {
        print("Fejl ved opslag af $id: $e");
      }
    }
    return members;
  }

  @override Future<void> ensureUserDocument(String email) async { /* ... */ }

  //lister
  @override Future<List<TodoList>> getLists() async {
    final snapshot = await _listsCollection.where('memberIds', arrayContains: _userId).orderBy('sortOrder', descending: false).get();
    final lists = snapshot.docs.map((doc) => TodoList.fromMap(doc.data() as Map<String, dynamic>)).toList();
Future<void> updateListsOrder(List<TodoList> lists) async {
    final batch = _db.batch();

    for (var list in lists) {
      final docRef = _listsCollection.doc(list.id);
      // Vi opdaterer KUN sortOrder feltet for at spare båndbredde
      batch.update(docRef, {'sortOrder': list.sortOrder});
    }

    await batch.commit();
  }
     
    // Vi sorterer manuelt her, da Firestore ikke kan lave "orderBy" på felter der ikke er med i "where" claues 
    // uden komplekse composite indexes, som kan fejle uden opsætning. 
    // Dette er sikkert for små/mellemstore mængder data.
    lists.sort((a, b)=> a.createdAt.compareTo(b.createdAt));
    return lists;
    
  }
  @override Future<void> createList(TodoList list) async {
    final members = [...list.memberIds];
    if (!members.contains(_userId)) members.add(_userId);
    final listData = list.toMap();
    listData['memberIds'] = members;
    await _listsCollection.doc(list.id).set(listData);
  }

  @override
  Future<void> updateList(TodoList list) async {
    await _listsCollection.doc(list.id).update(list.toMap());
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
     } else { throw Exception("Kun ejeren kan fjerne medlemmer"); }
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