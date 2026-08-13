import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:reelpin/router.dart';

void main() {
  // A launch link is the destination the user picked, so it is presented
  // rather than animated in over whatever the shell happened to show first.
  test('launch routes have no transition', () {
    for (final route in <Route<void>>[
      sharedCollectionRoute('tok', animate: false),
      collectionDetailRoute('id', animate: false),
    ]) {
      expect(route, isA<TransitionRoute<void>>());
      expect((route as TransitionRoute<void>).transitionDuration, Duration.zero);
      expect(route.reverseTransitionDuration, Duration.zero);
    }
  });

  // MaterialPageRoute resolves its duration from the theme, so the type is
  // what there is to assert here without building a tree.
  test('routes opened from inside the app keep their transition', () {
    expect(sharedCollectionRoute('tok'), isA<MaterialPageRoute<void>>());
    expect(collectionDetailRoute('id'), isA<MaterialPageRoute<void>>());
  });
}
