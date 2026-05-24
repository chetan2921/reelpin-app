import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/api_config.dart';
import '../models/processing_job.dart';
import '../models/reel_category_filters.dart';
import '../models/reel.dart';
import '../models/search_response.dart';
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
            .get(Uri.parse('$baseUrl/health'), headers: _headers())
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
            Uri.parse('$baseUrl/process-reel'),
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
            Uri.parse('$baseUrl/processing-jobs/reels'),
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
            Uri.parse('$baseUrl/processing-jobs/$jobId'),
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
          'Processing finished but the reel result is missing.',
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

    switch (job.failureCode) {
      case 'auth_failure':
        return 'The source platform blocked access. Try again after updating backend cookies.';
      case 'rate_limit':
        return 'The source platform rate limited processing. Try again later.';
      case 'no_audio':
        return 'This video does not include an audio track.';
      case 'transcript_unavailable':
        return 'A transcript was not available for this media.';
      case 'unsupported_post_type':
        return 'This shared post type is not supported yet.';
      case 'ocr_failure':
        return 'Image text extraction failed for this post.';
      case 'provider_timeout':
        return 'An upstream provider timed out while processing this reel.';
      case 'request_too_large':
        return 'The media payload was too large to process.';
      default:
        return 'Reel processing failed.';
    }
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
        Uri.parse('$baseUrl/process-video'),
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

  Future<List<Reel>> getReels({
    String? userId,
    String? category,
    int limit = 50,
  }) async {
    final res = await _requestWithFailover((baseUrl) {
      final params = <String, String>{
        'limit': limit.toString(),
        if (category != null && category.trim().isNotEmpty)
          'category': category,
      };
      final uri = Uri.parse('$baseUrl/reels').replace(queryParameters: params);
      return _client.get(uri, headers: _headers()).timeout(_requestTimeout);
    });

    if (res.statusCode != 200) {
      throw _exceptionFromResponse(
        res,
        fallbackMessage: 'Could not load saved reels right now.',
      );
    }
    final List<dynamic> data = jsonDecode(res.body) as List<dynamic>;
    return data.map((r) => Reel.fromJson(r as Map<String, dynamic>)).toList();
  }

  // ─── Get Single Reel ───

  Future<Reel> getReel(String reelId) async {
    final res = await _requestWithFailover(
      (baseUrl) => _client
          .get(Uri.parse('$baseUrl/reels/$reelId'), headers: _headers())
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
          .delete(Uri.parse('$baseUrl/reels/$reelId'), headers: _headers())
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
    required String userId,
  }) async {
    final res = await _requestWithFailover((baseUrl) {
      final uri = Uri.parse('$baseUrl/reels/category-filters');
      return _client.get(uri, headers: _headers()).timeout(_requestTimeout);
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
                  Uri.parse('$baseUrl/search'),
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
                  Uri.parse('$baseUrl/search'),
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

  Future<UserEntitlement> getAccountEntitlements({
    required String userId,
  }) async {
    final res = await _requestWithFailover((baseUrl) {
      final uri = Uri.parse('$baseUrl/account/entitlements');
      return _client.get(uri, headers: _headers()).timeout(_requestTimeout);
    });

    if (res.statusCode != 200) {
      if (res.statusCode == 404) {
        return UserEntitlement.unrestricted(userId: userId);
      }

      throw _exceptionFromResponse(
        res,
        fallbackMessage: 'Could not load account entitlements right now.',
      );
    }

    return UserEntitlement.fromJson(
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
            Uri.parse('$baseUrl/device-push-tokens'),
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
      }
    }

    if (lastNetworkError is TimeoutException) {
      throw ApiException(
        'Request timed out. Please check server/network.',
        408,
      );
    }

    throw ApiException(
      'Cannot connect to server. Tried: ${candidates.join(', ')}',
      503,
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
      throw ApiException(
        'Request timed out. Please check server/network.',
        408,
      );
    }

    if (lastNetworkError is http.ClientException) {
      throw lastNetworkError;
    }

    throw ApiException(
      'Cannot connect to server. Tried: ${candidates.join(', ')}',
      503,
    );
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
