import 'package:flutter_test/flutter_test.dart';
import 'package:reelpin/data_models/reels/reel.dart';
import 'package:reelpin/http/api_exception.dart';
import 'package:reelpin/services/chat/chat_reel_cache.dart';

Reel _reel(String id) => Reel(
  id: id,
  userId: 'u1',
  url: 'https://example.com/$id',
  title: 'Title $id',
  summary: '',
  caption: '',
  transcript: '',
  category: 'Food',
  subCategory: 'Ramen',
  keyFacts: const [],
  locations: const [],
  peopleMentioned: const [],
  actionableItems: const [],
);

void main() {
  test('resolve fetches an uncached id and caches the result', () async {
    var calls = 0;
    final cache = ChatReelCache((id) async {
      calls += 1;
      return _reel(id);
    });

    final reel = await cache.resolve('r1');

    expect(reel?.id, 'r1');
    expect(calls, 1);
    expect(cache.cached('r1')?.id, 'r1');
  });

  test('resolve never re-fetches an id already resolved', () async {
    var calls = 0;
    final cache = ChatReelCache((id) async {
      calls += 1;
      return _reel(id);
    });

    await cache.resolve('r1');
    await cache.resolve('r1');
    await cache.resolve('r1');

    expect(calls, 1);
  });

  test(
    'concurrent resolves for the same id share one in-flight fetch',
    () async {
      var calls = 0;
      final cache = ChatReelCache((id) async {
        calls += 1;
        await Future<void>.delayed(const Duration(milliseconds: 5));
        return _reel(id);
      });

      final results = await Future.wait([
        cache.resolve('r1'),
        cache.resolve('r1'),
      ]);

      expect(calls, 1);
      expect(results[0]?.id, 'r1');
      expect(results[1]?.id, 'r1');
    },
  );

  test('a fetch that throws resolves to null instead of throwing', () async {
    final cache = ChatReelCache((_) async => throw Exception('404'));

    final reel = await cache.resolve('gone');

    expect(reel, isNull);
    expect(cache.cached('gone'), isNull);
  });

  test('a failed fetch does not break resolving other ids', () async {
    final cache = ChatReelCache((id) async {
      if (id == 'gone') throw Exception('404');
      return _reel(id);
    });

    final gone = await cache.resolve('gone');
    final ok = await cache.resolve('r1');

    expect(gone, isNull);
    expect(ok?.id, 'r1');
  });

  test(
    'a second resolve for an id that 404d does not issue another fetch',
    () async {
      var calls = 0;
      final cache = ChatReelCache((_) async {
        calls += 1;
        throw const ApiException('Not found', 404);
      });

      final first = await cache.resolve('gone');
      final second = await cache.resolve('gone');

      expect(first, isNull);
      expect(second, isNull);
      expect(calls, 1);
    },
  );

  test('a transient failure (no 404) is retried on a later resolve', () async {
    var calls = 0;
    final cache = ChatReelCache((id) async {
      calls += 1;
      if (calls == 1) throw const ApiException('Server error', 500);
      return _reel(id);
    });

    final first = await cache.resolve('r1');
    final second = await cache.resolve('r1');

    expect(first, isNull);
    expect(second?.id, 'r1');
    expect(calls, 2);
  });
}
