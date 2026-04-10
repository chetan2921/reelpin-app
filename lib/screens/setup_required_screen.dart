import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/supabase_config.dart';
import '../theme/app_theme.dart';

class SetupRequiredScreen extends StatelessWidget {
  const SetupRequiredScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SUPABASE SETUP REQUIRED',
                style: GoogleFonts.spaceMono(
                  color: AppTheme.fg(context),
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                decoration: AppTheme.brutalCard(
                  context,
                  color: AppTheme.yellow,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Text(
                    'ADD YOUR SUPABASE PROJECT URL AND ANON KEY WITH DART DEFINES BEFORE RUNNING THE APP.',
                    style: GoogleFonts.spaceMono(
                      color: AppTheme.fg(context),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                decoration: AppTheme.brutalBox(context, shadow: false),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SelectableText(
                    'flutter run',
                    style: GoogleFonts.spaceMono(
                      color: AppTheme.fg(context),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      height: 1.6,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'LOCAL-ONLY FILE KEYS:',
                style: GoogleFonts.spaceMono(
                  color: AppTheme.textSec(context),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                decoration: AppTheme.brutalBox(context, shadow: false),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SelectableText(
                    'assets/config/local.env\n\n'
                    'SUPABASE_URL=https://YOUR_PROJECT_REF.supabase.co\n'
                    'SUPABASE_ANON_KEY=YOUR_SUPABASE_ANON_KEY\n'
                    'SUPABASE_REDIRECT_SCHEME=${SupabaseConfig.redirectScheme}\n'
                    'SUPABASE_REDIRECT_HOST=${SupabaseConfig.redirectHost}',
                    style: GoogleFonts.spaceMono(
                      color: AppTheme.fg(context),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      height: 1.6,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'DEFAULT OAUTH REDIRECT URL:',
                style: GoogleFonts.spaceMono(
                  color: AppTheme.textSec(context),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: AppTheme.brutalBox(
                  context,
                  color: AppTheme.cyan.withAlpha(40),
                  shadow: false,
                ),
                child: Text(
                  SupabaseConfig.redirectUrl,
                  style: GoogleFonts.spaceMono(
                    color: AppTheme.fg(context),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
