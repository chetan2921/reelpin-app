class ApiConfig {
  ApiConfig._();

  static const String _defaultLanBaseUrl = 'http://192.168.1.2:8000/api/v1';
  static const String _legacyLanBaseUrl = 'http://192.168.1.3:8000/api/v1';
  static const String _androidEmulatorBaseUrl = 'http://10.0.2.2:8000/api/v1';

  /// Local development URL — auto-detects platform.
  static String get baseUrl {
    // Override with: flutter run --dart-define=API_BASE_URL=http://<ip>:8000/api/v1
    const fromEnv = String.fromEnvironment('API_BASE_URL');
    final trimmed = fromEnv.trim();
    if (trimmed.isNotEmpty) {
      return trimmed;
    }
    return _defaultLanBaseUrl;
  }

  /// Additional URLs to auto-try when the primary host is unreachable.
  static List<String> get fallbackBaseUrls {
    final primary = baseUrl;
    final candidates = <String>[
      _defaultLanBaseUrl,
      _legacyLanBaseUrl,
      _androidEmulatorBaseUrl,
    ];

    final fallbacks = <String>[];
    for (final candidate in candidates) {
      if (candidate == primary) continue;
      if (!fallbacks.contains(candidate)) {
        fallbacks.add(candidate);
      }
    }
    return fallbacks;
  }

  /// Grouped categories for the filter sheet and broad category mapping.
  static const Map<String, List<String>> categoryGroups = {
    'Entertainment & Lifestyle': [
      'Food & Restaurants',
      'Travel & Places',
      'Fitness & Gym',
      'Fashion & Style',
      'Beauty & Skincare',
      'Home Decor & Interior',
      'Relationships & Dating',
      'Humor & Memes',
    ],
    'Knowledge & Learning': [
      'Study & Education',
      'Science & Technology',
      'History & Culture',
      'Language Learning',
      'Books & Reading',
      'General Knowledge & Facts',
    ],
    'Finance & Career': [
      'Stock Market & Trading',
      'Personal Finance & Investing',
      'Business & Startups',
      'Career & Jobs',
      'Crypto & Web3',
      'Real Estate',
    ],
    'Health & Wellness': [
      'Mental Health',
      'Nutrition & Diet',
      'Yoga & Meditation',
      'Medical & Health Tips',
      'Parenting & Kids',
      'Motivation & Mindset',
      'Spirituality & Religion',
    ],
    'Skills & Hobbies': [
      'Cooking & Recipes',
      'Music & Dance',
      'Art & Drawing',
      'Photography & Videography',
      'DIY & Crafts',
      'Gaming',
      'Sports & Cricket',
      'Gardening & Plants',
      'Pets & Animals',
    ],
    'Practical & Utility': [
      'Life Hacks & Tips',
      'Tech & Gadgets',
      'Shopping & Products',
      'Legal & Rights',
      'Government & Schemes',
      'Automotive & Cars',
    ],
  };

  static List<String> get broadCategories => categoryGroups.keys.toList();
  static List<String> get allCategories =>
      categoryGroups.values.expand((e) => e).toList();
}
