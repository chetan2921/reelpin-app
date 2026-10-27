import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:reelpin/services/cache/content_cache.dart';
import 'package:reelpin/env.dart';
import 'package:reelpin/utils/app_logger.dart';
import 'package:reelpin/http/api_exception.dart';
import 'package:reelpin/http/account_http.dart';
import 'package:reelpin/data_models/discover/discover_response.dart';
import 'package:reelpin/http/discover_http.dart';
import 'package:reelpin/http/reels_http.dart';
import 'package:reelpin/http/map_http.dart';
import 'package:reelpin/http/sharing_http.dart';
import 'package:reelpin/data_models/account/library_stats.dart';
import 'package:reelpin/data_models/map/map_bounds.dart';
import 'package:reelpin/data_models/map/map_place_search_response.dart';
import 'package:reelpin/data_models/map/map_response.dart';
import 'package:reelpin/data_models/reels/processing_job.dart';
import 'package:reelpin/data_models/reels/reel_filters.dart';
import 'package:reelpin/data_models/reels/reel.dart';
import 'package:reelpin/data_models/reels/reel_page.dart';
import 'package:reelpin/data_models/discover/search_response.dart';
import 'package:reelpin/data_models/sharing/share_resolve_response.dart';
import 'package:reelpin/data_models/account/user_entitlement.dart';
import 'package:reelpin/http/collections_http.dart';
import 'package:reelpin/data_models/collections/collection_models.dart';

