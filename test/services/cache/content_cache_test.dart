import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:reelpin/services/cache/content_cache.dart';

void main() {
  late Directory directory;
  late String? userId;
  late ContentCache cache;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('content_cache_test');
    userId = 'user-a';
    cache = ContentCache.forTesting(
      directory: directory,
      userIdProvider: () => userId,
    );
  });

  tearDown(() {
    if (directory.existsSync()) {
      directory.deleteSync(recursive: true);
    }
  });

  File fileFor(String key) =>
      File('${directory.path}${Platform.pathSeparator}$key.json');

  void writeEnvelope(
    String key, {
    required String forUserId,
    required DateTime savedAt,
    int schema = 1,
    Map<String, dynamic> payload = const {'reels': <dynamic>[]},
  }) {
    fileFor(key).writeAsStringSync(
      jsonEncode(<String, dynamic>{
        'schema': schema,
        'user_id': forUserId,
        'saved_at': savedAt.toUtc().toIso8601String(),
        'payload': payload,
      }),
    );
  }

  test('reads back what it wrote', () async {
    await cache.write(ContentCacheKeys.reelsFirstPage, {
      'reels': [
        {'id': 'reel-1'},
      ],
      'total_count': 1,
    });

    final payload = await cache.read(ContentCacheKeys.reelsFirstPage);

    expect(payload, isNotNull);
    expect(payload!['total_count'], 1);
    expect((payload['reels'] as List).single, {'id': 'reel-1'});
  });

  test('returns null when nothing has been written', () async {
    expect(await cache.read(ContentCacheKeys.mapOverview), isNull);
  });

  test('rejects a payload saved by a different user', () async {
    await cache.write(ContentCacheKeys.reelsFirstPage, {'reels': <dynamic>[]});

    userId = 'user-b';

    expect(await cache.read(ContentCacheKeys.reelsFirstPage), isNull);
  });

  test('does not write while signed out', () async {
    userId = null;

    await cache.write(ContentCacheKeys.reelsFirstPage, {'reels': <dynamic>[]});

    expect(fileFor(ContentCacheKeys.reelsFirstPage).existsSync(), isFalse);
  });

  test('drops a payload past its max age', () async {
    writeEnvelope(
      ContentCacheKeys.reelsFirstPage,
      forUserId: 'user-a',
      savedAt: DateTime.now().toUtc().subtract(const Duration(days: 8)),
    );

    expect(await cache.read(ContentCacheKeys.reelsFirstPage), isNull);
  });

  test('expires entitlements sooner than saved content', () async {
    final savedAt = DateTime.now().toUtc().subtract(const Duration(hours: 30));
    writeEnvelope(
      ContentCacheKeys.entitlements,
      forUserId: 'user-a',
      savedAt: savedAt,
    );
    writeEnvelope(
      ContentCacheKeys.reelsFirstPage,
      forUserId: 'user-a',
      savedAt: savedAt,
    );

    expect(await cache.read(ContentCacheKeys.entitlements), isNull);
    expect(await cache.read(ContentCacheKeys.reelsFirstPage), isNotNull);
  });

  test('drops a payload written by an older schema', () async {
    writeEnvelope(
      ContentCacheKeys.reelsFirstPage,
      forUserId: 'user-a',
      savedAt: DateTime.now().toUtc(),
      schema: 0,
    );

    expect(await cache.read(ContentCacheKeys.reelsFirstPage), isNull);
  });

  test('survives a corrupt file', () async {
    fileFor(ContentCacheKeys.reelsFirstPage).writeAsStringSync('{not json');

    expect(await cache.read(ContentCacheKeys.reelsFirstPage), isNull);
  });

  test(
    'invalidateContent clears saved content but keeps entitlements',
    () async {
      await cache.write(ContentCacheKeys.reelsFirstPage, {
        'reels': <dynamic>[],
      });
      await cache.write(ContentCacheKeys.mapOverview, {
        'map_items': <dynamic>[],
      });
      await cache.write(ContentCacheKeys.entitlements, {'plan': 'pro'});

      await cache.invalidateContent();

      expect(await cache.read(ContentCacheKeys.reelsFirstPage), isNull);
      expect(await cache.read(ContentCacheKeys.mapOverview), isNull);
      expect(await cache.read(ContentCacheKeys.entitlements), isNotNull);
    },
  );

  test('clear removes every slot', () async {
    await cache.write(ContentCacheKeys.reelsFirstPage, {'reels': <dynamic>[]});
    await cache.write(ContentCacheKeys.entitlements, {'plan': 'pro'});

    await cache.clear();

    for (final key in ContentCacheKeys.all) {
      expect(await cache.read(key), isNull, reason: key);
    }
  });

  test('keeps the newest payload when writes overlap', () async {
    final first = cache.write(ContentCacheKeys.reelsFirstPage, {'version': 1});
    final second = cache.write(ContentCacheKeys.reelsFirstPage, {'version': 2});
    await Future.wait([first, second]);

    final payload = await cache.read(ContentCacheKeys.reelsFirstPage);

    expect(payload!['version'], 2);
  });
}
