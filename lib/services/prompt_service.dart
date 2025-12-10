import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/prompt_model.dart';

// Interface for Dependency Inversion (SOLID)
abstract class IPromptRepository {
  Stream<List<PromptModel>> getPromptsStream();
  Future<void> addPrompt(PromptModel prompt);
  Future<void> updatePrompt(PromptModel prompt);
  Future<void> deletePrompt(String promptId);
  Future<String> optimizePrompt(String rawPrompt); // Future-proofing
}

class FirestorePromptService implements IPromptRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _userId;

  FirestorePromptService(this._userId);

  CollectionReference get _promptsCollection => 
      _db.collection('users').doc(_userId).collection('prompts');

  @override
  Stream<List<PromptModel>> getPromptsStream() {
    return _promptsCollection
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PromptModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  @override
  Future<void> addPrompt(PromptModel prompt) async {
    await _promptsCollection.doc(prompt.id).set(prompt.toMap());
  }

  @override
  Future<void> updatePrompt(PromptModel prompt) async {
    await _promptsCollection.doc(prompt.id).update(prompt.toMap());
  }

  @override
  Future<void> deletePrompt(String promptId) async {
    await _promptsCollection.doc(promptId).delete();
  }

  // --- AI FUTURE PROOFING ---
  @override
  Future<String> optimizePrompt(String rawPrompt) async {
    // TODO: Implementer API kald til OpenAI/Gemini her senere.
    // Lige nu simulerer vi en "tænkepause" og returnerer en mock.
    await Future.delayed(const Duration(seconds: 1)); 
    return "$rawPrompt\n\n[Optimized by AI: Gør denne prompt mere specifik og handlingsorienteret...]";
  }
}