/// Stateless HTTP API wrapper for the ReelPin backend.
class ApiClient
    implements
        ReelsHttp,
        DiscoverHttp,
        MapHttp,
        CollectionsHttp,
        AccountHttp,
        SharingHttp {
  final String _baseUrl;
  final http.Client _client;
  final ContentCache _cache;
  final String? Function() _accessTokenProvider;
  final Future<void> Function() _sessionRefresher;
  static const Duration _requestTimeout = Duration(seconds: 15);
  static const Duration _backgroundRequestTimeout = Duration(seconds: 5);
  static const Duration _jobPollingTimeout = Duration(minutes: 8);

  /// The API rejects a page size outside this range rather than capping it.
  static const int _maxPageSize = 100;
  static final Random _random = Random.secure();

  ApiClient({
    http.Client? client,
    ContentCache? cache,
    String? baseUrl,
    String? Function()? accessTokenProvider,
    Future<void> Function()? sessionRefresher,
  }) : _client = client ?? http.Client(),
       _cache = cache ?? ContentCache.instance,
       _accessTokenProvider = accessTokenProvider ?? _currentAccessToken,
       _sessionRefresher = sessionRefresher ?? _refreshCurrentSession,
       _baseUrl = (baseUrl ?? ApiConfig.baseUrl).trim();

  // ─── Process Reel from URL ───

  @override
  Future<Reel> processReel(
    String url, {
    String userId = 'default-user',
    void Function(ProcessingJob job)? onJobUpdate,
  }) async {
    final job = await _submitReel(url);
    return _waitForProcessingJob(
      job.id,
      initialJob: job,
      onJobUpdate: onJobUpdate,
    );
  }

  @override
  Future<ProcessingJob> enqueueReelProcessing(
    String url, {
    String userId = 'default-user',
    List<String> collectionIds = const [],
  }) {
    return _submitReel(url, collectionIds: collectionIds);
  }

  Future<ProcessingJob> _submitReel(
    String url, {
    List<String> collectionIds = const [],
  }) async {
    // One key per submission attempt. The session renewal in _sendRequest
    // resends the same attempt, so it has to carry the same key.
    final idempotencyKey = _newIdempotencyKey();
    final res = await _sendRequest(
      (baseUrl) => _client
          .post(
            _apiUri(baseUrl, '/api/v2/processing-jobs/reels'),
            headers: {
              ..._headers(json: true),
              'Idempotency-Key': idempotencyKey,
            },
            // Same field the native share extensions post, so a share that
            // falls back to the app files itself the same way.
            body: jsonEncode({
              'url': url,
              if (collectionIds.isNotEmpty) 'collection_ids': collectionIds,
            }),
          )
          .timeout(_requestTimeout),
    );

    if (res.statusCode == 200) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final reel = Reel.fromJson(body);
      // The reel is ready and there is no job to poll, so it is handed on as
      // a job that has already completed.
      return ProcessingJob(
        id: '',
        status: 'completed',
        terminal: true,
        resultReelId: reel.id,
        reel: reel,
        alreadySaved: body['already_saved'] == true,
      );
    }
    if (res.statusCode != 202) {
      throw _exceptionFromResponse(
        res,
        fallbackMessage: 'Could not queue this reel right now.',
      );
    }

    return ProcessingJob.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  @override
  Future<List<ProcessingJob>> listProcessingJobs({
    bool activeOnly = true,
    int limit = 20,
  }) async {
    final res = await _sendRequest(
      (baseUrl) => _client
          .get(
            _apiUri(
              baseUrl,
              '/api/v2/processing-jobs',
              queryParameters: {
                'active_only': activeOnly.toString(),
                'limit': limit.toString(),
              },
            ),
            headers: _headers(),
          )
          .timeout(_requestTimeout),
    );

    if (res.statusCode != 200) {
      throw _exceptionFromResponse(
        res,
        fallbackMessage: 'Could not load the processing status right now.',
      );
    }

    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    return (decoded['jobs'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(ProcessingJob.fromJson)
        .toList(growable: false);
  }

  Future<ProcessingJob> _getProcessingJob(String jobId) async {
    final res = await _sendRequest(
      (baseUrl) => _client
          .get(
            _apiUri(baseUrl, '/api/v2/processing-jobs/$jobId'),
            headers: _headers(),
          )
          .timeout(_requestTimeout),
    );

    if (res.statusCode != 200) {
      throw _exceptionFromResponse(
        res,
        fallbackMessage: 'Could not load the processing status right now.',
      );
    }

    return ProcessingJob.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<Reel> _waitForProcessingJob(
    String jobId, {
    ProcessingJob? initialJob,
    void Function(ProcessingJob job)? onJobUpdate,
  }) async {
    final normalizedJobId = jobId.trim();
    final startedAt = DateTime.now();
    var attempt = 0;

    if (initialJob != null) {
      onJobUpdate?.call(initialJob);
      final completed = await _completedJobResult(initialJob);
      if (completed != null) return completed;
      _throwIfTerminalFailure(initialJob);

      if (initialJob.recommendedPollAfterSeconds != null ||
          initialJob.isRetryScheduled) {
        await Future.delayed(_jobPollingDelay(attempt, initialJob));
        attempt += 1;
      }
    }

    if (normalizedJobId.isEmpty) {
      throw const ApiException(
        'Processing started but the job id is missing.',
        500,
      );
    }

    while (DateTime.now().difference(startedAt) < _jobPollingTimeout) {
      final job = await _getProcessingJob(normalizedJobId);
      onJobUpdate?.call(job);

      final completed = await _completedJobResult(job);
      if (completed != null) return completed;
      _throwIfTerminalFailure(job);

      final delay = _jobPollingDelay(attempt, job);
      attempt += 1;
      await Future.delayed(delay);
    }

    throw const ApiException(
      'Processing is taking longer than expected. Please check again in a minute.',
      504,
    );
  }

  Future<Reel?> _completedJobResult(ProcessingJob job) async {
    if (!job.isCompleted) return null;
    if (job.reel != null) return job.reel;

    final reelId = job.resultReelId?.trim();
    if (reelId != null && reelId.isNotEmpty) {
      return getReel(reelId);
    }

    throw const ApiException(
      'Could not finish saving this post. Please try again.',
      500,
    );
  }

  void _throwIfTerminalFailure(ProcessingJob job) {
    if (!job.isTerminalFailure) return;
    throw ApiException(
      _jobFailureMessage(job),
      500,
      errorCode: job.failureCode,
      retryable: job.retryable,
    );
  }

  Duration _jobPollingDelay(int attempt, ProcessingJob job) {
    Duration baseDelay;
    if (attempt < 3) {
      baseDelay = const Duration(seconds: 2);
    } else if (attempt < 8) {
      baseDelay = const Duration(seconds: 3);
    } else {
      baseDelay = const Duration(seconds: 5);
    }

    if (!job.isRetryScheduled || job.nextRetryAt == null) {
      if (job.recommendedPollAfterSeconds != null &&
          job.recommendedPollAfterSeconds! > 0) {
        return Duration(seconds: job.recommendedPollAfterSeconds!);
      }
      return baseDelay;
    }

    final waitUntilRetry = job.nextRetryAt!.difference(DateTime.now());
    if (waitUntilRetry <= Duration.zero) {
      return baseDelay;
    }

    if (waitUntilRetry > const Duration(seconds: 30)) {
      return const Duration(seconds: 30);
    }

    return waitUntilRetry;
  }

  String _jobFailureMessage(ProcessingJob job) {
    final statusMessage = job.statusMessage?.trim();
    if (statusMessage != null && statusMessage.isNotEmpty) {
      return statusMessage;
    }

    // Codes named for X stay worded for X; the shared ones are reached by every
    // platform we ingest from, so they stay platform-neutral.
    final fallback = switch (job.failureCode?.trim().toLowerCase()) {
      'invalid_url' => 'This shared link is not valid.',
      'unsupported_x_url' =>
        'ReelPin can only save public X post links from X or Twitter.',
      'external_tco_destination' =>
        'This t.co link does not lead to a supported X post.',
      'post_not_found' => 'This post could not be found. It may be deleted.',
      'protected_or_unavailable' => 'This post is private or unavailable.',
      'malformed_oembed_response' => 'X returned an unreadable post response.',
      'post_id_mismatch' =>
        'The X post redirect did not match the shared post.',
      'empty_post_content' => 'This post does not contain readable text.',
      'x_oembed_timeout' => 'X took too long to return this post.',
      'x_oembed_upstream_error' => 'X could not return this post right now.',
      'unsafe_redirect' => 'This link redirected to an unsafe destination.',
      'auth_failure' =>
        'ReelPin could not reach this post. Please try again later.',
      'provider_timeout' => 'The source app took too long to answer.',
      'rate_limit' =>
        'The source app is rate limiting requests. Please try again later.',
      'internal_error' => 'ReelPin could not save this post right now.',
      _ => null,
    };
    if (fallback != null) return fallback;

    final message = job.errorMessage?.trim();
    return message == null || message.isEmpty
        ? 'Post processing failed.'
        : message;
  }

  // ─── List Saved Reels ───

  @override
  Future<ReelPage> getReelsPage({
    String? userId,
    String? platform,
    String? category,
    String? subcategory,
    String? savedDate,
    String? cursor,
    int limit = 50,
  }) async {
    final res = await _sendRequest((baseUrl) {
      final params = <String, String>{
        'limit': _pageLimit(limit),
        'view': 'concise',
        if (platform != null && platform.trim().isNotEmpty)
          'platform': platform,
        if (category != null && category.trim().isNotEmpty)
          'category': category,
        if (subcategory != null && subcategory.trim().isNotEmpty)
          'subcategory': subcategory,
        if (savedDate != null && savedDate.trim().isNotEmpty)
          'saved_date': savedDate,
        if (cursor != null && cursor.trim().isNotEmpty) 'cursor': cursor,
      };
      return _client
          .get(
            _apiUri(baseUrl, '/api/v2/reels', queryParameters: params),
            headers: _headers(),
          )
          .timeout(_requestTimeout);
    });

    if (res.statusCode != 200) {
      throw _exceptionFromResponse(
        res,
        fallbackMessage: 'Could not load saved reels right now.',
      );
    }
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    final isUnfilteredFirstPage =
        _isBlank(platform) &&
        _isBlank(category) &&
        _isBlank(subcategory) &&
        _isBlank(savedDate) &&
        _isBlank(cursor);
    if (isUnfilteredFirstPage) {
      unawaited(
        _cache.write(ContentCacheKeys.reelsFirstPage, decoded),
      );
    }
    return ReelPage.fromJson(decoded);
  }

  @override
  Future<List<Reel>> getReels({
    String? userId,
    String? platform,
    String? category,
    String? subcategory,
    String? savedDate,
    int limit = 50,
  }) async {
    final page = await getReelsPage(
      userId: userId,
      platform: platform,
      category: category,
      subcategory: subcategory,
      savedDate: savedDate,
      limit: limit,
    );
    return page.reels;
  }

  // ─── Get Single Reel ───

  @override
  Future<Reel> getReel(String reelId) async {
    final res = await _sendRequest(
      (baseUrl) => _client
          .get(_apiUri(baseUrl, '/api/v2/reels/$reelId'), headers: _headers())
          .timeout(_requestTimeout),
    );

    if (res.statusCode != 200) {
      throw _exceptionFromResponse(
        res,
        fallbackMessage: res.statusCode == 404
            ? 'Reel not found.'
            : 'Could not load this reel right now.',
      );
    }
    return Reel.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  // ─── Delete Reel ───

  @override
  Future<void> deleteReel(String reelId) async {
    final res = await _sendRequest(
      (baseUrl) => _client
          .delete(
            _apiUri(baseUrl, '/api/v2/reels/$reelId'),
            headers: _headers(),
          )
          .timeout(_requestTimeout),
    );
    if (res.statusCode != 204) {
      throw _exceptionFromResponse(
        res,
        fallbackMessage: 'Could not delete this reel right now.',
      );
    }
  }

  // ─── Collections ───

  @override
  Future<List<CollectionSummary>> getCollections() async {
    final res = await _sendRequest(
      (baseUrl) => _client
          .get(_apiUri(baseUrl, '/api/v2/collections'), headers: _headers())
          .timeout(_requestTimeout),
    );
    if (res.statusCode != 200) {
      throw _exceptionFromResponse(
        res,
        fallbackMessage: 'Could not load collections right now.',
      );
    }
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    return (decoded['collections'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map(
          (item) => CollectionSummary.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList(growable: false);
  }

  @override
  Future<CollectionDetail> getCollectionDetail(
    String collectionId, {
    int limit = 25,
    String? cursor,
  }) async {
    final res = await _sendRequest((baseUrl) {
      final params = <String, String>{
        'limit': _pageLimit(limit),
        if (cursor != null && cursor.trim().isNotEmpty) 'cursor': cursor,
      };
      return _client
          .get(
            _apiUri(
              baseUrl,
              '/api/v2/collections/$collectionId',
              queryParameters: params,
            ),
            headers: _headers(),
          )
          .timeout(_requestTimeout);
    });
    if (res.statusCode != 200) {
      throw _exceptionFromResponse(
        res,
        fallbackMessage: 'Could not load this collection right now.',
      );
    }
    return CollectionDetail.fromJson(
      jsonDecode(res.body) as Map<String, dynamic>,
    );
  }

  @override
  Future<CollectionSummary> createCollection({
    required String name,
    String description = '',
    List<String> reelIds = const [],
  }) async {
    final res = await _sendRequest(
      (baseUrl) => _client
          .post(
            _apiUri(baseUrl, '/api/v2/collections'),
            headers: _headers(json: true),
            body: jsonEncode({
              'name': name,
              'description': description,
              'reel_ids': reelIds,
            }),
          )
          .timeout(_requestTimeout),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw _exceptionFromResponse(
        res,
        fallbackMessage: 'Could not create the collection right now.',
      );
    }
    return _collectionFromMutation(res);
  }

  @override
  Future<CollectionSummary> updateCollection({
    required String collectionId,
    String? name,
    String? description,
    String? coverReelId,
  }) async {
    final res = await _sendRequest(
      (baseUrl) => _client
          .patch(
            _apiUri(baseUrl, '/api/v2/collections/$collectionId'),
            headers: _headers(json: true),
            body: jsonEncode({
              'name': ?name,
              'description': ?description,
              'cover_reel_id': ?coverReelId,
            }),
          )
          .timeout(_requestTimeout),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw _exceptionFromResponse(
        res,
        fallbackMessage: 'Could not update the collection right now.',
      );
    }
    return _collectionFromMutation(res);
  }

  @override
  Future<void> deleteCollection(String collectionId) async {
    final res = await _sendRequest(
      (baseUrl) => _client
          .delete(
            _apiUri(baseUrl, '/api/v2/collections/$collectionId'),
            headers: _headers(),
          )
          .timeout(_requestTimeout),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw _exceptionFromResponse(
        res,
        fallbackMessage: 'Could not delete the collection right now.',
      );
    }
  }

  @override
  Future<int> addReelsToCollection({
    required String collectionId,
    required List<String> reelIds,
  }) async {
    final res = await _sendRequest(
      (baseUrl) => _client
          .post(
            _apiUri(baseUrl, '/api/v2/collections/$collectionId/items'),
            headers: _headers(json: true),
            body: jsonEncode({'reel_ids': reelIds}),
          )
          .timeout(_requestTimeout),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw _exceptionFromResponse(
        res,
        fallbackMessage: 'Could not add reels to this collection right now.',
      );
    }
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    return (decoded['added_count'] as num?)?.toInt() ?? 0;
  }

  @override
  Future<void> removeReelFromCollection({
    required String collectionId,
    required String reelId,
  }) async {
    final res = await _sendRequest(
      (baseUrl) => _client
          .delete(
            _apiUri(baseUrl, '/api/v2/collections/$collectionId/items/$reelId'),
            headers: _headers(),
          )
          .timeout(_requestTimeout),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw _exceptionFromResponse(
        res,
        fallbackMessage: 'Could not remove this reel from the collection.',
      );
    }
  }

  @override
  Future<CollectionLink> enableCollectionLink(String collectionId) async {
    final res = await _sendRequest(
      (baseUrl) => _client
          .post(
            _apiUri(baseUrl, '/api/v2/collections/$collectionId/link'),
            headers: _headers(json: true),
          )
          .timeout(_requestTimeout),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw _exceptionFromResponse(
        res,
        fallbackMessage: 'Could not create a share link right now.',
      );
    }
    return CollectionLink.fromJson(
      jsonDecode(res.body) as Map<String, dynamic>,
    );
  }

  @override
  Future<void> disableCollectionLink(String collectionId) async {
    final res = await _sendRequest(
      (baseUrl) => _client
          .delete(
            _apiUri(baseUrl, '/api/v2/collections/$collectionId/link'),
            headers: _headers(),
          )
          .timeout(_requestTimeout),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw _exceptionFromResponse(
        res,
        fallbackMessage: 'Could not update the share link right now.',
      );
    }
  }

  @override
  Future<CollectionMembers> getCollectionMembers(String collectionId) async {
    final res = await _sendRequest(
      (baseUrl) => _client
          .get(
            _apiUri(baseUrl, '/api/v2/collections/$collectionId/members'),
            headers: _headers(),
          )
          .timeout(_requestTimeout),
    );
    if (res.statusCode != 200) {
      throw _exceptionFromResponse(
        res,
        fallbackMessage: 'Could not load collaborators right now.',
      );
    }
    return CollectionMembers.fromJson(
      jsonDecode(res.body) as Map<String, dynamic>,
    );
  }

  @override
  Future<void> removeCollectionMember({
    required String collectionId,
    required String memberUserId,
  }) async {
    final res = await _sendRequest(
      (baseUrl) => _client
          .delete(
            _apiUri(
              baseUrl,
              '/api/v2/collections/$collectionId/members/$memberUserId',
            ),
            headers: _headers(),
          )
          .timeout(_requestTimeout),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw _exceptionFromResponse(
        res,
        fallbackMessage: 'Could not remove the collaborator right now.',
      );
    }
  }

  @override
  Future<void> leaveCollection(String collectionId) async {
    final res = await _sendRequest(
      (baseUrl) => _client
          .post(
            _apiUri(baseUrl, '/api/v2/collections/$collectionId/leave'),
            headers: _headers(json: true),
          )
          .timeout(_requestTimeout),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw _exceptionFromResponse(
        res,
        fallbackMessage: 'Could not leave the collection right now.',
      );
    }
  }

  @override
  Future<CollectionInvite> createCollectionInvite({
    required String collectionId,
    required String role,
  }) async {
    final res = await _sendRequest(
      (baseUrl) => _client
          .post(
            _apiUri(baseUrl, '/api/v2/collections/$collectionId/invites'),
            headers: _headers(json: true),
            body: jsonEncode({'role': role}),
          )
          .timeout(_requestTimeout),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw _exceptionFromResponse(
        res,
        fallbackMessage: 'Could not create an invite right now.',
      );
    }
    return CollectionInvite.fromJson(
      jsonDecode(res.body) as Map<String, dynamic>,
    );
  }

  @override
  Future<CollectionSummary> acceptCollectionInvite(String token) async {
    final res = await _sendRequest(
      (baseUrl) => _client
          .post(
            _apiUri(baseUrl, '/api/v2/collection-invites/$token/accept'),
            headers: _headers(json: true),
          )
          .timeout(_requestTimeout),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw _exceptionFromResponse(
        res,
        fallbackMessage: 'Could not join this collection right now.',
      );
    }
    return _collectionFromMutation(res);
  }

  @override
  Future<CollectionDetail> getSharedCollection(
    String token, {
    int limit = 25,
    String? cursor,
  }) async {
    final res = await _sendRequest((baseUrl) {
      final params = <String, String>{
        'limit': _pageLimit(limit),
        if (cursor != null && cursor.trim().isNotEmpty) 'cursor': cursor,
      };
      return _client
          .get(
            _apiUri(
              baseUrl,
              '/api/v2/shared-collections/$token',
              queryParameters: params,
            ),
            headers: _headers(),
          )
          .timeout(_requestTimeout);
    });
    if (res.statusCode != 200) {
      throw _exceptionFromResponse(
        res,
        fallbackMessage: 'Could not open this shared collection right now.',
      );
    }
    return CollectionDetail.fromJson(
      jsonDecode(res.body) as Map<String, dynamic>,
    );
  }

  CollectionSummary _collectionFromMutation(http.Response res) {
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    return CollectionSummary.fromJson(
      Map<String, dynamic>.from(decoded['collection'] as Map),
    );
  }

  // ─── RAG Search ───

  @override
  Future<ReelFiltersResponse> getReelFilters({
    String? userId,
    String? platform,
    String? category,
    String? subcategory,
  }) async {
    final res = await _sendRequest((baseUrl) {
      final params = <String, String>{
        if (platform != null && platform.trim().isNotEmpty)
          'platform': platform,
        if (category != null && category.trim().isNotEmpty)
          'category': category,
        if (subcategory != null && subcategory.trim().isNotEmpty)
          'subcategory': subcategory,
      };
      return _client
          .get(
            _apiUri(baseUrl, '/api/v2/reels/filters', queryParameters: params),
            headers: _headers(),
          )
          .timeout(_requestTimeout);
    });

    if (res.statusCode != 200) {
      throw _exceptionFromResponse(
        res,
        fallbackMessage: 'Could not load filters right now.',
      );
    }

    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    // Only the unscoped tree is worth restoring on a cold start; a scoped
    // response carries a `selected_preview_count` for a selection the next
    // session will not have.
    if (_isBlank(platform) && _isBlank(category) && _isBlank(subcategory)) {
      unawaited(
        _cache.write(ContentCacheKeys.reelFilters, decoded),
      );
    }
    return ReelFiltersResponse.fromJson(decoded);
  }

  @override
  Future<SearchResponse> searchReels(
    String query, {
    String userId = 'default-user',
    String? category,
    String? subcategory,
    int limit = 5,
    http.Client? client,
    ContentCache? cache,
  }) async {
    final res = client == null
        ? await _sendRequest(
            (baseUrl) => _client
                .post(
                  _apiUri(
                    baseUrl,
                    '/api/v2/search',
                    queryParameters: const {'view': 'concise'},
                  ),
                  headers: _headers(json: true),
                  body: jsonEncode({
                    'query': query,
                    if (category != null && category.trim().isNotEmpty)
                      'category': category,
                    if (subcategory != null && subcategory.trim().isNotEmpty)
                      'subcategory': subcategory,
                    'limit': limit,
                  }),
                )
                .timeout(_requestTimeout),
          )
        : await _sendRequestWithClient(
            client,
            (baseUrl, activeClient) => activeClient
                .post(
                  _apiUri(
                    baseUrl,
                    '/api/v2/search',
                    queryParameters: const {'view': 'concise'},
                  ),
                  headers: _headers(json: true),
                  body: jsonEncode({
                    'query': query,
                    if (category != null && category.trim().isNotEmpty)
                      'category': category,
                    if (subcategory != null && subcategory.trim().isNotEmpty)
                      'subcategory': subcategory,
                    'limit': limit,
                  }),
                )
                .timeout(_requestTimeout),
          );

    if (res.statusCode != 200) {
      throw _exceptionFromResponse(
        res,
        fallbackMessage: 'Search is not available right now.',
      );
    }
    return SearchResponse.fromJson(
      jsonDecode(res.body) as Map<String, dynamic>,
    );
  }

  @override
  Future<EntitlementsResponse> getAccountEntitlements({
    required String userId,
  }) async {
    final res = await _sendRequest((baseUrl) {
      return _client
          .get(
            _apiUri(baseUrl, '/api/v2/account/entitlements'),
            headers: _headers(),
          )
          .timeout(_requestTimeout);
    });

    if (res.statusCode != 200) {
      throw _exceptionFromResponse(
        res,
        fallbackMessage: 'Could not load account entitlements right now.',
      );
    }

    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    unawaited(
      _cache.write(ContentCacheKeys.entitlements, decoded),
    );
    return EntitlementsResponse.fromJson(decoded);
  }

  /// The pins inside [bounds], at most 500. The server matches [category]
  /// exactly, before the cap.
  @override
  Future<MapResponse> getMapData({
    required MapBounds bounds,
    String? category,
  }) async {
    final res = await _sendRequest((baseUrl) {
      final params = <String, String>{
        ...bounds.toQueryParameters(),
        if (category != null && category.trim().isNotEmpty)
          'category': category,
      };
      return _client
          .get(
            _apiUri(baseUrl, '/api/v2/map/pins', queryParameters: params),
            headers: _headers(),
          )
          .timeout(_requestTimeout);
    });

    if (res.statusCode != 200) {
      throw _exceptionFromResponse(
        res,
        fallbackMessage: 'Could not load map data right now.',
      );
    }

    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    if (_isBlank(category)) {
      unawaited(
        _cache.write(ContentCacheKeys.mapOverview, decoded),
      );
    }
    return MapResponse.fromJson(decoded);
  }

  /// Content pins nearest a point, nearest first, within the server's default
  /// 5 km radius. Manual pins are not part of this answer.
  @override
  Future<MapResponse> getNearbyPins({
    required double latitude,
    required double longitude,
    int limit = 5,
  }) async {
    final res = await _sendRequest(
      (baseUrl) => _client
          .get(
            _apiUri(
              baseUrl,
              '/api/v2/map/nearby',
              queryParameters: {
                'latitude': latitude.toString(),
                'longitude': longitude.toString(),
                'limit': limit.toString(),
              },
            ),
            headers: _headers(),
          )
          .timeout(_requestTimeout),
    );

    if (res.statusCode != 200) {
      throw _exceptionFromResponse(
        res,
        fallbackMessage: 'Could not load nearby places right now.',
      );
    }

    return MapResponse.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  @override
  Future<MapPlaceSearchResponse> searchMapPlaces(
    String query, {
    String? category,
    String? sessionToken,
    int limit = 8,
  }) async {
    final res = await _sendRequest((baseUrl) {
      final params = <String, String>{
        'query': query,
        'limit': limit.toString(),
        if (category != null && category.trim().isNotEmpty)
          'category': category,
        if (sessionToken != null && sessionToken.trim().isNotEmpty)
          'session_token': sessionToken,
      };
      return _client
          .get(
            _apiUri(baseUrl, '/api/v2/map/search', queryParameters: params),
            headers: _headers(),
          )
          .timeout(_requestTimeout);
    });

    if (res.statusCode != 200) {
      throw _exceptionFromResponse(
        res,
        fallbackMessage: 'Could not search map places right now.',
      );
    }

    return MapPlaceSearchResponse.fromJson(
      jsonDecode(res.body) as Map<String, dynamic>,
    );
  }

  /// 201 is a new pin; 200 is the pin this user already had for the place.
  @override
  Future<MapItem> pinMapPlace(
    String googlePlaceId, {
    String? sessionToken,
  }) async {
    final res = await _sendRequest(
      (baseUrl) => _client
          .post(
            _apiUri(baseUrl, '/api/v2/map/pins'),
            headers: _headers(json: true),
            body: jsonEncode({
              'google_place_id': googlePlaceId,
              if (sessionToken != null && sessionToken.trim().isNotEmpty)
                'session_token': sessionToken,
            }),
          )
          .timeout(_requestTimeout),
    );

    if (res.statusCode != 200 && res.statusCode != 201) {
      throw _exceptionFromResponse(
        res,
        fallbackMessage: 'Could not save this map pin right now.',
      );
    }

    return MapItem.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// [mapItemId] is a bare location id, `reel:{reel_id}:{index}` or
  /// `manual:{pin_id}`.
  @override
  Future<void> removeMapItem(String mapItemId) async {
    final res = await _sendRequest(
      (baseUrl) => _client
          .delete(
            _apiUri(baseUrl, '/api/v2/map/items/$mapItemId'),
            headers: _headers(),
          )
          .timeout(_requestTimeout),
    );

    if (res.statusCode != 204) {
      throw _exceptionFromResponse(
        res,
        fallbackMessage: 'Could not remove this map pin right now.',
      );
    }
  }

  @override
  Future<DiscoverResponse> getDiscover({
    String? savedDate,
    String? cursor,
    int limit = 25,
  }) async {
    final res = await _sendRequest((baseUrl) {
      final params = <String, String>{
        'limit': _pageLimit(limit),
        if (savedDate != null && savedDate.trim().isNotEmpty)
          'saved_date': savedDate,
        if (cursor != null && cursor.trim().isNotEmpty) 'cursor': cursor,
      };
      return _client
          .get(
            _apiUri(baseUrl, '/api/v2/discover', queryParameters: params),
            headers: _headers(),
          )
          .timeout(_requestTimeout);
    });

    if (res.statusCode != 200) {
      throw _exceptionFromResponse(
        res,
        fallbackMessage: 'Could not load discover data right now.',
      );
    }

    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    if (_isBlank(savedDate) && _isBlank(cursor)) {
      unawaited(
        _cache.write(ContentCacheKeys.discoverOverview, decoded),
      );
    }
    return DiscoverResponse.fromJson(decoded);
  }

  @override
  Future<LibraryStats> getLibraryStats() async {
    final res = await _sendRequest(
      (baseUrl) => _client
          .get(
            _apiUri(baseUrl, '/api/v2/account/library-stats'),
            headers: _headers(),
          )
          .timeout(_requestTimeout),
    );

    if (res.statusCode != 200) {
      throw _exceptionFromResponse(
        res,
        fallbackMessage: 'Could not load library stats right now.',
      );
    }

    return LibraryStats.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  @override
  Future<void> deleteAccount() async {
    final res = await _sendRequest(
      (baseUrl) => _client
          .delete(_apiUri(baseUrl, '/api/v2/account'), headers: _headers())
          .timeout(_requestTimeout),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw _exceptionFromResponse(
        res,
        fallbackMessage: 'Could not delete your account right now.',
      );
    }
  }

  /// An unsupported link is a 200 with `supported: false`, not an error.
  @override
  Future<ShareResolveResponse> resolveSharePayload({
    required String rawPayloadText,
  }) async {
    final res = await _sendRequest(
      (baseUrl) => _client
          .post(
            _apiUri(baseUrl, '/api/v2/share/resolve'),
            headers: _headers(json: true),
            body: jsonEncode({'raw_payload_text': rawPayloadText}),
          )
          .timeout(_requestTimeout),
    );

    if (res.statusCode != 200) {
      throw _exceptionFromResponse(
        res,
        fallbackMessage: 'Could not read this shared reel.',
      );
    }

    return ShareResolveResponse.fromJson(
      jsonDecode(res.body) as Map<String, dynamic>,
    );
  }

  // ─── Helpers ───

  /// Only the token and platform are sent: the API rejects any other field.
  @override
  Future<void> registerPushToken({
    required String userId,
    required String token,
    required String platform,
    required String appVersion,
    required String appBuild,
    required String timezone,
    required String locale,
  }) async {
    final res = await _sendRequest(
      (baseUrl) => _client
          .post(
            _apiUri(baseUrl, '/api/v2/device-push-tokens'),
            headers: _headers(json: true),
            body: jsonEncode({'token': token, 'platform': platform}),
          )
          .timeout(_backgroundRequestTimeout),
    );

    if (res.statusCode != 200) {
      throw _exceptionFromResponse(
        res,
        fallbackMessage: 'Could not register this device right now.',
      );
    }
  }

  @override
  Future<void> unregisterPushToken({required String token}) async {
    final res = await _sendRequest(
      (baseUrl) => _client
          .delete(
            _apiUri(baseUrl, '/api/v2/device-push-tokens'),
            headers: _headers(json: true),
            body: jsonEncode({'token': token}),
          )
          .timeout(_backgroundRequestTimeout),
    );

    if (res.statusCode != 200) {
      throw _exceptionFromResponse(
        res,
        fallbackMessage: 'Could not unregister this device right now.',
      );
    }
  }

  @override
  Future<void> recordNotificationOpened({
    required String notificationId,
  }) async {
    final res = await _sendRequest(
      (baseUrl) => _client
          .post(
            _apiUri(baseUrl, '/api/v2/notifications/$notificationId/opened'),
            headers: _headers(),
          )
          .timeout(_backgroundRequestTimeout),
    );

    if (res.statusCode != 200) {
      throw _exceptionFromResponse(
        res,
        fallbackMessage: 'Could not record this notification open.',
      );
    }
  }

  /// Mint a long-lived device share token (used by the native background share
  /// path so it doesn't depend on the short-lived Supabase session). Uses the
  /// live session for auth.
  @override
  Future<String> mintShareToken() async {
    final res = await _sendRequest(
      (baseUrl) => _client
          .post(
            _apiUri(baseUrl, '/api/v2/share-tokens'),
            headers: _headers(json: true),
          )
          .timeout(_requestTimeout),
    );
    if (res.statusCode != 200) {
      throw _exceptionFromResponse(
        res,
        fallbackMessage: 'Could not set up background sharing right now.',
      );
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['token'] ?? '').toString();
  }

  @override
  Future<void> revokeShareToken() async {
    final res = await _sendRequest(
      (baseUrl) => _client
          .delete(_apiUri(baseUrl, '/api/v2/share-tokens'), headers: _headers())
          .timeout(_requestTimeout),
    );
    if (res.statusCode != 200) {
      throw _exceptionFromResponse(
        res,
        fallbackMessage: 'Could not revoke share access right now.',
      );
    }
  }

  /// Runs [request] against the one configured host, turning transport failures
  /// into an [ApiException] so callers only ever handle one error type.
  Future<http.Response> _sendRequest(
    Future<http.Response> Function(String baseUrl) request,
  ) async {
    try {
      final sentToken = _accessTokenProvider();
      final res = await request(_baseUrl);
      if (res.statusCode != 401 || sentToken == null) return res;
      // At launch the saved access token can be expired, and requests go out
      // before Supabase finishes renewing it. Rejected, the screens that sent
      // them silently stay on stale data — the SAVED grid's failed load meant
      // no collection was warmed. Renew once, unless another request already
      // did, and send it again.
      if (_accessTokenProvider() == sentToken && !await _renewSession()) {
        return res;
      }
      return await request(_baseUrl);
    } on TimeoutException catch (e) {
      _logNetworkError(_baseUrl, e);
      throw ApiException(_networkErrorMessage(e), 408);
    } on SocketException catch (e) {
      _logNetworkError(_baseUrl, e);
      throw ApiException(_networkErrorMessage(e), 503);
    } on http.ClientException catch (e) {
      _logNetworkError(_baseUrl, e);
      throw ApiException(_networkErrorMessage(e), 503);
    }
  }

  Uri _apiUri(
    String baseUrl,
    String path, {
    Map<String, String>? queryParameters,
  }) {
    final base = baseUrl.trim().replaceFirst(RegExp(r'/$'), '');
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    final effectivePath =
        base.endsWith('/api/v2') && normalizedPath.startsWith('/api/v2/')
        ? normalizedPath.substring('/api/v2'.length)
        : normalizedPath;
    return Uri.parse('$base$effectivePath').replace(
      queryParameters: queryParameters == null || queryParameters.isEmpty
          ? null
          : queryParameters,
    );
  }

  /// [_sendRequest] for callers that supply their own short-lived client.
  Future<http.Response> _sendRequestWithClient(
    http.Client client,
    Future<http.Response> Function(String baseUrl, http.Client client) request,
  ) {
    return _sendRequest((baseUrl) => request(baseUrl, client));
  }

  String _networkErrorMessage(Object? error) {
    return 'Could not connect. Please try again.';
  }

  void _logNetworkError(String baseUrl, Object error) {
    if (kDebugMode) {
      AppLogger.error('API network error for $baseUrl: $error');
    }
  }

  Map<String, String> _headers({bool json = false}) {
    final accessToken = _accessTokenProvider()?.trim();
    return {
      if (json) 'Content-Type': 'application/json; charset=UTF-8',
      if (accessToken != null && accessToken.isNotEmpty)
        'Authorization': 'Bearer $accessToken',
    };
  }

  static bool _isBlank(String? value) => value == null || value.trim().isEmpty;

  static String _pageLimit(int limit) =>
      limit.clamp(1, _maxPageSize).toString();

  /// A random (version 4) UUID.
  static String _newIdempotencyKey() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }

  static String? _currentAccessToken() {
    try {
      return Supabase.instance.client.auth.currentSession?.accessToken;
    } catch (_) {
      return null;
    }
  }

  /// False when the session could not be renewed, so the caller surfaces the
  /// original 401 instead of retrying.
  Future<bool> _renewSession() async {
    try {
      await _sessionRefresher();
      return true;
    } catch (e) {
      AppLogger.error('Session renewal after a 401 skipped: $e');
      return false;
    }
  }

  /// Concurrent calls share one refresh inside gotrue, so a burst of 401s at
  /// launch still renews the session only once.
  static Future<void> _refreshCurrentSession() async {
    await Supabase.instance.client.auth.refreshSession();
  }

  /// Every error body is `{error: {code, message, request_id, retryable,
  /// details}}`. Anything else, such as a proxy's HTML page, gets the
  /// caller's message.
  ApiException _exceptionFromResponse(
    http.Response res, {
    required String fallbackMessage,
  }) {
    Map<String, dynamic> error = const {};
    try {
      final body = jsonDecode(res.body);
      if (body is Map && body['error'] is Map) {
        error = Map<String, dynamic>.from(body['error'] as Map);
      }
    } on FormatException {
      // Not JSON; fall through to the caller's message.
    }
    final details = error['details'];
    return ApiException(
      error['message']?.toString() ?? fallbackMessage,
      res.statusCode,
      errorCode: error['code']?.toString(),
      requestId: error['request_id']?.toString(),
      details: details is Map ? Map<String, dynamic>.from(details) : const {},
      retryable: error['retryable'] == true,
    );
  }
}
