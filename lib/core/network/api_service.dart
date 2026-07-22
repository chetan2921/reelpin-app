import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:reelpin/core/config/api_config.dart';
import 'package:reelpin/core/logging/app_logger.dart';
import 'package:reelpin/core/network/api_exception.dart';
import 'package:reelpin/features/account/data/account_api.dart';
import 'package:reelpin/features/discover/domain/discover_response.dart';
import 'package:reelpin/features/discover/data/discover_api.dart';
import 'package:reelpin/features/folders/data/folders_api.dart';
import 'package:reelpin/features/folders/domain/folder.dart';
import 'package:reelpin/features/reels/data/reels_api.dart';
import 'package:reelpin/features/map/data/map_api.dart';
import 'package:reelpin/features/sharing/data/sharing_api.dart';
import 'package:reelpin/features/account/domain/library_stats.dart';
import 'package:reelpin/features/map/domain/map_place_search_response.dart';
import 'package:reelpin/features/map/domain/map_response.dart';
import 'package:reelpin/features/reels/domain/processing_job.dart';
import 'package:reelpin/features/reels/domain/reel_category_filters.dart';
import 'package:reelpin/features/reels/domain/reel.dart';
import 'package:reelpin/features/reels/domain/reel_page.dart';
import 'package:reelpin/features/discover/domain/search_response.dart';
import 'package:reelpin/features/sharing/domain/share_resolve_response.dart';
import 'package:reelpin/features/account/domain/user_entitlement.dart';

