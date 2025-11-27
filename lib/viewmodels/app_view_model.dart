import '../repository.dart';
import '../services/notification_service.dart'; // Husk import
import 'base_view_model.dart';
import 'mixins/theme_mixin.dart';
import 'mixins/task_mixin.dart';
import 'mixins/pomodoro_mixin.dart';

export 'mixins/pomodoro_mixin.dart' show TimerStatus;
export '../models.dart';
export '../models/todo_list.dart';

class AppViewModel extends BaseViewModel with ThemeMixin, TaskMixin, PomodoroMixin {
  
  // Opdateret constructor: Nu med 2 argumenter
  AppViewModel(TaskRepository repository, NotificationService notificationService) 
      : super(repository, notificationService) {
    loadData();
  }

  @override
  void updateRepository(TaskRepository repository) {
    super.updateRepository(repository);
    loadData();
  }

  Future<void> loadData() async {
    setLoading(true);
    await Future.wait([
      loadTaskData(),
      loadThemeData(),
      loadPomodoroData(),
    ]);
    setLoading(false);
  }
}