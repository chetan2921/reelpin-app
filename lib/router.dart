import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:reelpin/data_models/chat/chat_attachment.dart';
import 'package:reelpin/data_models/reels/reel.dart';
import 'package:reelpin/providers.dart';
import 'package:reelpin/services/analytics/analytics_event.dart';
import 'package:reelpin/services/analytics/analytics_service.dart';
import 'package:reelpin/services/billing/billing_service.dart';
import 'package:reelpin/screens/collections/collection_detail_screen.dart';
import 'package:reelpin/screens/feature_announcement/feature_announcement_screen.dart';
import 'package:reelpin/screens/how_to/how_to_use_screen.dart';
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

/// [animate] is false when this is where a launch link landed, for the same
/// reason as [sharedCollectionRoute]: the collection is the destination, so it
/// should appear rather than slide in over whatever was behind it.
Route<void> collectionDetailRoute(String collectionId, {bool animate = true}) {
  final screen = CollectionDetailScreen(collectionId: collectionId);
  if (animate) return MaterialPageRoute<void>(builder: (_) => screen);
  return PageRouteBuilder<void>(
    pageBuilder: (_, _, _) => screen,
    transitionDuration: Duration.zero,
    reverseTransitionDuration: Duration.zero,
  );
}

/// Read-only view of a collection opened from a share link. The token is the
/// capability, so there is no collection id to pass.
///
/// [animate] is false for the link the app was launched with. Sliding the
/// collection in leaves Home on screen for the length of the transition, which
/// on a cold start reads as the app opening Home and then moving somewhere else;
/// the collection is the destination, so it should simply be what appears.
Route<void> sharedCollectionRoute(
  String token, {
  bool animate = true,
  String? url,
}) {
  final screen = CollectionDetailScreen(
    collectionId: '',
    sharedToken: token,
    sharedUrl: url,
  );
  if (animate) return MaterialPageRoute<void>(builder: (_) => screen);
  return PageRouteBuilder<void>(
    pageBuilder: (_, _, _) => screen,
    transitionDuration: Duration.zero,
    reverseTransitionDuration: Duration.zero,
  );
}

/// Where a paywall was opened from, for analytics.
enum PaywallEntryPoint { account, saveLimit, history, chat }

/// Shows RevenueCat's paywall. True when the user bought or restored Pro; the
/// plan is then re-read with a backend sync, because the purchase webhook may
/// not have landed yet and every screen gating on the plan should update now.
Future<bool> openPaywall(
  BuildContext context, {
  PaywallEntryPoint entryPoint = PaywallEntryPoint.account,
}) async {
  unawaited(
    AnalyticsService.log(
      AnalyticsEvent.paywallViewed,
      parameters: {'entry_point': entryPoint.name},
    ),
  );
  final container = ProviderScope.containerOf(context, listen: false);
  final messenger = ScaffoldMessenger.maybeOf(context);
  final outcome = await BillingService.instance.presentPaywall();
  if (outcome == PaywallOutcome.unavailable) {
    messenger?.showSnackBar(const SnackBar(content: Text(_storeUnavailable)));
  }
  final unlocked = outcome == PaywallOutcome.unlocked;
  if (unlocked) {
    unawaited(
      container
          .read(entitlementsViewModelProvider)
          .refresh(reloadContent: true, syncBilling: true),
    );
  }
  return unlocked;
}

/// Opens RevenueCat's subscription management (cancel, change plan, restore).
Future<void> openSubscriptionManagement(BuildContext context) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (!await BillingService.instance.manageSubscription()) {
    messenger?.showSnackBar(const SnackBar(content: Text(_storeUnavailable)));
  }
}

const _storeUnavailable =
    "Couldn't reach the store right now. Please try again.";

/// Every door into the chat funnels through here: seed the composer, then
/// select the tab. One path, so a reel, a collection and the search bar cannot
/// drift into three different behaviours.
Future<void> openChat(
  BuildContext context,
  WidgetRef ref, {
  String seedText = '',
  List<ChatAttachment> seedAttachments = const [],
  required VoidCallback showAskTab,
}) async {
  ref
      .read(chatViewModelProvider)
      .startNewThread(seedText: seedText, seedAttachments: seedAttachments);
  Navigator.of(context).popUntil((route) => route.isFirst);
  showAskTab();
}
