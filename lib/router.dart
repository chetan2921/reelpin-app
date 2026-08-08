import 'package:flutter/material.dart';

import 'package:reelpin/data_models/reels/reel.dart';
import 'package:reelpin/screens/feature_announcement/feature_announcement_screen.dart';
import 'package:reelpin/screens/how_to/how_to_use_screen.dart';
import 'package:reelpin/screens/paywall/paywall_screen.dart';
import 'package:reelpin/screens/profile/profile_screen.dart';
import 'package:reelpin/screens/reel_detail/reel_detail_loader_screen.dart';
import 'package:reelpin/screens/reel_detail/reel_detail_screen.dart';

/// Every push target in the app, built in one place so screens do not construct
/// routes inline. These use Flutter's own [Navigator] APIs — there is no route
/// table or generated router.

Route<void> reelDetailRoute(Reel reel) {
  return MaterialPageRoute<void>(builder: (_) => ReelDetailScreen(reel: reel));
}

/// Slide-in variant used by the home grid.
Route<void> reelDetailSlideRoute(Reel reel) {
  return PageRouteBuilder<void>(
    pageBuilder: (_, _, _) => ReelDetailScreen(reel: reel),
    transitionsBuilder: (_, anim, _, child) {
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
        child: child,
      );
    },
    transitionDuration: const Duration(milliseconds: 200),
  );
}

Route<void> reelDetailLoaderRoute(String reelId) {
  return MaterialPageRoute<void>(
    builder: (_) => ReelDetailLoaderScreen(reelId: reelId),
  );
}

Route<void> featureAnnouncementRoute({
  required String title,
  required String body,
}) {
  return MaterialPageRoute<void>(
    builder: (_) => FeatureAnnouncementScreen(title: title, body: body),
  );
}

Route<void> howToUseRoute({bool isFirstRun = false}) {
  return MaterialPageRoute<void>(
    builder: (_) => HowToUseScreen(isFirstRun: isFirstRun),
    fullscreenDialog: !isFirstRun,
  );
}

Route<void> profileRoute() {
  return MaterialPageRoute<void>(builder: (_) => const ProfileScreen());
}

Route<void> paywallRoute({
  PaywallEntryPoint entryPoint = PaywallEntryPoint.account,
}) {
  return MaterialPageRoute<void>(
    builder: (_) => PaywallScreen(entryPoint: entryPoint),
  );
}

Future<void> openPaywall(
  BuildContext context, {
  PaywallEntryPoint entryPoint = PaywallEntryPoint.account,
}) {
  return Navigator.of(context).push(paywallRoute(entryPoint: entryPoint));
}
