class ApiConfig {
  ApiConfig._();

  /// Local development URL — auto-detects platform.
  static String get baseUrl {
    // FORCE all API calls to the absolute local WiFi IP regardless of whether
    // it's a Debug build or a Release APK.
    return 'http://192.168.1.3:8000/api/v1';
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
      'Motivation & Mindset',
      'Humor & Memes',
      'Spirituality & Religion',
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
