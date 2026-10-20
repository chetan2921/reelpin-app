import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:reelpin/data_models/collections/collection_models.dart';
import 'package:reelpin/screens/reel_detail/reel_detail_screen.dart';

void main() {
  testWidgets('a read-only reel built from a collection card renders', (
    tester,
  ) async {
    // A collaborator or shared-link viewer gets only the item card and cannot
    // fetch someone else's reel, so every section the card lacks is empty.
    final detail = CollectionDetail.fromJson({
      'collection': {'id': 'col-1', 'name': 'Goa'},
      'items': [
        {
          'reel_id': 'reel-123',
          'title': 'Best cafes in Goa',
          'summary': 'Three cafes worth the ride.',
          'url': 'https://www.instagram.com/reel/abc/',
          'web_url': 'https://reelpin.in/r/reel-123',
          'thumbnail_url': null,
          'source_platform': 'instagram',
          'saved_at': '2026-09-02T12:00:00Z',
          'added_at': '2026-09-03T12:00:00Z',
          'added_by': 'user-123',
        },
      ],
      'page': {'next_cursor': null},
    });

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: ReelDetailScreen(reel: detail.reels.single, readOnly: true),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('BEST CAFES IN GOA'), findsOneWidget);
    expect(find.text('Three cafes worth the ride.'), findsOneWidget);
    for (final section in [
      'KEY FACTS',
      'LOCATIONS',
      'PEOPLE MENTIONED',
      'ACTION ITEMS',
      'TRANSCRIPT',
    ]) {
      expect(find.text(section), findsNothing, reason: section);
    }
    expect(find.byIcon(Icons.delete), findsNothing);
    expect(find.byIcon(Icons.playlist_add), findsNothing);
  });
}
