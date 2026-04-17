import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeViewModel extends ChangeNotifier with WidgetsBindingObserver {
  static const _themeKey = 'theme_mode_is_dark';
  static const _themeOverrideKey = 'theme_mode_has_explicit_override';

  bool? _savedIsDarkMode;
  bool _hasExplicitOverride = false;

  ThemeViewModel() {
    WidgetsBinding.instance.addObserver(this);
  }

  bool get isDarkMode => _hasExplicitOverride
      ? (_savedIsDarkMode ?? _platformBrightness == Brightness.dark)
      : _platformBrightness == Brightness.dark;

  ThemeMode get themeMode => _hasExplicitOverride
      ? ((_savedIsDarkMode ?? false) ? ThemeMode.dark : ThemeMode.light)
      : ThemeMode.system;

  IconData get themeIcon => isDarkMode ? Icons.dark_mode : Icons.light_mode;

  String get themeLabel => isDarkMode ? 'DARK' : 'LIGHT';

  String get nextThemeLabel =>
      isDarkMode ? 'SWITCH TO LIGHT' : 'SWITCH TO DARK';

  Brightness get _platformBrightness =>
      WidgetsBinding.instance.platformDispatcher.platformBrightness;

  Future<void> loadPreference() async {
    final prefs = await SharedPreferences.getInstance();
    _hasExplicitOverride = prefs.getBool(_themeOverrideKey) ?? false;
    _savedIsDarkMode = _hasExplicitOverride ? prefs.getBool(_themeKey) : null;
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    await setDarkMode(!isDarkMode);
  }

  Future<void> setDarkMode(bool value) async {
    _hasExplicitOverride = true;
    _savedIsDarkMode = value;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeKey, value);
    await prefs.setBool(_themeOverrideKey, true);
  }

  @override
  void didChangePlatformBrightness() {
    if (!_hasExplicitOverride) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
