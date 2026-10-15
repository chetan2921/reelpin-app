import 'package:flutter_test/flutter_test.dart';

import 'package:reelpin/data_models/sharing/pending_share.dart';

/// Native share code stores a share it could not send so the app can send it
/// on the next launch or resume. Each platform writes its own shape.
void main() {
  test('reads an Android entry', () {
    final share = PendingShare.fromNative({
      'raw_payload_text': 'Look at this https://www.instagram.com/reel/abc/',
      'collection_ids': ['c1'],
    });

    expect(share?.payload, 'Look at this https://www.instagram.com/reel/abc/');
    expect(share?.collectionIds, ['c1']);
  });

  test('reads an iOS share extension entry, which stores url', () {
    final share = PendingShare.fromNative({
      'url': 'https://www.instagram.com/reel/abc/',
      'collection_ids': ['c1', 'c2'],
    });

    expect(share?.payload, 'https://www.instagram.com/reel/abc/');
    expect(share?.collectionIds, ['c1', 'c2']);
  });

  test('reads a bare string left by an older build', () {
    final share = PendingShare.fromNative(
      '  https://www.instagram.com/reel/abc/  ',
    );

    expect(share?.payload, 'https://www.instagram.com/reel/abc/');
    expect(share?.collectionIds, isEmpty);
  });

  test('skips an entry with nothing to send', () {
    expect(PendingShare.fromNative({'url': '   '}), isNull);
    expect(
      PendingShare.fromNative({
        'collection_ids': ['c1'],
      }),
      isNull,
    );
    expect(PendingShare.fromNative(null), isNull);
  });

  test('drops empty collection ids', () {
    final share = PendingShare.fromNative({
      'url': 'https://www.instagram.com/reel/abc/',
      'collection_ids': ['c1', ''],
    });

    expect(share?.collectionIds, ['c1']);
  });
}
