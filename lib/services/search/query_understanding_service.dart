import 'dart:convert';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart';

import 'package:reelpin/data_models/discover/parsed_query.dart';
import 'package:reelpin/data_models/reels/reel_filters.dart';
import 'package:reelpin/utils/app_logger.dart';

/// Turns a search sentence into the parameters `/api/v1/search` accepts.
///
/// Every failure returns null so the caller can send the raw query instead,
/// which is exactly today's behaviour — this path can never make search worse
/// than not having it.
abstract class QueryUnderstandingService {
  Future<ParsedQuery?> parse(
    String rawQuery, {
    required List<ReelCategoryGroup> facets,
  });
}

class GeminiQueryUnderstandingService implements QueryUnderstandingService {
  GeminiQueryUnderstandingService({this.timeout = const Duration(seconds: 3)});

  /// Search should feel instant. Past this the raw query goes out instead of
  /// leaving the user watching a spinner.
  final Duration timeout;

  static const _modelName = 'gemini-3.5-flash-lite';

  @override
  Future<ParsedQuery?> parse(
    String rawQuery, {
    required List<ReelCategoryGroup> facets,
  }) async {
    try {
      final model = FirebaseAI.googleAI().generativeModel(
        model: _modelName,
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json',
          responseSchema: Schema.object(
            properties: {
              'semantic_query': Schema.string(),
              'category': Schema.string(nullable: true),
              'subcategory': Schema.string(nullable: true),
              'limit': Schema.integer(nullable: true),
            },
            optionalProperties: const ['category', 'subcategory', 'limit'],
          ),
        ),
      );

      final response = await model
          .generateContent([Content.text(buildPrompt(rawQuery, facets))])
          .timeout(timeout);

      final text = response.text?.trim();
      if (text == null || text.isEmpty) return null;

      final decoded = jsonDecode(text);
      if (decoded is! Map) return null;

      return ParsedQuery.fromGeminiJson(
        Map<String, dynamic>.from(decoded),
        rawQuery: rawQuery,
        facets: facets,
      );
    } catch (e) {
      // Includes timeouts, App Check rejections, quota errors and malformed
      // JSON. All of them mean the same thing to the caller: no parse.
      AppLogger.error('Query understanding unavailable: $e');
      return null;
    }
  }

  /// The model must map onto categories this user actually has, so their real
  /// facet tree goes into the prompt rather than a fixed list. This is what
  /// stops "show me cafes" becoming a hallucinated `category: "cafes"`.
  @visibleForTesting
  String buildPrompt(String rawQuery, List<ReelCategoryGroup> facets) {
    final buffer = StringBuffer()
      ..writeln(
        'You convert a search sentence into filters for a personal library of '
        'saved social media posts. Fix spelling mistakes as you go.',
      )
      ..writeln()
      ..writeln('Available categories (use these exact values, or null):');

    if (facets.isEmpty) {
      buffer.writeln('  (none known - return null for category)');
    } else {
      for (final group in facets) {
        final subs = group.subcategories.map((s) => s.name).join(', ');
        buffer.writeln(
          '  - ${group.category}${subs.isEmpty ? '' : ' (subcategories: $subs)'}',
        );
      }
    }

    buffer
      ..writeln()
      ..writeln('Rules:')
      ..writeln(
        '- semantic_query: the search terms only, spelling corrected. Remove '
        'any words you moved into category or subcategory.',
      )
      ..writeln('- Keep place names in semantic_query.')
      ..writeln('- category/subcategory: only values listed above, else null.')
      ..writeln('- limit: only when the user asked for a count, else null.')
      ..writeln()
      ..writeln('Query: $rawQuery');

    return buffer.toString();
  }
}
