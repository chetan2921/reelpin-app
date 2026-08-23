import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Light unless the user has picked dark.
///
/// The app used to fall back to the system setting, so it opened dark for
/// anyone whose phone was dark — including people who had never expressed a
/// preference about the app itself. Light is now the default and dark is a
/// choice, which is why nothing here watches platform brightness any more.
class ThemeViewModel extends ChangeNotifier {
  ThemeViewModel({bool isDarkMode = false}) : _isDarkMode = isDarkMode;

  /// Reads the stored preference before the app is built, so the first frame
  /// is already the right theme.
  ///
  /// Left to [loadPreference], the first frame is painted light and corrected
  /// once the async read lands — one frame of white on every launch for anyone
  /// who chose dark. Warming the preferences store here also means the reads
  /// that follow it, onboarding's among them, come back off the cache.
  static Future<ThemeViewModel> restored() async {
    final prefs = await SharedPreferences.getInstance();
    return ThemeViewModel(isDarkMode: prefs.getBool(_themeKey) ?? false);
  }

  static const _themeKey = 'theme_mode_is_dark';

  bool _isDarkMode;

  bool get isDarkMode => _isDarkMode;

  ThemeMode get themeMode => _isDarkMode ? ThemeMode.dark : ThemeMode.light;

  IconData get themeIcon => isDarkMode ? Icons.dark_mode : Icons.light_mode;

  String get themeLabel => isDarkMode ? 'DARK' : 'LIGHT';

  String get nextThemeLabel =>
      isDarkMode ? 'SWITCH TO LIGHT' : 'SWITCH TO DARK';

  /// A stored `true` is someone who chose dark before this change, so their
  /// choice survives; everyone else lands on light.
  Future<void> loadPreference() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool(_themeKey) ?? false;
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    await setDarkMode(!isDarkMode);
  }

  Future<void> setDarkMode(bool value) async {
    _isDarkMode = value;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeKey, value);
  }
}
