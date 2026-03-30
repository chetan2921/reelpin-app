
class ApiConfig {
  ApiConfig._();



  /// Local development URL — auto-detects platform.
  static String get baseUrl {
    // FORCE all API calls to the absolute local WiFi IP regardless of whether 
    // it's a Debug build or a Release APK.
    return 'http://192.168.1.3:8000/api/v1';
  }

  /// Categories used across the app for filtering.
  static const List<String> categories = [
    'Food',
    'Travel',
    'Fitness',
    'Finance',
    'Study',
    'Tech',
    'Fashion',
    'Entertainment',
    'Health',
    'Other',
  ];
}
