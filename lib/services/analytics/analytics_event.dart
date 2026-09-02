/// Every event ReelPin is allowed to report.
///
/// The set is deliberately closed. Firebase reports on up to 500 distinct event
/// names at no cost, and the analytics tools that sit behind the same call are
/// capped by volume rather than by name, so a fixed enum keeps both budgets
/// predictable: nothing reaches the wire without being added here first.
///
/// Names follow Firebase's rules — snake_case, 40 characters or fewer, starting
/// with a letter. Events Firebase collects on its own (`first_open`,
/// `session_start`, `screen_view`, `app_update`) are deliberately absent; adding
/// them here would double-count.
enum AnalyticsEvent {
  onboardingStarted('onboarding_started'),
  onboardingCompleted('onboarding_completed'),

  signupCompleted('signup_completed'),
  loginCompleted('login_completed'),
  logoutCompleted('logout_completed'),

  shareReceived('share_received'),
  shareDuplicateSkipped('share_duplicate_skipped'),
  reelSaveStarted('reel_save_started'),
  reelSaveSucceeded('reel_save_succeeded'),
  reelSaveFailed('reel_save_failed'),
  reelOpened('reel_opened'),
  reelDeleted('reel_deleted'),

  collectionCreated('collection_created'),
  collectionDeleted('collection_deleted'),
  collectionShared('collection_shared'),
  collectionLinkOpened('collection_link_opened'),

  searchPerformed('search_performed'),
  discoverOpened('discover_opened'),
  mapOpened('map_opened'),

  howToOpened('how_to_opened'),
  paywallViewed('paywall_viewed'),
  notificationOpened('notification_opened');

  const AnalyticsEvent(this.wireName);

  /// The name sent to the analytics backends.
  final String wireName;
}
