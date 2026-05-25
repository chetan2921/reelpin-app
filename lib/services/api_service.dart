import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/api_config.dart';
import '../models/discover_response.dart';
import '../models/library_stats.dart';
import '../models/map_response.dart';
import '../models/processing_job.dart';
import '../models/reel_category_filters.dart';
import '../models/reel.dart';
import '../models/reel_page.dart';
import '../models/search_response.dart';
import '../models/share_resolve_response.dart';
import '../models/user_entitlement.dart';

/// Stateless HTTP API wrapper for the ReelPin backend.
class ApiService {
  String _baseUrl;
  final List<String> _fallbackBaseUrls;
  final http.Client _client;
  final String? Function() _accessTokenProvider;
  static const Duration _requestTimeout = Duration(seconds: 15);
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
            .get(_apiUri(baseUrl, '/health'), headers: _headers())
            .timeout(const Duration(seconds: 5)),
      );
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ─── Process Reel from URL ───

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

  // ─── RAG Search ───

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

  Future<void> registerPushToken({
    required String userId,
    required String token,
    required String platform,
  }) async {
    final res = await _requestWithFailover(
      (baseUrl) => _client
          .post(
            _apiUri(baseUrl, '/api/v1/device-push-tokens'),
            headers: _headers(json: true),
            body: jsonEncode({'token': token, 'platform': platform}),
          )
          .timeout(_requestTimeout),
    );

    if (res.statusCode != 200) {
      throw _exceptionFromResponse(
        res,
        fallbackMessage: 'Could not register this device right now.',
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
      } on SocketException catch (e) {
        lastNetworkError = e;
      } on http.ClientException catch (e) {
        lastNetworkError = e;
      }
    }

    if (lastNetworkError is TimeoutException) {
      throw ApiException('Could not connect. Please try again.', 408);
    }

    throw ApiException('Could not connect. Please try again.', 503);
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
      } on SocketException catch (e) {
        lastNetworkError = e;
      } on http.ClientException catch (e) {
        lastNetworkError = e;
      }
    }

    if (lastNetworkError is TimeoutException) {
      throw ApiException('Could not connect. Please try again.', 408);
    }

    throw ApiException('Could not connect. Please try again.', 503);
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

String userFacingErrorMessage(
  Object error, {
  String fallbackMessage = 'Something went wrong. Please try again.',
}) {
  if (error is ApiException) {
    final message = error.message.trim();
    if (message.isEmpty) {
      return fallbackMessage;
    }
    return _looksTechnicalError(message)
        ? 'Could not connect. Please try again.'
        : message;
  }

  if (error is TimeoutException ||
      error is SocketException ||
      error is http.ClientException) {
    return 'Could not connect. Please try again.';
  }

  return fallbackMessage;
}

bool _looksTechnicalError(String message) {
  final normalized = message.toLowerCase();
  return normalized.contains('exception') ||
      normalized.contains('socket') ||
      normalized.contains('connection closed') ||
      normalized.contains('connection refused') ||
      normalized.contains('failed host lookup') ||
      normalized.contains('http://') ||
      normalized.contains('https://') ||
      normalized.contains('uri=');
}

/// Custom exception for API errors with status code.
class ApiException implements Exception {
  final String message;
  final int statusCode;
  final String? errorCode;
  final String? detail;
  final bool retryable;

  const ApiException(
    this.message,
    this.statusCode, {
    this.errorCode,
    this.detail,
    this.retryable = false,
  });

  bool get isUpgradeRequired => statusCode == 402;
  bool get isMonthlyReelLimitReached =>
      errorCode == 'monthly_reel_limit_reached';
  bool get isHistoryUpgradeRequired => errorCode == 'history_upgrade_required';

  @override
  String toString() => message;
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
