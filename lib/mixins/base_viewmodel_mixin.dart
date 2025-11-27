// Fil: lib/mixins/base_viewmodel_mixin.dart
import 'package:flutter/material.dart';
import '../services/error_service.dart';

mixin BaseViewModelMixin on ChangeNotifier {
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  /// Kører en handling sikkert med loading-state og fejlhåndtering.
  Future<void> runSafe(Future<void> Function() action, {required bool handleLoading}) async {
    _isLoading = true;
    notifyListeners();

    try {
      await action();
    } catch (e, stack) {
      ErrorService.show(e, stackTrace: stack);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}