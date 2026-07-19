import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reelpin/app/app_entry.dart';
import 'package:reelpin/app/providers.dart';
import 'package:reelpin/app/setup_required_screen.dart';
import 'package:reelpin/core/design/app_theme.dart';

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
