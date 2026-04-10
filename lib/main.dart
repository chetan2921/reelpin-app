import 'package:flutter/material.dart';
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
import 'services/profile_service.dart';
import 'services/reel_store.dart';
import 'theme/app_theme.dart';
import 'viewmodels/home_viewmodel.dart';
import 'viewmodels/map_viewmodel.dart';
import 'viewmodels/search_viewmodel.dart';
import 'viewmodels/session_viewmodel.dart';
import 'viewmodels/theme_viewmodel.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseConfig.loadLocalConfig();

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
  const ReelPinApp({
    super.key,
    required this.isSupabaseConfigured,
  });

  final bool isSupabaseConfigured;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeViewModel()..loadPreference()),
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
  late final ApiService _apiService;
  late final ReelStore _reelStore;
  late final ReelRepository _repository;

  @override
  void initState() {
    super.initState();
    final authService = context.read<AuthService>();
    _apiService = ApiService();
    _reelStore = ReelStore();
    _repository = ReelRepository(_apiService, _reelStore, authService);
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ApiService>.value(value: _apiService),
        Provider<ReelStore>.value(value: _reelStore),
        Provider<ReelRepository>.value(value: _repository),
        ChangeNotifierProvider(
          create: (_) => HomeViewModel(_repository)..loadReels(),
        ),
        ChangeNotifierProvider(
          create: (_) => MapViewModel(_repository)..loadMapReels(),
        ),
        ChangeNotifierProvider(create: (_) => SearchViewModel(_repository)),
      ],
      child: const AppShell(),
    );
  }
}
