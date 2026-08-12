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
      });

      expect(summary.id, 'col-1');
      expect(summary.coverReelId, 'reel-9');
      expect(summary.itemCount, 12);
      expect(summary.memberCount, 3);
      expect(summary.hasLink, isTrue);
      expect(summary.canEdit, isTrue);
      expect(summary.isOwner, isFalse);
    });

    test('falls back to collection_id and items_count aliases', () {
      final summary = CollectionSummary.fromJson(const {
        'collection_id': 'col-2',
        'name': 'Aliased',
        'items_count': 7,
      });

      expect(summary.id, 'col-2');
      expect(summary.itemCount, 7);
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
    test('parses the nested envelope', () {
      final detail = CollectionDetail.fromJson({
        'collection': const {'id': 'col-1', 'name': 'Tokyo'},
        'reels': [_reelJson],
        'pagination': const {
          'next_cursor': '26',
          'next_offset': 26,
          'has_more': true,
          'total_count': 12,
          'limit': 25,
          'offset': 0,
        },
        'can_edit': true,
        'owner_name': 'Chetan',
      });

      expect(detail.collection.id, 'col-1');
      expect(detail.reels.single.id, 'reel-123');
      expect(detail.canEdit, isTrue);
      expect(detail.ownerName, 'Chetan');
      expect(detail.pagination.hasMore, isTrue);
      expect(detail.pagination.nextOffset, 26);
    });

    test('falls back to a flat body with no collection key', () {
      final detail = CollectionDetail.fromJson(const {
        'id': 'col-1',
        'name': 'Flat',
      });

      expect(detail.collection.id, 'col-1');
      expect(detail.reels, isEmpty);
      expect(detail.canEdit, isFalse);
      expect(detail.pagination.hasMore, isFalse);
    });

    test('append concatenates reels and takes the newer pagination', () {
      final first = CollectionDetail.fromJson({
        'collection': const {'id': 'col-1', 'name': 'Tokyo'},
        'reels': [_reelJson],
        'pagination': const {'has_more': true, 'next_offset': 1},
        'can_edit': true,
        'owner_name': 'Chetan',
      });
      final second = CollectionDetail.fromJson({
        'collection': const {'id': 'col-1', 'name': 'Tokyo'},
        'reels': [
          {..._reelJson, 'id': 'reel-456'},
        ],
        'pagination': const {'has_more': false},
      });

      final merged = first.append(second);

      expect(merged.reels.map((r) => r.id), ['reel-123', 'reel-456']);
      expect(merged.pagination.hasMore, isFalse);
      // ownerName only arrives on the first page of a shared view.
      expect(merged.ownerName, 'Chetan');
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

const _reelJson = {
  'id': 'reel-123',
  'user_id': 'user-123',
  'url': 'https://instagram.com/reel/abc',
  'title': 'Test reel',
  'summary': 'Short summary',
  'caption': '',
  'transcript': '',
  'category': 'Travel',
  'sub_category': 'Coffee Shops',
  'key_facts': <String>[],
  'locations': <Map<String, Object?>>[],
  'people_mentioned': <String>[],
  'actionable_items': <String>[],
  'created_at': '2026-05-23T00:00:00Z',
};
