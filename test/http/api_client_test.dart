import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:reelpin/data_models/map/map_response.dart';
import 'package:reelpin/data_models/reels/processing_job.dart';
import 'package:reelpin/http/api_client.dart';
import 'package:reelpin/http/api_exception.dart';
import 'package:reelpin/utils/error_message.dart';

void main() {
  test('healthCheck uses the backend health endpoint', () async {
    final service = ApiClient(
      baseUrl: 'https://example.com',
      client: MockClient((request) async {
        expect(request.url.path, '/api/v1/health');
        return http.Response(jsonEncode({'status': 'ok'}), 200);
      }),
    );

    expect(await service.healthCheck(), isTrue);
  });

  test('processReel queues a job and polls until the reel is ready', () async {
    final requests = <Uri>[];
    final service = ApiClient(
      baseUrl: 'https://example.com',
      accessTokenProvider: () => 'token-123',
      client: MockClient((request) async {
        requests.add(request.url);
        expect(request.headers['Authorization'], 'Bearer token-123');

        if (request.url.path == '/api/v1/processing-jobs/reels') {
          expect(request.headers['Content-Type'], contains('application/json'));
          expect(jsonDecode(request.body), {
            'url': 'https://instagram.com/reel/abc',
          });
          return http.Response(
            jsonEncode({'id': 'job-123', 'status': 'queued'}),
            202,
          );
        }

        if (request.url.path == '/api/v1/processing-jobs/job-123') {
          return http.Response(
            jsonEncode({
              'id': 'job-123',
              'status': 'completed',
              'reel': _reelJson,
            }),
            200,
          );
        }

        return http.Response(jsonEncode({'detail': 'Not Found'}), 404);
      }),
    );

    final updates = <ProcessingJob>[];
    final reel = await service.processReel(
      'https://instagram.com/reel/abc',
      userId: 'user-123',
      onJobUpdate: updates.add,
    );

    expect(reel.id, 'reel-123');
    expect(updates.map((job) => job.status), ['queued', 'completed']);
    expect(requests.map((uri) => uri.path), [
      '/api/v1/processing-jobs/reels',
      '/api/v1/processing-jobs/job-123',
    ]);
  });

  test('processReel polls a job returned by the legacy endpoint', () async {
    final requests = <Uri>[];
    final service = ApiClient(
      baseUrl: 'https://example.com',
      accessTokenProvider: () => 'token-123',
      client: MockClient((request) async {
        requests.add(request.url);
        expect(request.headers['Authorization'], 'Bearer token-123');

        if (request.url.path == '/api/v1/processing-jobs/reels') {
          return http.Response(jsonEncode({'detail': 'Not Found'}), 404);
        }

        if (request.url.path == '/api/v1/process-reel') {
          expect(request.headers['Content-Type'], contains('application/json'));
          expect(jsonDecode(request.body), {
            'url': 'https://instagram.com/reel/abc',
          });
          return http.Response(
            jsonEncode({'job_id': 'job-legacy', 'status': 'queued'}),
            202,
          );
        }

        if (request.url.path == '/api/v1/processing-jobs/job-legacy') {
          return http.Response(
            jsonEncode({
              'id': 'job-legacy',
              'status': 'completed',
              'result_reel_id': 'reel-123',
            }),
            200,
          );
        }

        if (request.url.path == '/api/v1/reels/reel-123') {
          return http.Response(jsonEncode(_reelJson), 200);
        }

        return http.Response(jsonEncode({'detail': 'Not Found'}), 404);
      }),
    );

    final reel = await service.processReel(
      'https://instagram.com/reel/abc',
      userId: 'user-123',
    );

    expect(reel.id, 'reel-123');
    expect(requests.map((uri) => uri.path), [
      '/api/v1/processing-jobs/reels',
      '/api/v1/process-reel',
      '/api/v1/processing-jobs/job-legacy',
      '/api/v1/reels/reel-123',
    ]);
  });

  test(
    'enqueueReelProcessing accepts job_id from process-reel compatibility path',
    () async {
      final service = ApiClient(
        baseUrl: 'https://example.com',
        accessTokenProvider: () => 'token-123',
        client: MockClient((request) async {
          expect(request.headers['Authorization'], 'Bearer token-123');
          if (request.url.path == '/api/v1/processing-jobs/reels') {
            expect(jsonDecode(request.body), {
              'url': 'https://instagram.com/reel/abc',
            });
            return http.Response(jsonEncode({'detail': 'Not Found'}), 404);
          }

          if (request.url.path == '/api/v1/process-reel') {
            return http.Response(
              jsonEncode({'job_id': 'job-legacy', 'status': 'queued'}),
              202,
            );
          }

          return http.Response(jsonEncode({'detail': 'Not Found'}), 404);
        }),
      );

      final job = await service.enqueueReelProcessing(
        'https://instagram.com/reel/abc',
        userId: 'user-123',
      );

      expect(job.id, 'job-legacy');
      expect(job.status, 'queued');
    },
  );

  test(
    'enqueueReelProcessing files the reel into the given collections',
    () async {
      Map<String, dynamic>? body;
      final service = ApiClient(
        baseUrl: 'https://example.com',
        accessTokenProvider: () => 'token-123',
        client: MockClient((request) async {
          body = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({'id': 'job-1', 'status': 'queued'}),
            202,
          );
        }),
      );

      await service.enqueueReelProcessing(
        'https://instagram.com/reel/abc',
        userId: 'user-123',
        collectionIds: const ['col-1', 'col-2'],
      );

      // Without this the reel is saved to the library only, which is what a
      // share that fell back to the app used to do.
      expect(body, {
        'url': 'https://instagram.com/reel/abc',
        'collection_ids': ['col-1', 'col-2'],
      });
    },
  );

  test(
    'processReel returns an existing X saved item without another poll',
    () async {
      final requests = <Uri>[];
      final service = ApiClient(
        baseUrl: 'https://example.com',
        accessTokenProvider: () => 'token-123',
        client: MockClient((request) async {
          requests.add(request.url);
          expect(request.headers['Authorization'], 'Bearer token-123');
          expect(jsonDecode(request.body), {
            'url': 'https://x.com/OpenAI/status/1234567890',
          });
          return http.Response(
            jsonEncode({
              'id': 'job-existing',
              'status': 'completed',
              'terminal': true,
              'reel': {..._reelJson, 'source_platform': 'x'},
            }),
            200,
          );
        }),
      );

      final reel = await service.processReel(
        'https://x.com/OpenAI/status/1234567890',
      );

      expect(reel.id, 'reel-123');
      expect(reel.sourcePlatform, 'x');
      expect(requests.map((uri) => uri.path), [
        '/api/v1/processing-jobs/reels',
      ]);
    },
  );

  test('processReel prefers status_message for protected X posts', () async {
    final service = ApiClient(
      baseUrl: 'https://example.com',
      accessTokenProvider: () => 'token-123',
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'id': 'job-protected',
            'status': 'failed',
            'failure_code': 'protected_or_unavailable',
            'status_message': 'This post is protected or was deleted.',
            'terminal': true,
            'retryable': false,
          }),
          202,
        ),
      ),
    );

    await expectLater(
      service.processReel('https://x.com/private/status/1234567890'),
      throwsA(
        isA<ApiException>()
            .having(
              (error) => error.message,
              'message',
              'This post is protected or was deleted.',
            )
            .having(
              (error) => error.errorCode,
              'errorCode',
              'protected_or_unavailable',
            )
            .having((error) => error.retryable, 'retryable', isFalse),
      ),
    );
  });

  test('processReel uses a local fallback for a deleted X post', () async {
    final service = ApiClient(
      baseUrl: 'https://example.com',
      accessTokenProvider: () => 'token-123',
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'id': 'job-deleted',
            'status': 'failed',
            'failure_code': 'post_not_found',
            'terminal': true,
          }),
          202,
        ),
      ),
    );

    await expectLater(
      service.processReel('https://x.com/OpenAI/status/0000000000'),
      throwsA(
        isA<ApiException>().having(
          (error) => error.message,
          'message',
          'This post could not be found. It may be deleted.',
        ),
      ),
    );
  });

  test('getReels sends auth header without user_id query param', () async {
    final service = ApiClient(
      baseUrl: 'https://example.com',
      accessTokenProvider: () => 'token-123',
      client: MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer token-123');
        expect(
          request.url.toString(),
          'https://example.com/api/v1/reels?limit=50',
        );
        return http.Response(
          jsonEncode({
            'reels': [_reelJson],
            'next_cursor': null,
            'next_offset': 1,
            'has_more': false,
            'total_count': 1,
            'limit': 50,
            'offset': 0,
          }),
          200,
        );
      }),
    );

    final reels = await service.getReels(userId: 'user-123');

    expect(reels.single.id, 'reel-123');
  });

  test('searchReels sends auth header without user_id body field', () async {
    final service = ApiClient(
      baseUrl: 'https://example.com',
      accessTokenProvider: () => 'token-123',
      client: MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer token-123');
        expect(request.headers['Content-Type'], contains('application/json'));
        expect(jsonDecode(request.body), {
          'query': 'coffee',
          'category': 'Travel',
          'limit': 5,
        });
        expect(request.url.toString(), 'https://example.com/api/v1/search');
        return http.Response(
          jsonEncode({
            'query': 'coffee',
            'results': <Map<String, Object?>>[],
            'total': 0,
            'search_mode': 'rag',
          }),
          200,
        );
      }),
    );

    final response = await service.searchReels(
      'coffee',
      userId: 'user-123',
      category: 'Travel',
    );

    expect(response.query, 'coffee');
  });

  test(
    'registerPushToken sends auth header without user_id body field',
    () async {
      final service = ApiClient(
        baseUrl: 'https://example.com',
        accessTokenProvider: () => 'token-123',
        client: MockClient((request) async {
          expect(request.headers['Authorization'], 'Bearer token-123');
          expect(request.headers['Content-Type'], contains('application/json'));
          expect(jsonDecode(request.body), {
            'token': 'push-token',
            'platform': 'android',
            'app_version': '1.0.8',
            'app_build': '14',
            'timezone': 'Asia/Kolkata',
            'locale': 'en-IN',
          });
          return http.Response(jsonEncode({'ok': true}), 200);
        }),
      );

      await service.registerPushToken(
        userId: 'user-123',
        token: 'push-token',
        platform: 'android',
        appVersion: '1.0.8',
        appBuild: '14',
        timezone: 'Asia/Kolkata',
        locale: 'en-IN',
      );
    },
  );

  test('unregisterPushToken deletes the authenticated device token', () async {
    final service = ApiClient(
      baseUrl: 'https://example.com',
      accessTokenProvider: () => 'token-123',
      client: MockClient((request) async {
        expect(request.method, 'DELETE');
        expect(request.url.path, '/api/v1/device-push-tokens');
        expect(request.headers['Authorization'], 'Bearer token-123');
        expect(jsonDecode(request.body), {'token': 'push-token'});
        return http.Response(jsonEncode({'ok': true}), 200);
      }),
    );

    await service.unregisterPushToken(token: 'push-token');
  });

  test('recordNotificationOpened posts the authenticated open event', () async {
    final service = ApiClient(
      baseUrl: 'https://example.com',
      accessTokenProvider: () => 'token-123',
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(
          request.url.path,
          '/api/v1/notifications/notification-123/opened',
        );
        expect(request.headers['Authorization'], 'Bearer token-123');
        return http.Response(jsonEncode({'ok': true}), 200);
      }),
    );

    await service.recordNotificationOpened(notificationId: 'notification-123');
  });

  test('getReelFilters sends auth header without user_id query param', () async {
    final service = ApiClient(
      baseUrl: 'https://example.com',
      accessTokenProvider: () => 'token-123',
      client: MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer token-123');
        expect(
          request.url.toString(),
          'https://example.com/api/v1/reels/filters',
        );
        return http.Response(
          jsonEncode({
            'total_count': 0,
            'platforms': <Map<String, Object?>>[],
            'categories': <Map<String, Object?>>[],
            'selected_preview_count': 0,
          }),
          200,
        );
      }),
    );

    final response = await service.getReelFilters(userId: 'user-123');

    expect(response.totalCount, 0);
  });

  test('getReelFilters forwards the selection as query params', () async {
    final service = ApiClient(
      baseUrl: 'https://example.com',
      accessTokenProvider: () => 'token-123',
      client: MockClient((request) async {
        expect(request.url.queryParameters, {
          'platform': 'instagram',
          'category': 'Food',
          'subcategory': 'Street Food',
        });
        return http.Response(
          jsonEncode({
            'total_count': 10,
            'platforms': <Map<String, Object?>>[],
            'categories': <Map<String, Object?>>[],
            'selected_preview_count': 3,
          }),
          200,
        );
      }),
    );

    final response = await service.getReelFilters(
      platform: 'instagram',
      category: 'Food',
      subcategory: 'Street Food',
    );

    expect(response.selectedPreviewCount, 3);
  });

  test('getReelsPage sends the platform filter', () async {
    final service = ApiClient(
      baseUrl: 'https://example.com',
      accessTokenProvider: () => 'token-123',
      client: MockClient((request) async {
        expect(request.url.path, '/api/v1/reels');
        expect(request.url.queryParameters['platform'], 'youtube');
        return http.Response(
          jsonEncode({'reels': <Map<String, Object?>>[], 'total_count': 0}),
          200,
        );
      }),
    );

    await service.getReelsPage(platform: 'youtube');
  });

  test('getReelsPage omits a blank platform filter', () async {
    final service = ApiClient(
      baseUrl: 'https://example.com',
      accessTokenProvider: () => 'token-123',
      client: MockClient((request) async {
        expect(request.url.queryParameters.containsKey('platform'), isFalse);
        return http.Response(
          jsonEncode({'reels': <Map<String, Object?>>[], 'total_count': 0}),
          200,
        );
      }),
    );

    await service.getReelsPage(platform: '   ');
  });

  test('deleteReel sends auth header', () async {
    final service = ApiClient(
      baseUrl: 'https://example.com',
      accessTokenProvider: () => 'token-123',
      client: MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer token-123');
        expect(
          request.url.toString(),
          'https://example.com/api/v1/reels/reel-123',
        );
        expect(request.method, 'DELETE');
        return http.Response(jsonEncode({'ok': true}), 200);
      }),
    );

    await service.deleteReel('reel-123');
  });

  test('searchMapPlaces sends auth header and search params', () async {
    final service = ApiClient(
      baseUrl: 'https://example.com',
      accessTokenProvider: () => 'token-123',
      client: MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer token-123');
        expect(request.url.path, '/api/v1/map/search');
        expect(request.url.queryParameters['query'], 'coffee');
        expect(request.url.queryParameters['category'], 'Food');
        expect(request.url.queryParameters['session_token'], 'session-1');
        expect(request.url.queryParameters['limit'], '8');
        return http.Response(
          jsonEncode({
            'query': 'coffee',
            'search_mode': 'google',
            'total': 1,
            'results': [
              {
                'result_type': 'google',
                'google_place_id': 'place-1',
                'display_title': 'Manual Cafe',
                'display_address': '12 Market Street',
                'place_name': 'Manual Cafe',
                'latitude': 12.91,
                'longitude': 77.61,
                'place_types': ['cafe'],
                'can_pin': true,
              },
            ],
          }),
          200,
        );
      }),
    );

    final response = await service.searchMapPlaces(
      'coffee',
      category: 'Food',
      sessionToken: 'session-1',
    );

    expect(response.total, 1);
    expect(response.results.single.googlePlaceId, 'place-1');
    expect(response.results.single.canPin, isTrue);
  });

  test('pinMapPlace posts google place id and parses map item', () async {
    final service = ApiClient(
      baseUrl: 'https://example.com',
      accessTokenProvider: () => 'token-123',
      client: MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer token-123');
        expect(request.headers['Content-Type'], contains('application/json'));
        expect(request.url.path, '/api/v1/map/pins');
        expect(jsonDecode(request.body), {
          'googlePlaceId': 'place-1',
          'sessionToken': 'session-1',
        });
        return http.Response(jsonEncode(_manualMapItemJson), 200);
      }),
    );

    final item = await service.pinMapPlace(
      'place-1',
      sessionToken: 'session-1',
    );

    expect(item, isA<MapItem>());
    expect(item.mapItemId, 'manual:pin-1');
    expect(item.displayName, 'Manual Cafe');
    expect(item.canOpenDetails, isFalse);
  });

  test('removeMapItem deletes map item by id', () async {
    final service = ApiClient(
      baseUrl: 'https://example.com',
      accessTokenProvider: () => 'token-123',
      client: MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer token-123');
        expect(request.method, 'DELETE');
        expect(request.url.path, '/api/v1/map/items/reel:reel-1:0');
        return http.Response(jsonEncode({'message': 'map item removed'}), 200);
      }),
    );

    await service.removeMapItem('reel:reel-1:0');
  });

  test('deleteAccount sends auth header', () async {
    final service = ApiClient(
      baseUrl: 'https://example.com',
      accessTokenProvider: () => 'token-123',
      client: MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer token-123');
        expect(request.url.toString(), 'https://example.com/api/v1/account');
        expect(request.method, 'DELETE');
        return http.Response(jsonEncode({'deleted': true}), 200);
      }),
    );

    await service.deleteAccount();
  });

  test(
    'getAccountEntitlements reports missing endpoint without assuming Pro',
    () async {
      final service = ApiClient(
        baseUrl: 'https://example.com',
        accessTokenProvider: () => 'token-123',
        client: MockClient((request) async {
          expect(
            request.url.toString(),
            'https://example.com/api/v1/account/entitlements',
          );
          expect(request.headers['Authorization'], 'Bearer token-123');
          return http.Response(jsonEncode({'detail': 'Not Found'}), 404);
        }),
      );

      expect(
        () => service.getAccountEntitlements(userId: 'user-123'),
        throwsA(
          isA<ApiException>().having(
            (error) => error.statusCode,
            'statusCode',
            404,
          ),
        ),
      );
    },
  );

  test('getAccountEntitlements still reports non-404 failures', () async {
    final service = ApiClient(
      baseUrl: 'https://example.com',
      client: MockClient((request) async {
        return http.Response(jsonEncode({'detail': 'Server error'}), 500);
      }),
    );

    expect(
      () => service.getAccountEntitlements(userId: 'user-123'),
      throwsA(
        isA<ApiException>().having(
          (error) => error.statusCode,
          'statusCode',
          500,
        ),
      ),
    );
  });

  test('userFacingErrorMessage hides network exception details', () {
    expect(
      userFacingErrorMessage(
        http.ClientException(
          'Connection closed before full header was received',
          Uri.parse('http://192.168.1.5:8000/reels/reel-123'),
        ),
        fallbackMessage: 'Could not load this reel right now.',
      ),
      'Could not connect. Please try again.',
    );
    expect(
      userFacingErrorMessage(
        TimeoutException('http://192.168.1.5:8000/reels/reel-123'),
        fallbackMessage: 'Could not load this reel right now.',
      ),
      'Could not connect. Please try again.',
    );
    expect(
      userFacingErrorMessage(
        const SocketException('Connection refused'),
        fallbackMessage: 'Could not load this reel right now.',
      ),
      'Could not connect. Please try again.',
    );
    expect(
      userFacingErrorMessage(
        const ApiException(
          'ClientException: Connection closed before full header was received, '
          'uri=http://192.168.1.5:8000/reels/reel-123',
          503,
        ),
        fallbackMessage: 'Could not load this reel right now.',
      ),
      'Could not connect. Please try again.',
    );
    expect(
      userFacingErrorMessage(
        const ApiException('Request failed (500)', 500),
        fallbackMessage: 'Could not load this reel right now.',
      ),
      'Could not load this reel right now.',
    );
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

const _manualMapItemJson = {
  'reel_id': '',
  'title': 'Manual Cafe',
  'summary': '12 Market Street',
  'category': 'Food',
  'sub_category': 'Cafes',
  'category_label': 'Food',
  'sub_category_label': 'Cafes',
  'locations': <Map<String, Object?>>[],
  'map_item_id': 'manual:pin-1',
  'source_type': 'manual',
  'source_id': 'pin-1',
  'display_title': 'Manual Cafe',
  'short_detail': '12 Market Street',
  'marker_id': 'manual:pin-1',
  'latitude': 12.91,
  'longitude': 77.61,
  'place_name': 'Manual Cafe',
  'display_address': '12 Market Street',
  'location_name': 'Manual Cafe',
  'location_display_label': '12 Market Street',
  'google_maps_url': 'https://maps.example/manual-cafe',
  'google_place_id': 'place-1',
  'place_types': ['cafe'],
  'can_hide': true,
  'can_remove': true,
};
