import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import '../services/location_service.dart';
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
  int _currentIndex = 0;
  late StreamSubscription _mediaIntentSub;
  bool _isQueueingSharedReel = false;
  String? _lastHandledSharedUrl;
  DateTime? _lastHandledSharedAt;

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
    _requestLocationOnStartup();
  }

  void _requestLocationOnStartup() {
    Future.microtask(() async {
      await LocationService.instance.warmUpLocation();
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
