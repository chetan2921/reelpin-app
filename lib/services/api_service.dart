import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/reel.dart';
import '../models/search_result.dart';

/// Stateless HTTP API wrapper for the ReelPin backend.
class ApiService {
  String _baseUrl;
  final List<String> _fallbackBaseUrls;
  final http.Client _client;
  static const Duration _requestTimeout = Duration(seconds: 15);

  ApiService({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = (baseUrl ?? ApiConfig.baseUrl).trim(),
      _fallbackBaseUrls = ApiConfig.fallbackBaseUrls;

  // ─── Health Check ───

  Future<bool> healthCheck() async {
    try {
      final res = await _requestWithFailover(
        (baseUrl) => _client
            .get(Uri.parse('$baseUrl/health'))
            .timeout(const Duration(seconds: 5)),
      );
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ─── Process Reel from URL ───

  Future<Reel> processReel(String url, {String userId = 'default-user'}) async {
    final res = await _requestWithFailover(
      (baseUrl) => _client
          .post(
            Uri.parse('$baseUrl/process-reel'),
            headers: {'Content-Type': 'application/json; charset=UTF-8'},
            body: jsonEncode({'url': url, 'user_id': userId}),
          )
          .timeout(_requestTimeout),
    );

    if (res.statusCode != 200) {
      final detail = _extractError(res);
      throw ApiException(detail, res.statusCode);
    }
    return Reel.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
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
      request.fields['user_id'] = userId;
      request.fields['url'] = url;
      request.files.add(
        await http.MultipartFile.fromPath('video', videoFile.path),
      );

      final streamedRes = await request.send().timeout(_requestTimeout);
      return http.Response.fromStream(streamedRes);
    });

    if (res.statusCode != 200) {
      final detail = _extractError(res);
      throw ApiException(detail, res.statusCode);
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
        if (userId != null && userId.trim().isNotEmpty) 'user_id': userId,
        if (category != null && category.trim().isNotEmpty) 'category': category,
      };
      final uri = Uri.parse('$baseUrl/reels').replace(queryParameters: params);
      return _client.get(uri).timeout(_requestTimeout);
    });

    if (res.statusCode != 200) {
      throw ApiException('Failed to load reels', res.statusCode);
    }
    final List<dynamic> data = jsonDecode(res.body) as List<dynamic>;
    return data.map((r) => Reel.fromJson(r as Map<String, dynamic>)).toList();
  }

  // ─── Get Single Reel ───

  Future<Reel> getReel(String reelId) async {
    final res = await _requestWithFailover(
      (baseUrl) => _client
          .get(Uri.parse('$baseUrl/reels/$reelId'))
          .timeout(_requestTimeout),
    );

    if (res.statusCode == 404) {
      throw ApiException('Reel not found', 404);
    }
    if (res.statusCode != 200) {
      throw ApiException('Failed to load reel', res.statusCode);
    }
    return Reel.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  // ─── Delete Reel ───

  Future<void> deleteReel(String reelId) async {
    final res = await _requestWithFailover(
      (baseUrl) => _client
          .delete(Uri.parse('$baseUrl/reels/$reelId'))
          .timeout(_requestTimeout),
    );
    if (res.statusCode != 200) {
      throw ApiException('Failed to delete reel', res.statusCode);
    }
  }

  // ─── RAG Search ───

  Future<List<SearchResult>> searchReels(
    String query, {
    String userId = 'default-user',
    String? category,
    String? subcategory,
    int limit = 5,
  }) async {
    final res = await _requestWithFailover(
      (baseUrl) => _client
          .post(
            Uri.parse('$baseUrl/search'),
            headers: {'Content-Type': 'application/json; charset=UTF-8'},
            body: jsonEncode({
              'query': query,
              'user_id': userId,
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
      throw ApiException('Search failed', res.statusCode);
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return (data['results'] as List<dynamic>)
        .map((r) => SearchResult.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  // ─── Helpers ───

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

  String _extractError(http.Response res) {
    try {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      return body['detail'] as String? ?? 'Request failed';
    } catch (_) {
      return 'Request failed (${res.statusCode})';
    }
  }
}

/// Custom exception for API errors with status code.
class ApiException implements Exception {
  final String message;
  final int statusCode;

  const ApiException(this.message, this.statusCode);

  @override
  String toString() => message;
}
