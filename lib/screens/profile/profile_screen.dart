import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:reelpin/data_models/account/library_stats.dart';
import 'package:reelpin/providers.dart';
import 'package:reelpin/router.dart';
import 'package:reelpin/utils/error_message.dart';
import 'package:reelpin/services/location/location_service.dart';
import 'package:reelpin/services/notifications/notification_service.dart';
import 'package:reelpin/constants/app_layout.dart';
import 'package:reelpin/constants/app_colors.dart';
import 'package:reelpin/constants/app_theme.dart';
part 'partials/location_preference_card.dart';
part 'partials/notification_preference_card.dart';
part 'partials/profile_action_card.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  LibraryStats? _stats;
  String? _statsError;
  bool _isLoadingStats = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadStats();
    });
  }

  Future<void> _loadStats() async {
    setState(() {
      _isLoadingStats = true;
      _statsError = null;
    });

    try {
      final stats = await ref.read(accountHttpProvider).getLibraryStats();
      if (!mounted) return;
      setState(() {
        _stats = stats;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _statsError = userFacingErrorMessage(
          error,
          fallbackMessage: 'Could not load library stats right now.',
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingStats = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    final sessionVm = ref.watch(sessionViewModelProvider);
    final themeVm = ref.watch(themeViewModelProvider);

    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        backgroundColor: AppColors.bg(context),
        surfaceTintColor: Colors.transparent,
        title: Text(
          'PROFILE',
          style: GoogleFonts.spaceMono(
            color: AppColors.fg(context),
            fontSize: layout.font(22),
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back, color: AppColors.fg(context)),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Builder(
          builder: (context) {
            final stats = _stats;
            const heroTextColor = AppColors.white;
            const heroSupportColor = Color(0xFFD6F3EF);

            return ListView(
              padding: EdgeInsets.fromLTRB(
                layout.inset(20),
                layout.gap(8),
                layout.inset(20),
                layout.gap(32),
              ),
              children: [
                Container(
                  decoration: AppTheme.brutalCard(
                    context,
                    color: const Color.fromARGB(255, 2, 50, 46),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(layout.inset(20)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: layout.inset(64),
                              height: layout.inset(64),
                              decoration: BoxDecoration(
                                color: AppColors.yellow,
                                border: Border.all(
                                  color: AppColors.fg(context),
                                  width: 3,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                sessionVm.initials,
                                style: GoogleFonts.spaceMono(
                                  color: AppColors.black,
                                  fontSize: layout.font(22),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            SizedBox(width: layout.inset(14)),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    sessionVm.displayName.toUpperCase(),
                                    style: GoogleFonts.spaceMono(
                                      color: heroTextColor,
                                      fontSize: layout.font(18),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  SizedBox(height: layout.gap(6)),
                                  Text(
                                    sessionVm.email,
                                    style: GoogleFonts.spaceMono(
                                      color: heroSupportColor,
                                      fontSize: layout.font(11),
                                      fontWeight: FontWeight.w500,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: layout.gap(18)),
                        Text(
                          'YOUR ACCOUNT HOLDS THE FULL LIBRARY, MAP PINS, AND DISCOVER INSIGHTS FOR EVERYTHING YOU SEND TO REELPIN.',
                          style: GoogleFonts.spaceMono(
                            color: heroTextColor,
                            fontSize: layout.font(11),
                            fontWeight: FontWeight.w600,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: layout.gap(18)),
                _sectionTitle(context, 'COLLECTION STATS'),
                SizedBox(height: layout.gap(10)),
                _buildStatsCard(context, stats),
                if (_statsError != null) ...[
                  SizedBox(height: layout.gap(10)),
                  Text(
                    _statsError!,
                    style: GoogleFonts.spaceMono(
                      color: AppColors.destructive,
                      fontSize: layout.font(11),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                SizedBox(height: layout.gap(18)),
                _sectionTitle(context, 'PREFERENCES'),
                SizedBox(height: layout.gap(10)),
                _actionCard(
                  context,
                  color: AppColors.bg(context),
                  title: 'THEME MODE',
                  subtitle:
                      'FOLLOWS YOUR DEVICE BY DEFAULT. THIS TOGGLE SETS A MANUAL OVERRIDE.',
                  trailing: GestureDetector(
                    onTap: () => themeVm.toggleTheme(),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: layout.inset(12),
                        vertical: layout.gap(10),
                      ),
                      decoration: AppTheme.brutalBox(
                        context,
                        color: themeVm.isDarkMode
                            ? AppColors.grauzone
                            : AppColors.accentSoft,
                        shadow: false,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            themeVm.themeIcon,
                            size: 16,
                            color: AppColors.fg(context),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            themeVm.themeLabel,
                            style: GoogleFonts.spaceMono(
                              color: themeVm.isDarkMode
                                  ? AppColors.background
                                  : AppColors.black,
                              fontSize: layout.font(11),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(height: layout.gap(14)),
                const _NotificationPreferenceCard(),
                SizedBox(height: layout.gap(14)),
                const _LocationPreferenceCard(),
                SizedBox(height: layout.gap(18)),
                _sectionTitle(context, 'HELP'),
                SizedBox(height: layout.gap(10)),
                GestureDetector(
                  onTap: () => Navigator.of(context).push(howToUseRoute()),
                  child: _actionCard(
                    context,
                    color: AppColors.bg(context),
                    title: 'HOW TO USE REELPIN',
                    subtitle:
                        'WALK THROUGH SENDING A POST, REEL, OR VIDEO TO REELPIN FROM ANY APP.',
                    trailing: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: layout.inset(12),
                        vertical: layout.gap(10),
                      ),
                      decoration: AppTheme.brutalBox(
                        context,
                        color: AppColors.yellow,
                        shadow: false,
                      ),
                      child: Text(
                        'VIEW',
                        style: GoogleFonts.spaceMono(
                          color: AppColors.black,
                          fontSize: layout.font(11),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: layout.gap(18)),
                _sectionTitle(context, 'ACCOUNT'),
                SizedBox(height: layout.gap(10)),
                GestureDetector(
                  onTap: sessionVm.isBusy
                      ? null
                      : () async {
                          await sessionVm.signOut();
                          if (context.mounted) {
                            Navigator.pop(context);
                          }
                        },
                  child: Opacity(
                    opacity: sessionVm.isBusy ? 0.7 : 1,
                    child: Container(
                      width: double.infinity,
                      decoration: AppTheme.brutalCard(
                        context,
                        color: AppColors.red,
                      ),
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: layout.gap(16)),
                        child: Center(
                          child: Text(
                            sessionVm.isSigningOut
                                ? 'SIGNING OUT...'
                                : 'SIGN OUT',
                            style: GoogleFonts.spaceMono(
                              color: AppColors.white,
                              fontSize: layout.font(14),
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: layout.gap(14)),
                GestureDetector(
                  onTap: sessionVm.isBusy ? null : _confirmDeleteAccount,
                  child: Opacity(
                    opacity: sessionVm.isBusy ? 0.7 : 1,
                    child: Container(
                      width: double.infinity,
                      decoration: AppTheme.brutalCard(
                        context,
                        color: AppColors.black,
                      ),
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: layout.gap(16)),
                        child: Center(
                          child: Text(
                            sessionVm.isDeletingAccount
                                ? 'DELETING ACCOUNT...'
                                : 'DELETE ACCOUNT',
                            style: GoogleFonts.spaceMono(
                              color: AppColors.white,
                              fontSize: layout.font(14),
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (sessionVm.error != null) ...[
                  SizedBox(height: layout.gap(10)),
                  Text(
                    sessionVm.error!,
                    style: GoogleFonts.spaceMono(
                      color: AppColors.destructive,
                      fontSize: layout.font(11),
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _confirmDeleteAccount() async {
    final shouldDelete = await _showDeleteAccountDialog(
      title: 'DELETE ACCOUNT?',
      message:
          'This will delete your ReelPin account and all data saved in ReelPin. This cannot be undone.',
      actionLabel: 'DELETE ACCOUNT',
    );
    if (shouldDelete != true || !mounted) return;

    final sessionVm = ref.read(sessionViewModelProvider);
    final success = await sessionVm.deleteAccount();
    if (!mounted || !success) return;

    ref.read(searchViewModelProvider).clear();
    ref.read(categoryFiltersViewModelProvider).reset();
    ref.read(mapViewModelProvider).reset();
    ref.read(homeViewModelProvider).reset();
    ref.read(discoverViewModelProvider).reset();
    ref.read(reelRepositoryProvider).clearCache();
    ref.read(entitlementsViewModelProvider).reset();

    if (context.mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  Future<bool?> _showDeleteAccountDialog({
    required String title,
    required String message,
    required String actionLabel,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.bg(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(0),
          side: BorderSide(
            color: AppColors.fg(context),
            width: AppTheme.borderWidth,
          ),
        ),
        title: Text(
          title,
          style: GoogleFonts.spaceMono(
            color: AppColors.fg(context),
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          message,
          style: GoogleFonts.spaceMono(
            color: AppColors.textSec(context),
            fontSize: 12,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'CANCEL',
              style: GoogleFonts.spaceMono(
                color: AppColors.textSec(context),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.pop(context, true),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.destructive,
                border: Border.all(color: AppColors.fg(context), width: 2),
                boxShadow: AppTheme.brutalShadowSmall(context),
              ),
              child: Text(
                actionLabel,
                style: GoogleFonts.spaceMono(
                  color: AppColors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String text) {
    final layout = AppLayout.of(context);
    return Text(
      text,
      style: GoogleFonts.spaceMono(
        color: AppColors.textSec(context),
        fontSize: layout.font(11),
        fontWeight: FontWeight.w700,
        letterSpacing: 1,
      ),
    );
  }

  Widget _divider(BuildContext context) {
    final layout = AppLayout.of(context);
    return Container(
      width: AppTheme.borderWidth,
      height: layout.gap(90),
      color: AppColors.fg(context),
    );
  }

  Widget _statTile(
    BuildContext context, {
    required String value,
    required String label,
    required Color color,
  }) {
    final layout = AppLayout.of(context);
    return Expanded(
      child: Container(
        color: color.withAlpha(50),
        padding: EdgeInsets.symmetric(vertical: layout.gap(16)),
        child: Column(
          children: [
            Text(
              value,
              style: GoogleFonts.spaceMono(
                color: AppColors.fg(context),
                fontSize: layout.font(22),
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: layout.gap(6)),
            Text(
              label,
              style: GoogleFonts.spaceMono(
                color: AppColors.fg(context),
                fontSize: layout.font(10),
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard(BuildContext context, LibraryStats? stats) {
    final layout = AppLayout.of(context);
    if (_isLoadingStats && stats == null) {
      return Container(
        decoration: AppTheme.brutalCard(context),
        padding: EdgeInsets.all(layout.inset(18)),
        child: Center(
          child: SizedBox(
            width: layout.inset(22),
            height: layout.inset(22),
            child: CircularProgressIndicator(
              color: AppColors.fg(context),
              strokeWidth: 2.5,
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: AppTheme.brutalCard(context),
      child: Row(
        children: [
          _statTile(
            context,
            value: '${stats?.totalReels ?? 0}',
            label: 'REELS',
            color: AppColors.yellow,
          ),
          _divider(context),
          _statTile(
            context,
            value: '${stats?.totalPinnedLocations ?? 0}',
            label: 'PINNED',
            color: AppColors.neonGreen,
          ),
          _divider(context),
          _statTile(
            context,
            value: '${stats?.totalTags ?? 0}',
            label: 'TAGS',
            color: AppColors.hotPink,
          ),
        ],
      ),
    );
  }

  Widget _actionCard(
    BuildContext context, {
    required Color color,
    required String title,
    required String subtitle,
    required Widget trailing,
  }) {
    final layout = AppLayout.of(context);
    return Container(
      decoration: AppTheme.brutalCard(context, color: color),
      child: Padding(
        padding: EdgeInsets.all(layout.inset(16)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.spaceMono(
                      color: AppColors.fg(context),
                      fontSize: layout.font(13),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: layout.gap(6)),
                  Text(
                    subtitle,
                    style: GoogleFonts.spaceMono(
                      color: AppColors.textSec(context),
                      fontSize: layout.font(11),
                      fontWeight: FontWeight.w500,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: layout.inset(12)),
            trailing,
          ],
        ),
      ),
    );
  }
}
