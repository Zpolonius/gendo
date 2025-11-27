import 'dart:async';
import '../base_view_model.dart';
import '../../models.dart';
import '../../models/todo_list.dart';

/// Håndterer Lister, Opgaver, Kategorier og AI generering
mixin TaskMixin on BaseViewModel {
  // State
  List<TodoList> _lists = [];
  String? _activeListId;
  Map<String, List<TodoTask>> _tasksByList = {};
  List<String> _categories = [];

  // Getters
  List<TodoList> get lists => _lists;
  String? get activeListId => _activeListId;
  List<String> get categories => _categories;
  
  // Returnerer alle opgaver på tværs af lister (nyttigt til Pomodoro)
  List<TodoTask> get allTasks => _tasksByList.values.expand((x) => x).toList();
  
  // Returnerer opgaver for den aktive liste
  List<TodoTask> get currentTasks => 
      _activeListId != null ? (_tasksByList[_activeListId!] ?? []) : [];

  // --- DATA LOADING ---

  Future<void> loadTaskData() async {
    try {
      if (currentUser?.email != null) {
        await repository.checkPendingInvites(currentUser!.email!);
      }

      final results = await Future.wait([
        repository.getLists(),
        repository.getCategories(),
      ]);

      _lists = results[0] as List<TodoList>;
      _categories = results[1] as List<String>;

      // Sæt standard aktiv liste hvis ingen er valgt
      if (_activeListId == null && _lists.isNotEmpty) {
        _activeListId = _lists.first.id;
      }

      // Hent opgaver for hver liste
      for (var list in _lists) {
        final tasks = await repository.getTasks(list.id);
        _tasksByList[list.id] = tasks;
      }
    } catch (e) {
      handleError(e);
    }
  }
// --- SUBTASKS / STEPS LOGIK ---

  Future<void> addTaskStep(String taskId, String title) async {
    // 1. Find opgaven
    final taskIndex = allTasks.indexWhere((t) => t.id == taskId);
    if (taskIndex == -1) return;
    
    final task = allTasks[taskIndex];

    // 2. Opret nyt step
    final newStep = TaskStep(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
    );

    // 3. Opdater opgaven med det nye step
    // Vi laver en ny liste for at sikre immutability
    final updatedSteps = List<TaskStep>.from(task.steps)..add(newStep);
    final updatedTask = task.copyWith(steps: updatedSteps);

    // 4. Gem ændringen via vores eksisterende update metode
    await updateTaskDetails(updatedTask);
  }

  // Opdateret: Returnerer nu Future<bool> i stedet for Future<void>
  Future<bool> toggleTaskStep(String taskId, String stepId) async {
    final taskIndex = allTasks.indexWhere((t) => t.id == taskId);
    // Hvis opgaven ikke findes, returner false
    if (taskIndex == -1) return false;
    
    final task = allTasks[taskIndex];
    
    // 1. Find og opdater det specifikke step
    final updatedSteps = task.steps.map((step) {
      if (step.id == stepId) {
        return step.copyWith(isCompleted: !step.isCompleted);
      }
      return step;
    }).toList();

    // 2. Gem ændringerne
    final updatedTask = task.copyWith(steps: updatedSteps);
    await updateTaskDetails(updatedTask);

    // 3. Tjek om ALLE steps nu er færdige og returner resultatet
    // Returnerer true hvis listen ikke er tom, og alle elementer er completed
    return updatedSteps.isNotEmpty && updatedSteps.every((step) => step.isCompleted);
  }

  Future<void> deleteTaskStep(String taskId, String stepId) async {
    final taskIndex = allTasks.indexWhere((t) => t.id == taskId);
    if (taskIndex == -1) return;
    
    final task = allTasks[taskIndex];

    // Fjern steppet fra listen
    final updatedSteps = task.steps.where((step) => step.id != stepId).toList();
    
    final updatedTask = task.copyWith(steps: updatedSteps);
    await updateTaskDetails(updatedTask);
  }
  // --- LISTER ---

  void setActiveList(String listId) {
    _activeListId = listId;
    notifyListeners();
  }

  Future<void> createList(String title) async {
    if (currentUser == null) return;

    final newList = TodoList(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      ownerId: currentUser!.uid,
      memberIds: [currentUser!.uid],
      createdAt: DateTime.now(),
    );

    await repository.createList(newList);
    _lists.add(newList);
    _tasksByList[newList.id] = [];
    _activeListId = newList.id;
    notifyListeners();
  }

  Future<void> deleteList(String listId) async {
    await repository.deleteList(listId);
    _lists.removeWhere((l) => l.id == listId);
    _tasksByList.remove(listId);
    
    if (_activeListId == listId) {
      _activeListId = _lists.isNotEmpty ? _lists.first.id : null;
    }
    notifyListeners();
  }
  
  Future<void> inviteUser(String listId, String email) async {
    await repository.inviteUserByEmail(listId, email);
  }

  Future<List<Map<String, String>>> getListMembers(String listId) async {
    try {
      final list = _lists.firstWhere((l) => l.id == listId);
      return await repository.getMembersDetails(list.memberIds);
    } catch (e) {
      return [];
    }
  }

  Future<void> removeMember(String listId, String userId) async {
    await repository.removeUserFromList(listId, userId);
    // Vi reloader ikke alt her, men man burde optimalt set opdatere den enkelte liste
    // For nuværende er dette fint for at matche eksisterende funktionalitet.
  }

  // --- OPGAVER ---

 Future<String> addTask(
    String title, {
    String category = 'Generelt',
    String description = '',
    TaskPriority priority = TaskPriority.medium,
    DateTime? dueDate,
    String? listId,
    TaskRepeat repeat = TaskRepeat.never, // <--- Tilføj denne parameter
  }) async {
    final targetListId = listId ?? _activeListId;
    if (targetListId == null) return '';

    if (!_categories.contains(category)) await addNewCategory(category);
    
    final newId = DateTime.now().millisecondsSinceEpoch.toString();
    final newTask = TodoTask(
      id: newId,
      title: title,
      category: category,
      description: description,
      priority: priority,
      dueDate: dueDate,
      createdAt: DateTime.now(),
      listId: targetListId,
      repeat: repeat, // <--- Brug den her
    );

    await repository.addTask(newTask);
    if (_tasksByList[targetListId] == null) _tasksByList[targetListId] = [];
    _tasksByList[targetListId]!.add(newTask);
    notifyListeners();
    
    return newId;
  }
  Future<void> toggleTask(String taskId) async {
    for (var listId in _tasksByList.keys) {
      final index = _tasksByList[listId]!.indexWhere((t) => t.id == taskId);
      if (index != -1) {
        var task = _tasksByList[listId]![index];
        final updatedTask = task.copyWith(isCompleted: !task.isCompleted);
        
        await repository.updateTask(updatedTask);
        _tasksByList[listId]![index] = updatedTask;
        notifyListeners();
        return;
      }
    }
  }

  Future<void> updateTaskDetails(TodoTask task, {String? oldListId}) async {
    // Hvis oldListId er angivet og forskellig fra den nye, så er det en flytning
    if (oldListId != null && oldListId != task.listId) {
      // 1. Slet fra gammel liste DB
      await repository.deleteTask(oldListId, task.id);
      // 2. Opret i ny liste DB
      await repository.addTask(task);
      
      // 3. Opdater lokalt state
      if (_tasksByList.containsKey(oldListId)) {
        _tasksByList[oldListId]!.removeWhere((t) => t.id == task.id);
      }
      if (_tasksByList[task.listId] == null) _tasksByList[task.listId] = [];
      _tasksByList[task.listId]!.add(task);

    } else {
      // Almindelig opdatering
      await repository.updateTask(task);
      final list = _tasksByList[task.listId];
      if (list != null) {
        final index = list.indexWhere((t) => t.id == task.id);
        if (index != -1) {
          list[index] = task;
        }
      }
    }
    notifyListeners();
  }

  Future<void> deleteTask(String taskId) async {
    String? listIdFound;
    // Find hvilken liste opgaven tilhører
    for (var entry in _tasksByList.entries) {
      if (entry.value.any((t) => t.id == taskId)) {
        listIdFound = entry.key;
        break;
      }
    }
    
    if (listIdFound != null) {
      await repository.deleteTask(listIdFound, taskId);
      _tasksByList[listIdFound]!.removeWhere((t) => t.id == taskId);
      notifyListeners();
    }
  }

  // --- KATEGORIER & AI ---

  Future<void> addNewCategory(String category) async { 
    if (category.trim().isEmpty) return; 
    await repository.addCategory(category); 
    if (!_categories.contains(category)) { 
      _categories.add(category); 
      notifyListeners(); 
    } 
  }

  Future<void> generatePlanFromAI(String prompt) async { 
    setLoading(true);
    // Simuleret AI kald
    await Future.delayed(const Duration(seconds: 2)); 
    List<String> suggestions = ["Research: $prompt", "Planlægning: $prompt", "Udførsel: $prompt"]; 
    for (var taskTitle in suggestions) { 
      await addTask(taskTitle, category: 'AI Genereret'); 
    } 
    setLoading(false);
  }
}