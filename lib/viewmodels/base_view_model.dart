import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../repository.dart';
import '../services/notification_service.dart'; // Husk import

abstract class BaseViewModel extends ChangeNotifier {
  TaskRepository _repository;
  final NotificationService notificationService; // NYT FELT
  bool _isLoading = false;

  // Opdateret constructor der tager notificationService med
  BaseViewModel(this._repository, this.notificationService);

  // Getters
  TaskRepository get repository => _repository;
  bool get isLoading => _isLoading;
  User? get currentUser => FirebaseAuth.instance.currentUser;

  void updateRepository(TaskRepository newRepo) {
    _repository = newRepo;
  }

  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void handleError(dynamic e) {
    print("ViewModel Error: $e");
  }
}