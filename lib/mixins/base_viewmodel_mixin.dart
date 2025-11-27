// Fil: lib/mixins/base_viewmodel_mixin.dart
import 'package:flutter/material.dart';
import '../services/error_service.dart';

mixin BaseViewModelMixin on ChangeNotifier {
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Future<void> runSafe(Future<void> Function() action, {bool handleLoading = true}) async {
    if (handleLoading) {
      _isLoading = true;
      notifyListeners();
    }

    try {
      await action();
    } catch (e, stack) {
      ErrorService.show(e, stackTrace: stack);
    } finally {
      if (handleLoading) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }
}