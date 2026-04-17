import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/supabase_config.dart';
import 'repositories/reel_repository.dart';
import 'screens/app_shell.dart';
import 'screens/auth_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/setup_required_screen.dart';
import 'screens/splash_screen.dart';
import 'services/api_service.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'services/profile_service.dart';
import 'services/reel_store.dart';
import 'theme/app_theme.dart';
import 'viewmodels/home_viewmodel.dart';
import 'viewmodels/map_viewmodel.dart';
import 'viewmodels/category_filters_viewmodel.dart';
import 'viewmodels/search_viewmodel.dart';
import 'viewmodels/session_viewmodel.dart';
import 'viewmodels/theme_viewmodel.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  await SupabaseConfig.loadLocalConfig();
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS)) {
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    } catch (e) {
      debugPrint('Firebase initialization skipped: $e');
    }
  }

  final isSupabaseConfigured = SupabaseConfig.isConfigured;
  if (isSupabaseConfigured) {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
  }

  runApp(ReelPinApp(isSupabaseConfigured: isSupabaseConfigured));
}

class ReelPinApp extends StatelessWidget {
  const ReelPinApp({super.key, required this.isSupabaseConfigured});

  final bool isSupabaseConfigured;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => ThemeViewModel()..loadPreference(),
        ),
        if (isSupabaseConfigured) Provider(create: (_) => ProfileService()),
        if (isSupabaseConfigured)
          Provider(
            create: (context) => AuthService(context.read<ProfileService>()),
          ),
        if (isSupabaseConfigured)
          ChangeNotifierProvider(
            create: (context) => SessionViewModel(context.read<AuthService>()),
          ),
      ],
      child: Consumer<ThemeViewModel>(
        builder: (context, themeVm, _) {
          return MaterialApp(
            title: 'ReelPin',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.brutalTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeVm.themeMode,
            home: isSupabaseConfigured
                ? const AppEntry()
                : const SetupRequiredScreen(),
          );
        },
      ),
    );
  }
}

class AppEntry extends StatefulWidget {
  const AppEntry({super.key});

  @override
  State<AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<AppEntry> {
  static const _minimumSplashDuration = Duration(milliseconds: 1600);
  bool _hasCompletedSplash = false;
  bool _hasCompletedOnboarding = false;

  @override
  void initState() {
    super.initState();
    _holdSplash();
  }

  Future<void> _holdSplash() async {
    await Future<void>.delayed(_minimumSplashDuration);
    if (!mounted) return;
    setState(() {
      _hasCompletedSplash = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SessionViewModel>(
      builder: (context, sessionVm, _) {
        if (!_hasCompletedSplash || sessionVm.isBootstrapping) {
          return const SplashScreen();
        }

        if (!sessionVm.isAuthenticated) {
          if (!_hasCompletedOnboarding) {
            return OnboardingScreen(
              onContinue: () {
                setState(() {
                  _hasCompletedOnboarding = true;
                });
              },
            );
          }
          return const AuthScreen();
        }

        return const AuthenticatedShell();
      },
    );
  }
}

class AuthenticatedShell extends StatefulWidget {
  const AuthenticatedShell({super.key});

  @override
  State<AuthenticatedShell> createState() => _AuthenticatedShellState();
}

class _AuthenticatedShellState extends State<AuthenticatedShell> {
  late final AuthService _authService;
  late final ApiService _apiService;
  late final ReelStore _reelStore;
  late final ReelRepository _repository;
  late final NotificationService _notificationService;
  late final HomeViewModel _homeViewModel;
  late final MapViewModel _mapViewModel;
  late final CategoryFiltersViewModel _categoryFiltersViewModel;
  late final SearchViewModel _searchViewModel;
  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<ReelReadyNotification>? _reelReadySubscription;
  Timer? _pushSyncRetryTimer;

  @override
  void initState() {
    super.initState();
    _authService = context.read<AuthService>();
    _apiService = ApiService();
    _reelStore = ReelStore();
    _repository = ReelRepository(_apiService, _reelStore, _authService);
    _notificationService = NotificationService.instance;
    _homeViewModel = HomeViewModel(_repository);
    _mapViewModel = MapViewModel(_repository);
    _categoryFiltersViewModel = CategoryFiltersViewModel(_repository);
    _searchViewModel = SearchViewModel(_repository);
    _initializeBackgroundMessaging();
    _homeViewModel.loadReels();
    _mapViewModel.loadMapReels();
    _categoryFiltersViewModel.loadCategoryFilters();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ApiService>.value(value: _apiService),
        Provider<ReelStore>.value(value: _reelStore),
        Provider<ReelRepository>.value(value: _repository),
        Provider<NotificationService>.value(value: _notificationService),
        ChangeNotifierProvider<HomeViewModel>.value(value: _homeViewModel),
        ChangeNotifierProvider<MapViewModel>.value(value: _mapViewModel),
        ChangeNotifierProvider<CategoryFiltersViewModel>.value(
          value: _categoryFiltersViewModel,
        ),
        ChangeNotifierProvider<SearchViewModel>.value(value: _searchViewModel),
      ],
      child: const AppShell(),
    );
  }

  Future<void> _initializeBackgroundMessaging() async {
    try {
      await _notificationService.initialize(requestPermissions: false);
    } catch (e) {
      debugPrint('Notification initialization skipped: $e');
      return;
    }

    final userId = _authService.currentUser?.id;
    if (userId == null || userId.trim().isEmpty) return;

    await _syncPushTokenRegistration();
    _pushSyncRetryTimer?.cancel();
    _pushSyncRetryTimer = Timer(
      const Duration(seconds: 5),
      () => unawaited(_syncPushTokenRegistration()),
    );

    if (_notificationService.isFirebaseConfigured) {
      _tokenRefreshSubscription = _notificationService.onTokenRefresh.listen((
        token,
      ) {
        unawaited(
          _apiService
              .registerPushToken(
                userId: userId,
                token: token,
                platform: _notificationService.currentPlatform,
              )
              .catchError((error) {
                debugPrint('Push token refresh sync failed: $error');
              }),
        );
      });
    }

    _reelReadySubscription = _notificationService.onReelReady.listen((event) {
      unawaited(_refreshSavedReels());
    });

    final initialReelReady = _notificationService
        .consumePendingInitialReelReady();
    if (initialReelReady != null) {
      await _refreshSavedReels();
    }
  }

  Future<void> _syncPushTokenRegistration() async {
    final userId = _authService.currentUser?.id;
    if (userId == null || userId.trim().isEmpty) return;

    try {
      final token = await _notificationService.getFcmToken();
      if (token == null || token.trim().isEmpty) return;

      await _apiService.registerPushToken(
        userId: userId,
        token: token,
        platform: _notificationService.currentPlatform,
      );
    } catch (e) {
      debugPrint('Push token registration skipped: $e');
    }
  }

  Future<void> _refreshSavedReels() async {
    try {
      await Future.wait([
        _homeViewModel.loadReels(forceRefresh: true),
        _mapViewModel.loadMapReels(forceRefresh: true),
        _categoryFiltersViewModel.loadCategoryFilters(forceRefresh: true),
      ]);
    } catch (e) {
      debugPrint('Saved reel refresh skipped: $e');
    }
  }

  @override
  void dispose() {
    _tokenRefreshSubscription?.cancel();
    _reelReadySubscription?.cancel();
    _pushSyncRetryTimer?.cancel();
    super.dispose();
  }
}
