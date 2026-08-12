import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:reelpin/data_models/collections/collection_models.dart';
import 'package:reelpin/http/collections_http.dart';
import 'package:reelpin/providers.dart';
import 'package:reelpin/screens/collections/share_collection_sheet.dart';

/// Regression cover for the copy flow. The sheet used to confirm a copy with a
/// ScaffoldMessenger snackbar, which renders *behind* the modal sheet — the
/// clipboard was written but the user saw nothing and reported copy as broken.
void main() {
  const collectionId = 'col-1';
  const cachedUrl = 'https://reelpin.in/c/tok-abc';

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'flutter.collection_share_link_v1_$collectionId': cachedUrl,
    });
  });

  Future<void> pumpSheet(WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: [
        collectionsHttpProvider.overrideWithValue(_FakeCollectionsHttp()),
      ],
    );
    addTearDown(container.dispose);
    // The sheet is always opened from the detail screen, so the detail is
    // already in the view model by the time it builds.
    await container
        .read(collectionsViewModelProvider)
        .loadCollectionDetail(collectionId);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: ShareCollectionSheet(collectionId: collectionId),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a cached link is restored even before the detail loads', (
    tester,
  ) async {
    await pumpSheet(tester);

    // detailFor() is null here — the old gate skipped the cache entirely and
    // left the owner with no url and no copy button.
    expect(find.textContaining('reelpin.in/c/tok-abc'), findsOneWidget);
    expect(find.byIcon(Icons.copy), findsOneWidget);
  });

  testWidgets('tapping copy writes the clipboard and confirms inline', (
    tester,
  ) async {
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await pumpSheet(tester);
    expect(find.text('Link copied'), findsNothing);

    await tester.tap(find.byIcon(Icons.copy));
    await tester.pump();

    expect(copied, [cachedUrl]);
    expect(find.text('Link copied'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsWidgets);
    // The whole point of the fix: a SnackBar renders behind the modal sheet,
    // so the confirmation has to live in the sheet's own subtree.
    expect(find.byType(SnackBar), findsNothing);
    expect(
      find.descendant(
        of: find.byType(ShareCollectionSheet),
        matching: find.text('Link copied'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('the share button opens the OS sheet with a promo message', (
    tester,
  ) async {
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('com.chetanjain.reelpin/reel_share'),
      (call) async {
        calls.add(call);
        return true;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('com.chetanjain.reelpin/reel_share'),
        null,
      ),
    );

    await pumpSheet(tester);
    await tester.tap(find.byIcon(Icons.ios_share));
    await tester.pump();

    expect(calls, hasLength(1));
    expect(calls.single.method, 'shareText');
    final args = calls.single.arguments as Map;
    expect(args['text'], contains(cachedUrl));
    expect(args['text'], contains('Tokyo Food Crawl'));
    // The whole reason for a custom message: it promotes the app too.
    expect(args['text'], contains('ReelPin'));
    expect(args['subject'], 'Tokyo Food Crawl on ReelPin');
  });

  testWidgets('the confirmation clears itself after a few seconds', (
    tester,
  ) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async => null,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await pumpSheet(tester);
    await tester.tap(find.byIcon(Icons.copy));
    await tester.pump();
    expect(find.text('Link copied'), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    expect(find.text('Link copied'), findsNothing);
  });
}

class _FakeCollectionsHttp implements CollectionsHttp {
  @override
  Future<CollectionDetail> getCollectionDetail(
    String collectionId, {
    int limit = 25,
    int? offset,
    String? cursor,
  }) async {
    return CollectionDetail(
      collection: CollectionSummary(
        id: collectionId,
        name: 'Tokyo Food Crawl',
        // 'link' is what makes the sheet render the link chip at all.
        visibility: 'link',
        role: 'owner',
      ),
      reels: const [],
      pagination: const CollectionPagination(),
      canEdit: true,
    );
  }

  @override
  Future<CollectionMembers> getCollectionMembers(String collectionId) async {
    return const CollectionMembers(ownerId: 'owner-1');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}
