import 'dart:async';

import 'package:flutter/material.dart';
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

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;
  late StreamSubscription _intentSub;

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
    _initSharingIntent();
    _requestLocationOnStartup();
  }

  void _requestLocationOnStartup() {
    Future.microtask(() async {
      await LocationService.instance.warmUpLocation();
    });
  }

  void _initSharingIntent() {
    _intentSub = ReceiveSharingIntent.instance.getMediaStream().listen(
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

    final urlRegex = RegExp(
      r'https?:\/\/(www\.)?(instagram\.com\/(reel|p)\/[A-Za-z0-9_-]+|tiktok\.com\/[A-Za-z0-9@._\/-]+)(\/?\S*)?',
    );
    final match = urlRegex.firstMatch(payload);

    if (match != null) {
      final String extractedUrl = match.group(0)!;

      if (mounted) {
        setState(() => _currentIndex = 0);

        final vm = context.read<HomeViewModel>();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: AppTheme.yellow,
                    border: Border.all(color: AppTheme.black, width: 2),
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 10,
                      height: 10,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.black,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'PROCESSING REEL...',
                  style: GoogleFonts.spaceMono(
                    color: AppTheme.black,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            backgroundColor: AppTheme.white,
            shape: RoundedRectangleBorder(
              side: const BorderSide(
                color: AppTheme.black,
                width: AppTheme.borderWidth,
              ),
            ),
            duration: const Duration(seconds: 3),
          ),
        );

        vm
            .processReel(extractedUrl)
            .then((_) {
              if (mounted) {
                context.read<MapViewModel>().loadMapReels(forceRefresh: true);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        Container(
                          width: 18,
                          height: 18,
                          color: AppTheme.neonGreen,
                          child: const Icon(
                            Icons.check,
                            size: 14,
                            color: AppTheme.black,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'REEL SAVED',
                          style: GoogleFonts.spaceMono(
                            color: AppTheme.black,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    backgroundColor: AppTheme.white,
                    shape: RoundedRectangleBorder(
                      side: const BorderSide(
                        color: AppTheme.black,
                        width: AppTheme.borderWidth,
                      ),
                    ),
                  ),
                );
              }
            })
            .catchError((error) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'FAILED: $error',
                      style: GoogleFonts.spaceMono(
                        color: AppTheme.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    backgroundColor: AppTheme.destructive,
                    shape: RoundedRectangleBorder(
                      side: const BorderSide(
                        color: AppTheme.black,
                        width: AppTheme.borderWidth,
                      ),
                    ),
                  ),
                );
              }
            });
      }
    }
  }

  @override
  void dispose() {
    _intentSub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: AppTheme.white,
        child: IndexedStack(index: _currentIndex, children: _screens),
      ),
      bottomNavigationBar: _buildNavBar(),
    );
  }

  Widget _buildNavBar() {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.white,
        border: Border(
          top: BorderSide(color: AppTheme.black, width: AppTheme.borderWidth),
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
              ? Border.all(color: AppTheme.black, width: 2)
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? item.activeIcon : item.icon,
              color: AppTheme.black,
              size: 24,
            ),
            const SizedBox(height: 2),
            Text(
              item.label,
              style: GoogleFonts.spaceMono(
                color: AppTheme.black,
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
