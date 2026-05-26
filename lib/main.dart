import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/supabase_config.dart';
import 'providers/app_providers.dart';
import 'repositories/reel_repository.dart';
import 'screens/app_shell.dart';
import 'screens/auth_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/setup_required_screen.dart';
import 'screens/splash_screen.dart';
import 'services/app_update_service.dart';
import 'services/api_service.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'services/share_handoff_service.dart';
import 'theme/app_theme.dart';
import 'viewmodels/category_filters_viewmodel.dart';
import 'viewmodels/entitlements_viewmodel.dart';
import 'viewmodels/home_viewmodel.dart';
import 'viewmodels/map_viewmodel.dart';
import 'viewmodels/search_viewmodel.dart';

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

  runApp(
    ProviderScope(
      child: ReelPinApp(isSupabaseConfigured: isSupabaseConfigured),
    ),
  );
}

class ReelPinApp extends ConsumerWidget {
  const ReelPinApp({super.key, required this.isSupabaseConfigured});

  final bool isSupabaseConfigured;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeVm = ref.watch(themeViewModelProvider);

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
  }
}

class AppEntry extends ConsumerStatefulWidget {
  const AppEntry({super.key});

  @override
  ConsumerState<AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends ConsumerState<AppEntry> {
  static const _minimumSplashDuration = Duration(milliseconds: 1600);
  static const _onboardingCompletedKey = 'app_entry_onboarding_completed_v1';

  bool _hasCompletedSplash = false;
  bool _hasCompletedOnboarding = false;
  bool _isLoadingOnboardingState = true;

  @override
  void initState() {
    super.initState();
    unawaited(AppUpdateService.checkForImmediateUpdate());
    _holdSplash();
    _loadOnboardingState();
  }

  Future<void> _holdSplash() async {
    await Future<void>.delayed(_minimumSplashDuration);
    if (!mounted) return;
    setState(() {
      _hasCompletedSplash = true;
    });
  }

  Future<void> _loadOnboardingState() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _hasCompletedOnboarding = prefs.getBool(_onboardingCompletedKey) ?? false;
      _isLoadingOnboardingState = false;
    });
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingCompletedKey, true);
    if (!mounted) return;
    setState(() {
      _hasCompletedOnboarding = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final sessionVm = ref.watch(sessionViewModelProvider);

    if (!_hasCompletedSplash ||
        sessionVm.isBootstrapping ||
        _isLoadingOnboardingState) {
      return const SplashScreen();
    }

    if (!sessionVm.isAuthenticated) {
      if (!_hasCompletedOnboarding) {
        return OnboardingScreen(
          onContinue: () {
            unawaited(_completeOnboarding());
          },
        );
      }
      return const AuthScreen();
    }

    return const AuthenticatedShell();
  }
}

class AuthenticatedShell extends ConsumerStatefulWidget {
  const AuthenticatedShell({super.key});

  @override
  ConsumerState<AuthenticatedShell> createState() => _AuthenticatedShellState();
}

class _AuthenticatedShellState extends ConsumerState<AuthenticatedShell> {
  static const _pushRegistrationInterval = Duration(hours: 12);

  late final AuthService _authService;
  late final ApiService _apiService;
  late final ReelRepository _repository;
  late final NotificationService _notificationService;
  late final HomeViewModel _homeViewModel;
  late final MapViewModel _mapViewModel;
  late final CategoryFiltersViewModel _categoryFiltersViewModel;
  late final SearchViewModel _searchViewModel;
  late final EntitlementsViewModel _entitlementsViewModel;
  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<ReelReadyNotification>? _reelReadySubscription;
  StreamSubscription<AuthState>? _authStateSubscription;
  String? _lastRegisteredPushUserId;
  String? _lastRegisteredPushToken;
  DateTime? _lastRegisteredPushAt;
  String? _activeUserId;

  @override
  void initState() {
    super.initState();
    _authService = ref.read(authServiceProvider);
    _apiService = ref.read(apiServiceProvider);
    _repository = ref.read(reelRepositoryProvider);
    _notificationService = ref.read(notificationServiceProvider);
    _homeViewModel = ref.read(homeViewModelProvider);
    _mapViewModel = ref.read(mapViewModelProvider);
    _categoryFiltersViewModel = ref.read(categoryFiltersViewModelProvider);
    _searchViewModel = ref.read(searchViewModelProvider);
    _entitlementsViewModel = ref.read(entitlementsViewModelProvider);
    _activeUserId = _authService.currentUser?.id;
    _authStateSubscription = _authService.authStateChanges.listen((state) {
      final nextUserId = state.session?.user.id;
      if (nextUserId == _activeUserId) return;
      _activeUserId = nextUserId;
      _clearUserScopedState();
      if (nextUserId != null && nextUserId.trim().isNotEmpty) {
        unawaited(_entitlementsViewModel.refresh(reloadContent: true));
      }
    });
    _initializeBackgroundMessaging();
    unawaited(_entitlementsViewModel.refresh(reloadContent: true));
  }

  @override
  Widget build(BuildContext context) {
    return const AppShell();
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

    if (_notificationService.isFirebaseConfigured) {
      _tokenRefreshSubscription = _notificationService.onTokenRefresh.listen((
        token,
      ) {
        unawaited(
          _syncPushTokenRegistration(candidateToken: token).catchError((error) {
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

  Future<void> _syncPushTokenRegistration({String? candidateToken}) async {
    final userId = _authService.currentUser?.id;
    if (userId == null || userId.trim().isEmpty) return;

    try {
      final token = candidateToken?.trim().isNotEmpty == true
          ? candidateToken!.trim()
          : await _notificationService.getFcmToken();
      if (token == null || token.trim().isEmpty) return;

      final normalizedToken = token.trim();
      final recentlyRegistered =
          _lastRegisteredPushAt != null &&
          DateTime.now().difference(_lastRegisteredPushAt!) <
              _pushRegistrationInterval;
      final isDuplicateRegistration =
          _lastRegisteredPushUserId == userId &&
          _lastRegisteredPushToken == normalizedToken &&
          recentlyRegistered;
      if (isDuplicateRegistration) {
        return;
      }

      await _apiService.registerPushToken(
        userId: userId,
        token: normalizedToken,
        platform: _notificationService.currentPlatform,
      );
      await ShareHandoffService.instance.syncPushToken(
        token: normalizedToken,
        platform: _notificationService.currentPlatform,
      );
      _lastRegisteredPushUserId = userId;
      _lastRegisteredPushToken = normalizedToken;
      _lastRegisteredPushAt = DateTime.now();
    } catch (e) {
      debugPrint('Push token registration skipped: $e');
    }
  }

  Future<void> _refreshSavedReels() async {
    try {
      await _entitlementsViewModel.refresh(reloadContent: true);
    } catch (e) {
      debugPrint('Saved reel refresh skipped: $e');
    }
  }

  void _clearUserScopedState() {
    _searchViewModel.clear();
    _categoryFiltersViewModel.reset();
    _mapViewModel.reset();
    _homeViewModel.reset();
    _repository.clearCache();
    _entitlementsViewModel.reset();
    _lastRegisteredPushUserId = null;
    _lastRegisteredPushToken = null;
    _lastRegisteredPushAt = null;
  }

  @override
  void dispose() {
    _clearUserScopedState();
    _tokenRefreshSubscription?.cancel();
    _reelReadySubscription?.cancel();
    _authStateSubscription?.cancel();
    super.dispose();
  }
}
