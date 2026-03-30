import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/reel.dart';
import '../models/search_result.dart';

/// Stateless HTTP API wrapper for the ReelPin backend.
class ApiService {
  final String _baseUrl;
  final http.Client _client;

  ApiService({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = baseUrl ?? ApiConfig.baseUrl;

  // ─── Health Check ───

  Future<bool> healthCheck() async {
    try {
      final res = await _client
          .get(Uri.parse('$_baseUrl/health'))
          .timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ─── Process Reel from URL ───

  Future<Reel> processReel(String url, {String userId = 'default-user'}) async {
    final res = await _client.post(
      Uri.parse('$_baseUrl/process-reel'),
      headers: {'Content-Type': 'application/json; charset=UTF-8'},
      body: jsonEncode({'url': url, 'user_id': userId}),
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
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/process-video'),
    );
    request.fields['user_id'] = userId;
    request.fields['url'] = url;
    request.files.add(
      await http.MultipartFile.fromPath('video', videoFile.path),
    );

    final streamedRes = await request.send();
    final res = await http.Response.fromStream(streamedRes);

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
    final params = <String, String>{
      'user_id': ?userId,
      'category': ?category,
      'limit': limit.toString(),
    };
    final uri = Uri.parse('$_baseUrl/reels').replace(queryParameters: params);
    final res = await _client.get(uri);

    if (res.statusCode != 200) {
      throw ApiException('Failed to load reels', res.statusCode);
    }
    final List<dynamic> data = jsonDecode(res.body) as List<dynamic>;
    return data.map((r) => Reel.fromJson(r as Map<String, dynamic>)).toList();
  }

  // ─── Get Single Reel ───

  Future<Reel> getReel(String reelId) async {
    final res = await _client.get(Uri.parse('$_baseUrl/reels/$reelId'));

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
    final res = await _client.delete(Uri.parse('$_baseUrl/reels/$reelId'));
    if (res.statusCode != 200) {
      throw ApiException('Failed to delete reel', res.statusCode);
    }
  }

  // ─── RAG Search ───

  Future<List<SearchResult>> searchReels(
    String query, {
    String userId = 'default-user',
    String? category,
    int limit = 5,
  }) async {
    final res = await _client.post(
      Uri.parse('$_baseUrl/search'),
      headers: {'Content-Type': 'application/json; charset=UTF-8'},
      body: jsonEncode({
        'query': query,
        'user_id': userId,
        'category': ?category,
        'limit': limit,
      }),
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
