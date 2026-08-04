import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:reelpin/constants/app_colors.dart';
import 'package:reelpin/constants/app_theme.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg(context),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        width: 116,
                        height: 116,
                        color: AppColors.fg(context),
                      ),
                    ),
                    Container(
                      width: 116,
                      height: 116,
                      decoration: AppTheme.brutalBox(
                        context,
                        color: AppColors.yellow,
                        shadow: false,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Image.asset(
                          'assets/images/splash_icon.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                Text(
                  'REELPIN',
                  style: GoogleFonts.spaceMono(
                    color: AppColors.fg(context),
                    fontSize: 34,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'SYNCING YOUR SAVED WORLD',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.spaceMono(
                    color: AppColors.textSec(context),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 28),
                Container(
                  width: 220,
                  padding: const EdgeInsets.all(4),
                  decoration: AppTheme.brutalBox(context, shadow: false),
                  child: LinearProgressIndicator(
                    minHeight: 10,
                    color: AppColors.red,
                    backgroundColor: AppColors.accentSoft,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
