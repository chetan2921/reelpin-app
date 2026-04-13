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
    final layout = AppLayout.of(context);

    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      appBar: AppBar(
        backgroundColor: AppTheme.bg(context),
        surfaceTintColor: Colors.transparent,
        title: Text(
          'PROFILE',
          style: GoogleFonts.spaceMono(
            color: AppTheme.fg(context),
            fontSize: layout.font(22),
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
            const heroTextColor = AppTheme.white;
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
                                  color: AppTheme.black,
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
                SizedBox(height: layout.gap(18)),
                _sectionTitle(context, 'PREFERENCES'),
                SizedBox(height: layout.gap(10)),
                _actionCard(
                  context,
                  color: AppTheme.bg(context),
                  title: 'THEME MODE',
                  subtitle:
                      'DEFAULTS TO DARK AND NOW PERSISTS ACROSS APP RESTARTS.',
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
                              fontSize: layout.font(11),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(height: layout.gap(18)),
                _sectionTitle(context, 'ACCOUNT'),
                SizedBox(height: layout.gap(10)),
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
                      padding: EdgeInsets.symmetric(vertical: layout.gap(16)),
                      child: Center(
                        child: Text(
                          sessionVm.isSigningOut
                              ? 'SIGNING OUT...'
                              : 'SIGN OUT',
                          style: GoogleFonts.spaceMono(
                            color: AppTheme.white,
                            fontSize: layout.font(14),
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
    final layout = AppLayout.of(context);
    return Text(
      text,
      style: GoogleFonts.spaceMono(
        color: AppTheme.textSec(context),
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
      color: AppTheme.fg(context),
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
                color: AppTheme.fg(context),
                fontSize: layout.font(22),
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: layout.gap(6)),
            Text(
              label,
              style: GoogleFonts.spaceMono(
                color: AppTheme.fg(context),
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
                      color: AppTheme.fg(context),
                      fontSize: layout.font(13),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: layout.gap(6)),
                  Text(
                    subtitle,
                    style: GoogleFonts.spaceMono(
                      color: AppTheme.textSec(context),
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
