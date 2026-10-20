import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:reelpin/data_models/account/user_entitlement.dart';
import 'package:reelpin/providers.dart';
import 'package:reelpin/constants/app_layout.dart';
import 'package:reelpin/constants/app_colors.dart';
import 'package:reelpin/constants/app_theme.dart';

enum PaywallEntryPoint {
  account('account'),
  saveLimit('save_limit'),
  history('history');

  const PaywallEntryPoint(this.messageKey);

  /// The key of this entry point's copy in the entitlements paywall messages.
  final String messageKey;
}

class PaywallScreen extends ConsumerWidget {
  const PaywallScreen({super.key, required this.entryPoint});

  final PaywallEntryPoint entryPoint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layout = AppLayout.of(context);
    final entitlementVm = ref.watch(entitlementsViewModelProvider);
    final entitlementResponse = entitlementVm.response;
    final entitlements = entitlementVm.entitlement;
    final isRefreshing = entitlementVm.isLoading;
    final message = entitlementResponse?.messageFor(entryPoint.messageKey);

    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        backgroundColor: AppColors.bg(context),
        surfaceTintColor: Colors.transparent,
        title: Text(
          'REELPIN PRO',
          style: GoogleFonts.spaceMono(
            color: AppColors.fg(context),
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
                      color: AppColors.yellow,
                      border: Border.all(
                        color: AppColors.fg(context),
                        width: AppTheme.borderWidth,
                      ),
                    ),
                    child: Text(
                      entryPoint.messageKey.replaceAll('_', ' ').toUpperCase(),
                      style: GoogleFonts.spaceMono(
                        color: AppColors.black,
                        fontSize: layout.font(10),
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  SizedBox(height: layout.gap(14)),
                  Text(
                    (message ?? '').toUpperCase(),
                    style: GoogleFonts.spaceMono(
                      color: AppColors.white,
                      fontSize: layout.font(20),
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: layout.gap(18)),
          _sectionTitle(context, 'CURRENT PLAN'),
          SizedBox(height: layout.gap(10)),
          _statusCard(context, entitlementResponse),
          SizedBox(height: layout.gap(18)),
          _sectionTitle(context, 'PLAN COMPARISON'),
          SizedBox(height: layout.gap(10)),
          ..._buildBackendPlanCards(
            context,
            entitlementResponse?.planCards ?? const [],
          ),
          SizedBox(height: layout.gap(18)),
          GestureDetector(
            onTap: isRefreshing
                ? null
                : () => ref
                      .read(entitlementsViewModelProvider)
                      .refresh(reloadContent: true),
            child: Container(
              decoration: AppTheme.brutalCard(
                context,
                color: AppColors.hotPink,
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: layout.gap(16)),
                child: Center(
                  child: isRefreshing
                      ? SizedBox(
                          width: layout.inset(18),
                          height: layout.inset(18),
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: AppColors.white,
                          ),
                        )
                      : Text(
                          entitlements?.isPro == true
                              ? 'REFRESH PRO ACCESS'
                              : 'CHECK MY PLAN AGAIN',
                          style: GoogleFonts.spaceMono(
                            color: AppColors.white,
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
                color: AppColors.destructive,
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
        color: AppColors.textSec(context),
        fontSize: layout.font(11),
        fontWeight: FontWeight.w700,
        letterSpacing: 1,
      ),
    );
  }

  Widget _statusCard(BuildContext context, EntitlementsResponse? response) {
    final layout = AppLayout.of(context);
    final entitlements = response?.currentEntitlement;
    if (entitlements == null) {
      return Container(
        decoration: AppTheme.brutalCard(context),
        child: Padding(
          padding: EdgeInsets.all(layout.inset(16)),
          child: Text(
            'LOADING YOUR PLAN...',
            style: GoogleFonts.spaceMono(
              color: AppColors.fg(context),
              fontSize: layout.font(12),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }

    final usageText = response!.limits.savedReels == null
        ? '${response.usage.savedReels} reels saved'
        : '${response.usage.savedReels}/${response.limits.savedReels} reels saved';

    return Container(
      decoration: AppTheme.brutalCard(
        context,
        color: entitlements.isPro
            ? const Color(0xFFE1FFF5)
            : AppColors.bg(context),
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
                        ? AppColors.neonGreen
                        : AppColors.yellow,
                    border: Border.all(
                      color: AppColors.fg(context),
                      width: AppTheme.borderWidth,
                    ),
                  ),
                  child: Text(
                    entitlements.plan.toUpperCase(),
                    style: GoogleFonts.spaceMono(
                      color: AppColors.black,
                      fontSize: layout.font(10),
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
                color: AppColors.fg(context),
                fontSize: layout.font(11),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildBackendPlanCards(
    BuildContext context,
    List<PlanCard> planCards,
  ) {
    final layout = AppLayout.of(context);
    if (planCards.isEmpty) {
      return [
        Container(
          decoration: AppTheme.brutalCard(context),
          padding: EdgeInsets.all(layout.inset(16)),
          child: Text(
            'PLAN DETAILS ARE NOT AVAILABLE RIGHT NOW.',
            style: GoogleFonts.spaceMono(
              color: AppColors.fg(context),
              fontSize: layout.font(12),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ];
    }

    return [
      for (var index = 0; index < planCards.length; index++) ...[
        if (index > 0) SizedBox(height: layout.gap(12)),
        _planCard(
          context,
          card: planCards[index],
          accent: index == 0 ? AppColors.yellow : AppColors.neonGreen,
        ),
      ],
    ];
  }

  Widget _planCard(
    BuildContext context, {
    required PlanCard card,
    required Color accent,
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
                      color: AppColors.fg(context),
                      width: AppTheme.borderWidth,
                    ),
                  ),
                  child: Text(
                    card.name.toUpperCase(),
                    style: GoogleFonts.spaceMono(
                      color: accent.computeLuminance() > 0.5
                          ? AppColors.black
                          : AppColors.white,
                      fontSize: layout.font(10),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                SizedBox(width: layout.inset(10)),
                Expanded(
                  child: Text(
                    card.price.toUpperCase(),
                    style: GoogleFonts.spaceMono(
                      color: AppColors.fg(context),
                      fontSize: layout.font(13),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: layout.gap(12)),
            ...card.features.map(
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
                          color: AppColors.fg(context),
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
}
