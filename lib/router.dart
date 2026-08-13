import 'package:flutter/material.dart';

import 'package:reelpin/data_models/reels/reel.dart';
import 'package:reelpin/screens/collections/collection_detail_screen.dart';
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

Route<void> collectionDetailRoute(String collectionId) {
  return MaterialPageRoute<void>(
    builder: (_) => CollectionDetailScreen(collectionId: collectionId),
  );
}

/// Read-only view of a collection opened from a share link. The token is the
/// capability, so there is no collection id to pass.
///
/// [animate] is false for the link the app was launched with. Sliding the
/// collection in leaves Home on screen for the length of the transition, which
/// on a cold start reads as the app opening Home and then moving somewhere else;
/// the collection is the destination, so it should simply be what appears.
Route<void> sharedCollectionRoute(String token, {bool animate = true}) {
  final screen = CollectionDetailScreen(collectionId: '', sharedToken: token);
  if (animate) return MaterialPageRoute<void>(builder: (_) => screen);
  return PageRouteBuilder<void>(
    pageBuilder: (_, _, _) => screen,
    transitionDuration: Duration.zero,
    reverseTransitionDuration: Duration.zero,
  );
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
