import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:reelpin/data_models/collections/collection_models.dart';
import 'package:reelpin/services/sharing/share_handoff_service.dart';

/// The native share pickers read this cached snapshot instead of calling the
/// API — a share extension has a tiny time budget and can be killed mid-request.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.chetanjain.reelpin/share_handoff');
  late List<MethodCall> calls;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    calls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return call.method == 'shareAssetsDir' ? '/tmp/share-assets' : null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  CollectionSummary c(String id, String name, {String role = 'owner'}) =>
      CollectionSummary(id: id, name: name, role: role);

  Map<String, dynamic>? syncedCollections() {
    final sync = calls.where((c) => c.method == 'sync').toList();
    if (sync.isEmpty) return null;
    final raw = (sync.last.arguments as Map)['collections'] as String;
    return raw.isEmpty ? null : {'items': jsonDecode(raw)};
  }

  test(
    'sign-out clears cached collection names and artwork directory',
    () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('share_handoff_collections', '[{"id":"old"}]');
      await prefs.setString('share_handoff_collections_dir', '/tmp/old');
      await prefs.setBool('share_handoff_collection_picker', false);

      await ShareHandoffService.instance.clear();
      await ShareHandoffService.instance.syncAuthenticatedUser(
        'next',
        'access',
      );

      expect(prefs.getString('share_handoff_collections'), isNull);
      expect(prefs.getString('share_handoff_collections_dir'), isNull);
      expect(prefs.getBool('share_handoff_collection_picker'), isFalse);
      expect(syncedCollections(), isNull);
    },
  );

  test(
    'switching users drops collections and the previous share token',
    () async {
      await ShareHandoffService.instance.syncAuthenticatedUser('old', 'access');
      await ShareHandoffService.instance.setShareToken('old-share-token');
      await ShareHandoffService.instance.syncCollections([c('old', 'Private')]);

      await ShareHandoffService.instance.syncAuthenticatedUser(
        'next',
        'access',
      );

      expect(syncedCollections(), isNull);
      expect(await ShareHandoffService.instance.getShareToken(), isNull);
    },
  );

  test('a pending picker preference cannot sync a signed-out snapshot', () async {
    await ShareHandoffService.instance.syncAuthenticatedUser('old', 'access');
    var renders = 0;
    final pending = ShareHandoffService.instance.setCollectionPickerEnabled(
      true,
      [c('old', 'Private')],
      renderTiles: ({required directory, required collections}) async {
        renders += 1;
        return {'old': 'old.png'};
      },
    );

    await ShareHandoffService.instance.clear();
    await pending;

    expect(renders, 0);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('share_handoff_collections'), isNull);
  });

  for (final signOut in [false, true]) {
    test(
      'late artwork cannot restore a snapshot after ${signOut ? 'sign-out' : 'switching users'}',
      () async {
        await ShareHandoffService.instance.syncAuthenticatedUser(
          'old',
          'access',
        );
        final rendering = Completer<void>();
        final artwork = Completer<Map<String, String>>();
        final pending = ShareHandoffService.instance.syncCollections(
          [c('old', 'Private')],
          renderTiles: ({required directory, required collections}) {
            rendering.complete();
            return artwork.future;
          },
        );
        await rendering.future;
        if (signOut) {
          await ShareHandoffService.instance.clear();
        } else {
          await ShareHandoffService.instance.syncAuthenticatedUser(
            'next',
            'access',
          );
        }
        final callCount = calls.length;
        artwork.complete({'old': 'old.png'});
        await pending;

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('share_handoff_collections'), isNull);
        expect(prefs.getString('share_handoff_collections_dir'), isNull);
        expect(calls.length, callCount);
      },
    );
  }

  test('syncs editable collections as id and name only', () async {
    await ShareHandoffService.instance.syncCollections([
      c('a', 'Tokyo Food Crawl'),
      c('b', 'Weekend Hikes', role: 'editor'),
    ]);

    final items = syncedCollections()!['items'] as List;
    expect(items, [
      {'id': 'a', 'name': 'Tokyo Food Crawl'},
      {'id': 'b', 'name': 'Weekend Hikes'},
    ]);
  });

  test('drops view-only collections — you cannot add reels to those', () async {
    await ShareHandoffService.instance.syncCollections([
      c('a', 'Mine'),
      c('b', 'Someone elses', role: 'viewer'),
    ]);

    final items = syncedCollections()!['items'] as List;
    expect(items, [
      {'id': 'a', 'name': 'Mine'},
    ]);
  });

  test('an empty list clears the snapshot so the picker is skipped', () async {
    await ShareHandoffService.instance.syncCollections([]);

    expect(syncedCollections(), isNull);
    expect(
      SharedPreferences.getInstance().then(
        (p) => p.getString('share_handoff_collections'),
      ),
      completion(isNull),
    );
  });

  test(
    'a viewer-only account clears rather than sending an empty array',
    () async {
      await ShareHandoffService.instance.syncCollections([
        c('b', 'Someone elses', role: 'viewer'),
      ]);

      expect(syncedCollections(), isNull);
    },
  );
}