/// Stateless HTTP API wrapper for the ReelPin backend.
class ApiService
    implements
        ReelsApi,
        DiscoverApi,
        MapApi,
        FoldersApi,
        AccountApi,
        SharingApi {
  String _baseUrl;
  final List<String> _fallbackBaseUrls;
  final http.Client _client;
  final String? Function() _accessTokenProvider;
  static const Duration _requestTimeout = Duration(seconds: 15);
  static const Duration _backgroundRequestTimeout = Duration(seconds: 5);
  static const Duration _jobPollingTimeout = Duration(minutes: 8);

  ApiService({
    http.Client? client,
    String? baseUrl,
    String? Function()? accessTokenProvider,
  }) : _client = client ?? http.Client(),
       _accessTokenProvider = accessTokenProvider ?? _currentAccessToken,
       _baseUrl = (baseUrl ?? ApiConfig.baseUrl).trim(),
       _fallbackBaseUrls = ApiConfig.fallbackBaseUrls;

  // ─── Health Check ───

  Future<bool> healthCheck() async {
    try {
      final res = await _requestWithFailover(
        (baseUrl) => _client
            .get(_apiUri(baseUrl, '/api/v1/health'), headers: _headers())
            .timeout(const Duration(seconds: 5)),
      );
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ─── Process Reel from URL ───

  @override
  Future<Reel> processReel(
    String url, {
    String userId = 'default-user',
    void Function(ProcessingJob job)? onJobUpdate,
  }) async {
    try {
      final job = await _enqueueReelProcessing(url, userId: userId);
      return _waitForProcessingJob(job.id, onJobUpdate: onJobUpdate);
    } on ApiException catch (e) {
      if (e.statusCode == 404 || e.statusCode == 405) {
        final job = await _startProcessReelJob(url, userId: userId);
        return _waitForProcessingJob(job.id, onJobUpdate: onJobUpdate);
      }
      rethrow;
    }
  }

  @override
  Future<ProcessingJob> enqueueReelProcessing(
    String url, {
    String userId = 'default-user',
  }) async {
    try {
      return await _enqueueReelProcessing(url, userId: userId);
    } on ApiException catch (e) {
      if (e.statusCode == 404 || e.statusCode == 405) {
        return _startProcessReelJob(url, userId: userId);
      }
      rethrow;
    }
  }

  Future<ProcessingJob> _startProcessReelJob(
    String url, {
    String userId = 'default-user',
  }) async {
    final res = await _requestWithFailover(
      (baseUrl) => _client
          .post(
            _apiUri(baseUrl, '/api/v1/process-reel'),
            headers: _headers(json: true),
            body: jsonEncode({'url': url}),
          )
          .timeout(_requestTimeout),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw _exceptionFromResponse(
        res,
        fallbackMessage: 'Could not save this reel right now.',
      );
    }
    return ProcessingJob.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<ProcessingJob> _enqueueReelProcessing(
    String url, {
    String userId = 'default-user',
  }) async {
    final res = await _requestWithFailover(
      (baseUrl) => _client
          .post(
            _apiUri(baseUrl, '/api/v1/processing-jobs/reels'),
            headers: _headers(json: true),
            body: jsonEncode({'url': url}),
          )
          .timeout(_requestTimeout),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw _exceptionFromResponse(
        res,
        fallbackMessage: 'Could not queue this reel right now.',
      );
    }

    return ProcessingJob.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<ProcessingJob> _getProcessingJob(String jobId) async {
    final res = await _requestWithFailover(
      (baseUrl) => _client
          .get(
            _apiUri(baseUrl, '/api/v1/processing-jobs/$jobId'),
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
    void Function(ProcessingJob job)? onJobUpdate,
  }) async {
    final normalizedJobId = jobId.trim();
    if (normalizedJobId.isEmpty) {
      throw const ApiException(
        'Processing started but the job id is missing.',
        500,
      );
    }

    final startedAt = DateTime.now();
    var attempt = 0;

    while (DateTime.now().difference(startedAt) < _jobPollingTimeout) {
      final job = await _getProcessingJob(normalizedJobId);
      onJobUpdate?.call(job);

      if (job.isCompleted) {
        if (job.reel != null) {
          return job.reel!;
        }

        final reelId = job.resultReelId;
        if (reelId != null && reelId.isNotEmpty) {
          return getReel(reelId);
        }

        throw const ApiException(
          'Could not finish saving this reel. Please try again.',
          500,
        );
      }

      if (job.isTerminalFailure) {
        throw ApiException(_jobFailureMessage(job), 500);
      }

      await Future.delayed(_jobPollingDelay(attempt, job));
      attempt += 1;
    }

    throw const ApiException(
      'Processing is taking longer than expected. Please check again in a minute.',
      504,
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

    final message = job.errorMessage?.trim();
    if (message != null && message.isNotEmpty) {
      return message;
    }

    return 'Reel processing failed.';
  }

  // ─── Process Video File ───

  @override
  Future<Reel> processVideo(
    File videoFile, {
    String userId = 'default-user',
    String url = '',
  }) async {
    final res = await _requestWithFailover((baseUrl) async {
      final request = http.MultipartRequest(
        'POST',
        _apiUri(baseUrl, '/api/v1/process-video'),
      );
      request.headers.addAll(_headers());
      request.fields['url'] = url;
      request.files.add(
        await http.MultipartFile.fromPath('video', videoFile.path),
      );

      final streamedRes = await request.send().timeout(_requestTimeout);
      return http.Response.fromStream(streamedRes);
    });

    if (res.statusCode != 200) {
      throw _exceptionFromResponse(
        res,
        fallbackMessage: 'Could not process this video right now.',
      );
    }
    return Reel.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  // ─── List Saved Reels ───

  @override
  Future<ReelPage> getReelsPage({
    String? userId,
    String? category,
    String? subcategory,
    String? savedDate,
    int? offset,
    String? cursor,
    int limit = 50,
    String? sort,
  }) async {
    final res = await _requestWithFailover((baseUrl) {
      final params = <String, String>{
        'limit': limit.toString(),
        if (category != null && category.trim().isNotEmpty)
          'category': category,
        if (subcategory != null && subcategory.trim().isNotEmpty)
          'subcategory': subcategory,
        if (savedDate != null && savedDate.trim().isNotEmpty)
          'saved_date': savedDate,
        if (offset != null) 'offset': offset.toString(),
        if (cursor != null && cursor.trim().isNotEmpty) 'cursor': cursor,
        if (sort != null && sort.trim().isNotEmpty) 'sort': sort,
      };
      return _client
          .get(
            _apiUri(baseUrl, '/api/v1/reels', queryParameters: params),
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
    return ReelPage.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  @override
  Future<List<Reel>> getReels({
    String? userId,
    String? category,
    String? subcategory,
    String? savedDate,
    int limit = 50,
  }) async {
    final page = await getReelsPage(
      userId: userId,
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
    final res = await _requestWithFailover(
      (baseUrl) => _client
          .get(_apiUri(baseUrl, '/api/v1/reels/$reelId'), headers: _headers())
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
    final res = await _requestWithFailover(
      (baseUrl) => _client
          .delete(
            _apiUri(baseUrl, '/api/v1/reels/$reelId'),
            headers: _headers(),
          )
          .timeout(_requestTimeout),
    );
    if (res.statusCode != 200) {
      throw _exceptionFromResponse(
        res,
        fallbackMessage: 'Could not delete this reel right now.',
      );
    }
  }

  // ─── Folders ───

  @override
  Future<List<FolderSummary>> getFolders() async {
    final res = await _requestWithFailover(
      (baseUrl) => _client
          .get(_apiUri(baseUrl, '/api/v1/folders'), headers: _headers())
          .timeout(_requestTimeout),
    );

    if (res.statusCode != 200) {
      throw _exceptionFromResponse(
        res,
        fallbackMessage: 'Could not load folders right now.',
      );
    }

    final decoded = jsonDecode(res.body);
    final folders = decoded is List
        ? decoded
        : decoded is Map<String, dynamic>
        ? decoded['folders']
        : null;
    if (folders is! List) return const [];
    return folders
        .whereType<Map>()
        .map((item) => FolderSummary.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }

  @override
  Future<FolderDetailResponse> getFolderDetail(
    String folderId, {
    int limit = 25,
    int? offset,
    String? cursor,
  }) async {
    final res = await _requestWithFailover((baseUrl) {
      final params = <String, String>{
        'limit': limit.toString(),
        if (offset != null) 'offset': offset.toString(),
        if (cursor != null && cursor.trim().isNotEmpty) 'cursor': cursor,
      };
      return _client
          .get(
            _apiUri(
              baseUrl,
              '/api/v1/folders/$folderId',
              queryParameters: params,
            ),
            headers: _headers(),
          )
          .timeout(_requestTimeout);
    });

    if (res.statusCode != 200) {
      throw _exceptionFromResponse(
        res,
        fallbackMessage: 'Could not load this folder right now.',
      );
    }

    return FolderDetailResponse.fromJson(
      jsonDecode(res.body) as Map<String, dynamic>,
    );
  }

  @override
  Future<FolderSummary> updateFolder({
    required String folderId,
    required String name,
    required String note,
  }) async {
    final res = await _requestWithFailover(
      (baseUrl) => _client
          .patch(
            _apiUri(baseUrl, '/api/v1/folders/$folderId'),
            headers: _headers(json: true),
            body: jsonEncode({'name': name, 'note': note}),
          )
          .timeout(_requestTimeout),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw _exceptionFromResponse(
        res,
        fallbackMessage: 'Could not update this folder right now.',
      );
    }

    final decoded = jsonDecode(res.body);
    final folder = decoded is Map<String, dynamic> ? decoded['folder'] : null;
    return FolderSummary.fromJson(
      folder is Map<String, dynamic> ? folder : decoded as Map<String, dynamic>,
    );
  }

  @override
  Future<void> deleteFolder(String folderId) async {
    final res = await _requestWithFailover(
      (baseUrl) => _client
          .delete(
            _apiUri(baseUrl, '/api/v1/folders/$folderId'),
            headers: _headers(),
          )
          .timeout(_requestTimeout),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw _exceptionFromResponse(
        res,
        fallbackMessage: 'Could not delete this folder right now.',
      );
    }
  }

  @override
  Future<void> addReelsToFolder({
    required String folderId,
    required List<String> reelIds,
    bool moveExisting = false,
  }) async {
    final res = await _requestWithFailover(
      (baseUrl) => _client
          .post(
            _apiUri(baseUrl, '/api/v1/folders/$folderId/reels'),
            headers: _headers(json: true),
            body: jsonEncode({
              'reel_ids': reelIds,
              'move_existing': moveExisting,
            }),
          )
          .timeout(_requestTimeout),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw _exceptionFromResponse(
        res,
        fallbackMessage: 'Could not add reels to this folder right now.',
      );
    }
  }

  @override
  Future<void> removeReelFromFolder({
    required String folderId,
    required String reelId,
  }) async {
    final res = await _requestWithFailover(
      (baseUrl) => _client
          .delete(
            _apiUri(baseUrl, '/api/v1/folders/$folderId/reels/$reelId'),
            headers: _headers(),
          )
          .timeout(_requestTimeout),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw _exceptionFromResponse(
        res,
        fallbackMessage: 'Could not remove this reel from the folder.',
      );
    }
  }

  // ─── RAG Search ───

  @override
  Future<ReelCategoryFiltersResponse> getReelCategoryFilters({
    String? userId,
    String? category,
    String? subcategory,
  }) async {
    final res = await _requestWithFailover((baseUrl) {
      final params = <String, String>{
        if (category != null && category.trim().isNotEmpty)
          'category': category,
        if (subcategory != null && subcategory.trim().isNotEmpty)
          'subcategory': subcategory,
      };
      return _client
          .get(
            _apiUri(
              baseUrl,
              '/api/v1/reels/category-filters',
              queryParameters: params,
            ),
            headers: _headers(),
          )
          .timeout(_requestTimeout);
    });

    if (res.statusCode != 200) {
      throw _exceptionFromResponse(
        res,
        fallbackMessage: 'Could not load category filters right now.',
      );
    }

    return ReelCategoryFiltersResponse.fromJson(
      jsonDecode(res.body) as Map<String, dynamic>,
    );
  }

  @override
  Future<SearchResponse> searchReels(
    String query, {
    String userId = 'default-user',
    String? category,
    String? subcategory,
    int limit = 5,
    http.Client? client,
  }) async {
    final res = client == null
        ? await _requestWithFailover(
            (baseUrl) => _client
                .post(
                  _apiUri(baseUrl, '/api/v1/search'),
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
        : await _requestWithClientFailover(
            client,
            (baseUrl, activeClient) => activeClient
                .post(
                  _apiUri(baseUrl, '/api/v1/search'),
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
    final res = await _requestWithFailover((baseUrl) {
      return _client
          .get(
            _apiUri(baseUrl, '/api/v1/account/entitlements'),
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

    return EntitlementsResponse.fromJson(
      jsonDecode(res.body) as Map<String, dynamic>,
    );
  }

  @override
  Future<MapResponse> getMapData({String? category}) async {
    final res = await _requestWithFailover((baseUrl) {
      final params = <String, String>{
        if (category != null && category.trim().isNotEmpty)
          'category': category,
      };
      return _client
          .get(
            _apiUri(baseUrl, '/api/v1/map', queryParameters: params),
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

    return MapResponse.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  @override
  Future<MapPlaceSearchResponse> searchMapPlaces(
    String query, {
    String? category,
    String? sessionToken,
    int limit = 8,
  }) async {
    final res = await _requestWithFailover((baseUrl) {
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
            _apiUri(baseUrl, '/api/v1/map/search', queryParameters: params),
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

  @override
  Future<MapItem> pinMapPlace(
    String googlePlaceId, {
    String? sessionToken,
  }) async {
    final res = await _requestWithFailover(
      (baseUrl) => _client
          .post(
            _apiUri(baseUrl, '/api/v1/map/pins'),
            headers: _headers(json: true),
            body: jsonEncode({
              'googlePlaceId': googlePlaceId,
              if (sessionToken != null && sessionToken.trim().isNotEmpty)
                'sessionToken': sessionToken,
            }),
          )
          .timeout(_requestTimeout),
    );

    if (res.statusCode != 200) {
      throw _exceptionFromResponse(
        res,
        fallbackMessage: 'Could not save this map pin right now.',
      );
    }

    return MapItem.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  @override
  Future<void> removeMapItem(String mapItemId) async {
    final res = await _requestWithFailover(
      (baseUrl) => _client
          .delete(
            _apiUri(baseUrl, '/api/v1/map/items/$mapItemId'),
            headers: _headers(),
          )
          .timeout(_requestTimeout),
    );

    if (res.statusCode != 200) {
      throw _exceptionFromResponse(
        res,
        fallbackMessage: 'Could not remove this map pin right now.',
      );
    }
  }

  @override
  Future<DiscoverResponse> getDiscover({
    String? savedDate,
    int? offset,
    String? cursor,
    int limit = 25,
  }) async {
    final res = await _requestWithFailover((baseUrl) {
      final params = <String, String>{
        'limit': limit.toString(),
        if (savedDate != null && savedDate.trim().isNotEmpty)
          'saved_date': savedDate,
        if (offset != null) 'offset': offset.toString(),
        if (cursor != null && cursor.trim().isNotEmpty) 'cursor': cursor,
      };
      return _client
          .get(
            _apiUri(baseUrl, '/api/v1/discover', queryParameters: params),
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

    return DiscoverResponse.fromJson(
      jsonDecode(res.body) as Map<String, dynamic>,
    );
  }

  @override
  Future<LibraryStats> getLibraryStats() async {
    final res = await _requestWithFailover(
      (baseUrl) => _client
          .get(
            _apiUri(baseUrl, '/api/v1/account/library-stats'),
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
    final res = await _requestWithFailover(
      (baseUrl) => _client
          .delete(_apiUri(baseUrl, '/api/v1/account'), headers: _headers())
          .timeout(_requestTimeout),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw _exceptionFromResponse(
        res,
        fallbackMessage: 'Could not delete your account right now.',
      );
    }
  }

  @override
  Future<ShareResolveResponse> resolveSharePayload({
    required String rawPayloadText,
    required String platform,
    Map<String, dynamic> metadata = const {},
  }) async {
    final res = await _requestWithFailover(
      (baseUrl) => _client
          .post(
            _apiUri(baseUrl, '/api/v1/share/resolve'),
            headers: _headers(json: true),
            body: jsonEncode({
              'raw_payload_text': rawPayloadText,
              'platform': platform,
              'metadata': metadata,
            }),
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
    final res = await _requestWithFailover(
      (baseUrl) => _client
          .post(
            _apiUri(baseUrl, '/api/v1/device-push-tokens'),
            headers: _headers(json: true),
            body: jsonEncode({
              'token': token,
              'platform': platform,
              'app_version': appVersion,
              'app_build': appBuild,
              'timezone': timezone,
              'locale': locale,
            }),
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
    final res = await _requestWithFailover(
      (baseUrl) => _client
          .delete(
            _apiUri(baseUrl, '/api/v1/device-push-tokens'),
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
    final res = await _requestWithFailover(
      (baseUrl) => _client
          .post(
            _apiUri(baseUrl, '/api/v1/notifications/$notificationId/opened'),
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
    final res = await _requestWithFailover(
      (baseUrl) => _client
          .post(
            _apiUri(baseUrl, '/api/v1/share-tokens'),
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
    return (body['share_token'] ?? '').toString();
  }

  @override
  Future<void> revokeShareToken() async {
    final res = await _requestWithFailover(
      (baseUrl) => _client
          .delete(_apiUri(baseUrl, '/api/v1/share-tokens'), headers: _headers())
          .timeout(_requestTimeout),
    );
    if (res.statusCode != 200) {
      throw _exceptionFromResponse(
        res,
        fallbackMessage: 'Could not revoke share access right now.',
      );
    }
  }

  Future<http.Response> _requestWithFailover(
    Future<http.Response> Function(String baseUrl) request,
  ) async {
    final candidates = <String>[
      _baseUrl,
      ..._fallbackBaseUrls.where((u) => u != _baseUrl),
    ];

    Object? lastNetworkError;
    for (final candidate in candidates) {
      try {
        final response = await request(candidate);
        _baseUrl = candidate;
        return response;
      } on TimeoutException catch (e) {
        lastNetworkError = e;
        _logNetworkError(candidate, e);
      } on SocketException catch (e) {
        lastNetworkError = e;
        _logNetworkError(candidate, e);
      } on http.ClientException catch (e) {
        lastNetworkError = e;
        _logNetworkError(candidate, e);
      }
    }

    if (lastNetworkError is TimeoutException) {
      throw ApiException(_networkErrorMessage(lastNetworkError), 408);
    }

    throw ApiException(_networkErrorMessage(lastNetworkError), 503);
  }

  Uri _apiUri(
    String baseUrl,
    String path, {
    Map<String, String>? queryParameters,
  }) {
    final base = baseUrl.trim().replaceFirst(RegExp(r'/$'), '');
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    final effectivePath =
        base.endsWith('/api/v1') && normalizedPath.startsWith('/api/v1/')
        ? normalizedPath.substring('/api/v1'.length)
        : normalizedPath;
    return Uri.parse('$base$effectivePath').replace(
      queryParameters: queryParameters == null || queryParameters.isEmpty
          ? null
          : queryParameters,
    );
  }

  Future<http.Response> _requestWithClientFailover(
    http.Client client,
    Future<http.Response> Function(String baseUrl, http.Client client) request,
  ) async {
    final candidates = <String>[
      _baseUrl,
      ..._fallbackBaseUrls.where((u) => u != _baseUrl),
    ];

    Object? lastNetworkError;
    for (final candidate in candidates) {
      try {
        final response = await request(candidate, client);
        _baseUrl = candidate;
        return response;
      } on TimeoutException catch (e) {
        lastNetworkError = e;
        _logNetworkError(candidate, e);
      } on SocketException catch (e) {
        lastNetworkError = e;
        _logNetworkError(candidate, e);
      } on http.ClientException catch (e) {
        lastNetworkError = e;
        _logNetworkError(candidate, e);
      }
    }

    if (lastNetworkError is TimeoutException) {
      throw ApiException(_networkErrorMessage(lastNetworkError), 408);
    }

    throw ApiException(_networkErrorMessage(lastNetworkError), 503);
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

  static String? _currentAccessToken() {
    try {
      return Supabase.instance.client.auth.currentSession?.accessToken;
    } catch (_) {
      return null;
    }
  }

  ApiException _exceptionFromResponse(
    http.Response res, {
    required String fallbackMessage,
  }) {
    final payload = _extractErrorPayload(res);
    return ApiException(
      payload.message ?? fallbackMessage,
      res.statusCode,
      errorCode: payload.errorCode,
      detail: payload.detail,
      retryable: payload.retryable,
    );
  }

  _ApiErrorPayload _extractErrorPayload(http.Response res) {
    try {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      return _ApiErrorPayload(
        message: body['message']?.toString(),
        detail: body['detail']?.toString(),
        errorCode: body['error_code']?.toString(),
        retryable: body['retryable'] == true,
      );
    } catch (_) {
      return _ApiErrorPayload(message: 'Request failed (${res.statusCode})');
    }
  }
}

class _ApiErrorPayload {
  const _ApiErrorPayload({
    this.message,
    this.detail,
    this.errorCode,
    this.retryable = false,
  });

  final String? message;
  final String? detail;
  final String? errorCode;
  final bool retryable;
}
