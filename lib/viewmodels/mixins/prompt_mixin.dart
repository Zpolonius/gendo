import 'dart:async';
import '../../models/prompt_model.dart';
import '../../models.dart';
import '../../services/prompt_service.dart';
import '../base_view_model.dart'; 

mixin PromptMixin on BaseViewModel {
  // Kontrakt
  String? get activeListId;
  Future<String> addTask(String title, {String description = '', String category = 'Generelt', String? listId});
  Future<void> updateTaskDetails(TodoTask task);

  FirestorePromptService? _promptRepository;

  void initPromptService() {
    if (currentUser != null) {
      _promptRepository = FirestorePromptService(currentUser!.uid);
      print("PromptService initialiseret for bruger: ${currentUser!.uid}");
    } else {
      print("Advarsel: Forsøgte initPromptService, men ingen bruger fundet.");
    }
  }

  Stream<List<PromptModel>> get promptsStream {
    // Sikkerhedscheck: Prøv at init hvis den er null men vi har en bruger
    if (_promptRepository == null && currentUser != null) {
      initPromptService();
    }
    
    if (_promptRepository == null) {
      return const Stream.empty();
    }
    return _promptRepository!.getPromptsStream();
  }

  // --- SAFE WRAPPERS ---
  
  Future<void> addPrompt(PromptModel prompt) async {
    // LØSNING PÅ "INTET SKER":
    if (_promptRepository == null) {
      initPromptService();
      if (_promptRepository == null) {
        throw Exception("Du skal være logget ind for at gemme prompts.");
      }
    }
    await _promptRepository!.addPrompt(prompt);
  }

  Future<void> updatePrompt(PromptModel prompt) async {
    if (_promptRepository != null) await _promptRepository!.updatePrompt(prompt);
  }

  Future<void> deletePrompt(String promptId) async {
    if (_promptRepository != null) await _promptRepository!.deletePrompt(promptId);
  }

  // ... (Dine createTodoFromPrompt, attachPromptToTask og optimerPromptText metoder forbliver uændrede) ...
  Future<void> createTodoFromPrompt(PromptModel prompt, {String? targetListId}) async {
    setLoading(true);
    try {
      final descriptionBuilder = StringBuffer();
      descriptionBuilder.writeln(prompt.content);
      if (prompt.tags.isNotEmpty) descriptionBuilder.writeln("\nTags: ${prompt.tags.join(', ')}");

      await addTask(
        prompt.title,
        description: descriptionBuilder.toString(),
        category: 'AI Prompts',
        listId: targetListId ?? activeListId,
      );
    } catch (e) {
      print("Fejl ved create: $e");
    } finally {
      setLoading(false);
    }
  }

  Future<void> attachPromptToTask(TodoTask task, PromptModel prompt) async {
    setLoading(true);
    try {
      String currentDesc = task.description;
      final sb = StringBuffer();
      if (currentDesc.isNotEmpty) {
        sb.writeln(currentDesc);
        sb.writeln("\n--- 🤖 Vedhæftet Prompt: ${prompt.title} ---");
      } else {
        sb.writeln("--- 🤖 Vedhæftet Prompt: ${prompt.title} ---");
      }
      sb.writeln(prompt.content);
      if (prompt.tags.isNotEmpty) sb.writeln("\nTags: ${prompt.tags.join(', ')}");

      final updatedTask = task.copyWith(description: sb.toString());
      await updateTaskDetails(updatedTask);
    } catch (e) {
      print("Fejl ved attach: $e");
    } finally {
      setLoading(false);
    }
  }

  Future<String> optimerPromptText(String currentText) async {
    if (_promptRepository == null) initPromptService(); // Prøv init igen
    if (_promptRepository == null) return currentText;
    
    setLoading(true);
    try {
      return await _promptRepository!.optimizePrompt(currentText);
    } catch (e) {
      return currentText;
    } finally {
      setLoading(false);
    }
  }
}