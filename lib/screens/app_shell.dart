import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/geofence_recall_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../viewmodels/home_viewmodel.dart';
import '../viewmodels/map_viewmodel.dart';
import 'home_screen.dart';
import 'map_screen.dart';
import 'search_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  static const _permissionsPromptedKey =
      'app_shell_initial_permissions_prompted_v1';

  int _currentIndex = 0;
  late StreamSubscription _mediaIntentSub;
  bool _isQueueingSharedReel = false;
  String? _lastHandledSharedUrl;
  DateTime? _lastHandledSharedAt;
  bool _isCheckingInitialPermissions = false;

  final _screens = const [HomeScreen(), MapScreen(), SearchScreen()];

  static const _navItems = [
    _NavItem(
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      label: 'HOME',
    ),
    _NavItem(
      icon: Icons.map_outlined,
      activeIcon: Icons.map_rounded,
      label: 'MAP',
    ),
    _NavItem(
      icon: Icons.explore_outlined,
      activeIcon: Icons.explore_rounded,
      label: 'DISCOVER',
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initSharingIntent();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_maybePromptInitialPermissions());
    });
  }

  void _initSharingIntent() {
    _mediaIntentSub = ReceiveSharingIntent.instance.getMediaStream().listen(
      (value) {
        _processSharedData(value);
      },
      onError: (err) {
        debugPrint("Intent stream error: $err");
      },
    );

    ReceiveSharingIntent.instance.getInitialMedia().then((value) {
      _processSharedData(value);
    });
  }

  void _processSharedData(List<SharedMediaFile> files) {
    if (files.isEmpty) return;

    final payload = files.first.path;
    _handleSharedPayload(payload);
    unawaited(ReceiveSharingIntent.instance.reset());
  }

  void _handleSharedPayload(String payload) {
    final urlRegex = RegExp(
      r'https?:\/\/(www\.)?(instagram\.com\/(reel|p|tv)\/[A-Za-z0-9_-]+|((vt|vm)\.)?tiktok\.com\/[A-Za-z0-9@._\/-]+|youtube\.com\/shorts\/[A-Za-z0-9_-]+|youtu\.be\/[A-Za-z0-9_-]+)(\/?\S*)?',
    );
    final match = urlRegex.firstMatch(payload);

    if (match != null) {
      final String extractedUrl = match.group(0)!;
      if (_lastHandledSharedUrl == extractedUrl &&
          _lastHandledSharedAt != null &&
          DateTime.now().difference(_lastHandledSharedAt!).inSeconds < 8) {
        return;
      }
      _lastHandledSharedUrl = extractedUrl;
      _lastHandledSharedAt = DateTime.now();

      if (mounted) {
        _enqueueSharedReel(extractedUrl);
      }
    }
  }

  Future<void> _enqueueSharedReel(String url) async {
    if (_isQueueingSharedReel) return;

    final homeVm = context.read<HomeViewModel>();
    final messenger = ScaffoldMessenger.of(context);

    setState(() {
      _isQueueingSharedReel = true;
    });

    try {
      await homeVm.enqueueReelProcessing(url);

      if (!mounted) return;
      setState(() {
        _isQueueingSharedReel = false;
      });

      messenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Container(
                width: 18,
                height: 18,
                color: AppTheme.neonGreen,
                child: Icon(Icons.check, size: 14, color: AppTheme.fg(context)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'SAVED TO REELPIN. PROCESSING IN BACKGROUND.',
                  style: GoogleFonts.spaceMono(
                    color: AppTheme.fg(context),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: AppTheme.bg(context),
          shape: RoundedRectangleBorder(
            side: BorderSide(
              color: AppTheme.fg(context),
              width: AppTheme.borderWidth,
            ),
          ),
        ),
      );

      if (!mounted) return;
      if (Theme.of(context).platform == TargetPlatform.android) {
        Future<void>.delayed(const Duration(milliseconds: 350), () async {
          if (!mounted) return;
          await SystemNavigator.pop();
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isQueueingSharedReel = false;
      });
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'COULD NOT START BACKGROUND SAVE: $error',
            style: GoogleFonts.spaceMono(
              color: AppTheme.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          backgroundColor: AppTheme.destructive,
          shape: RoundedRectangleBorder(
            side: BorderSide(
              color: AppTheme.fg(context),
              width: AppTheme.borderWidth,
            ),
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _mediaIntentSub.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !mounted) return;

    unawaited(context.read<HomeViewModel>().loadReels(forceRefresh: true));
    unawaited(context.read<MapViewModel>().loadMapReels(forceRefresh: true));
    unawaited(_refreshPushRegistrationIfPossible());
  }

  Future<void> _maybePromptInitialPermissions() async {
    if (!mounted || _isCheckingInitialPermissions) return;

    _isCheckingInitialPermissions = true;
    final prefs = await SharedPreferences.getInstance();
    final alreadyPrompted = prefs.getBool(_permissionsPromptedKey) ?? false;
    if (alreadyPrompted) {
      _isCheckingInitialPermissions = false;
      return;
    }

    if (!mounted) {
      _isCheckingInitialPermissions = false;
      return;
    }

    final enable = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppTheme.bg(dialogContext),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.zero,
            side: BorderSide(
              color: AppTheme.fg(dialogContext),
              width: AppTheme.borderWidth,
            ),
          ),
          title: Text(
            'ALLOW REELPIN ALERTS?',
            style: GoogleFonts.spaceMono(
              color: AppTheme.fg(dialogContext),
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          content: Text(
            'TURN ON NOTIFICATIONS AND LOCATION SO REELPIN CAN TELL YOU WHEN A REEL IS READY AND WHEN YOU ARE NEAR A PLACE YOU SAVED.',
            style: GoogleFonts.spaceMono(
              color: AppTheme.textSec(dialogContext),
              fontSize: 12,
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(
                'NOT NOW',
                style: GoogleFonts.spaceMono(
                  color: AppTheme.textSec(dialogContext),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            GestureDetector(
              onTap: () => Navigator.pop(dialogContext, true),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: AppTheme.brutalBox(
                  dialogContext,
                  color: AppTheme.yellow,
                  shadow: true,
                ),
                child: Text(
                  'ENABLE',
                  style: GoogleFonts.spaceMono(
                    color: AppTheme.black,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    await prefs.setBool(_permissionsPromptedKey, true);
    _isCheckingInitialPermissions = false;

    if (enable == true) {
      await _enableReelPinPermissions();
    }
  }

  Future<void> _enableReelPinPermissions() async {
    final notificationService = context.read<NotificationService>();
    final geofenceRecallService = context.read<GeofenceRecallService>();
    final apiService = context.read<ApiService>();
    final authService = context.read<AuthService>();
    final homeVm = context.read<HomeViewModel>();

    try {
      await notificationService.initialize(requestPermissions: true);
    } catch (e) {
      debugPrint('Notification permission setup skipped: $e');
    }

    final userId = authService.currentUser?.id;
    if (userId != null && userId.trim().isNotEmpty) {
      try {
        final token = await notificationService.getFcmToken();
        if (token != null && token.trim().isNotEmpty) {
          await apiService.registerPushToken(
            userId: userId,
            token: token,
            platform: notificationService.currentPlatform,
          );
        }
      } catch (e) {
        debugPrint('Push token registration skipped after prompt: $e');
      }
    }

    try {
      await geofenceRecallService.initialize(requestPermissions: true);
      await geofenceRecallService.syncFromReels(homeVm.reels);
    } catch (e) {
      debugPrint('Geofence recall setup skipped after prompt: $e');
    }
  }

  Future<void> _refreshPushRegistrationIfPossible() async {
    final notificationService = context.read<NotificationService>();
    final apiService = context.read<ApiService>();
    final authService = context.read<AuthService>();
    final userId = authService.currentUser?.id;
    if (userId == null || userId.trim().isEmpty) return;

    try {
      final token = await notificationService.getFcmToken();
      if (token == null || token.trim().isEmpty) return;

      await apiService.registerPushToken(
        userId: userId,
        token: token,
        platform: notificationService.currentPlatform,
      );
    } catch (e) {
      debugPrint('Push token refresh on resume skipped: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: AppTheme.bg(context),
        child: IndexedStack(index: _currentIndex, children: _screens),
      ),
      bottomNavigationBar: _buildNavBar(),
    );
  }

  Widget _buildNavBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bg(context),
        border: Border(
          top: BorderSide(
            color: AppTheme.fg(context),
            width: AppTheme.borderWidth,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(_navItems.length, (i) {
              return _buildNavItem(i, _navItems[i]);
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, _NavItem item) {
    final isSelected = _currentIndex == index;

    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.yellow : Colors.transparent,
          border: isSelected
              ? Border.all(color: AppTheme.fg(context), width: 2)
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? item.activeIcon : item.icon,
              color: isSelected ? AppTheme.black : AppTheme.fg(context),
              size: 24,
            ),
            const SizedBox(height: 2),
            Text(
              item.label,
              style: GoogleFonts.spaceMono(
                color: isSelected ? AppTheme.black : AppTheme.fg(context),
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}
