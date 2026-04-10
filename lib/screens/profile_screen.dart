import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../theme/app_theme.dart';
import '../viewmodels/home_viewmodel.dart';
import '../viewmodels/session_viewmodel.dart';
import '../viewmodels/theme_viewmodel.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      appBar: AppBar(
        backgroundColor: AppTheme.bg(context),
        surfaceTintColor: Colors.transparent,
        title: Text(
          'PROFILE',
          style: GoogleFonts.spaceMono(
            color: AppTheme.fg(context),
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back, color: AppTheme.fg(context)),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Consumer3<SessionViewModel, ThemeViewModel, HomeViewModel>(
          builder: (context, sessionVm, themeVm, homeVm, _) {
            final pinned = homeVm.totalPinnedLocations;
            final categories = {
              ...homeVm.reels.map((reel) => reel.category),
              ...homeVm.reels.map((reel) => reel.subCategory),
            }.length;

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                Container(
                  decoration: AppTheme.brutalCard(
                    context,
                    color: AppTheme.cyan.withGreen(30),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: AppTheme.yellow,
                                border: Border.all(
                                  color: AppTheme.fg(context),
                                  width: 3,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                sessionVm.initials,
                                style: GoogleFonts.spaceMono(
                                  color: AppTheme.fg(context),
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    sessionVm.displayName.toUpperCase(),
                                    style: GoogleFonts.spaceMono(
                                      color: AppTheme.fg(context),
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    sessionVm.email,
                                    style: GoogleFonts.spaceMono(
                                      color: AppTheme.textSec(context),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'YOUR ACCOUNT HOLDS THE FULL LIBRARY, MAP PINS, AND DISCOVER INSIGHTS FOR EVERYTHING YOU SEND TO REELPIN.',
                          style: GoogleFonts.spaceMono(
                            color: AppTheme.fg(context),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                _sectionTitle(context, 'COLLECTION STATS'),
                const SizedBox(height: 10),
                Container(
                  decoration: AppTheme.brutalCard(context),
                  child: Row(
                    children: [
                      _statTile(
                        context,
                        value: '${homeVm.reels.length}',
                        label: 'REELS',
                        color: AppTheme.yellow,
                      ),
                      _divider(context),
                      _statTile(
                        context,
                        value: '$pinned',
                        label: 'PINNED',
                        color: AppTheme.neonGreen,
                      ),
                      _divider(context),
                      _statTile(
                        context,
                        value: '$categories',
                        label: 'TAGS',
                        color: AppTheme.hotPink,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _sectionTitle(context, 'PREFERENCES'),
                const SizedBox(height: 10),
                _actionCard(
                  context,
                  color: AppTheme.bg(context),
                  title: 'THEME MODE',
                  subtitle:
                      'DEFAULTS TO DARK AND NOW PERSISTS ACROSS APP RESTARTS.',
                  trailing: GestureDetector(
                    onTap: () => themeVm.toggleTheme(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: AppTheme.brutalBox(
                        context,
                        color: themeVm.isDarkMode
                            ? AppTheme.grauzone
                            : AppTheme.accentSoft,
                        shadow: false,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            themeVm.themeIcon,
                            size: 16,
                            color: AppTheme.fg(context),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            themeVm.themeLabel,
                            style: GoogleFonts.spaceMono(
                              color: themeVm.isDarkMode
                                  ? AppTheme.background
                                  : AppTheme.black,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                _sectionTitle(context, 'ACCOUNT'),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () async {
                    await sessionVm.signOut();
                    if (context.mounted) {
                      Navigator.pop(context);
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    decoration: AppTheme.brutalCard(
                      context,
                      color: AppTheme.red,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: Text(
                          sessionVm.isSigningOut
                              ? 'SIGNING OUT...'
                              : 'SIGN OUT',
                          style: GoogleFonts.spaceMono(
                            color: AppTheme.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String text) {
    return Text(
      text,
      style: GoogleFonts.spaceMono(
        color: AppTheme.textSec(context),
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1,
      ),
    );
  }

  Widget _divider(BuildContext context) {
    return Container(
      width: AppTheme.borderWidth,
      height: 90,
      color: AppTheme.fg(context),
    );
  }

  Widget _statTile(
    BuildContext context, {
    required String value,
    required String label,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        color: color.withAlpha(50),
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            Text(
              value,
              style: GoogleFonts.spaceMono(
                color: AppTheme.fg(context),
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: GoogleFonts.spaceMono(
                color: AppTheme.fg(context),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
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
    return Container(
      decoration: AppTheme.brutalCard(context, color: color),
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                      color: AppTheme.fg(context),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: GoogleFonts.spaceMono(
                      color: AppTheme.textSec(context),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            trailing,
          ],
        ),
      ),
    );
  }
}
