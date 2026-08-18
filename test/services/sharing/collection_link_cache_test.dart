import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:reelpin/services/sharing/collection_link_cache.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final cache = CollectionLinkCache.instance;

  test('a link written for one collection reads back', () async {
    await cache.write('col-1', 'https://reelpin.in/c/tok-1');

    expect(await cache.read('col-1'), 'https://reelpin.in/c/tok-1');
  });

  test('an unknown collection reads back null', () async {
    expect(await cache.read('never-written'), isNull);
  });

  test('links are scoped per collection', () async {
    await cache.write('col-1', 'https://reelpin.in/c/tok-1');
    await cache.write('col-2', 'https://reelpin.in/c/tok-2');

    expect(await cache.read('col-1'), 'https://reelpin.in/c/tok-1');
    expect(await cache.read('col-2'), 'https://reelpin.in/c/tok-2');
  });

  test('regenerating overwrites the previous url', () async {
    await cache.write('col-1', 'https://reelpin.in/c/old');
    await cache.write('col-1', 'https://reelpin.in/c/new');

    expect(await cache.read('col-1'), 'https://reelpin.in/c/new');
  });

  test('clear removes the url so a stale link is never offered', () async {
    await cache.write('col-1', 'https://reelpin.in/c/tok-1');
    await cache.clear('col-1');

    expect(await cache.read('col-1'), isNull);
  });

  test('blank ids and urls are ignored rather than stored', () async {
    await cache.write('', 'https://reelpin.in/c/tok');
    await cache.write('col-1', '   ');

    expect(await cache.read(''), isNull);
    expect(await cache.read('col-1'), isNull);
  });
}
