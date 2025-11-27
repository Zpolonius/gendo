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
  
  // NYT: Et map der husker indstillingen for hver enkelt liste
  // Key = Liste ID, Value = true (vis) / false (skjul)
  final Map<String, bool> _listVisibilitySettings = {};

  // Getters
  List<TodoList> get lists => _lists;
  String? get activeListId => _activeListId;
  List<String> get categories => _categories;
  
  // Returnerer alle opgaver på tværs af lister
  List<TodoTask> get allTasks => _tasksByList.values.expand((x) => x).toList();
  
  // Returnerer opgaver for den aktive liste (filtreret)
  List<TodoTask> get currentTasks => getFilteredTasks(_activeListId);

  // --- FILTER LOGIK (OPDATERET) ---

  // Tjekker om en specifik liste viser færdige opgaver (Standard: false/skjul)
  bool showCompletedTasks(String listId) {
    return _listVisibilitySettings[listId] ?? false;
  }

  // Henter filtrerede opgaver baseret på listens unikke indstilling
  List<TodoTask> getFilteredTasks(String? listId) {
    if (listId == null) return [];
    
    final tasks = _tasksByList[listId] ?? [];
    
    // Tjek indstillingen for netop denne liste
    if (showCompletedTasks(listId)) {
      return tasks; // Vis alt
    }
    
    // Ellers skjul de færdige
    return tasks.where((t) => !t.isCompleted).toList();
  }

  // Opdateret toggle der kræver et listId
  void toggleShowCompletedTasks(String listId) {
    final currentSetting = showCompletedTasks(listId);
    _listVisibilitySettings[listId] = !currentSetting;
    notifyListeners();
  }

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

      if (_activeListId == null && _lists.isNotEmpty) {
        _activeListId = _lists.first.id;
      }

      for (var list in _lists) {
        final tasks = await repository.getTasks(list.id);
        _tasksByList[list.id] = tasks;
      }
    } catch (e) {
      handleError(e);
    }
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
    _listVisibilitySettings.remove(listId); // Ryd op i indstillinger
    
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
  }

  // --- OPGAVER ---

  Future<String> addTask(String title, {
    String category = 'Generelt', 
    String description = '', 
    TaskPriority priority = TaskPriority.medium, 
    DateTime? dueDate, 
    String? listId,
    TaskRepeat repeat = TaskRepeat.never,
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
      repeat: repeat,
    );

    await repository.addTask(newTask);
    if (_tasksByList[targetListId] == null) _tasksByList[targetListId] = [];
    _tasksByList[targetListId]!.add(newTask);
    
    if (dueDate != null) {
      await notificationService.scheduleTaskNotification(
        id: newTask.id.hashCode,
        title: "Deadline: $title",
        body: "Din opgave skal være færdig nu!",
        scheduledDate: dueDate,
      );
    }

    notifyListeners();
    return newId;
  }

  Future<void> toggleTask(String taskId) async {
    for (var listId in _tasksByList.keys) {
      final index = _tasksByList[listId]!.indexWhere((t) => t.id == taskId);
      if (index != -1) {
        var task = _tasksByList[listId]![index];
        final updatedTask = task.copyWith(isCompleted: !task.isCompleted);
        await updateTaskDetails(updatedTask);
        return;
      }
    }
  }

  Future<void> updateTaskDetails(TodoTask task, {String? oldListId}) async {
    if (oldListId != null && oldListId != task.listId) {
      await repository.deleteTask(oldListId, task.id);
      await repository.addTask(task);
      
      if (_tasksByList.containsKey(oldListId)) {
        _tasksByList[oldListId]!.removeWhere((t) => t.id == task.id);
      }
      if (_tasksByList[task.listId] == null) _tasksByList[task.listId] = [];
      _tasksByList[task.listId]!.add(task);

    } else {
      await repository.updateTask(task);
      final list = _tasksByList[task.listId];
      if (list != null) {
        final index = list.indexWhere((t) => t.id == task.id);
        if (index != -1) {
          list[index] = task;
        }
      }
    }

    if (task.isCompleted) {
      await notificationService.cancelNotification(task.id.hashCode);
    } else if (task.dueDate != null) {
      await notificationService.scheduleTaskNotification(
        id: task.id.hashCode,
        title: "Deadline: ${task.title}",
        body: "Din opgave skal være færdig nu!",
        scheduledDate: task.dueDate!,
      );
    } else {
      await notificationService.cancelNotification(task.id.hashCode);
    }

    notifyListeners();
  }

  Future<void> deleteTask(String taskId) async {
    String? listIdFound;
    for (var entry in _tasksByList.entries) {
      if (entry.value.any((t) => t.id == taskId)) {
        listIdFound = entry.key;
        break;
      }
    }
    
    if (listIdFound != null) {
      await repository.deleteTask(listIdFound, taskId);
      _tasksByList[listIdFound]!.removeWhere((t) => t.id == taskId);
      await notificationService.cancelNotification(taskId.hashCode);
      notifyListeners();
    }
  }

  // --- SUBTASKS / STEPS ---

  Future<bool> toggleTaskStep(String taskId, String stepId) async {
    final taskIndex = allTasks.indexWhere((t) => t.id == taskId);
    if (taskIndex == -1) return false;
    
    final task = allTasks[taskIndex];
    
    final updatedSteps = task.steps.map((step) {
      if (step.id == stepId) {
        return step.copyWith(isCompleted: !step.isCompleted);
      }
      return step;
    }).toList();

    final updatedTask = task.copyWith(steps: updatedSteps);
    await updateTaskDetails(updatedTask);

    return updatedSteps.isNotEmpty && updatedSteps.every((step) => step.isCompleted);
  }

  Future<void> addTaskStep(String taskId, String title) async {
    final taskIndex = allTasks.indexWhere((t) => t.id == taskId);
    if (taskIndex == -1) return;
    
    final task = allTasks[taskIndex];
    final newStep = TaskStep(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
    );
    final updatedSteps = List<TaskStep>.from(task.steps)..add(newStep);
    final updatedTask = task.copyWith(steps: updatedSteps);
    await updateTaskDetails(updatedTask);
  }

  Future<void> deleteTaskStep(String taskId, String stepId) async {
    final taskIndex = allTasks.indexWhere((t) => t.id == taskId);
    if (taskIndex == -1) return;
    
    final task = allTasks[taskIndex];
    final updatedSteps = task.steps.where((step) => step.id != stepId).toList();
    final updatedTask = task.copyWith(steps: updatedSteps);
    await updateTaskDetails(updatedTask);
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
    await Future.delayed(const Duration(seconds: 2)); 
    List<String> suggestions = ["Research: $prompt", "Planlægning: $prompt", "Udførsel: $prompt"]; 
    for (var taskTitle in suggestions) { 
      await addTask(taskTitle, category: 'AI Genereret'); 
    } 
    setLoading(false);
  }
}