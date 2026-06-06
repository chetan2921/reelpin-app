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
