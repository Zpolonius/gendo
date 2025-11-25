import 'dart:async';
import 'models.dart';
import 'models/todo_list.dart';

abstract class TaskRepository {
  // Opgaver
  Future<List<TodoTask>> getTasks(String listId);
  Future<void> addTask(TodoTask task);
  Future<void> updateTask(TodoTask task);
  Future<void> deleteTask(String listId, String taskId);
  
  // Lister
  Future<List<TodoList>> getLists();
  Future<void> createList(TodoList list);
  Future<void> deleteList(String listId);
  Future<void> updateList(TodoList list);
  
  // Medlemmer
  Future<void> inviteUserByEmail(String listId, String email);
  Future<void> removeUserFromList(String listId, String userIdToRemove);
  Future<void> checkPendingInvites(String email);
  Future<List<Map<String, String>>> getMembersDetails(List<String> memberIds);
  
  // NY: Sikrer at brugeren findes i databasen (Self-healing)
  Future<void> ensureUserDocument(String email);

  // Kategorier
  Future<List<String>> getCategories();
  Future<void> addCategory(String category);

  // Tema
  Future<bool> getThemePreference();
  Future<void> updateThemePreference(bool isDarkMode);

  // Pomodoro
  Future<PomodoroSettings> getPomodoroSettings();
  Future<void> updatePomodoroSettings(PomodoroSettings settings);
}

class MockTaskRepository implements TaskRepository {
  // Mock implementationer...
    @override Future<List<TodoTask>> getTasks(String listId) async => [];
  @override Future<void> addTask(TodoTask task) async {}
  @override Future<void> updateTask(TodoTask task) async {}
  @override Future<void> deleteTask(String listId, String taskId) async {}
  @override Future<List<TodoList>> getLists() async => [];
  @override Future<void> createList(TodoList list) async {}
  @override Future<void> deleteList(String listId) async {}
  @override Future<void> inviteUserByEmail(String listId, String email) async {}
  @override Future<void> removeUserFromList(String listId, String userIdToRemove) async {}
  @override Future<void> checkPendingInvites(String email) async {}
  @override Future<List<Map<String, String>>> getMembersDetails(List<String> memberIds) async => [];
  @override Future<void> updateList(TodoList list) async {}
  @override Future<void> ensureUserDocument(String email) async {} // Mock gør intet

  @override Future<List<String>> getCategories() async => ['Generelt'];
  @override Future<void> addCategory(String category) async {}
  @override Future<bool> getThemePreference() async => false;
  @override Future<void> updateThemePreference(bool isDarkMode) async {}
  @override Future<PomodoroSettings> getPomodoroSettings() async => PomodoroSettings();
  @override Future<void> updatePomodoroSettings(PomodoroSettings settings) async {}
}