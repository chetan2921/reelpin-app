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
  });
}
