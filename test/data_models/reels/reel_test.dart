import 'package:flutter_test/flutter_test.dart';
import 'package:reelpin/data_models/reels/reel.dart';

import '../../fixtures/api_v2.dart';

void main() {
  test('preserves backend source URLs for opening the original reel', () {
    final reel = Reel.fromJson({
      'id': 'reel-123',
      'user_id': 'user-123',
      'url': 'https://cdn.example.com/reel-123',
      'source_url': 'https://instagram.com/reel/original-source',
      'original_url': 'https://instagram.com/reel/original',
      'normalized_url': 'https://instagram.com/reel/normalized',
      'thumbnail_url': 'https://cdn.example.com/reel-123-thumb.jpg',
      'title': 'Original reel',
      'summary': '',
      'caption': '',
      'transcript': '',
      'category': 'Food',
      'sub_category': 'Product Showcase',
      'key_facts': <String>[],
      'locations': <Map<String, Object?>>[],
      'people_mentioned': <String>[],
      'actionable_items': <String>[],
    });

    expect(reel.url, 'https://cdn.example.com/reel-123');
    expect(reel.sourceUrl, 'https://instagram.com/reel/original-source');
    expect(reel.originalUrl, 'https://instagram.com/reel/original');
    expect(reel.normalizedUrl, 'https://instagram.com/reel/normalized');
    expect(reel.thumbnailUrl, 'https://cdn.example.com/reel-123-thumb.jpg');
    expect(
      reel.toJson()['thumbnail_url'],
      'https://cdn.example.com/reel-123-thumb.jpg',
    );
  });

  test('reads a list reel from the v2 reel page', () {
    final json = (ApiV2Fixture('reel_page').body['reels'] as List).single;
    final reel = Reel.fromJson(Map<String, dynamic>.from(json as Map));

    expect(reel.id, '22222222-2222-4222-8222-222222222222');
    expect(
      reel.webUrl,
      'https://reelpin.in/r/22222222-2222-4222-8222-222222222222',
    );
    expect(reel.subCategory, 'cafes');
    expect(reel.categoryLabel, 'Food And Drink');
    expect(reel.subCategoryLabel, 'Cafes');
    expect(reel.relativeDate, '2 days ago');
    expect(reel.savedDateKey, '2026-09-02');
    expect(reel.transcript, isEmpty);
    final location = reel.mappableLocations.single;
    expect(location.name, 'Artjuna Cafe');
    expect(location.address, 'Anjuna');
    expect(location.displayLabel, 'Artjuna Cafe');
    expect(location.latitude, 15.5834);
  });

  test('reads a single reel from the v2 detail', () {
    final reel = Reel.fromJson(ApiV2Fixture('reel_detail').body);

    expect(reel.userId, '11111111-1111-4111-8111-111111111111');
    expect(reel.subCategory, 'cafes');
    expect(reel.transcript, 'spoken words');
    expect(reel.locations.map((l) => l.name), [
      'Artjuna Cafe',
      'No coordinates',
    ]);
    expect(reel.locations.first.address, 'Anjuna');
    expect(reel.locations.last.latitude, isNull);
  });

  test('ignores names the API does not send', () {
    final reel = Reel.fromJson(
      _reelJson({
        'thumbnailUrl': 'https://example.com/a.jpg',
        'transcript_text': 'Alias transcript',
      }),
    );

    expect(reel.thumbnailUrl, isEmpty);
    expect(reel.transcript, isEmpty);
  });

  test('normalizes backend content type values', () {
    expect(
      Reel.fromJson(_reelJson({'content_type': 'reel'})).contentType,
      'reel',
    );
    expect(
      Reel.fromJson(_reelJson({'content_type': 'carousel'})).contentType,
      'carousel',
    );
    expect(
      Reel.fromJson(_reelJson({'content_type': 'video'})).contentType,
      'post',
    );
    expect(Reel.fromJson(_reelJson({})).contentType, 'post');
    expect(
      Reel.fromJson(
        _reelJson({'content_type': 'carousel'}),
      ).toJson()['content_type'],
      'carousel',
    );
  });

  test('normalizes parse_status and defaults to parsed', () {
    expect(Reel.fromJson(_reelJson({})).parseStatus, 'parsed');
    expect(Reel.fromJson(_reelJson({})).isUnparsed, false);

    final unparsed = Reel.fromJson(_reelJson({'parse_status': 'unparsed'}));
    expect(unparsed.parseStatus, 'unparsed');
    expect(unparsed.isUnparsed, true);
    expect(unparsed.toJson()['parse_status'], 'unparsed');

    expect(
      Reel.fromJson(_reelJson({'parse_status': 'garbage'})).parseStatus,
      'parsed',
    );
  });

  test('preserves source platform metadata from backend', () {
    final reel = Reel.fromJson(
      _reelJson({'source_platform': 'YouTube', 'source_content_type': 'Short'}),
    );

    expect(reel.sourcePlatform, 'youtube');
    expect(reel.sourceContentType, 'short');
    expect(reel.toJson()['source_platform'], 'youtube');
    expect(reel.toJson()['source_content_type'], 'short');
  });

  test('parses X post metadata and a null thumbnail', () {
    final reel = Reel.fromJson(
      _reelJson({
        'source_platform': 'x',
        'source_content_type': 'post',
        'content_type': 'post',
        'thumbnail_url': null,
      }),
    );

    expect(reel.sourcePlatform, 'x');
    expect(reel.sourceContentType, 'post');
    expect(reel.contentType, 'post');
    expect(reel.thumbnailUrl, isEmpty);
  });

  test('a location round-trips through its cache form', () {
    final reel = Reel.fromJson(ApiV2Fixture('reel_detail').body);

    final restored = Reel.fromJson(reel.toJson());

    expect(restored.locations.first.address, 'Anjuna');
    expect(restored.webUrl, reel.webUrl);
    expect(restored.subCategory, 'cafes');
  });
}

Map<String, Object?> _reelJson(Map<String, Object?> overrides) {
  return {
    'id': 'reel-123',
    'user_id': 'user-123',
    'url': 'https://instagram.com/reel/original',
    'title': 'Original reel',
    'summary': '',
    'caption': '',
    'transcript': '',
    'category': 'Food',
    'sub_category': 'Product Showcase',
    'key_facts': <String>[],
    'locations': <Map<String, Object?>>[],
    'people_mentioned': <String>[],
    'actionable_items': <String>[],
    ...overrides,
  };
}
