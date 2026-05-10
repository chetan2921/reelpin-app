import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/user_entitlement.dart';
import '../providers/app_providers.dart';
import '../theme/app_theme.dart';

enum PaywallEntryPoint { account, saveLimit, history }

Future<void> openPaywall(
  BuildContext context, {
  PaywallEntryPoint entryPoint = PaywallEntryPoint.account,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => PaywallScreen(entryPoint: entryPoint)),
  );
}

class PaywallScreen extends ConsumerWidget {
  const PaywallScreen({super.key, required this.entryPoint});

  final PaywallEntryPoint entryPoint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layout = AppLayout.of(context);
    final entitlementVm = ref.watch(entitlementsViewModelProvider);
    final entitlements = entitlementVm.entitlement;
    final isRefreshing = entitlementVm.isLoading;

    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      appBar: AppBar(
        backgroundColor: AppTheme.bg(context),
        surfaceTintColor: Colors.transparent,
        title: Text(
          'REELPIN PRO',
          style: GoogleFonts.spaceMono(
            color: AppTheme.fg(context),
            fontSize: layout.font(18),
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
      ),
      body: ListView(
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
              color: const Color(0xFF0D3A5A),
            ),
            child: Padding(
              padding: EdgeInsets.all(layout.inset(20)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: layout.inset(10),
                      vertical: layout.gap(6),
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.yellow,
                      border: Border.all(
                        color: AppTheme.fg(context),
                        width: AppTheme.borderWidth,
                      ),
                    ),
                    child: Text(
                      _titleForEntryPoint(entryPoint),
                      style: GoogleFonts.spaceMono(
                        color: AppTheme.black,
                        fontSize: layout.font(10),
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  SizedBox(height: layout.gap(14)),
                  Text(
                    _headlineForEntryPoint(entryPoint),
                    style: GoogleFonts.spaceMono(
                      color: AppTheme.white,
                      fontSize: layout.font(20),
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                    ),
                  ),
                  SizedBox(height: layout.gap(10)),
                  Text(
                    _supportingText(entitlements, entryPoint),
                    style: GoogleFonts.spaceMono(
                      color: const Color(0xFFD6F3EF),
                      fontSize: layout.font(11),
                      fontWeight: FontWeight.w500,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: layout.gap(18)),
          _sectionTitle(context, 'CURRENT PLAN'),
          SizedBox(height: layout.gap(10)),
          _statusCard(context, entitlements),
          SizedBox(height: layout.gap(18)),
          _sectionTitle(context, 'PLAN COMPARISON'),
          SizedBox(height: layout.gap(10)),
          _planCard(
            context,
            title: 'FREE',
            accent: AppTheme.yellow,
            price: '₹0',
            bullets: const [
              '30 reels each month',
              'Keyword search',
              'Private only',
              'Last 30 days of saved history',
              '30 map pins',
            ],
          ),
          SizedBox(height: layout.gap(12)),
          _planCard(
            context,
            title: 'PRO',
            accent: AppTheme.neonGreen,
            price:
                '${entitlements?.monthlyPriceLabel ?? '₹149/month'} or ${entitlements?.yearlyPriceLabel ?? '₹999/year'}',
            bullets: const [
              'Unlimited reels',
              'Conversational search',
              'Sharing',
              'Weekly digest',
              'Full history',
              'Priority processing',
            ],
          ),
          SizedBox(height: layout.gap(18)),
          _sectionTitle(context, 'LAUNCH NOTE'),
          SizedBox(height: layout.gap(10)),
          Container(
            decoration: AppTheme.brutalCard(context),
            child: Padding(
              padding: EdgeInsets.all(layout.inset(16)),
              child: Text(
                'BILLING IS NOT LIVE IN THE APP YET. PRO ACCESS IS ASSIGNED OUTSIDE THE APP FOR LAUNCH TESTING. AFTER YOUR PLAN CHANGES, COME BACK HERE AND REFRESH.',
                style: GoogleFonts.spaceMono(
                  color: AppTheme.textSec(context),
                  fontSize: layout.font(11),
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                ),
              ),
            ),
          ),
          SizedBox(height: layout.gap(18)),
          GestureDetector(
            onTap: isRefreshing
                ? null
                : () => ref
                      .read(entitlementsViewModelProvider)
                      .refresh(reloadContent: true),
            child: Container(
              decoration: AppTheme.brutalCard(context, color: AppTheme.hotPink),
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: layout.gap(16)),
                child: Center(
                  child: isRefreshing
                      ? SizedBox(
                          width: layout.inset(18),
                          height: layout.inset(18),
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: AppTheme.white,
                          ),
                        )
                      : Text(
                          entitlements?.isPro == true
                              ? 'REFRESH PRO ACCESS'
                              : 'CHECK MY PLAN AGAIN',
                          style: GoogleFonts.spaceMono(
                            color: AppTheme.white,
                            fontSize: layout.font(13),
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                ),
              ),
            ),
          ),
          if (entitlementVm.error != null) ...[
            SizedBox(height: layout.gap(12)),
            Text(
              entitlementVm.error!,
              style: GoogleFonts.spaceMono(
                color: AppTheme.destructive,
                fontSize: layout.font(11),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
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

  Widget _statusCard(BuildContext context, UserEntitlement? entitlements) {
    final layout = AppLayout.of(context);
    if (entitlements == null) {
      return Container(
        decoration: AppTheme.brutalCard(context),
        child: Padding(
          padding: EdgeInsets.all(layout.inset(16)),
          child: Text(
            'LOADING YOUR PLAN...',
            style: GoogleFonts.spaceMono(
              color: AppTheme.fg(context),
              fontSize: layout.font(12),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }

    final usageText = entitlements.limits.reelsPerMonth == null
        ? 'Unlimited saves'
        : '${entitlements.usage.reelsSavedThisMonth}/${entitlements.limits.reelsPerMonth} reels used this month';

    return Container(
      decoration: AppTheme.brutalCard(
        context,
        color: entitlements.isPro
            ? const Color(0xFFE1FFF5)
            : AppTheme.bg(context),
      ),
      child: Padding(
        padding: EdgeInsets.all(layout.inset(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: layout.inset(10),
                    vertical: layout.gap(6),
                  ),
                  decoration: BoxDecoration(
                    color: entitlements.isPro
                        ? AppTheme.neonGreen
                        : AppTheme.yellow,
                    border: Border.all(
                      color: AppTheme.fg(context),
                      width: AppTheme.borderWidth,
                    ),
                  ),
                  child: Text(
                    entitlements.planLabel,
                    style: GoogleFonts.spaceMono(
                      color: AppTheme.black,
                      fontSize: layout.font(10),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                SizedBox(width: layout.inset(10)),
                Expanded(
                  child: Text(
                    '${entitlements.searchModeLabel} SEARCH',
                    style: GoogleFonts.spaceMono(
                      color: AppTheme.fg(context),
                      fontSize: layout.font(12),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: layout.gap(12)),
            Text(
              usageText.toUpperCase(),
              style: GoogleFonts.spaceMono(
                color: AppTheme.fg(context),
                fontSize: layout.font(11),
                fontWeight: FontWeight.w700,
              ),
            ),
            if (entitlements.limits.accessibleHistoryDays != null) ...[
              SizedBox(height: layout.gap(6)),
              Text(
                'History window: last ${entitlements.limits.accessibleHistoryDays} days',
                style: GoogleFonts.spaceMono(
                  color: AppTheme.textSec(context),
                  fontSize: layout.font(11),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _planCard(
    BuildContext context, {
    required String title,
    required Color accent,
    required String price,
    required List<String> bullets,
  }) {
    final layout = AppLayout.of(context);
    return Container(
      decoration: AppTheme.brutalCard(context),
      child: Padding(
        padding: EdgeInsets.all(layout.inset(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: layout.inset(10),
                    vertical: layout.gap(6),
                  ),
                  decoration: BoxDecoration(
                    color: accent,
                    border: Border.all(
                      color: AppTheme.fg(context),
                      width: AppTheme.borderWidth,
                    ),
                  ),
                  child: Text(
                    title,
                    style: GoogleFonts.spaceMono(
                      color: accent.computeLuminance() > 0.5
                          ? AppTheme.black
                          : AppTheme.white,
                      fontSize: layout.font(10),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                SizedBox(width: layout.inset(10)),
                Expanded(
                  child: Text(
                    price.toUpperCase(),
                    style: GoogleFonts.spaceMono(
                      color: AppTheme.fg(context),
                      fontSize: layout.font(13),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: layout.gap(12)),
            ...bullets.map(
              (bullet) => Padding(
                padding: EdgeInsets.only(bottom: layout.gap(8)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: EdgeInsets.only(top: layout.gap(4)),
                      width: layout.inset(8),
                      height: layout.inset(8),
                      color: accent,
                    ),
                    SizedBox(width: layout.inset(10)),
                    Expanded(
                      child: Text(
                        bullet.toUpperCase(),
                        style: GoogleFonts.spaceMono(
                          color: AppTheme.fg(context),
                          fontSize: layout.font(11),
                          fontWeight: FontWeight.w600,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _titleForEntryPoint(PaywallEntryPoint entryPoint) {
    switch (entryPoint) {
      case PaywallEntryPoint.saveLimit:
        return 'SAVE LIMIT';
      case PaywallEntryPoint.history:
        return 'FULL HISTORY';
      case PaywallEntryPoint.account:
        return 'ACCOUNT';
    }
  }

  String _headlineForEntryPoint(PaywallEntryPoint entryPoint) {
    switch (entryPoint) {
      case PaywallEntryPoint.saveLimit:
        return 'You hit the Free save limit for this month.';
      case PaywallEntryPoint.history:
        return 'Older saved reels live behind Pro.';
      case PaywallEntryPoint.account:
        return 'Choose how much of ReelPin you want unlocked.';
    }
  }

  String _supportingText(
    UserEntitlement? entitlements,
    PaywallEntryPoint entryPoint,
  ) {
    final monthlyLimit = entitlements?.limits.reelsPerMonth ?? 30;
    final historyDays = entitlements?.limits.accessibleHistoryDays ?? 30;

    switch (entryPoint) {
      case PaywallEntryPoint.saveLimit:
        return 'Free includes $monthlyLimit saves each month. Pro removes the cap and keeps priority processing turned on.';
      case PaywallEntryPoint.history:
        return 'Free only shows the last $historyDays days of saved history. Pro keeps your full library available.';
      case PaywallEntryPoint.account:
        return 'Free keeps the basics. Pro unlocks unlimited saves, conversational search, sharing, weekly digest, full history, and priority processing.';
    }
  }
}
