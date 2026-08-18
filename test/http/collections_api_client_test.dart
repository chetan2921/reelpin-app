import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:reelpin/http/api_client.dart';
import 'package:reelpin/http/api_exception.dart';

/// Contract tests for the collections half of [ApiClient], pinned against the
/// shapes `app/main.py` actually returns. Every request is asserted on method,
/// path, query and body so a backend rename cannot pass silently.
void main() {
  ApiClient clientFor(MockClient mock) => ApiClient(
    baseUrl: 'https://example.com',
    accessTokenProvider: () => 'token-123',
    client: mock,
  );

  group('reads', () {
    test('getCollections unwraps the collections envelope', () async {
      late http.Request seen;
      final service = clientFor(
        MockClient((request) async {
          seen = request;
          return http.Response(
            jsonEncode({
              'collections': [_summaryJson, _summaryJson],
            }),
            200,
          );
        }),
      );

      final collections = await service.getCollections();

      expect(seen.method, 'GET');
      expect(seen.url.path, '/api/v1/collections');
      expect(seen.headers['Authorization'], 'Bearer token-123');
      expect(collections, hasLength(2));
      expect(collections.first.id, 'col-1');
      expect(collections.first.name, 'Tokyo Food Crawl');
      expect(collections.first.itemCount, 12);
      expect(collections.first.role, 'owner');
      expect(collections.first.hasLink, isTrue);
    });

    test('getCollections tolerates a bare list and a junk body', () async {
      final asList = clientFor(
        MockClient((_) async => http.Response(jsonEncode([_summaryJson]), 200)),
      );
      expect(await asList.getCollections(), hasLength(1));

      final asJunk = clientFor(
        MockClient((_) async => http.Response(jsonEncode({'ok': true}), 200)),
      );
      expect(await asJunk.getCollections(), isEmpty);
    });

    test('getCollectionDetail sends paging and parses reels', () async {
      late http.Request seen;
      final service = clientFor(
        MockClient((request) async {
          seen = request;
          return http.Response(jsonEncode(_detailJson), 200);
        }),
      );

      final detail = await service.getCollectionDetail(
        'col-1',
        limit: 10,
        offset: 25,
        cursor: '25',
      );

      expect(seen.method, 'GET');
      expect(seen.url.path, '/api/v1/collections/col-1');
      expect(seen.url.queryParameters, {
        'limit': '10',
        'offset': '25',
        'cursor': '25',
      });
      expect(detail.collection.id, 'col-1');
      expect(detail.reels.single.id, 'reel-123');
      expect(detail.canEdit, isTrue);
      expect(detail.pagination.hasMore, isTrue);
      expect(detail.pagination.nextOffset, 26);
      expect(detail.pagination.totalCount, 12);
    });

    test('getCollectionDetail omits absent paging params', () async {
      late http.Request seen;
      final service = clientFor(
        MockClient((request) async {
          seen = request;
          return http.Response(jsonEncode(_detailJson), 200);
        }),
      );

      await service.getCollectionDetail('col-1');

      expect(seen.url.queryParameters, {'limit': '25'});
      expect(seen.url.queryParameters.containsKey('cursor'), isFalse);
      expect(seen.url.queryParameters.containsKey('offset'), isFalse);
    });

    test('getSharedCollection uses the public token path', () async {
      late http.Request seen;
      final service = clientFor(
        MockClient((request) async {
          seen = request;
          return http.Response(
            jsonEncode({..._detailJson, 'owner_name': 'Chetan'}),
            200,
          );
        }),
      );

      final detail = await service.getSharedCollection(
        'tok-abc',
        limit: 50,
        offset: 10,
      );

      expect(seen.method, 'GET');
      expect(seen.url.path, '/api/v1/collections/shared/tok-abc');
      expect(seen.url.queryParameters, {'limit': '50', 'offset': '10'});
      expect(detail.ownerName, 'Chetan');
      expect(detail.reels, hasLength(1));
    });

    test('getCollectionMembers parses owner and members', () async {
      late http.Request seen;
      final service = clientFor(
        MockClient((request) async {
          seen = request;
          return http.Response(
            jsonEncode({
              'owner_id': 'user-owner',
              'members': [
                {
                  'user_id': 'user-2',
                  'role': 'editor',
                  'created_at': '2026-08-01T00:00:00Z',
                },
              ],
            }),
            200,
          );
        }),
      );

      final members = await service.getCollectionMembers('col-1');

      expect(seen.url.path, '/api/v1/collections/col-1/members');
      expect(members.ownerId, 'user-owner');
      expect(members.members.single.userId, 'user-2');
      expect(members.members.single.role, 'editor');
    });
  });

  group('mutations', () {
    test('createCollection posts name, description and reel ids', () async {
      late http.Request seen;
      final service = clientFor(
        MockClient((request) async {
          seen = request;
          return http.Response(
            jsonEncode({'collection': _summaryJson, 'added_count': 2}),
            200,
          );
        }),
      );

      final created = await service.createCollection(
        name: 'Tokyo Food Crawl',
        description: 'Ramen etc',
        reelIds: const ['reel-1', 'reel-2'],
      );

      expect(seen.method, 'POST');
      expect(seen.url.path, '/api/v1/collections');
      expect(seen.headers['Content-Type'], contains('application/json'));
      expect(jsonDecode(seen.body), {
        'name': 'Tokyo Food Crawl',
        'description': 'Ramen etc',
        'reel_ids': ['reel-1', 'reel-2'],
      });
      expect(created.id, 'col-1');
    });

    test('updateCollection sends only the fields provided', () async {
      late http.Request seen;
      final service = clientFor(
        MockClient((request) async {
          seen = request;
          return http.Response(jsonEncode({'collection': _summaryJson}), 200);
        }),
      );

      await service.updateCollection(collectionId: 'col-1', name: 'Renamed');

      expect(seen.method, 'PATCH');
      expect(seen.url.path, '/api/v1/collections/col-1');
      // description / cover_reel_id must be absent, not null — the backend
      // treats a present null as "clear this field".
      expect(jsonDecode(seen.body), {'name': 'Renamed'});
    });

    test('updateCollection can send every field at once', () async {
      late http.Request seen;
      final service = clientFor(
        MockClient((request) async {
          seen = request;
          return http.Response(jsonEncode({'collection': _summaryJson}), 200);
        }),
      );

      await service.updateCollection(
        collectionId: 'col-1',
        name: 'Renamed',
        description: 'New blurb',
        coverReelId: 'reel-9',
      );

      expect(jsonDecode(seen.body), {
        'name': 'Renamed',
        'description': 'New blurb',
        'cover_reel_id': 'reel-9',
      });
    });

    test('deleteCollection issues a DELETE', () async {
      late http.Request seen;
      final service = clientFor(
        MockClient((request) async {
          seen = request;
          return http.Response(jsonEncode({'ok': true}), 200);
        }),
      );

      await service.deleteCollection('col-1');

      expect(seen.method, 'DELETE');
      expect(seen.url.path, '/api/v1/collections/col-1');
    });

    test('addReelsToCollection returns added_count', () async {
      late http.Request seen;
      final service = clientFor(
        MockClient((request) async {
          seen = request;
          return http.Response(
            jsonEncode({'collection': _summaryJson, 'added_count': 3}),
            200,
          );
        }),
      );

      final added = await service.addReelsToCollection(
        collectionId: 'col-1',
        reelIds: const ['reel-1', 'reel-2', 'reel-3'],
      );

      expect(seen.method, 'POST');
      expect(seen.url.path, '/api/v1/collections/col-1/items');
      expect(jsonDecode(seen.body), {
        'reel_ids': ['reel-1', 'reel-2', 'reel-3'],
      });
      expect(added, 3);
    });

    test('addReelsToCollection defaults a missing count to zero', () async {
      final service = clientFor(
        MockClient(
          (_) async =>
              http.Response(jsonEncode({'collection': _summaryJson}), 200),
        ),
      );

      expect(
        await service.addReelsToCollection(
          collectionId: 'col-1',
          reelIds: const ['reel-1'],
        ),
        0,
      );
    });

    test('removeReelFromCollection targets the item path', () async {
      late http.Request seen;
      final service = clientFor(
        MockClient((request) async {
          seen = request;
          return http.Response(jsonEncode({'ok': true}), 200);
        }),
      );

      await service.removeReelFromCollection(
        collectionId: 'col-1',
        reelId: 'reel-7',
      );

      expect(seen.method, 'DELETE');
      expect(seen.url.path, '/api/v1/collections/col-1/items/reel-7');
    });
  });

  group('sharing', () {
    test('enableCollectionLink parses url and token', () async {
      late http.Request seen;
      final service = clientFor(
        MockClient((request) async {
          seen = request;
          return http.Response(
            jsonEncode({
              'url': 'https://reelpin.in/c/tok-abc',
              'token': 'tok-abc',
            }),
            200,
          );
        }),
      );

      final link = await service.enableCollectionLink('col-1');

      expect(seen.method, 'POST');
      expect(seen.url.path, '/api/v1/collections/col-1/link');
      expect(link.url, 'https://reelpin.in/c/tok-abc');
      expect(link.token, 'tok-abc');
    });

    test('disableCollectionLink deletes the link', () async {
      late http.Request seen;
      final service = clientFor(
        MockClient((request) async {
          seen = request;
          return http.Response(jsonEncode({'ok': true}), 200);
        }),
      );

      await service.disableCollectionLink('col-1');

      expect(seen.method, 'DELETE');
      expect(seen.url.path, '/api/v1/collections/col-1/link');
    });

    test('createCollectionInvite posts the role', () async {
      late http.Request seen;
      final service = clientFor(
        MockClient((request) async {
          seen = request;
          return http.Response(
            jsonEncode({
              'url': 'https://reelpin.in/c/invite/inv-1',
              'token': 'inv-1',
              'role': 'editor',
              'expires_at': '2026-08-17T00:00:00Z',
            }),
            200,
          );
        }),
      );

      final invite = await service.createCollectionInvite(
        collectionId: 'col-1',
        role: 'editor',
      );

      expect(seen.method, 'POST');
      expect(seen.url.path, '/api/v1/collections/col-1/invites');
      expect(jsonDecode(seen.body), {'role': 'editor'});
      expect(invite.role, 'editor');
      expect(invite.token, 'inv-1');
      expect(invite.expiresAt, '2026-08-17T00:00:00Z');
    });

    test('acceptCollectionInvite unwraps the mutation envelope', () async {
      late http.Request seen;
      final service = clientFor(
        MockClient((request) async {
          seen = request;
          return http.Response(
            jsonEncode({
              'collection': {..._summaryJson, 'role': 'editor'},
            }),
            200,
          );
        }),
      );

      final joined = await service.acceptCollectionInvite('inv-1');

      expect(seen.method, 'POST');
      expect(seen.url.path, '/api/v1/collections/invites/inv-1/accept');
      expect(joined.role, 'editor');
      expect(joined.canEdit, isTrue);
      expect(joined.isOwner, isFalse);
    });

    test('removeCollectionMember targets the member path', () async {
      late http.Request seen;
      final service = clientFor(
        MockClient((request) async {
          seen = request;
          return http.Response(jsonEncode({'ok': true}), 200);
        }),
      );

      await service.removeCollectionMember(
        collectionId: 'col-1',
        memberUserId: 'user-2',
      );

      expect(seen.method, 'DELETE');
      expect(seen.url.path, '/api/v1/collections/col-1/members/user-2');
    });

    test('leaveCollection posts to leave', () async {
      late http.Request seen;
      final service = clientFor(
        MockClient((request) async {
          seen = request;
          return http.Response(jsonEncode({'ok': true}), 200);
        }),
      );

      await service.leaveCollection('col-1');

      expect(seen.method, 'POST');
      expect(seen.url.path, '/api/v1/collections/col-1/leave');
    });
  });

  group('errors', () {
    test('surfaces the backend error envelope on 403', () async {
      final service = clientFor(
        MockClient(
          (_) async => http.Response(
            jsonEncode({
              'success': false,
              'error_code': 'collection_forbidden',
              'message': 'Only the collection owner can do that.',
            }),
            403,
          ),
        ),
      );

      await expectLater(
        service.deleteCollection('col-1'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 403)
              .having((e) => e.errorCode, 'errorCode', 'collection_forbidden')
              .having(
                (e) => e.message,
                'message',
                'Only the collection owner can do that.',
              ),
        ),
      );
    });

    test(
      'a 404 on a shared token throws rather than returning empty',
      () async {
        final service = clientFor(
          MockClient(
            (_) async => http.Response(
              jsonEncode({
                'success': false,
                'error_code': 'collection_not_found',
                'message': 'That collection was not found.',
              }),
              404,
            ),
          ),
        );

        await expectLater(
          service.getSharedCollection('bad-token'),
          throwsA(
            isA<ApiException>()
                .having((e) => e.statusCode, 'statusCode', 404)
                .having(
                  (e) => e.errorCode,
                  'errorCode',
                  'collection_not_found',
                ),
          ),
        );
      },
    );

    test('an invite gone 410 keeps its error code', () async {
      final service = clientFor(
        MockClient(
          (_) async => http.Response(
            jsonEncode({
              'success': false,
              'error_code': 'invite_expired',
              'message': 'This invite has expired.',
            }),
            410,
          ),
        ),
      );

      await expectLater(
        service.acceptCollectionInvite('inv-1'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 410)
              .having((e) => e.errorCode, 'errorCode', 'invite_expired'),
        ),
      );
    });
  });
}

const _summaryJson = {
  'id': 'col-1',
  'name': 'Tokyo Food Crawl',
  'description': 'Ramen, sushi, yakitori',
  'cover_reel_id': null,
  'visibility': 'link',
  'role': 'owner',
  'item_count': 12,
  'member_count': 2,
  'created_at': '2026-08-01T00:00:00Z',
  'updated_at': '2026-08-02T00:00:00Z',
};

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

const _detailJson = {
  'collection': _summaryJson,
  'reels': [_reelJson],
  'pagination': {
    'next_cursor': '26',
    'next_offset': 26,
    'has_more': true,
    'total_count': 12,
    'limit': 25,
    'offset': 0,
  },
  'can_edit': true,
};
