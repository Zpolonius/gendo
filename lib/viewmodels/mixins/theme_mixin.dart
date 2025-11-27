import '../base_view_model.dart';

/// Håndterer appens tema (Dark/Light mode)
mixin ThemeMixin on BaseViewModel {
  bool _isDarkMode = false;

  bool get isDarkMode => _isDarkMode;

  Future<void> loadThemeData() async {
    try {
      _isDarkMode = await repository.getThemePreference();
    } catch (e) {
      handleError(e);
    }
  }

  void toggleTheme(bool isDark) {
    _isDarkMode = isDark;
    notifyListeners(); // Opdater UI med det samme
    repository.updateThemePreference(isDark); // Gem i baggrunden
  }
}