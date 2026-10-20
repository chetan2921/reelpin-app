import 'package:flutter_test/flutter_test.dart';

import 'package:reelpin/data_models/collections/collection_models.dart';

void main() {
  group('CollectionSummary', () {
    test('parses the full backend shape', () {
      final summary = CollectionSummary.fromJson(const {
        'id': 'col-1',
        'name': 'Tokyo Food Crawl',
        'description': 'Ramen',
        'cover_reel_id': 'reel-9',
        'visibility': 'link',
        'role': 'editor',
        'item_count': 12,
        'member_count': 3,
        'created_at': '2026-08-01T00:00:00Z',
        'updated_at': '2026-08-02T00:00:00Z',
        'web_url': 'https://reelpin.in/collections/col-1',
      });

      expect(summary.id, 'col-1');
      expect(summary.webUrl, 'https://reelpin.in/collections/col-1');
      expect(summary.coverReelId, 'reel-9');
      expect(summary.itemCount, 12);
      expect(summary.memberCount, 3);
      expect(summary.hasLink, isTrue);
      expect(summary.canEdit, isTrue);
      expect(summary.isOwner, isFalse);
    });

    test('applies defaults when fields are missing', () {
      final summary = CollectionSummary.fromJson(const {'id': 'col-3'});

      expect(summary.name, '');
      expect(summary.description, '');
      expect(summary.visibility, 'private');
      expect(summary.role, 'owner');
      expect(summary.itemCount, 0);
      expect(summary.hasLink, isFalse);
      expect(summary.isOwner, isTrue);
    });

    test('role drives the permission getters', () {
      CollectionSummary withRole(String role) =>
          CollectionSummary(id: 'x', name: 'x', role: role);

      expect(withRole('owner').canEdit, isTrue);
      expect(withRole('owner').isOwner, isTrue);
      expect(withRole('editor').canEdit, isTrue);
      expect(withRole('editor').isOwner, isFalse);
      expect(withRole('viewer').canEdit, isFalse);
      expect(withRole('viewer').isOwner, isFalse);
    });

    test('copyWith preserves id and timestamps', () {
      const original = CollectionSummary(
        id: 'col-1',
        name: 'Before',
        createdAt: '2026-08-01T00:00:00Z',
        updatedAt: '2026-08-02T00:00:00Z',
      );

      final updated = original.copyWith(name: 'After', visibility: 'link');

      expect(updated.id, 'col-1');
      expect(updated.name, 'After');
      expect(updated.visibility, 'link');
      expect(updated.createdAt, '2026-08-01T00:00:00Z');
      expect(updated.updatedAt, '2026-08-02T00:00:00Z');
    });
  });

  group('CollectionDetail', () {
    test('parses item cards and the cursor page', () {
      final detail = CollectionDetail.fromJson({
        'collection': const {'id': 'col-1', 'name': 'Tokyo'},
        'items': [_itemJson],
        'page': const {
          'next_cursor': 'opaque-cursor',
          'has_more': true,
          'limit': 25,
        },
        'can_edit': true,
      });

      expect(detail.collection.id, 'col-1');
      final reel = detail.reels.single;
      expect(reel.id, 'reel-123');
      expect(reel.title, 'Test reel');
      expect(reel.url, 'https://instagram.com/reel/abc');
      expect(reel.webUrl, 'https://reelpin.in/r/reel-123');
      expect(reel.thumbnailUrl, 'https://cdn.example/thumb.jpg');
      expect(reel.sourcePlatform, 'instagram');
      expect(detail.canEdit, isTrue);
      expect(detail.pagination.hasMore, isTrue);
      expect(detail.pagination.nextCursor, 'opaque-cursor');
    });

    test('a page with no next_cursor is the last one', () {
      final detail = CollectionDetail.fromJson({
        'collection': const {'id': 'col-1', 'name': 'Tokyo'},
        'items': const <Map<String, Object?>>[],
        'page': const {'next_cursor': null, 'has_more': false, 'limit': 25},
        'can_edit': false,
      });

      expect(detail.reels, isEmpty);
      expect(detail.canEdit, isFalse);
      expect(detail.pagination.hasMore, isFalse);
    });

    test('restores from its own cache form', () {
      final detail = CollectionDetail.fromJson({
        'collection': const {'id': 'col-1', 'name': 'Tokyo'},
        'items': [_itemJson],
        'page': const {'next_cursor': 'opaque-cursor', 'limit': 25},
        'can_edit': true,
      });

      final restored = CollectionDetail.fromJson(detail.toJson());

      expect(restored.reels.single.id, 'reel-123');
      expect(restored.reels.single.webUrl, 'https://reelpin.in/r/reel-123');
      expect(restored.pagination.nextCursor, 'opaque-cursor');
      expect(restored.canEdit, isTrue);
    });

    test('append concatenates reels and takes the newer pagination', () {
      final first = CollectionDetail.fromJson({
        'collection': const {'id': 'col-1', 'name': 'Tokyo'},
        'items': [_itemJson],
        'page': const {'next_cursor': 'opaque-cursor'},
        'can_edit': true,
      });
      final second = CollectionDetail.fromJson({
        'collection': const {'id': 'col-1', 'name': 'Tokyo'},
        'items': [
          {..._itemJson, 'reel_id': 'reel-456'},
        ],
        'page': const {'next_cursor': null},
      });

      final merged = first.append(second);

      expect(merged.reels.map((r) => r.id), ['reel-123', 'reel-456']);
      expect(merged.pagination.hasMore, isFalse);
    });
  });

  group('sharing models', () {
    test('CollectionMembers parses owner and member list', () {
      final members = CollectionMembers.fromJson(const {
        'owner_id': 'user-1',
        'members': [
          {'user_id': 'user-2', 'role': 'editor'},
          {'user_id': 'user-3'},
        ],
      });

      expect(members.ownerId, 'user-1');
      expect(members.members.map((m) => m.userId), ['user-2', 'user-3']);
      expect(members.members.first.role, 'editor');
      expect(members.members.last.role, 'viewer');
    });

    test('CollectionLink and CollectionInvite parse their payloads', () {
      final link = CollectionLink.fromJson(const {
        'url': 'https://reelpin.in/c/tok',
        'token': 'tok',
      });
      expect(link.url, 'https://reelpin.in/c/tok');
      expect(link.token, 'tok');

      final invite = CollectionInvite.fromJson(const {
        'url': 'https://reelpin.in/c/invite/inv',
        'token': 'inv',
        'role': 'editor',
        'expires_at': '2026-08-17T00:00:00Z',
      });
      expect(invite.role, 'editor');
      expect(invite.expiresAt, '2026-08-17T00:00:00Z');

      // An invite with no role defaults to the least privileged option.
      expect(CollectionInvite.fromJson(const {}).role, 'viewer');
    });
  });
}

/// A CollectionItem card as the v2 API sends it.
const _itemJson = {
  'reel_id': 'reel-123',
  'title': 'Test reel',
  'summary': 'Short summary',
  'url': 'https://instagram.com/reel/abc',
  'web_url': 'https://reelpin.in/r/reel-123',
  'thumbnail_url': 'https://cdn.example/thumb.jpg',
  'source_platform': 'instagram',
  'saved_at': '2026-05-23T00:00:00Z',
  'added_at': '2026-05-24T00:00:00Z',
  'added_by': 'user-123',
};
