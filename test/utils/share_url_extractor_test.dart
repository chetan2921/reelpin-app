import 'package:flutter_test/flutter_test.dart';
import 'package:reelpin/utils/share_url_extractor.dart';

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

    group('X URLs', () {
      const cases = {
        'https://x.com/OpenAI/status/1234567890':
            'https://x.com/OpenAI/status/1234567890',
        'https://twitter.com/OpenAI/status/1234567890?s=20&utm_source=share':
            'https://twitter.com/OpenAI/status/1234567890?s=20&utm_source=share',
        'https://mobile.twitter.com/OpenAI/status/1234567890':
            'https://mobile.twitter.com/OpenAI/status/1234567890',
        'https://x.com/i/web/status/1234567890':
            'https://x.com/i/web/status/1234567890',
        'https://t.co/AbCdEf123': 'https://t.co/AbCdEf123',
        'Check this post https://x.com/OpenAI/status/1234567890?s=20':
            'https://x.com/OpenAI/status/1234567890?s=20',
        'https://MoBiLe.TwItTeR.CoM/OpenAI/status/1234567890':
            'https://MoBiLe.TwItTeR.CoM/OpenAI/status/1234567890',
      };

      for (final entry in cases.entries) {
        test('extracts ${entry.value}', () {
          expect(ShareUrlExtractor.extractSupportedUrl(entry.key), entry.value);
        });
      }

      test('leaves malformed status paths for backend validation', () {
        const url = 'https://x.com/OpenAI/status/not-a-number';
        expect(ShareUrlExtractor.extractSupportedUrl(url), url);
      });

      test('leaves profile URLs for backend validation', () {
        const url = 'https://x.com/OpenAI';
        expect(ShareUrlExtractor.extractSupportedUrl(url), url);
      });

      test('rejects lookalike domains', () {
        expect(
          ShareUrlExtractor.extractSupportedUrl(
            'https://x.com.example.com/OpenAI/status/1234567890',
          ),
          isNull,
        );
      });
    });

    group('Pinterest URLs', () {
      const cases = {
        'https://www.pinterest.com/pin/1234567890/':
            'https://www.pinterest.com/pin/1234567890/',
        'https://pinterest.com/pin/1234567890/':
            'https://pinterest.com/pin/1234567890/',
        'https://in.pinterest.com/pin/1234567890/':
            'https://in.pinterest.com/pin/1234567890/',
        'https://www.pinterest.co.uk/pin/1234567890/':
            'https://www.pinterest.co.uk/pin/1234567890/',
        'https://www.pinterest.com.au/pin/1234567890/':
            'https://www.pinterest.com.au/pin/1234567890/',
        'https://pinterest.ca/pin/1234567890/':
            'https://pinterest.ca/pin/1234567890/',
        'https://pin.it/AbCdEf123': 'https://pin.it/AbCdEf123',
        'Saved this https://www.pinterest.com/pin/1234567890/?sender=1':
            'https://www.pinterest.com/pin/1234567890/?sender=1',
      };

      for (final entry in cases.entries) {
        test('extracts ${entry.value}', () {
          expect(ShareUrlExtractor.extractSupportedUrl(entry.key), entry.value);
        });
      }

      test('leaves board URLs for backend validation', () {
        const url = 'https://www.pinterest.com/someuser/some-board/';
        expect(ShareUrlExtractor.extractSupportedUrl(url), url);
      });

      test('rejects lookalike domains', () {
        expect(
          ShareUrlExtractor.extractSupportedUrl(
            'https://pinterest.com.example.com/pin/1234567890/',
          ),
          isNull,
        );
        expect(
          ShareUrlExtractor.extractSupportedUrl(
            'https://evil-pinterest.com/pin/1234567890/',
          ),
          isNull,
        );
      });
    });

    group('Reddit URLs', () {
      const cases = {
        'https://www.reddit.com/r/flutter/comments/abc123/some_title/':
            'https://www.reddit.com/r/flutter/comments/abc123/some_title/',
        'https://reddit.com/r/flutter/comments/abc123/':
            'https://reddit.com/r/flutter/comments/abc123/',
        'https://old.reddit.com/r/flutter/comments/abc123/':
            'https://old.reddit.com/r/flutter/comments/abc123/',
        'https://redd.it/abc123': 'https://redd.it/abc123',
        'Look at this https://www.reddit.com/r/flutter/comments/abc123/?share_id=xyz':
            'https://www.reddit.com/r/flutter/comments/abc123/?share_id=xyz',
      };

      for (final entry in cases.entries) {
        test('extracts ${entry.value}', () {
          expect(ShareUrlExtractor.extractSupportedUrl(entry.key), entry.value);
        });
      }

      test('leaves subreddit URLs for backend validation', () {
        const url = 'https://www.reddit.com/r/flutter/';
        expect(ShareUrlExtractor.extractSupportedUrl(url), url);
      });

      test('rejects lookalike domains', () {
        expect(
          ShareUrlExtractor.extractSupportedUrl(
            'https://reddit.com.example.com/r/flutter/comments/abc123/',
          ),
          isNull,
        );
      });
    });

    group('LinkedIn URLs', () {
      const cases = {
        'https://www.linkedin.com/feed/update/urn:li:activity:1234567890123/':
            'https://www.linkedin.com/feed/update/urn:li:activity:1234567890123/',
        'https://www.linkedin.com/posts/someone_a-slug-activity-1234567890123-Ab1c':
            'https://www.linkedin.com/posts/someone_a-slug-activity-1234567890123-Ab1c',
        'https://linkedin.com/feed/update/urn:li:activity:1234567890123/':
            'https://linkedin.com/feed/update/urn:li:activity:1234567890123/',
        'https://in.linkedin.com/posts/someone_a-slug-activity-1234567890123-Ab1c':
            'https://in.linkedin.com/posts/someone_a-slug-activity-1234567890123-Ab1c',
      };

      for (final entry in cases.entries) {
        test('extracts ${entry.value}', () {
          expect(ShareUrlExtractor.extractSupportedUrl(entry.key), entry.value);
        });
      }

      test('leaves profile URLs for backend validation', () {
        const url = 'https://www.linkedin.com/in/someone/';
        expect(ShareUrlExtractor.extractSupportedUrl(url), url);
      });

      test('rejects lookalike domains', () {
        expect(
          ShareUrlExtractor.extractSupportedUrl(
            'https://linkedin.com.example.com/feed/update/urn:li:activity:1/',
          ),
          isNull,
        );
      });
    });
  });
}
