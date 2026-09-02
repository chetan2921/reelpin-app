import 'package:flutter_test/flutter_test.dart';

import 'package:reelpin/data_models/account/user_entitlement.dart';

EntitlementsResponse _response({
  int reelsSaved = 3,
  int? reelsRemaining = 17,
  int? reelsPerMonth = 20,
  String plan = 'free',
}) {
  return EntitlementsResponse.fromJson({
    'current_entitlement': {
      'user_id': 'user-1',
      'plan': plan,
      'status': 'active',
    },
    'usage': {
      'reels_saved_this_month': reelsSaved,
      'reels_remaining_this_month': reelsRemaining,
    },
    'limits': {'reels_per_month': reelsPerMonth},
    'features': const <String, dynamic>{},
  });
}

void main() {
  test('saving a reel does not read as a change in access', () {
    // The signature decides whether every visible tab is wiped and refetched.
    // Usage ticking up on each save must not trigger that.
    final before = _response(reelsSaved: 3, reelsRemaining: 17);
    final after = _response(reelsSaved: 4, reelsRemaining: 16);

    expect(
      before.contentAccessSignature(),
      after.contentAccessSignature(),
    );
  });

  test('a changed plan still counts as a change in access', () {
    expect(
      _response(plan: 'free').contentAccessSignature(),
      isNot(_response(plan: 'pro').contentAccessSignature()),
    );
  });

  test('a changed limit still counts as a change in access', () {
    expect(
      _response(reelsPerMonth: 20).contentAccessSignature(),
      isNot(_response(reelsPerMonth: 200).contentAccessSignature()),
    );
  });
}
