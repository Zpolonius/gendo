import 'package:flutter/foundation.dart';
import '../models.dart';
import '../repository.dart';
import '../services/notification_service.dart';

/// En Mixin der håndterer logikken for gentagende opgaver.
/// Den kræver at klassen der bruger den er en [ChangeNotifier]
/// og stiller visse services til rådighed.
mixin RecurringTaskHandler on ChangeNotifier {
  
  // Kontrakt: ViewModel skal udstille disse til mixin'en
  TaskRepository get repository;
  NotificationService get notificationService;
  Map<String, List<TodoTask>> get tasksByList;

  /// Håndterer når en gentagende opgave markeres som færdig.
  /// I stedet for at afslutte den, flyttes den til næste dato og nulstilles.
  Future<void> handleRecurringTaskCompletion(TodoTask task, String listId, int index) async {
    DateTime baseDate = task.dueDate ?? DateTime.now();
    DateTime nextDate;

    // 1. Beregn næste dato baseret på frekvens
    switch (task.repeat) {
      case TaskRepeat.daily:
        nextDate = baseDate.add(const Duration(days: 1));
        break;
      case TaskRepeat.weekly:
        nextDate = baseDate.add(const Duration(days: 7));
        break;
      case TaskRepeat.monthly:
        // Simpel månedlig logik (d. 15. i denne måned -> d. 15. i næste)
        // Edge cases som d. 31. jan -> 28. feb håndteres af DateTime automatisk (til 2./3. marts),
        // men for en simpel app er dette ofte fint.
        nextDate = DateTime(baseDate.year, baseDate.month + 1, baseDate.day);
        break;
      case TaskRepeat.never:
        return; // Burde ikke ske, men sikring
    }

    // 2. Nulstil eventuelle underopgaver (steps), så de er klar til næste gang
    final resetSteps = task.steps.map((s) => s.copyWith(isCompleted: false)).toList();

    // 3. Opret den opdaterede opgave
    final updatedTask = task.copyWith(
      dueDate: nextDate,
      isCompleted: false, // Forbliver "ikke færdig" men flyttet
      steps: resetSteps,  // Nulstillede steps
    );

    // 4. Gem i databasen
    await repository.updateTask(updatedTask);
    
    // 5. Opdater lokalt state
    if (tasksByList.containsKey(listId) && tasksByList[listId]!.length > index) {
       tasksByList[listId]![index] = updatedTask;
    }
    
    // 6. Opdater notifikationer
    // Fjern den gamle (hvis ID var baseret på hash/id) og planlæg ny
    notificationService.cancelNotification(task.hashCode); 
    
    await notificationService.scheduleTaskNotification(
      id: updatedTask.hashCode,
      title: "Deadline: ${updatedTask.title}",
      body: updatedTask.description.isNotEmpty ? updatedTask.description : "Gentagende opgave",
      scheduledDate: nextDate,
    );

    // 7. Fortæl UI at der er sket ændringer
    notifyListeners();
  }
}