import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeViewModel extends ChangeNotifier {
  static const _themeKey = 'theme_mode_is_dark';

  bool _isDarkMode = true;

  bool get isDarkMode => _isDarkMode;

  ThemeMode get themeMode => _isDarkMode ? ThemeMode.dark : ThemeMode.light;

  IconData get themeIcon => _isDarkMode ? Icons.dark_mode : Icons.light_mode;

  String get themeLabel => _isDarkMode ? 'DARK' : 'LIGHT';

  String get nextThemeLabel =>
      _isDarkMode ? 'SWITCH TO LIGHT' : 'SWITCH TO DARK';

  Future<void> loadPreference() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool(_themeKey) ?? true;
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    await setDarkMode(!_isDarkMode);
  }

  Future<void> setDarkMode(bool value) async {
    _isDarkMode = value;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeKey, value);
  }
}
