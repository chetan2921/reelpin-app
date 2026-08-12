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
          return null;
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

  test('a viewer-only account clears rather than sending an empty array', () async {
    await ShareHandoffService.instance.syncCollections([
      c('b', 'Someone elses', role: 'viewer'),
    ]);

    expect(syncedCollections(), isNull);
  });
}
