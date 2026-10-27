import 'package:flutter_test/flutter_test.dart';

import 'package:reelpin/data_models/account/user_entitlement.dart';

/// The v2 shape, as `internal/entitlements` builds it for a free user.
EntitlementsResponse _response({
  int savedReels = 3,
  int? savedReelsLimit = 25,
  String plan = 'free',
  bool isPremium = false,
  bool restricted = false,
}) {
  return EntitlementsResponse.fromJson({
    'user_id': 'user-1',
    'current_entitlement': {
      'plan': plan,
      'billing_interval': 'monthly',
      'subscription_status': 'active',
      'is_premium': isPremium,
      'restricted': restricted,
      'error_message': null,
    },
    'usage': {
      'saved_reels': savedReels,
      'pinned_locations': 1,
      'tags': 0,
      'categories': 2,
      'subcategories': 2,
    },
    'limits': {
      'saved_reels': savedReelsLimit,
      'pinned_locations': 10,
      'searches_per_month': 50,
      'processing_jobs_per_hour': null,
    },
    'features': {
      'save_reels': true,
      'search': true,
      'map': true,
      'discover': true,
      'unlimited_saves': isPremium,
      'unlimited_map_pins': isPremium,
    },
    'pricing': {'pro_monthly': r'$9.99'},
    'plan_cards': [
      {
        'plan': 'pro',
        'name': 'Pro',
        'billing_interval': 'monthly',
        'price': r'$9.99/mo',
        'features': ['Unlimited saved reels'],
        'limits': {'saved_reels': null},
        'cta_label': 'Upgrade',
      },
    ],
    'paywall_messages': {
      'account': 'Upgrade to Pro for unlimited saves, search, and map pins.',
      'save_limit': 'You have reached the Free save limit.',
      'history': 'Upgrade to Pro to keep your full reel history.',
    },
    'plan': plan,
    'is_premium': isPremium,
  });
}

void main() {
  test('reads the v2 shape', () {
    final response = _response();

    expect(response.currentEntitlement.userId, 'user-1');
    expect(response.currentEntitlement.plan, 'free');
    expect(response.currentEntitlement.isFree, isTrue);
    expect(response.usage.savedReels, 3);
    expect(response.limits.savedReels, 25);
    expect(response.limits.processingJobsPerHour, isNull);
    expect(response.features['map'], isTrue);
    expect(response.pricing['pro_monthly'], r'$9.99');
    expect(response.planCards.single.name, 'Pro');
    expect(response.planCards.single.price, r'$9.99/mo');
    expect(response.planCards.single.limits.savedReels, isNull);
    expect(
      response.messageFor('save_limit'),
      'You have reached the Free save limit.',
    );
  });

  test('premium is Pro only when the plan is not restricted', () {
    expect(_response(isPremium: true).currentEntitlement.isPro, isTrue);
    expect(
      _response(isPremium: true, restricted: true).currentEntitlement.isPro,
      isFalse,
    );
  });

  test('saving a reel does not read as a change in access', () {
    // The signature decides whether every visible tab is wiped and refetched.
    // Usage ticking up on each save must not trigger that.
    final before = _response(savedReels: 3);
    final after = _response(savedReels: 4);

    expect(before.contentAccessSignature(), after.contentAccessSignature());
  });

  test('a changed plan still counts as a change in access', () {
    expect(
      _response(plan: 'free').contentAccessSignature(),
      isNot(_response(plan: 'pro', isPremium: true).contentAccessSignature()),
    );
  });

  test('a changed limit still counts as a change in access', () {
    expect(
      _response(savedReelsLimit: 25).contentAccessSignature(),
      isNot(_response(savedReelsLimit: null).contentAccessSignature()),
    );
  });
}
