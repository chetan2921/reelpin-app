import 'package:reelpin/data_models/chat/answer_text_segment.dart';

/// Recognises a lightweight structure inside a chat answer's plain-text
/// blocks — the backend sends prose today, but is moving toward sending
/// headings and bullets as plain lines rather than a markdown dialect. Small
/// enough to stay a line-by-line scan rather than pull in a Markdown
/// dependency.
///
/// Line by line:
///  * A line that is entirely uppercase (letters, digits, spaces, `&`, `/`,
///    `-`) with no trailing sentence punctuation is a section heading.
///  * A line starting with `- `, `• ` or `* ` is a bullet.
///  * A blank line separates paragraphs.
///  * Anything else is a paragraph line; consecutive paragraph lines join
///    into one paragraph, so a plain answer with none of the above markers
///    comes back as a single paragraph holding the original text unchanged.
List<AnswerTextSegment> parseAnswerText(String text) {
  final segments = <AnswerTextSegment>[];
  final paragraphLines = <String>[];

  void flushParagraph() {
    if (paragraphLines.isEmpty) return;
    segments.add(AnswerParagraph(paragraphLines.join('\n')));
    paragraphLines.clear();
  }

  for (final rawLine in text.split('\n')) {
    final trimmed = rawLine.trim();

    if (trimmed.isEmpty) {
      flushParagraph();
      continue;
    }

    if (_isHeading(trimmed)) {
      flushParagraph();
      segments.add(AnswerHeading(trimmed));
      continue;
    }

    final bulletText = _bulletText(trimmed);
    if (bulletText != null) {
      flushParagraph();
      segments.add(AnswerBullet(bulletText));
      continue;
    }

    paragraphLines.add(rawLine);
  }
  flushParagraph();

  return segments;
}

final _headingCharset = RegExp(r'^[A-Z0-9 &/-]+$');
final _hasLetter = RegExp('[A-Z]');
const _bulletPrefixes = ['- ', '• ', '* '];

bool _isHeading(String trimmed) {
  if (!_headingCharset.hasMatch(trimmed)) return false;
  if (!_hasLetter.hasMatch(trimmed)) return false;
  return !trimmed.endsWith('.') &&
      !trimmed.endsWith('!') &&
      !trimmed.endsWith('?');
}

String? _bulletText(String trimmed) {
  for (final prefix in _bulletPrefixes) {
    if (trimmed.startsWith(prefix)) return trimmed.substring(prefix.length);
  }
  return null;
}

/// One run of a paragraph or bullet's text, marked bold or not. The renderer
/// turns these into a single `Text.rich` so the keywords the backend wraps
/// in `**double asterisks**` stand out from the surrounding sentence.
class BoldRun {
  final String text;
  final bool bold;

  const BoldRun(this.text, this.bold);

  @override
  bool operator ==(Object other) =>
      other is BoldRun && other.text == text && other.bold == bold;

  @override
  int get hashCode => Object.hash(text, bold);
}

final _boldMarker = RegExp(r'\*\*(.+?)\*\*');

/// Splits `text` on `**bold**` markers. Text with no markers comes back as a
/// single non-bold run holding the original string unchanged.
List<BoldRun> parseBoldRuns(String text) {
  final runs = <BoldRun>[];
  var cursor = 0;
  for (final match in _boldMarker.allMatches(text)) {
    if (match.start > cursor) {
      runs.add(BoldRun(text.substring(cursor, match.start), false));
    }
    runs.add(BoldRun(match.group(1)!, true));
    cursor = match.end;
  }
  if (cursor < text.length) {
    runs.add(BoldRun(text.substring(cursor), false));
  }
  if (runs.isEmpty) runs.add(BoldRun(text, false));
  return runs;
}
