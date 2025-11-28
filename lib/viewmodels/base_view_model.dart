import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../repository.dart'; // Tjek at stien passer
import '../services/notification_service.dart'; // Tjek at stien passer

abstract class BaseViewModel extends ChangeNotifier {
  TaskRepository _repository;
  final NotificationService notificationService;
  
  // Vi gemmer brugeren her internt
  User? _user;
  
  bool _isLoading = false;

  // Constructor tager user med (valgfri)
  BaseViewModel(this._repository, this.notificationService, {User? user}) : _user = user;

  // --- GETTERS ---
  TaskRepository get repository => _repository;
  bool get isLoading => _isLoading;
  
  // HER ER FIXET: Vi definerer 'currentUser' getteren, så task_mixin kan finde den.
  // Vi returnerer _user (den stabile bruger fra main) i stedet for FirebaseAuth.instance.currentUser
  User? get currentUser => _user; 

  // --- METODER ---
  void updateRepository(TaskRepository newRepo) {
    _repository = newRepo;
    notifyListeners();
  }

  void updateUser(User? user) {
    _user = user;
    notifyListeners();
  }

  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void handleError(dynamic e) {
    debugPrint("ViewModel Error: $e");
  }
}