import 'dart:async';
import 'dart:convert';
import 'dart:io';

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
    expect(updates.map((job) => job.status), ['completed']);
    expect(requests.map((uri) => uri.path), [
      '/api/v1/processing-jobs/reels',
      '/api/v1/processing-jobs/job-123',
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
      final service = ApiService(
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

  test('getReels sends auth header without user_id query param', () async {
    final service = ApiService(
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
            'https://example.com/api/v1/reels/category-filters',
          );
          return http.Response(
            jsonEncode({
              'total_count': 0,
              'categories': <Map<String, Object?>>[],
              'selected_preview_count': 0,
            }),
            200,
          );
        }),
      );

      final response = await service.getReelCategoryFilters(userId: 'user-123');

      expect(response.totalCount, 0);
    },
  );

  test('deleteReel sends auth header', () async {
    final service = ApiService(
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

  test(
    'getAccountEntitlements reports missing endpoint without assuming Pro',
    () async {
      final service = ApiService(
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
