import 'package:flutter/material.dart';
import '../mixins/base_viewmodel_mixin.dart';

/// En dedikeret ViewModel til at håndtere fejl-logik.
/// Denne klasse bruger [BaseViewModelMixin] for at få adgang til 'runSafe' og 'isLoading'.
class ErrorViewModel extends ChangeNotifier with BaseViewModelMixin {
  
  // Eksempel: Vi kan gemme den sidste fejl for at vise den i et "Debug" panel
  String? _lastErrorMessage;
  String? get lastErrorMessage => _lastErrorMessage;

  /// Metode til at fremprovokere en fejl (til test af ErrorService)
  Future<void> triggerTestError() async {
    // Vi bruger 'runSafe' fra mixin'et.
    // Hvis koden indeni fejler, fanges den automatisk af mixin'et og sendes til ErrorService.
    await runSafe(() async {
      // Simuler ventetid for at se loading-spinner
      await Future.delayed(const Duration(seconds: 1));
      
      // Kast en fejl med vilje
      throw Exception("Dette er en test-fejl fra ErrorViewModel!");
    }, handleLoading: false);
  }

  /// Eksempel på en metode der IKKE viser loading spinner, men håndterer fejl
  Future<void> logSilentError() async {
    await runSafe(
      () async {
        await Future.delayed(const Duration(milliseconds: 500));
        throw Exception("Silent error (ingen spinner vises)");
      },
      handleLoading: false, // <-- Vi slår loading-state fra her
    );
  }

  // Metode til at rydde fejl-historik (hvis vi implementerede en liste)
  void clearErrors() {
    _lastErrorMessage = null;
    notifyListeners();
  }
}