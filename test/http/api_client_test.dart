import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:reelpin/data_models/map/map_bounds.dart';
import 'package:reelpin/data_models/map/map_response.dart';
import 'package:reelpin/data_models/reels/processing_job.dart';
import 'package:reelpin/http/api_client.dart';
import 'package:reelpin/http/api_exception.dart';
import 'package:reelpin/utils/error_message.dart';

import '../fixtures/api_v2.dart';

final _uuidV4 = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

void main() {
  group('an expired session', () {
    /// The backend accepts only [validToken]; everything else is a 401.
    MockClient backendAccepting(String validToken, List<String?> seen) {
      return MockClient((request) async {
        final auth = request.headers['Authorization'];
        seen.add(auth);
        return auth == 'Bearer $validToken'
            ? ApiV2Fixture('library_stats').toResponse()
            : ApiV2Fixture('error_unauthorized').toResponse();
      });
    }

    test('is renewed once and the request sent again', () async {
      var token = _tokenFor('user-a', 'expired');
      var renewals = 0;
      final seen = <String?>[];
      final service = ApiClient(
        baseUrl: 'https://example.com',
        accessTokenProvider: () => token,
        sessionRefresher: () async {
          renewals += 1;
          token = _tokenFor('user-a', 'fresh');
        },
        client: backendAccepting(_tokenFor('user-a', 'fresh'), seen),
      );

      final stats = await service.getLibraryStats();

      expect(stats.totalReels, 0);
      expect(renewals, 1);
      expect(seen, [
        'Bearer ${_tokenFor('user-a', 'expired')}',
        'Bearer ${_tokenFor('user-a', 'fresh')}',
      ]);
    });

    test('that cannot be renewed surfaces the 401 without looping', () async {
      final seen = <String?>[];
      final service = ApiClient(
        baseUrl: 'https://example.com',
        accessTokenProvider: () => _tokenFor('user-a', 'revoked'),
        sessionRefresher: () async => throw Exception('refresh failed'),
        client: backendAccepting(_tokenFor('user-a', 'fresh'), seen),
      );

      await expectLater(
        service.getLibraryStats(),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 401)
              .having(
                (e) => e.errorCode,
                'errorCode',
                'authentication_required',
              ),
        ),
      );
      expect(seen, ['Bearer ${_tokenFor('user-a', 'revoked')}']);
    });

    test('already renewed by another request is not renewed again', () async {
      var token = _tokenFor('user-a', 'expired');
      var renewals = 0;
      final seen = <String?>[];
      final service = ApiClient(
        baseUrl: 'https://example.com',
        accessTokenProvider: () => token,
        sessionRefresher: () async => renewals += 1,
        client: MockClient((request) async {
          seen.add(request.headers['Authorization']);
          if (request.headers['Authorization'] == 'Bearer ${_tokenFor('user-a', 'fresh')}') {
            return ApiV2Fixture('library_stats').toResponse();
          }
          // Renewed elsewhere while this request was in flight.
          token = _tokenFor('user-a', 'fresh');
          return ApiV2Fixture('error_unauthorized').toResponse();
        }),
      );

      await service.getLibraryStats();

      expect(renewals, 0);
      expect(seen, [
        'Bearer ${_tokenFor('user-a', 'expired')}',
        'Bearer ${_tokenFor('user-a', 'fresh')}',
      ]);
    });

    for (final switchDuringRefresh in [false, true]) {
      test(
        'account deletion is not replayed after switching users ${switchDuringRefresh ? 'during renewal' : 'while awaiting a response'}',
        () async {
          var token = _tokenFor('user-a', 'expired');
          var renewals = 0;
          final seen = <String?>[];
          final service = ApiClient(
            baseUrl: 'https://example.com',
            accessTokenProvider: () => token,
            sessionRefresher: () async {
              renewals += 1;
              token = _tokenFor('user-b', 'fresh');
            },
            client: MockClient((request) async {
              expect(request.method, 'DELETE');
              expect(request.url.path, '/api/v2/account');
              seen.add(request.headers['Authorization']);
              if (seen.length == 1) {
                if (!switchDuringRefresh) {
                  token = _tokenFor('user-b', 'fresh');
                }
                return ApiV2Fixture('error_unauthorized').toResponse();
              }
              return http.Response('{}', 200);
            }),
          );

          await expectLater(
            service.deleteAccount(),
            throwsA(
              isA<ApiException>().having((e) => e.statusCode, 'statusCode', 401),
            ),
          );
          expect(seen, ['Bearer ${_tokenFor('user-a', 'expired')}']);
          expect(renewals, switchDuringRefresh ? 1 : 0);
        },
      );
    }

    test('a delayed 401 after sign-out is not replayed', () async {
      String? token = _tokenFor('user-a', 'expired');
      var renewals = 0;
      final seen = <String?>[];
      final service = ApiClient(
        baseUrl: 'https://example.com',
        accessTokenProvider: () => token,
        sessionRefresher: () async => renewals += 1,
        client: MockClient((request) async {
          seen.add(request.headers['Authorization']);
          token = null;
          return ApiV2Fixture('error_unauthorized').toResponse();
        }),
      );

      await expectLater(service.deleteAccount(), throwsA(isA<ApiException>()));

      expect(seen, ['Bearer ${_tokenFor('user-a', 'expired')}']);
      expect(renewals, 0);
    });

    test('is not renewed for a request sent signed out', () async {
      var renewals = 0;
      final seen = <String?>[];
      final service = ApiClient(
        baseUrl: 'https://example.com',
        accessTokenProvider: () => null,
        sessionRefresher: () async => renewals += 1,
        client: backendAccepting(_tokenFor('user-a', 'fresh'), seen),
      );

      await expectLater(
        service.getLibraryStats(),
        throwsA(isA<ApiException>()),
      );
      expect(renewals, 0);
      expect(seen, [null]);
    });
  });

  group('the error envelope', () {
    test('carries code, request id, retryable and details', () async {
      final service = ApiClient(
        baseUrl: 'https://example.com',
        client: MockClient(
          (_) async => ApiV2Fixture('error_validation').toResponse(),
        ),
      );

      await expectLater(
        service.getReelsPage(cursor: '25'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 422)
              .having((e) => e.errorCode, 'errorCode', 'validation_error')
              .having((e) => e.requestId, 'requestId', 'fixture-request-id')
              .having((e) => e.retryable, 'retryable', isFalse)
              .having((e) => e.details['field'], 'details.field', 'cursor')
              .having(
                (e) => e.message,
                'message',
                'The request is missing required fields or contains invalid values.',
              ),
        ),
      );
    });

    test('keeps retryable for a temporary outage', () async {
      final service = ApiClient(
        baseUrl: 'https://example.com',
        client: MockClient(
          (_) async =>
              ApiV2Fixture('error_processing_unavailable').toResponse(),
        ),
      );

      await expectLater(
        service.enqueueReelProcessing('https://instagram.com/reel/abc'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 503)
              .having((e) => e.errorCode, 'errorCode', 'processing_unavailable')
              .having((e) => e.retryable, 'retryable', isTrue),
        ),
      );
    });

    test(
      'falls back to the caller message for a body that is not JSON',
      () async {
        final service = ApiClient(
          baseUrl: 'https://example.com',
          client: MockClient(
            (_) async => http.Response('<html>Bad Gateway</html>', 502),
          ),
        );

        await expectLater(
          service.getLibraryStats(),
          throwsA(
            isA<ApiException>()
                .having((e) => e.statusCode, 'statusCode', 502)
                .having((e) => e.errorCode, 'errorCode', isNull)
                .having(
                  (e) => e.message,
                  'message',
                  'Could not load library stats right now.',
                ),
          ),
        );
      },
    );

    test('never trips the dormant v1 plan-limit checks', () async {
      // openapi.yaml has no code enum; these are the codes its prose names,
      // plus every code in the captured error fixtures.
      final codes = <String>{
        'processing_unavailable',
        'spend_limit_reached',
        'feedback_unavailable',
        'link_clicks_unavailable',
      };
      final fixtures = Directory('test/fixtures/api_v2')
          .listSync()
          .map((file) => file.uri.pathSegments.last)
          .where((name) => name.startsWith('error_'))
          .map((name) => name.replaceAll('.json', ''));
      expect(fixtures, isNotEmpty);

      for (final fixture in fixtures) {
        final service = ApiClient(
          baseUrl: 'https://example.com',
          client: MockClient((_) async => ApiV2Fixture(fixture).toResponse()),
        );
        try {
          await service.getLibraryStats();
          fail('$fixture did not throw');
        } on ApiException catch (error) {
          codes.add(error.errorCode!);
        }
      }

      for (final code in codes) {
        final error = ApiException('', 400, errorCode: code);
        expect(error.isMonthlyReelLimitReached, isFalse, reason: code);
        expect(error.isHistoryUpgradeRequired, isFalse, reason: code);
      }
    });
  });

  group('submission', () {
    test('sends a UUID Idempotency-Key and the url', () async {
      late http.Request seen;
      final service = ApiClient(
        baseUrl: 'https://example.com',
        accessTokenProvider: () => 'token-123',
        client: MockClient((request) async {
          seen = request;
          return ApiV2Fixture('submission_accepted').toResponse();
        }),
      );

      final job = await service.enqueueReelProcessing(
        'https://www.instagram.com/reel/C8abc123/',
      );

      expect(seen.method, 'POST');
      expect(seen.url.path, '/api/v2/processing-jobs/reels');
      expect(seen.headers['Authorization'], 'Bearer token-123');
      expect(seen.headers['Content-Type'], contains('application/json'));
      expect(seen.headers['Idempotency-Key'], matches(_uuidV4));
      expect(jsonDecode(seen.body), {
        'url': 'https://www.instagram.com/reel/C8abc123/',
      });
      expect(job.id, 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa');
      expect(job.status, 'queued');
      expect(job.alreadySaved, isFalse);
      expect(job.isCompleted, isFalse);
    });

    test('files the reel into the given collections', () async {
      Map<String, dynamic>? body;
      final service = ApiClient(
        baseUrl: 'https://example.com',
        accessTokenProvider: () => 'token-123',
        client: MockClient((request) async {
          body = jsonDecode(request.body) as Map<String, dynamic>;
          return ApiV2Fixture('submission_accepted').toResponse();
        }),
      );

      await service.enqueueReelProcessing(
        'https://instagram.com/reel/abc',
        collectionIds: const ['col-1', 'col-2'],
      );

      // Without this the reel is saved to the library only, which is what a
      // share that fell back to the app used to do.
      expect(body, {
        'url': 'https://instagram.com/reel/abc',
        'collection_ids': ['col-1', 'col-2'],
      });
    });

    test('a new attempt gets a new key; a renewed resend keeps it', () async {
      var token = _tokenFor('user-a', 'expired');
      final keys = <String?>[];
      final service = ApiClient(
        baseUrl: 'https://example.com',
        accessTokenProvider: () => token,
        sessionRefresher: () async => token = _tokenFor('user-a', 'fresh'),
        client: MockClient((request) async {
          keys.add(request.headers['Idempotency-Key']);
          if (request.headers['Authorization'] != 'Bearer ${_tokenFor('user-a', 'fresh')}') {
            return ApiV2Fixture('error_unauthorized').toResponse();
          }
          return ApiV2Fixture('submission_accepted').toResponse();
        }),
      );

      await service.enqueueReelProcessing('https://instagram.com/reel/abc');
      await service.enqueueReelProcessing('https://instagram.com/reel/abc');

      expect(keys, hasLength(3));
      expect(keys[0], keys[1]);
      expect(keys[2], isNot(keys[1]));
    });

    test('202 with already_saved is the job already in flight', () async {
      final service = ApiClient(
        baseUrl: 'https://example.com',
        client: MockClient(
          (_) async => ApiV2Fixture('submission_in_flight').toResponse(),
        ),
      );

      final job = await service.enqueueReelProcessing(
        'https://www.instagram.com/reel/C8abc123/',
      );

      expect(job.alreadySaved, isTrue);
      expect(job.status, 'processing');
      expect(job.progressPercent, 40);
      expect(job.terminal, isFalse);
    });

    test('200 is the ready reel, handed on as a completed job', () async {
      final service = ApiClient(
        baseUrl: 'https://example.com',
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              ...ApiV2Fixture('reel_detail').body,
              'already_saved': true,
            }),
            200,
          ),
        ),
      );

      final job = await service.enqueueReelProcessing(
        'https://www.instagram.com/reel/abc/',
      );

      expect(job.id, isEmpty);
      expect(job.isCompleted, isTrue);
      expect(job.alreadySaved, isTrue);
      expect(job.resultReelId, '22222222-2222-4222-8222-222222222222');
      expect(job.reel?.title, 'Best cafes in Goa');
    });

    test('a 409 keeps the idempotency_conflict code', () async {
      final service = ApiClient(
        baseUrl: 'https://example.com',
        client: MockClient(
          (_) async => ApiV2Fixture('error_idempotency_conflict').toResponse(),
        ),
      );

      await expectLater(
        service.enqueueReelProcessing('https://instagram.com/reel/abc'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 409)
              .having((e) => e.errorCode, 'errorCode', 'idempotency_conflict'),
        ),
      );
    });
  });

  test('processReel queues a job and polls until the reel is ready', () async {
    final requests = <Uri>[];
    final completed = (ApiV2Fixture('job_list').body['jobs'] as List)[1];
    final service = ApiClient(
      baseUrl: 'https://example.com',
      accessTokenProvider: () => 'token-123',
      client: MockClient((request) async {
        requests.add(request.url);
        expect(request.headers['Authorization'], 'Bearer token-123');

        if (request.url.path == '/api/v2/processing-jobs/reels') {
          return http.Response(
            jsonEncode({'id': 'job-123', 'status': 'queued'}),
            202,
          );
        }
        if (request.url.path == '/api/v2/processing-jobs/job-123') {
          return http.Response(jsonEncode(completed), 200);
        }
        return ApiV2Fixture('error_validation').toResponse();
      }),
    );

    final updates = <ProcessingJob>[];
    final reel = await service.processReel(
      'https://instagram.com/reel/abc',
      onJobUpdate: updates.add,
    );

    expect(reel.id, '22222222-2222-4222-8222-222222222222');
    expect(updates.map((job) => job.status), ['queued', 'completed']);
    expect(requests.map((uri) => uri.path), [
      '/api/v2/processing-jobs/reels',
      '/api/v2/processing-jobs/job-123',
    ]);
  });

  test('processReel returns a ready reel without polling', () async {
    final requests = <Uri>[];
    final service = ApiClient(
      baseUrl: 'https://example.com',
      client: MockClient((request) async {
        requests.add(request.url);
        return ApiV2Fixture('reel_detail').toResponse();
      }),
    );

    final reel = await service.processReel('https://instagram.com/reel/abc/');

    expect(reel.id, '22222222-2222-4222-8222-222222222222');
    expect(requests.map((uri) => uri.path), ['/api/v2/processing-jobs/reels']);
  });

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

  test('listProcessingJobs reads the jobs envelope', () async {
    late http.Request seen;
    final service = ApiClient(
      baseUrl: 'https://example.com',
      client: MockClient((request) async {
        seen = request;
        return ApiV2Fixture('job_list').toResponse();
      }),
    );

    final jobs = await service.listProcessingJobs(activeOnly: false);

    expect(seen.url.path, '/api/v2/processing-jobs');
    expect(seen.url.queryParameters, {'active_only': 'false', 'limit': '20'});
    expect(jobs, hasLength(2));
    expect(jobs.first.stage, 'Transcribing');
    expect(jobs.first.estimatedSecondsRemaining, 405);
    expect(jobs.first.summary, isNull);
    expect(jobs.last.summary, 'Three cafes worth the ride.');
    expect(jobs.last.reel?.subCategory, 'cafes');
  });

  group('reels', () {
    test('getReels asks for the concise view without user_id', () async {
      final service = ApiClient(
        baseUrl: 'https://example.com',
        accessTokenProvider: () => 'token-123',
        client: MockClient((request) async {
          expect(request.headers['Authorization'], 'Bearer token-123');
          expect(
            request.url.toString(),
            'https://example.com/api/v2/reels?limit=50&view=concise',
          );
          return ApiV2Fixture('reel_page').toResponse();
        }),
      );

      final reels = await service.getReels(userId: 'user-123');

      expect(reels.single.id, '22222222-2222-4222-8222-222222222222');
      expect(reels.single.webUrl, contains('/r/22222222'));
    });

    test('getReelsPage passes the opaque cursor through', () async {
      final service = ApiClient(
        baseUrl: 'https://example.com',
        client: MockClient((request) async {
          expect(request.url.queryParameters['cursor'], 'opaque-cursor');
          expect(request.url.queryParameters.containsKey('offset'), isFalse);
          return http.Response(
            jsonEncode({
              ...ApiV2Fixture('reel_page').body,
              'next_cursor': 'next-cursor',
              'has_more': true,
            }),
            200,
          );
        }),
      );

      final page = await service.getReelsPage(cursor: 'opaque-cursor');

      expect(page.nextCursor, 'next-cursor');
      expect(page.hasMore, isTrue);
    });

    test('getReelsPage reads the last page from a null cursor', () async {
      final service = ApiClient(
        baseUrl: 'https://example.com',
        client: MockClient((_) async => ApiV2Fixture('reel_page').toResponse()),
      );

      final page = await service.getReelsPage();

      expect(page.nextCursor, isNull);
      expect(page.hasMore, isFalse);
    });

    test('getReelsPage sends the platform filter', () async {
      final service = ApiClient(
        baseUrl: 'https://example.com',
        client: MockClient((request) async {
          expect(request.url.path, '/api/v2/reels');
          expect(request.url.queryParameters['platform'], 'youtube');
          return ApiV2Fixture('reel_page').toResponse();
        }),
      );

      await service.getReelsPage(platform: 'youtube');
    });

    test('getReelsPage omits a blank platform filter', () async {
      final service = ApiClient(
        baseUrl: 'https://example.com',
        client: MockClient((request) async {
          expect(request.url.queryParameters.containsKey('platform'), isFalse);
          return ApiV2Fixture('reel_page').toResponse();
        }),
      );

      await service.getReelsPage(platform: '   ');
    });

    test('getReelsPage caps the page size at the contract maximum', () async {
      final service = ApiClient(
        baseUrl: 'https://example.com',
        client: MockClient((request) async {
          expect(request.url.queryParameters['limit'], '100');
          return ApiV2Fixture('reel_page').toResponse();
        }),
      );

      await service.getReelsPage(limit: 240);
    });

    test('getReel uses the default detailed view', () async {
      final service = ApiClient(
        baseUrl: 'https://example.com',
        client: MockClient((request) async {
          expect(
            request.url.toString(),
            'https://example.com/api/v2/reels/22222222-2222-4222-8222-222222222222',
          );
          return ApiV2Fixture('reel_detail').toResponse();
        }),
      );

      final reel = await service.getReel(
        '22222222-2222-4222-8222-222222222222',
      );

      expect(reel.transcript, 'spoken words');
      expect(reel.subCategory, 'cafes');
    });

    test('deleteReel accepts the 204', () async {
      final service = ApiClient(
        baseUrl: 'https://example.com',
        accessTokenProvider: () => 'token-123',
        client: MockClient((request) async {
          expect(request.headers['Authorization'], 'Bearer token-123');
          expect(
            request.url.toString(),
            'https://example.com/api/v2/reels/reel-123',
          );
          expect(request.method, 'DELETE');
          return http.Response('', 204);
        }),
      );

      await service.deleteReel('reel-123');
    });

    test(
      'getReelFilters sends auth header without user_id query param',
      () async {
        final service = ApiClient(
          baseUrl: 'https://example.com',
          accessTokenProvider: () => 'token-123',
          client: MockClient((request) async {
            expect(request.headers['Authorization'], 'Bearer token-123');
            expect(
              request.url.toString(),
              'https://example.com/api/v2/reels/filters',
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
      },
    );

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
  });

  test('searchReels posts the query and asks for the concise view', () async {
    final service = ApiClient(
      baseUrl: 'https://example.com',
      accessTokenProvider: () => 'token-123',
      client: MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer token-123');
        expect(request.headers['Content-Type'], contains('application/json'));
        expect(jsonDecode(request.body), {
          'query': 'artjuna cafe',
          'category': 'Travel',
          'limit': 5,
        });
        expect(
          request.url.toString(),
          'https://example.com/api/v2/search?view=concise',
        );
        return ApiV2Fixture('search_results').toResponse();
      }),
    );

    final response = await service.searchReels(
      'artjuna cafe',
      userId: 'user-123',
      category: 'Travel',
    );

    expect(response.total, 1);
    expect(response.results.single.relevancePercent, '100');
    expect(response.results.single.reel.title, 'Best cafes in Goa');
  });

  test(
    'getDiscover sends the saved date and cursor, never an offset',
    () async {
      final service = ApiClient(
        baseUrl: 'https://example.com',
        client: MockClient((request) async {
          expect(request.url.path, '/api/v2/discover');
          expect(request.url.queryParameters, {
            'limit': '25',
            'saved_date': '2026-09-02',
            'cursor': 'opaque-cursor',
          });
          return http.Response(
            jsonEncode({
              'recent_saves': [ApiV2Fixture('reel_page').body['reels'][0]],
              'recent_saves_count': 1,
              'saved_dates': ['2026-09-02'],
              'selected_date': '2026-09-02',
              'reels_for_selected_date': <Object?>[],
              'category_grid': [
                {
                  'category': 'food_and_drink',
                  'label': 'Food And Drink',
                  'count': 1,
                  'subcategories': <Object?>[],
                },
              ],
              'quick_search_prompts': ['cafes'],
              'pagination': {
                'next_cursor': null,
                'has_more': false,
                'limit': 25,
                'total_count': 1,
              },
            }),
            200,
          );
        }),
      );

      final discover = await service.getDiscover(
        savedDate: '2026-09-02',
        cursor: 'opaque-cursor',
      );

      expect(discover.savedDates.single.value, '2026-09-02');
      expect(discover.categoryGrid.single.label, 'Food And Drink');
      expect(discover.pagination.hasMore, isFalse);
    },
  );

  group('sharing and notifications', () {
    test('registerPushToken sends only the token and platform', () async {
      final service = ApiClient(
        baseUrl: 'https://example.com',
        accessTokenProvider: () => 'token-123',
        client: MockClient((request) async {
          expect(request.url.path, '/api/v2/device-push-tokens');
          expect(request.headers['Authorization'], 'Bearer token-123');
          expect(request.headers['Content-Type'], contains('application/json'));
          expect(jsonDecode(request.body), {
            'token': 'push-token',
            'platform': 'android',
          });
          return http.Response(jsonEncode({'registered': true}), 200);
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
    });

    test(
      'unregisterPushToken deletes the authenticated device token',
      () async {
        final service = ApiClient(
          baseUrl: 'https://example.com',
          accessTokenProvider: () => 'token-123',
          client: MockClient((request) async {
            expect(request.method, 'DELETE');
            expect(request.url.path, '/api/v2/device-push-tokens');
            expect(request.headers['Authorization'], 'Bearer token-123');
            expect(jsonDecode(request.body), {'token': 'push-token'});
            return http.Response(jsonEncode({'deleted': true}), 200);
          }),
        );

        await service.unregisterPushToken(token: 'push-token');
      },
    );

    test(
      'recordNotificationOpened posts the authenticated open event',
      () async {
        final service = ApiClient(
          baseUrl: 'https://example.com',
          accessTokenProvider: () => 'token-123',
          client: MockClient((request) async {
            expect(request.method, 'POST');
            expect(
              request.url.path,
              '/api/v2/notifications/notification-123/opened',
            );
            expect(request.headers['Authorization'], 'Bearer token-123');
            return http.Response(jsonEncode({'opened': true}), 200);
          }),
        );

        await service.recordNotificationOpened(
          notificationId: 'notification-123',
        );
      },
    );

    test('mintShareToken reads the token field', () async {
      final service = ApiClient(
        baseUrl: 'https://example.com',
        client: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/api/v2/share-tokens');
          return ApiV2Fixture('share_token_minted').toResponse();
        }),
      );

      expect(await service.mintShareToken(), 'fixture-share-token');
    });

    test('revokeShareToken deletes every share token', () async {
      final service = ApiClient(
        baseUrl: 'https://example.com',
        client: MockClient((request) async {
          expect(request.method, 'DELETE');
          expect(request.url.path, '/api/v2/share-tokens');
          return http.Response(jsonEncode({'revoked': 2}), 200);
        }),
      );

      await service.revokeShareToken();
    });

    test('resolveSharePayload sends only the raw text', () async {
      final service = ApiClient(
        baseUrl: 'https://example.com',
        client: MockClient((request) async {
          expect(request.url.path, '/api/v2/share/resolve');
          expect(jsonDecode(request.body), {
            'raw_payload_text': 'look https://www.instagram.com/reel/C8abc123/',
          });
          return ApiV2Fixture('share_resolved').toResponse();
        }),
      );

      final resolved = await service.resolveSharePayload(
        rawPayloadText: 'look https://www.instagram.com/reel/C8abc123/',
      );

      expect(resolved.supported, isTrue);
      expect(resolved.url, 'https://www.instagram.com/reel/C8abc123/');
      expect(resolved.sourcePlatform, 'instagram');
    });

    test('an unsupported share is an answer, not an error', () async {
      final service = ApiClient(
        baseUrl: 'https://example.com',
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'supported': false,
              'url': null,
              'source_platform': null,
              'source_content_type': null,
            }),
            200,
          ),
        ),
      );

      final resolved = await service.resolveSharePayload(rawPayloadText: 'hi');

      expect(resolved.supported, isFalse);
      expect(resolved.url, isNull);
    });
  });

  group('map', () {
    Map<String, Object?> pin({
      required String id,
      required String kind,
      String? reelId,
      String? category,
    }) => {
      'id': id,
      'kind': kind,
      'name': 'Artjuna Cafe',
      'address': 'Anjuna',
      'latitude': 15.5834,
      'longitude': 73.7407,
      'reel_id': reelId,
      'confidence': null,
      'category': category,
      'subcategory': null,
      'google_place_id': null,
      'google_maps_url': null,
      'place_types': <String>[],
    };

    test('getMapData sends the viewport and the category', () async {
      final fixture = ApiV2Fixture('map_pins');
      late http.Request seen;
      final service = ApiClient(
        baseUrl: 'https://example.com',
        client: MockClient((request) async {
          seen = request;
          return fixture.toResponse();
        }),
      );

      final map = await service.getMapData(
        bounds: const MapBounds(south: 15, west: 73, north: 16, east: 74),
        category: 'food_and_drink',
      );

      // The fixture's own request is south=15&west=73&north=16&east=74.
      expect(seen.url.path, '/api/v2/map/pins');
      expect(seen.url.queryParameters, {
        'south': '15.0',
        'west': '73.0',
        'north': '16.0',
        'east': '74.0',
        'category': 'food_and_drink',
      });
      expect(
        map.mapItems.single.effectiveMapItemId,
        '66666666-6666-4666-8666-666666666666',
      );
    });

    test('getMapData leaves an empty category out', () async {
      late http.Request seen;
      final service = ApiClient(
        baseUrl: 'https://example.com',
        client: MockClient((request) async {
          seen = request;
          return http.Response(jsonEncode({'pins': []}), 200);
        }),
      );

      await service.getMapData(
        bounds: const MapBounds(south: 15, west: 73, north: 16, east: 74),
        category: ' ',
      );

      expect(seen.url.queryParameters.containsKey('category'), isFalse);
    });

    test('getMapData sends an antimeridian box unchanged', () async {
      late http.Request seen;
      final service = ApiClient(
        baseUrl: 'https://example.com',
        client: MockClient((request) async {
          seen = request;
          return http.Response(jsonEncode({'pins': []}), 200);
        }),
      );

      await service.getMapData(
        bounds: const MapBounds(south: -20, west: 170, north: 20, east: -170),
      );

      expect(seen.url.queryParameters['west'], '170.0');
      expect(seen.url.queryParameters['east'], '-170.0');
    });

    test('getMapData reads both pin kinds with their removal ids', () async {
      final service = ApiClient(
        baseUrl: 'https://example.com',
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'pins': [
                pin(
                  id: 'loc-1',
                  kind: 'content',
                  reelId: 'reel-1',
                  category: 'food_and_drink',
                ),
                pin(id: 'pin-1', kind: 'manual', category: 'Other'),
              ],
            }),
            200,
          ),
        ),
      );

      final map = await service.getMapData(bounds: MapBounds.world);

      final content = map.mapItems.first;
      expect(content.reelId, 'reel-1');
      expect(content.canOpenDetails, isTrue);
      expect(content.effectiveMapItemId, 'loc-1');
      final manual = map.mapItems.last;
      expect(manual.isManual, isTrue);
      expect(manual.canOpenDetails, isFalse);
      // A bare id is read as a location id, so a manual pin needs its prefix.
      expect(manual.effectiveMapItemId, 'manual:pin-1');
    });

    test('getNearbyPins sends the point and the limit', () async {
      late http.Request seen;
      final service = ApiClient(
        baseUrl: 'https://example.com',
        client: MockClient((request) async {
          seen = request;
          return http.Response(
            jsonEncode({
              'pins': [pin(id: 'loc-1', kind: 'content', reelId: 'reel-1')],
            }),
            200,
          );
        }),
      );

      final nearby = await service.getNearbyPins(
        latitude: 15.5,
        longitude: 73.7,
      );

      expect(seen.url.path, '/api/v2/map/nearby');
      expect(seen.url.queryParameters, {
        'latitude': '15.5',
        'longitude': '73.7',
        'limit': '5',
      });
      expect(nearby.mapItems.single.effectiveMapItemId, 'loc-1');
    });

    test('searchMapPlaces sends auth header and search params', () async {
      final service = ApiClient(
        baseUrl: 'https://example.com',
        accessTokenProvider: () => 'token-123',
        client: MockClient((request) async {
          expect(request.headers['Authorization'], 'Bearer token-123');
          expect(request.url.path, '/api/v2/map/search');
          expect(request.url.queryParameters, {
            'query': 'coffee',
            'limit': '8',
            'category': 'Food',
            'session_token': 'session-1',
          });
          return http.Response(
            jsonEncode({
              'query': 'coffee',
              'search_mode': 'mixed',
              'total': 2,
              'results': [
                {
                  'result_type': 'existing',
                  'source_type': 'manual',
                  'map_item': pin(id: 'pin-1', kind: 'manual'),
                  'google_place_id': null,
                  'display_title': 'Artjuna Cafe',
                  'display_address': 'Anjuna',
                  'place_name': 'Artjuna Cafe',
                  'latitude': 15.5834,
                  'longitude': 73.7407,
                  'google_maps_url': null,
                  'place_types': <String>[],
                  'can_pin': false,
                },
                {
                  'result_type': 'google',
                  'source_type': null,
                  'map_item': null,
                  'google_place_id': 'place-1',
                  'display_title': 'Manual Cafe',
                  'display_address': '12 Market Street',
                  'place_name': 'Manual Cafe',
                  'latitude': null,
                  'longitude': null,
                  'google_maps_url': null,
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

      expect(response.total, 2);
      expect(response.results.first.isExisting, isTrue);
      expect(
        response.results.first.mapItem?.effectiveMapItemId,
        'manual:pin-1',
      );
      expect(response.results.last.googlePlaceId, 'place-1');
      expect(response.results.last.canPin, isTrue);
    });

    test('pinMapPlace posts the place id and reads the new pin', () async {
      final service = ApiClient(
        baseUrl: 'https://example.com',
        accessTokenProvider: () => 'token-123',
        client: MockClient((request) async {
          expect(request.headers['Authorization'], 'Bearer token-123');
          expect(request.headers['Content-Type'], contains('application/json'));
          expect(request.url.path, '/api/v2/map/pins');
          expect(jsonDecode(request.body), {
            'google_place_id': 'place-1',
            'session_token': 'session-1',
          });
          return http.Response(
            jsonEncode({
              ...pin(id: 'pin-1', kind: 'manual', category: 'Other'),
              'name': 'Manual Cafe',
              'google_place_id': 'place-1',
            }),
            201,
          );
        }),
      );

      final item = await service.pinMapPlace(
        'place-1',
        sessionToken: 'session-1',
      );

      expect(item, isA<MapItem>());
      expect(item.mapItemId, 'manual:pin-1');
      expect(item.displayName, 'Manual Cafe');
      expect(item.googlePlaceId, 'place-1');
      expect(item.canOpenDetails, isFalse);
    });

    test('pinMapPlace accepts the pin the user already had', () async {
      final service = ApiClient(
        baseUrl: 'https://example.com',
        client: MockClient(
          (_) async =>
              http.Response(jsonEncode(pin(id: 'pin-1', kind: 'manual')), 200),
        ),
      );

      final item = await service.pinMapPlace('place-1');

      expect(item.mapItemId, 'manual:pin-1');
    });

    test('removeMapItem deletes map item by id', () async {
      final service = ApiClient(
        baseUrl: 'https://example.com',
        accessTokenProvider: () => 'token-123',
        client: MockClient((request) async {
          expect(request.headers['Authorization'], 'Bearer token-123');
          expect(request.method, 'DELETE');
          expect(request.url.path, '/api/v2/map/items/manual:pin-1');
          return http.Response('', 204);
        }),
      );

      await service.removeMapItem('manual:pin-1');
    });

    test('removeMapItem hides a content pin by its bare location id', () async {
      late http.Request seen;
      final service = ApiClient(
        baseUrl: 'https://example.com',
        client: MockClient((request) async {
          seen = request;
          return http.Response('', 204);
        }),
      );

      await service.removeMapItem('66666666-6666-4666-8666-666666666666');

      expect(seen.method, 'DELETE');
      expect(
        seen.url.path,
        '/api/v2/map/items/66666666-6666-4666-8666-666666666666',
      );
    });
  });

  group('account', () {
    test('deleteAccount sends auth header', () async {
      final service = ApiClient(
        baseUrl: 'https://example.com',
        accessTokenProvider: () => 'token-123',
        client: MockClient((request) async {
          expect(request.headers['Authorization'], 'Bearer token-123');
          expect(request.url.toString(), 'https://example.com/api/v2/account');
          expect(request.method, 'DELETE');
          return http.Response(
            jsonEncode({
              'data_deleted': true,
              'identity_deleted': false,
              'pending': true,
              'removed': {'saves': 1},
            }),
            200,
          );
        }),
      );

      await service.deleteAccount();
    });

    test('getAccountEntitlements reads the v2 path', () async {
      final service = ApiClient(
        baseUrl: 'https://example.com',
        accessTokenProvider: () => 'token-123',
        client: MockClient((request) async {
          expect(
            request.url.toString(),
            'https://example.com/api/v2/account/entitlements',
          );
          expect(request.headers['Authorization'], 'Bearer token-123');
          return http.Response(
            jsonEncode({
              'user_id': 'user-123',
              'current_entitlement': {
                'plan': 'pro',
                'billing_interval': 'monthly',
                'subscription_status': 'active',
                'is_premium': true,
                'restricted': false,
                'error_message': null,
              },
              'usage': {'saved_reels': 3},
              'limits': {'saved_reels': null},
              'features': {'map': true},
              'pricing': <String, String>{},
              'plan_cards': <Object?>[],
              'paywall_messages': {'account': 'Upgrade'},
              'plan': 'pro',
              'is_premium': true,
            }),
            200,
          );
        }),
      );

      final response = await service.getAccountEntitlements(userId: 'user-123');

      expect(response.currentEntitlement.isPro, isTrue);
      expect(response.usage.savedReels, 3);
    });

    test('getAccountEntitlements still reports failures', () async {
      final service = ApiClient(
        baseUrl: 'https://example.com',
        client: MockClient(
          (_) async => ApiV2Fixture('error_unauthorized').toResponse(),
        ),
      );

      expect(
        () => service.getAccountEntitlements(userId: 'user-123'),
        throwsA(
          isA<ApiException>().having(
            (error) => error.statusCode,
            'statusCode',
            401,
          ),
        ),
      );
    });
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

String _tokenFor(String subject, String version) {
  final header = base64Url.encode(utf8.encode('{}'));
  final payload = base64Url.encode(
    utf8.encode(jsonEncode({'sub': subject, 'version': version})),
  );
  return '$header.$payload.signature';
}
