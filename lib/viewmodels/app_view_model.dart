
import '../repository.dart';

import 'base_view_model.dart';
import 'mixins/theme_mixin.dart';
import 'mixins/task_mixin.dart';
import 'mixins/pomodoro_mixin.dart';
import 'mixins/prompt_mixin.dart';

// Exports til resten af appen
export 'mixins/pomodoro_mixin.dart' show TimerStatus;
export '../models.dart';
export '../models/todo_list.dart';

class AppViewModel extends BaseViewModel with PromptMixin, ThemeMixin, TaskMixin, PomodoroMixin {
  
  // Constructor: Tager nu User? med som valgfri parameter
  AppViewModel(
    super.repository, 
    super.notificationService, 
    {super.user}
  ) {
    // Vi loader data med det samme
    loadData();
  }

  @override
  void updateRepository(TaskRepository newRepo) {
    super.updateRepository(newRepo);
    // Genindlæs data når repository skifter (f.eks. ved login)
    loadData();
  }

  Future<void> loadData() async {
    setLoading(true);
    try { 
       if (currentUser != null) {
        initPromptService(); // <-- Fra PromptMixin
      }
      await Future.wait([
        loadTaskData(),    // Fra TaskMixin
        loadThemeData(),   // Fra ThemeMixin
        loadPomodoroData(),// Fra PomodoroMixin
      ]);
    } catch (e) {
      handleError(e);
    }
    setLoading(false);
  }
}