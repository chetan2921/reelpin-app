import 'package:flutter_test/flutter_test.dart';
import 'package:reelpin/data_models/reels/reel.dart';

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

  test('prefers backend transcript over YouTube transcript aliases', () {
    final reel = Reel.fromJson(
      _reelJson({
        'transcript': 'Stored transcript',
        'transcript_text': 'Alias transcript',
      }),
    );

    expect(reel.transcript, 'Stored transcript');
  });

  test('accepts YouTube transcript text alias', () {
    final reel = Reel.fromJson(
      _reelJson({'transcript_text': 'YouTube transcript'}),
    );

    expect(reel.transcript, 'YouTube transcript');
  });

  test('flattens YouTube caption segment lists', () {
    final reel = Reel.fromJson(
      _reelJson({
        'captions': [
          {'text': 'First line'},
          {'caption': 'Second line'},
        ],
      }),
    );

    expect(reel.transcript, 'First line\nSecond line');
  });

  test('flattens YouTube transcripts segment lists', () {
    final reel = Reel.fromJson(
      _reelJson({
        'transcripts': [
          {
            'lines': [
              {'text': 'First transcript line'},
              {'text': 'Second transcript line'},
            ],
          },
        ],
      }),
    );

    expect(reel.transcript, 'First transcript line\nSecond transcript line');
  });

  test('accepts encoded YouTube transcript segment lists', () {
    final reel = Reel.fromJson(
      _reelJson({
        'transcription':
            '[{"text":"First encoded line"},{"text":"Second encoded line"}]',
      }),
    );

    expect(reel.transcript, 'First encoded line\nSecond encoded line');
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
