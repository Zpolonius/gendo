import 'package:cloud_firestore/cloud_firestore.dart';
import '../models.dart';
import '../models/todo_list.dart';
import '../models/user_profile.dart'; // Husk import
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
  
  // --- HENT BRUGER PROFIL (NY) ---
  // Bruges til ProfileScreen
  Future<UserProfile?> getUserProfile() async {
    final doc = await _userDoc.get();
    if (doc.exists && doc.data() != null) {
      return UserProfile.fromMap(doc.data() as Map<String, dynamic>, _userId);
    }
    return null;
  }
  
  // --- OPDATER PROFIL (NY) ---
  Future<void> updateUserProfile(Map<String, dynamic> data) async {
    await _userDoc.update(data);
  }
  //scomplete status
@override
  Future<void> updateList(TodoList list) async {
    // Vi bruger toMap til at opdatere dokumentet. 
    // Dette opdaterer både titel, medlemmer og nu showCompleted.
    await _listsCollection.doc(list.id).update(list.toMap());
  }
  // --- MEDLEMS DETALJER (OPDATERET) ---
  // Nu henter vi Navn+Efternavn i stedet for email hvis muligt
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
          
          // Hvis vi har fornavn og efternavn, så brug det!
          if (data['firstName'] != null && data['lastName'] != null) {
            displayName = "${data['firstName']} ${data['lastName']}";
          }
          
          members.add({
            'id': id,
            'email': data['email'] as String, // Vi beholder email til identifikation
            'displayName': displayName,      // Det navn vi viser i UI
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

  // ... (RESTEN AF FILEN ER UÆNDRET. KOPIER DINE EKSISTERENDE METODER IND HER)
  // For at holde svaret kort, udelader jeg de metoder vi lavede sidst (getTasks, createList osv.),
  // da de ikke skal ændres. Du skal bare beholde dem.
  
  @override Future<void> ensureUserDocument(String email) async { /* ... */ }
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