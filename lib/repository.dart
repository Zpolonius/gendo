import 'models.dart';

abstract class TaskRepository {
  Future<List<TodoTask>> getTasks();
  Future<void> addTask(TodoTask task);
  Future<void> updateTask(TodoTask task);
  Future<void> deleteTask(String id);
}

class MockTaskRepository implements TaskRepository {
  final List<TodoTask> _tasks = [
    TodoTask(id: '1', title: 'Opsæt Flutter projekt', category: 'Dev', createdAt: DateTime.now()),
    TodoTask(id: '2', title: 'Test GenDo Dark Mode', category: 'QA', createdAt: DateTime.now()),
    TodoTask(id: '3', title: 'Køb snacks til kodning', category: 'Privat', isCompleted: true, createdAt: DateTime.now()),
  ];

  @override
  Future<List<TodoTask>> getTasks() async {
    await Future.delayed(const Duration(milliseconds: 400));
    return _tasks;
  }

  @override
  Future<void> addTask(TodoTask task) async {
    _tasks.add(task);
  }

  @override
  Future<void> updateTask(TodoTask task) async {
    final index = _tasks.indexWhere((t) => t.id == task.id);
    if (index != -1) {
      _tasks[index] = task;
    }
  }

  @override
  Future<void> deleteTask(String id) async {
    _tasks.removeWhere((t) => t.id == id);
  }
}