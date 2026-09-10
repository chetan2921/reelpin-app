import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:reelpin/constants/app_colors.dart';
import 'package:reelpin/data_models/chat/answer_text_segment.dart';
import 'package:reelpin/utils/answer_text_parser.dart';

/// Renders a `TextBlock`'s text with the same section/bullet language the
/// reel detail screen uses for KEY FACTS and friends, once the text has any
/// of those markers in it. A plain paragraph with none of them — everything
/// the backend sends today — comes back from the parser as a single
/// paragraph holding the original string, so it renders exactly as the bare
/// `Text` it replaced.
///
/// Each bullet group's dot cycles to the next colour in [_bulletColors]
/// rather than always red, so a multi-section answer doesn't read as one
/// flat block — the same "cycle a palette by index" trick the empty-state
/// suggestion cards and the reel strip already use.
class ChatAnswerTextView extends StatelessWidget {
  const ChatAnswerTextView({super.key, required this.text});

  final String text;

  static const _bulletColors = [
    AppColors.red,
    AppColors.neonGreen,
    AppColors.blue,
    AppColors.yellow,
    AppColors.orange,
    AppColors.purple,
  ];

  @override
  Widget build(BuildContext context) {
    final segments = parseAnswerText(text);
    final children = <Widget>[];
    var bulletBuffer = <String>[];
    var groupIndex = 0;

    void flushBullets() {
      if (bulletBuffer.isEmpty) return;
      if (children.isNotEmpty) children.add(const SizedBox(height: 8));
      final color = _bulletColors[groupIndex % _bulletColors.length];
      children.add(_buildBulletGroup(context, bulletBuffer, color));
      bulletBuffer = [];
      groupIndex++;
    }

    for (final segment in segments) {
      switch (segment) {
        case AnswerHeading(:final text):
          flushBullets();
          if (children.isNotEmpty) children.add(const SizedBox(height: 14));
          children.add(_buildHeading(context, text));
        case AnswerBullet(:final text):
          bulletBuffer.add(text);
        case AnswerParagraph(:final text):
          flushBullets();
          if (children.isNotEmpty) children.add(const SizedBox(height: 8));
          children.add(_buildParagraph(context, text));
      }
    }
    flushBullets();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  Widget _buildHeading(BuildContext context, String text) {
    return Row(
      children: [
        Container(width: 4, height: 16, color: AppColors.fg(context)),
        const SizedBox(width: 8),
        Text(
          text,
          style: GoogleFonts.spaceMono(
            color: AppColors.fg(context),
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildBulletGroup(
    BuildContext context,
    List<String> bullets,
    Color dotColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < bullets.length; i++) ...[
          if (i > 0) const SizedBox(height: 6),
          _buildBullet(context, bullets[i], dotColor),
        ],
      ],
    );
  }

  Widget _buildBullet(BuildContext context, String text, Color dotColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 4),
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: dotColor,
            border: Border.all(color: AppColors.fg(context), width: 1),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _richText(
            context,
            text,
            GoogleFonts.spaceMono(
              color: AppColors.fg(context),
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildParagraph(BuildContext context, String text) {
    return _richText(
      context,
      text,
      GoogleFonts.spaceMono(
        color: AppColors.fg(context),
        fontSize: 13,
        height: 1.55,
      ),
    );
  }

  /// Renders `**word**` markers as bold, keyed off the same style everything
  /// else in the segment uses so a bold run differs only in weight.
  Widget _richText(BuildContext context, String text, TextStyle baseStyle) {
    return Text.rich(
      TextSpan(
        children: [
          for (final run in parseBoldRuns(text))
            TextSpan(
              text: run.text,
              style: run.bold
                  ? baseStyle.copyWith(fontWeight: FontWeight.w700)
                  : baseStyle,
            ),
        ],
      ),
      style: baseStyle,
    );
  }
}
