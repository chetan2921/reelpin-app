import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

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
      label: 'Home',
    ),
    _NavItem(
      icon: Icons.map_outlined,
      activeIcon: Icons.map_rounded,
      label: 'Map',
    ),
    _NavItem(
      icon: Icons.search_rounded,
      activeIcon: Icons.manage_search_rounded,
      label: 'Search',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initSharingIntent();
  }

  void _initSharingIntent() {
    // 1. Listen for intent while the app is already running in memory
    _intentSub = ReceiveSharingIntent.instance.getMediaStream().listen((value) {
      _processSharedData(value);
    }, onError: (err) {
      debugPrint("Intent stream error: $err");
    });

    // 2. Grab the intent if the app was launched from a cold state via the share sheet
    ReceiveSharingIntent.instance.getInitialMedia().then((value) {
      _processSharedData(value);
    });
  }

  void _processSharedData(List<SharedMediaFile> files) {
    if (files.isEmpty) return;

    // We take the first shared item. Usually text intent stores payload in `.path` or URL.
    final payload = files.first.path;
    
    // Extract the Instagram URL from the shared text block using RegExp
    final urlRegex = RegExp(r'https?:\/\/(www\.)?instagram\.com\/(reel|p)\/[A-Za-z0-9_-]+(\/?.*)?');
    final match = urlRegex.firstMatch(payload);
    
    if (match != null) {
      final String extractedUrl = match.group(0)!;
      
      // Navigate uniquely to Home so we can watch it load 
      if (mounted) {
         setState(() => _currentIndex = 0);
         
         // Trigger the viewmodel
         final vm = context.read<HomeViewModel>();
         
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(
             content: Text('Received URL! Extracting location...'),
             backgroundColor: AppTheme.amethyst,
             duration: Duration(seconds: 2),
           )
         );
         
         vm.processReel(extractedUrl).then((_) {
            if (mounted) {
               // Silently update the pins in the Map Screen directly from the database!
               context.read<MapViewModel>().loadMapReels(forceRefresh: true);
               
               ScaffoldMessenger.of(context).showSnackBar(
                 const SnackBar(
                   content: Text('Pin dropped!'),
                   backgroundColor: AppTheme.amethyst,
                 )
               );
            }
         }).catchError((error) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed: $error'),
                  backgroundColor: AppTheme.mauve,
                )
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
      extendBody: true,
      body: Container(
        color: AppTheme.midnightPlum,
        child: IndexedStack(index: _currentIndex, children: _screens),
      ),
      bottomNavigationBar: _buildGlassNavBar(),
    );
  }

  Widget _buildGlassNavBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            height: 70,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.deepIndigo.withAlpha(200),
                  AppTheme.amethyst.withAlpha(120),
                ],
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: AppTheme.cream.withAlpha(25), width: 1),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.midnightPlum.withAlpha(160),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(_navItems.length, (i) {
                return _buildNavItem(i, _navItems[i]);
              }),
            ),
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 20 : 16,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [
                    AppTheme.mauve.withAlpha(100),
                    AppTheme.dustyRose.withAlpha(60),
                  ],
                )
              : null,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Icon(
                isSelected ? item.activeIcon : item.icon,
                key: ValueKey(isSelected),
                color: isSelected
                    ? AppTheme.cream
                    : AppTheme.cream.withAlpha(100),
                size: 22,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                item.label,
                style: TextStyle(
                  color: AppTheme.cream,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
            ],
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
