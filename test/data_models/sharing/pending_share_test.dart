import 'package:flutter_test/flutter_test.dart';
import 'package:reelpin/data_models/sharing/pending_share.dart';

void main() {
  test('iOS pending TikTok shares retain URL and collections', () {
    final share = PendingShare.fromNative({
      'url': 'https://vm.tiktok.com/ABC/',
      'collection_ids': ['collection-1', 'collection-2'],
    });
    expect(share!.rawPayloadText, 'https://vm.tiktok.com/ABC/');
    expect(share.collectionIds, ['collection-1', 'collection-2']);
  });

  test('Android pending shares retain raw caption and post link', () {
    const text = 'A useful guide https://www.tiktok.com/@a/photo/123?_t=share';
    final share = PendingShare.fromNative({
      'raw_payload_text': text,
      'collection_ids': ['collection-1'],
    });
    expect(share!.rawPayloadText, text);
    expect(share.collectionIds, ['collection-1']);
  });

  test('older bare-string shares and empty raw fields still drain', () {
    expect(
      PendingShare.fromNative(' https://vt.tiktok.com/ABC ')!.rawPayloadText,
      'https://vt.tiktok.com/ABC',
    );
    expect(
      PendingShare.fromNative({
        'raw_payload_text': '',
        'url': 'https://www.tiktok.com/t/ABC',
      })!.rawPayloadText,
      'https://www.tiktok.com/t/ABC',
    );
  });

  test('invalid entries do not prevent valid pending shares from draining', () {
    for (final value in [
      null,
      3,
      {},
      {'url': ''},
      {'url': 3},
    ]) {
      expect(PendingShare.fromNative(value), isNull);
    }
    final share = PendingShare.fromNative({
      'url': 'https://www.tiktok.com/@a/live',
      'collection_ids': 'not a list',
    });
    expect(share!.collectionIds, isEmpty);
  });
}
