import 'package:flutter_test/flutter_test.dart';

import 'package:reelpin/services/sharing/collection_share_message.dart';

void main() {
  group('forLink', () {
    test('names the collection, counts the reels, and carries the url', () {
      final message = CollectionShareMessage.forLink(
        collectionName: 'Tokyo Food Crawl',
        url: 'https://reelpin.in/c/tok',
        itemCount: 12,
      );

      expect(message.subject, 'Tokyo Food Crawl on ReelPin');
      expect(message.body, contains('"Tokyo Food Crawl"'));
      expect(message.body, contains('12 saved reels'));
      expect(message.body, contains('https://reelpin.in/c/tok'));
    });

    test('says reel, not reels, for a single item', () {
      final message = CollectionShareMessage.forLink(
        collectionName: 'Solo',
        url: 'https://reelpin.in/c/tok',
        itemCount: 1,
      );

      expect(message.body, contains('1 saved reel'));
      expect(message.body, isNot(contains('1 saved reels')));
    });

    test('omits the count entirely when the collection is empty', () {
      final message = CollectionShareMessage.forLink(
        collectionName: 'Empty',
        url: 'https://reelpin.in/c/tok',
      );

      expect(message.body, isNot(contains('0 saved')));
      expect(message.body, contains('"Empty"'));
    });

    test('falls back to a readable name when the title is blank', () {
      final message = CollectionShareMessage.forLink(
        collectionName: '   ',
        url: 'https://reelpin.in/c/tok',
      );

      expect(message.body, contains('this collection'));
      expect(message.subject, 'this collection on ReelPin');
    });

    test('always promotes the app so a recipient without it has context', () {
      final message = CollectionShareMessage.forLink(
        collectionName: 'Tokyo',
        url: 'https://reelpin.in/c/tok',
        itemCount: 3,
      );

      expect(message.body, contains('ReelPin'));
      expect(message.body.toLowerCase(), contains('save reels'));
    });
  });

  group('forInvite', () {
    test('an editor invite says they can add and remove', () {
      final message = CollectionShareMessage.forInvite(
        collectionName: 'Tokyo Food Crawl',
        url: 'https://reelpin.in/c/invite/inv',
        role: 'editor',
      );

      expect(message.subject, 'Join "Tokyo Food Crawl" on ReelPin');
      expect(message.body, contains('add and remove reels'));
      expect(message.body, contains('https://reelpin.in/c/invite/inv'));
    });

    test('a viewer invite does not promise edit rights', () {
      final message = CollectionShareMessage.forInvite(
        collectionName: 'Tokyo Food Crawl',
        url: 'https://reelpin.in/c/invite/inv',
        role: 'viewer',
      );

      expect(message.body, contains('browse'));
      expect(message.body, isNot(contains('add and remove')));
    });

    test('an unknown role is treated as view-only', () {
      final message = CollectionShareMessage.forInvite(
        collectionName: 'Tokyo',
        url: 'https://reelpin.in/c/invite/inv',
        role: 'something-else',
      );

      expect(message.body, isNot(contains('add and remove')));
    });
  });
}
