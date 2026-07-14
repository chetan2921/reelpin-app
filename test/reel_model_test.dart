import 'package:flutter_test/flutter_test.dart';
import 'package:reelpin/models/reel.dart';

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

  test('accepts common backend thumbnail aliases', () {
    expect(
      Reel.fromJson(
        _reelJson({'thumbnailUrl': 'https://example.com/a.jpg'}),
      ).thumbnailUrl,
      'https://example.com/a.jpg',
    );
    expect(
      Reel.fromJson(
        _reelJson({'cover_url': 'https://example.com/b.jpg'}),
      ).thumbnailUrl,
      'https://example.com/b.jpg',
    );
    expect(
      Reel.fromJson(
        _reelJson({'poster_url': 'https://example.com/c.jpg'}),
      ).thumbnailUrl,
      'https://example.com/c.jpg',
    );
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

  test('preserves source platform metadata from backend', () {
    final reel = Reel.fromJson(
      _reelJson({'source_platform': 'YouTube', 'source_content_type': 'Short'}),
    );

    expect(reel.sourcePlatform, 'youtube');
    expect(reel.sourceContentType, 'short');
    expect(reel.toJson()['source_platform'], 'youtube');
    expect(reel.toJson()['source_content_type'], 'short');
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
