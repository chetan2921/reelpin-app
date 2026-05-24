import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:reelpin/models/processing_job.dart';
import 'package:reelpin/services/api_service.dart';

void main() {
  test('processReel queues a job and polls until the reel is ready', () async {
    final requests = <Uri>[];
    final service = ApiService(
      baseUrl: 'https://example.com',
      accessTokenProvider: () => 'token-123',
      client: MockClient((request) async {
        requests.add(request.url);
        expect(request.headers['Authorization'], 'Bearer token-123');

        if (request.url.path == '/processing-jobs/reels') {
          expect(request.headers['Content-Type'], contains('application/json'));
          expect(jsonDecode(request.body), {
            'url': 'https://instagram.com/reel/abc',
          });
          return http.Response(
            jsonEncode({'id': 'job-123', 'status': 'queued'}),
            202,
          );
        }

        if (request.url.path == '/processing-jobs/job-123') {
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
    expect(updates.map((job) => job.status), ['completed']);
    expect(requests.map((uri) => uri.path), [
      '/processing-jobs/reels',
      '/processing-jobs/job-123',
    ]);
  });

  test('processReel polls a job returned by the legacy endpoint', () async {
    final requests = <Uri>[];
    final service = ApiService(
      baseUrl: 'https://example.com',
      accessTokenProvider: () => 'token-123',
      client: MockClient((request) async {
        requests.add(request.url);
        expect(request.headers['Authorization'], 'Bearer token-123');

        if (request.url.path == '/processing-jobs/reels') {
          return http.Response(jsonEncode({'detail': 'Not Found'}), 404);
        }

        if (request.url.path == '/process-reel') {
          expect(request.headers['Content-Type'], contains('application/json'));
          expect(jsonDecode(request.body), {
            'url': 'https://instagram.com/reel/abc',
          });
          return http.Response(
            jsonEncode({'job_id': 'job-legacy', 'status': 'queued'}),
            202,
          );
        }

        if (request.url.path == '/processing-jobs/job-legacy') {
          return http.Response(
            jsonEncode({
              'id': 'job-legacy',
              'status': 'completed',
              'result_reel_id': 'reel-123',
            }),
            200,
          );
        }

        if (request.url.path == '/reels/reel-123') {
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
      '/processing-jobs/reels',
      '/process-reel',
      '/processing-jobs/job-legacy',
      '/reels/reel-123',
    ]);
  });

  test(
    'enqueueReelProcessing accepts job_id from process-reel fallback',
    () async {
      final service = ApiService(
        baseUrl: 'https://example.com',
        accessTokenProvider: () => 'token-123',
        client: MockClient((request) async {
          expect(request.headers['Authorization'], 'Bearer token-123');
          if (request.url.path == '/processing-jobs/reels') {
            expect(jsonDecode(request.body), {
              'url': 'https://instagram.com/reel/abc',
            });
            return http.Response(jsonEncode({'detail': 'Not Found'}), 404);
          }

          if (request.url.path == '/process-reel') {
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

  test('getReels sends auth header without user_id query param', () async {
    final service = ApiService(
      baseUrl: 'https://example.com',
      accessTokenProvider: () => 'token-123',
      client: MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer token-123');
        expect(request.url.toString(), 'https://example.com/reels?limit=50');
        return http.Response(jsonEncode([_reelJson]), 200);
      }),
    );

    final reels = await service.getReels(userId: 'user-123');

    expect(reels.single.id, 'reel-123');
  });

  test('searchReels sends auth header without user_id body field', () async {
    final service = ApiService(
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
      final service = ApiService(
        baseUrl: 'https://example.com',
        accessTokenProvider: () => 'token-123',
        client: MockClient((request) async {
          expect(request.headers['Authorization'], 'Bearer token-123');
          expect(request.headers['Content-Type'], contains('application/json'));
          expect(jsonDecode(request.body), {
            'token': 'push-token',
            'platform': 'android',
          });
          return http.Response(jsonEncode({'ok': true}), 200);
        }),
      );

      await service.registerPushToken(
        userId: 'user-123',
        token: 'push-token',
        platform: 'android',
      );
    },
  );

  test(
    'getCategoryFilters sends auth header without user_id query param',
    () async {
      final service = ApiService(
        baseUrl: 'https://example.com',
        accessTokenProvider: () => 'token-123',
        client: MockClient((request) async {
          expect(request.headers['Authorization'], 'Bearer token-123');
          expect(
            request.url.toString(),
            'https://example.com/reels/category-filters',
          );
          return http.Response(
            jsonEncode({
              'user_id': 'user-123',
              'categories': <Map<String, Object?>>[],
            }),
            200,
          );
        }),
      );

      final response = await service.getReelCategoryFilters(userId: 'user-123');

      expect(response.userId, 'user-123');
    },
  );

  test('deleteReel sends auth header', () async {
    final service = ApiService(
      baseUrl: 'https://example.com',
      accessTokenProvider: () => 'token-123',
      client: MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer token-123');
        expect(request.url.toString(), 'https://example.com/reels/reel-123');
        expect(request.method, 'DELETE');
        return http.Response(jsonEncode({'ok': true}), 200);
      }),
    );

    await service.deleteReel('reel-123');
  });

  test(
    'getAccountEntitlements falls back when the endpoint is missing',
    () async {
      final service = ApiService(
        baseUrl: 'https://example.com',
        accessTokenProvider: () => 'token-123',
        client: MockClient((request) async {
          expect(
            request.url.toString(),
            'https://example.com/account/entitlements',
          );
          expect(request.headers['Authorization'], 'Bearer token-123');
          return http.Response(jsonEncode({'detail': 'Not Found'}), 404);
        }),
      );

      final entitlement = await service.getAccountEntitlements(
        userId: 'user-123',
      );

      expect(entitlement.userId, 'user-123');
      expect(entitlement.isPro, isTrue);
      expect(entitlement.features.conversationalRagSearch, isTrue);
      expect(entitlement.limits.reelsPerMonth, isNull);
    },
  );

  test('getAccountEntitlements still reports non-404 failures', () async {
    final service = ApiService(
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
