import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:reelpin/data_models/collections/collection_models.dart';
import 'package:reelpin/services/sharing/shared_collection_prefetch.dart';

void main() {
  tearDown(() {
    // The holder is static, so leave nothing behind for the next test.
    SharedCollectionPrefetch.take('token-a');
    SharedCollectionPrefetch.take('token-b');
  });

  test('hands the started fetch to the matching token, once', () async {
    SharedCollectionPrefetch.start('token-a', () async => _detail('A'));

    final taken = SharedCollectionPrefetch.take('token-a');
    expect(taken, isNotNull);
    expect((await taken!).collection.name, 'A');

    expect(SharedCollectionPrefetch.take('token-a'), isNull);
  });

  test('does not hand a fetch to a different token', () async {
    SharedCollectionPrefetch.start('token-a', () async => _detail('A'));

    expect(SharedCollectionPrefetch.take('token-b'), isNull);
    expect(SharedCollectionPrefetch.take('token-a'), isNotNull);
  });

  test('runs the fetch once for repeated starts on the same token', () async {
    var calls = 0;
    Future<CollectionDetail> load() async {
      calls += 1;
      return _detail('A');
    }

    SharedCollectionPrefetch.start('token-a', load);
    SharedCollectionPrefetch.start('token-a', load);

    await SharedCollectionPrefetch.take('token-a');
    expect(calls, 1);
  });

  test(
    'a failed prefetch surfaces to the caller, not as an unawaited error',
    () async {
      final failures = <Object>[];
      await runZonedGuarded(() async {
        SharedCollectionPrefetch.start(
          'token-a',
          () async => throw StateError('offline'),
        );
        // Nothing is listening while the screen is still being built.
        await Future<void>.delayed(Duration.zero);

        await expectLater(
          SharedCollectionPrefetch.take('token-a'),
          throwsStateError,
        );
      }, (error, _) => failures.add(error));

      expect(failures, isEmpty);
    },
  );
}

CollectionDetail _detail(String name) {
  return CollectionDetail(
    collection: CollectionSummary(id: 'id-$name', name: name),
    reels: const [],
    pagination: const CollectionPagination(),
  );
}
