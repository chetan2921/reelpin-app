import 'package:flutter_test/flutter_test.dart';
import 'package:reelpin/data_models/chat/answer_text_segment.dart';
import 'package:reelpin/utils/answer_text_parser.dart';

void main() {
  test('a plain paragraph with no markers renders unchanged', () {
    const text =
        'You have saved 11 reels in the Movies category, mostly about '
        'ramen shops you want to try.';

    final segments = parseAnswerText(text);

    expect(segments, [isA<AnswerParagraph>()]);
    expect((segments.single as AnswerParagraph).text, text);
  });

  test('an all-uppercase line with no trailing punctuation is a heading', () {
    final segments = parseAnswerText('KEY FACTS');

    expect(segments, [isA<AnswerHeading>()]);
    expect((segments.single as AnswerHeading).text, 'KEY FACTS');
  });

  test('an uppercase line ending in a period is not a heading', () {
    final segments = parseAnswerText('THIS IS SHOUTED.');

    expect(segments, [isA<AnswerParagraph>()]);
  });

  test('lines starting with -, • or * are bullets', () {
    final segments = parseAnswerText(
      '- dash bullet\n• dot bullet\n* star bullet',
    );

    expect(segments, [
      isA<AnswerBullet>(),
      isA<AnswerBullet>(),
      isA<AnswerBullet>(),
    ]);
    expect((segments[0] as AnswerBullet).text, 'dash bullet');
    expect((segments[1] as AnswerBullet).text, 'dot bullet');
    expect((segments[2] as AnswerBullet).text, 'star bullet');
  });

  test('mixed content produces a heading, bullets and a paragraph', () {
    const text =
        'KEY FACTS\n'
        '- Ichiran is a ramen chain\n'
        '- Its broth is tonkotsu\n'
        '\n'
        'You saved three related reels this week.';

    final segments = parseAnswerText(text);

    expect(segments, [
      isA<AnswerHeading>(),
      isA<AnswerBullet>(),
      isA<AnswerBullet>(),
      isA<AnswerParagraph>(),
    ]);
    expect((segments[0] as AnswerHeading).text, 'KEY FACTS');
    expect(
      (segments[3] as AnswerParagraph).text,
      'You saved three related reels this week.',
    );
  });

  test('consecutive plain lines join into one paragraph', () {
    const text = 'Line one of the answer\nLine two continues it';

    final segments = parseAnswerText(text);

    expect(segments, [isA<AnswerParagraph>()]);
    expect(
      (segments.single as AnswerParagraph).text,
      'Line one of the answer\nLine two continues it',
    );
  });

  test('a blank line separates two paragraphs', () {
    const text = 'First paragraph.\n\nSecond paragraph.';

    final segments = parseAnswerText(text);

    expect(segments, [isA<AnswerParagraph>(), isA<AnswerParagraph>()]);
    expect((segments[0] as AnswerParagraph).text, 'First paragraph.');
    expect((segments[1] as AnswerParagraph).text, 'Second paragraph.');
  });

  test('empty text produces no segments', () {
    expect(parseAnswerText(''), isEmpty);
  });

  test('text with no bold markers is a single non-bold run', () {
    final runs = parseBoldRuns('You saved 11 reels.');

    expect(runs, [const BoldRun('You saved 11 reels.', false)]);
  });

  test('a **bold** marker splits into surrounding and bold runs', () {
    final runs = parseBoldRuns('You saved **11 reels** this week.');

    expect(runs, [
      const BoldRun('You saved ', false),
      const BoldRun('11 reels', true),
      const BoldRun(' this week.', false),
    ]);
  });

  test('multiple bold markers each become their own run', () {
    final runs = parseBoldRuns('**Ichiran** is a **ramen** chain.');

    expect(runs, [
      const BoldRun('Ichiran', true),
      const BoldRun(' is a ', false),
      const BoldRun('ramen', true),
      const BoldRun(' chain.', false),
    ]);
  });
}
