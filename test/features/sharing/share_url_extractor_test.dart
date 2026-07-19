import 'package:flutter_test/flutter_test.dart';
import 'package:reelpin/features/sharing/services/share_url_extractor.dart';

void main() {
  group('ShareUrlExtractor', () {
    const cases = {
      'https://www.youtube.com/shorts/VIDEO_ID':
          'https://www.youtube.com/shorts/VIDEO_ID',
      'https://youtube.com/shorts/VIDEO_ID':
          'https://youtube.com/shorts/VIDEO_ID',
      'https://youtu.be/VIDEO_ID': 'https://youtu.be/VIDEO_ID',
      'https://m.youtube.com/shorts/VIDEO_ID':
          'https://m.youtube.com/shorts/VIDEO_ID',
      'https://www.youtube.com/watch?v=VIDEO_ID':
          'https://www.youtube.com/watch?v=VIDEO_ID',
      'https://www.youtube.com/shorts/VIDEO_ID?si=abc123':
          'https://www.youtube.com/shorts/VIDEO_ID?si=abc123',
      'Check this out https://www.youtube.com/shorts/VIDEO_ID?si=abc123':
          'https://www.youtube.com/shorts/VIDEO_ID?si=abc123',
    };

    for (final entry in cases.entries) {
      test('extracts ${entry.value}', () {
        expect(ShareUrlExtractor.extractSupportedUrl(entry.key), entry.value);
      });
    }

    test('extracts mobile YouTube watch URLs with extra query params', () {
      expect(
        ShareUrlExtractor.extractSupportedUrl(
          'https://m.youtube.com/watch?v=VIDEO_ID&feature=share&utm_source=x',
        ),
        'https://m.youtube.com/watch?v=VIDEO_ID&feature=share&utm_source=x',
      );
    });

    test('keeps Instagram extraction unchanged', () {
      expect(
        ShareUrlExtractor.extractSupportedUrl(
          'Saved this https://www.instagram.com/reel/abc_123/?utm_source=ig',
        ),
        'https://www.instagram.com/reel/abc_123/?utm_source=ig',
      );
    });
  });
}
