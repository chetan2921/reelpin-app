/// One piece of a parsed `TextBlock`, so the renderer can give a heading, a
/// bullet and a paragraph different treatment instead of dumping the whole
/// answer into one Text widget.
sealed class AnswerTextSegment {
  const AnswerTextSegment();
}

class AnswerHeading extends AnswerTextSegment {
  final String text;
  const AnswerHeading(this.text);
}

class AnswerBullet extends AnswerTextSegment {
  final String text;
  const AnswerBullet(this.text);
}

class AnswerParagraph extends AnswerTextSegment {
  final String text;
  const AnswerParagraph(this.text);
}
