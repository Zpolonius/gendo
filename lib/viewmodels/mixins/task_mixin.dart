import 'dart:async';
import '../base_view_model.dart';
import '../../models.dart';
import '../../models/todo_list.dart';

/// Håndterer Lister, Opgaver, Kategorier og AI generering
mixin TaskMixin on BaseViewModel {
  // State
  List<TodoList> _lists = [];
  String? _activeListId;
  final Map<String, List<TodoTask>> _tasksByList = {};
  List<String> _categories = [];
  
  final Map<String, bool> _listVisibilitySettings = {};

  // Getters
  List<TodoList> get lists => _lists;
  String? get activeListId => _activeListId;
  List<String> get categories => _categories;
  
  List<TodoTask> get allTasks => _tasksByList.values.expand((x) => x).toList();
  List<TodoTask> get currentTasks => getFilteredTasks(_activeListId);

  // --- FILTER LOGIK ---

  bool showCompletedTasks(String listId) {
    return _listVisibilitySettings[listId] ?? false;
  }

  List<TodoTask> getFilteredTasks(String? listId) {
    if (listId == null) return [];
    final tasks = _tasksByList[listId] ?? [];
    if (showCompletedTasks(listId)) {
      return tasks; 
    }
    return tasks.where((t) => !t.isCompleted).toList();
  }

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
      notifyListeners(); // Vigtigt at opdatere UI efter load
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

    // Optimistic Update
    _lists.add(newList);
    _tasksByList[newList.id] = [];
    _activeListId = newList.id;
    notifyListeners();

    try {
      await repository.createList(newList);
    } catch (e) {
      // Revert ved fejl
      _lists.remove(newList);
      _tasksByList.remove(newList.id);
      if (_activeListId == newList.id) _activeListId = null;
      notifyListeners();
      handleError(e);
    }
  }

  Future<void> deleteList(String listId) async {
    // Backup til revert
    final listIndex = _lists.indexWhere((l) => l.id == listId);
    if (listIndex == -1) return;
    final listBackup = _lists[listIndex];
    final tasksBackup = _tasksByList[listId];
    final settingsBackup = _listVisibilitySettings[listId];

    // Optimistic Update
    _lists.removeAt(listIndex);
    _tasksByList.remove(listId);
    _listVisibilitySettings.remove(listId);
    
    if (_activeListId == listId) {
      _activeListId = _lists.isNotEmpty ? _lists.first.id : null;
    }
    notifyListeners();

    try {
      await repository.deleteList(listId);
    } catch (e) {
      // Revert
      _lists.insert(listIndex, listBackup);
      if (tasksBackup != null) _tasksByList[listId] = tasksBackup;
      if (settingsBackup != null) _listVisibilitySettings[listId] = settingsBackup;
      notifyListeners();
      handleError(e);
    }
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

  // --- OPGAVER (Optimistic Updates) ---

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

    // Optimistic Category update
    if (!_categories.contains(category)) {
       _categories.add(category);
       // Vi venter ikke på addNewCategory her, men kører den asynkront
       addNewCategory(category); 
    }
    
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

    // 1. Optimistic Update: Opdater lokalt state straks
    if (_tasksByList[targetListId] == null) _tasksByList[targetListId] = [];
    _tasksByList[targetListId]!.add(newTask);
    notifyListeners();

    // 2. Notifikationer (lokalt)
    if (dueDate != null) {
       await notificationService.scheduleTaskNotification(
        id: newTask.id.hashCode,
        title: "Deadline: $title",
        body: "Din opgave skal være færdig nu!",
        scheduledDate: dueDate,
      );
    }

    // 3. Kald Repository (Database)
    try {
      await repository.addTask(newTask);
    } catch (e) {
      // 4. Revert ved fejl
      _tasksByList[targetListId]!.removeWhere((t) => t.id == newId);
      notifyListeners();
      handleError(e);
    }
    
    return newId;
  }

  Future<void> toggleTask(String taskId) async {
    // Vi finder opgaven og kalder updateTaskDetails, som nu håndterer optimistic update
    for (var listId in _tasksByList.keys) {
      final task = _tasksByList[listId]!.firstWhere((t) => t.id == taskId, orElse: () => TodoTask(id: '', title: '', createdAt: DateTime.now(), listId: ''));
      if (task.id.isNotEmpty) {
        final updatedTask = task.copyWith(isCompleted: !task.isCompleted);
        await updateTaskDetails(updatedTask);
        return;
      }
    }
  }

  // Central metode til opdatering af opgaver - Nu med Optimistic UI
 // Central metode til opdatering af opgaver - Nu med Optimistic UI
  Future<void> updateTaskDetails(TodoTask task, {String? oldListId}) async {
    // Scenario 1: Flytning mellem lister
    if (oldListId != null && oldListId != task.listId) {
      // Backup - Vi bruger explicit typing og <TodoTask>[] for at undgå type-fejl
      final List<TodoTask> oldListTasks = _tasksByList[oldListId] != null 
          ? List<TodoTask>.from(_tasksByList[oldListId]!) 
          : <TodoTask>[];
          
      final List<TodoTask> newListTasks = _tasksByList[task.listId] != null 
          ? List<TodoTask>.from(_tasksByList[task.listId]!) 
          : <TodoTask>[];

      // Optimistic Update
      if (_tasksByList.containsKey(oldListId)) {
        _tasksByList[oldListId]!.removeWhere((t) => t.id == task.id);
      }
      if (_tasksByList[task.listId] == null) _tasksByList[task.listId] = [];
      _tasksByList[task.listId]!.add(task);
      notifyListeners();

      try {
        await repository.deleteTask(oldListId, task.id);
        await repository.addTask(task);
      } catch (e) {
        // Revert - Nu passer typerne, så denne linje fejler ikke
        _tasksByList[oldListId] = oldListTasks;
        _tasksByList[task.listId] = newListTasks;
        notifyListeners();
        handleError(e);
      }

    } else {
      // Scenario 2: Almindelig opdatering (samme liste)
      final list = _tasksByList[task.listId];
      if (list != null) {
        final index = list.indexWhere((t) => t.id == task.id);
        if (index != -1) {
          final originalTask = list[index];
          
          // Optimistic Update
          list[index] = task;
          notifyListeners();

          // Håndter notifikationer (asynkront, blokerer ikke UI flowet kritisk)
          if (task.isCompleted) {
            notificationService.cancelNotification(task.id.hashCode);
          } else if (task.dueDate != null) {
            notificationService.scheduleTaskNotification(
              id: task.id.hashCode,
              title: "Deadline: ${task.title}",
              body: "Din opgave skal være færdig nu!",
              scheduledDate: task.dueDate!,
            );
          } else {
            notificationService.cancelNotification(task.id.hashCode);
          }

          try {
            await repository.updateTask(task);
          } catch (e) {
            // Revert
            list[index] = originalTask;
            notifyListeners();
            handleError(e);
          }
        }
      }
    }
  }

  Future<void> deleteTask(String taskId) async {
    String? listIdFound;
    TodoTask? taskBackup;
    int? indexBackup;

    // Find opgaven og gem backup
    for (var entry in _tasksByList.entries) {
      final index = entry.value.indexWhere((t) => t.id == taskId);
      if (index != -1) {
        listIdFound = entry.key;
        indexBackup = index;
        taskBackup = entry.value[index];
        break;
      }
    }
    
    if (listIdFound != null && taskBackup != null) {
      // Optimistic Update: Fjern lokalt først
      _tasksByList[listIdFound]!.removeAt(indexBackup!);
      notifyListeners();
      
      notificationService.cancelNotification(taskId.hashCode);

      try {
        await repository.deleteTask(listIdFound, taskId);
      } catch (e) {
        // Revert
        _tasksByList[listIdFound]!.insert(indexBackup, taskBackup);
        notifyListeners();
        handleError(e);
      }
    }
  }

  // --- SUBTASKS / STEPS ---
  // Disse bruger nu den opdaterede 'updateTaskDetails', så de får automatisk optimistic behavior,
  // da 'updateTaskDetails' opdaterer UI'en før DB kaldet.

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
    await updateTaskDetails(updatedTask); // Denne er nu optimistic

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
    
    // Optimistic Update
    if (!_categories.contains(category)) { 
      _categories.add(category); 
      notifyListeners(); 
    } 
    
    try {
      await repository.addCategory(category); 
    } catch (e) {
      // Revert er sjældent nødvendigt her, men kan tilføjes hvis strengt
      print("Kunne ikke gemme kategori: $e");
    }
  }

  Future<void> generatePlanFromAI(String prompt) async { 
    setLoading(true);
    // AI er en "ventetid" operation, så her beholder vi loading state,
    // da vi ikke kan forudsige resultatet optimistisk.
    try {
      await Future.delayed(const Duration(seconds: 2)); // Simulerer API kald
      List<String> suggestions = ["Research: $prompt", "Planlægning: $prompt", "Udførsel: $prompt"]; 
      for (var taskTitle in suggestions) { 
        await addTask(taskTitle, category: 'AI Genereret'); 
      } 
    } catch (e) {
      handleError(e);
    } finally {
      setLoading(false);
    }
  }
}