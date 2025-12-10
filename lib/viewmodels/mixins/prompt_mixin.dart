import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../models/prompt_model.dart';
import '../../models.dart'; // TodoTask
import '../../services/prompt_service.dart';
import '../base_view_model.dart'; // Vigtigt: Importér din base

/// Mixin der håndterer al logik vedrørende Prompts.
/// 'on BaseViewModel' giver os adgang til user, isLoading osv.
mixin PromptMixin on BaseViewModel {
  
  // --- KONTRAKT ---
  // Disse metoder forventer vi findes i AppViewModel (fra TaskMixin)
  // Ved at definere dem her, fjerner vi de røde streger.
  String? get activeListId;
  Future<String> addTask(String title, {String description = '', String category = 'Generelt', String? listId});
  Future<void> updateTaskDetails(TodoTask task);

  // --- PROMPT STATE ---
  FirestorePromptService? _promptRepository;
  
  // Init kaldes fra AppViewModel's loadData
  void initPromptService() {
    if (currentUser != null) {
      _promptRepository = FirestorePromptService(currentUser!.uid);
    }
  }

  Stream<List<PromptModel>> get promptsStream {
    if (_promptRepository == null) return const Stream.empty();
    return _promptRepository!.getPromptsStream();
  }

  // --- LOGIK: Opret opgave fra Prompt ---
  Future<void> createTodoFromPrompt(PromptModel prompt, {String? targetListId}) async {
    setLoading(true); // Kalder BaseViewModel's metode
    
    try {
      final descriptionBuilder = StringBuffer();
      descriptionBuilder.writeln(prompt.content);
      
      if (prompt.tags.isNotEmpty) {
        descriptionBuilder.writeln("\nTags: ${prompt.tags.join(', ')}");
      }

      await addTask(
        prompt.title,
        description: descriptionBuilder.toString(),
        category: 'AI Prompts',
        listId: targetListId ?? activeListId,
      );
      
    } catch (e) {
      print("Fejl ved oprettelse fra prompt: $e");
    } finally {
      setLoading(false);
    }
  }

  // --- LOGIK: Vedhæft Prompt til Opgave ---
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
      
      if (prompt.tags.isNotEmpty) {
        sb.writeln("\nTags: ${prompt.tags.join(', ')}");
      }

      final updatedTask = task.copyWith(
        description: sb.toString(),
      );

      await updateTaskDetails(updatedTask);
      
    } catch (e) {
      print("Fejl ved vedhæftning: $e");
    } finally {
      setLoading(false);
    }
  }

  // --- LOGIK: AI Optimering ---
  Future<String> optimerPromptText(String currentText) async {
    if (_promptRepository == null) return currentText;
    
    setLoading(true);
    try {
      final result = await _promptRepository!.optimizePrompt(currentText);
      return result;
    } catch (e) {
      return currentText;
    } finally {
      setLoading(false);
    }
  }
  
  // --- CRUD WRAPPERS ---
  Future<void> addPrompt(PromptModel prompt) async => await _promptRepository?.addPrompt(prompt);
  Future<void> updatePrompt(PromptModel prompt) async => await _promptRepository?.updatePrompt(prompt);
  Future<void> deletePrompt(String promptId) async => await _promptRepository?.deletePrompt(promptId);
}