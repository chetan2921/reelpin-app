part of 'reel_detail_screen.dart';

class ReelShareCard extends StatelessWidget {
  final Reel reel;

  const ReelShareCard({super.key, required this.reel});

  @override
  Widget build(BuildContext context) {
    final title = reel.title.trim().isEmpty ? 'Untitled reel' : reel.title;
    final summary = _shareSummary(reel.summary);
    final facts = _shareItems(reel.keyFacts, 4);
    final actions = reel.actionableItems
        .where((item) => item.trim().isNotEmpty)
        .take(3)
        .toList();
    final hasSummary = summary.isNotEmpty;
    final hasFacts = facts.isNotEmpty;
    final hasActions = actions.isNotEmpty;

    return Material(
      color: Colors.transparent,
      child: SizedBox(
        width: 540,
        height: 540,
        child: Container(
          color: const Color(0xFFFFDF36),
          padding: const EdgeInsets.all(12),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                right: -10,
                top: 20,
                child: Transform.rotate(
                  angle: 0.08,
                  child: Container(
                    width: 92,
                    height: 116,
                    decoration: BoxDecoration(
                      color: const Color(0xFF16D7C8),
                      border: Border.all(color: AppTheme.black, width: 3),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: -18,
                bottom: 78,
                child: Transform.rotate(
                  angle: -0.12,
                  child: Container(
                    width: 92,
                    height: 72,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF4AA4),
                      border: Border.all(color: AppTheme.black, width: 3),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 18,
                bottom: 16,
                child: Opacity(
                  opacity: 0.07,
                  child: Transform.rotate(
                    angle: -0.34,
                    child: Image.asset(
                      'assets/images/pin.png',
                      width: 132,
                      height: 132,
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.white,
                    border: Border.all(color: AppTheme.black, width: 4),
                    boxShadow: const [
                      BoxShadow(
                        color: AppTheme.black,
                        offset: Offset(7, 7),
                        blurRadius: 0,
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ShareHeader(contentType: reel.contentType),
                        const SizedBox(height: 5),
                        Container(height: 4, color: AppTheme.black),
                        const SizedBox(height: 5),
                        SizedBox(
                          height: 96,
                          child: _PinnedNote(
                            height: 96,
                            color: AppTheme.white,
                            angle: -0.018,
                            pinAlignment: Alignment.topRight,
                            childPadding: const EdgeInsets.fromLTRB(
                              14,
                              14,
                              14,
                              9,
                            ),
                            child: ClipRect(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      title.toUpperCase(),
                                      maxLines: 3,
                                      overflow: TextOverflow.clip,
                                      softWrap: true,
                                      textWidthBasis: TextWidthBasis.parent,
                                      style: GoogleFonts.spaceMono(
                                        color: AppTheme.black,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        height: 1.02,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    width: 84,
                                    height: 5,
                                    color: const Color(0xFFFF3D00),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 5),
                        if (hasSummary || hasFacts)
                          Expanded(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (hasSummary)
                                  Expanded(
                                    flex: hasFacts ? 8 : 1,
                                    child: _ShareSummaryNote(
                                      summary: summary,
                                      maxLines: hasFacts ? 8 : 7,
                                    ),
                                  ),
                                if (hasSummary && hasFacts)
                                  const SizedBox(width: 10),
                                if (hasFacts)
                                  Expanded(
                                    flex: hasSummary ? 7 : 1,
                                    child: _KeyFactsBoard(facts: facts),
                                  ),
                              ],
                            ),
                          )
                        else
                          const Spacer(),
                        if (hasActions) ...[
                          SizedBox(height: hasSummary || hasFacts ? 7 : 0),
                          _ShareActionNote(
                            actions: actions,
                            isPrimary: !hasSummary && !hasFacts,
                          ),
                        ],
                        SizedBox(height: hasActions ? 8 : 10),
                        _ShareFooter(),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static List<String> _shareItems(List<String> values, int limit) {
    return values
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .take(limit)
        .toList(growable: false);
  }

  static String _shareSummary(String value) {
    final cleaned = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (cleaned.isEmpty) return '';
    final sentences = cleaned
        .split(RegExp(r'(?<=[.!?])\s+'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .take(3)
        .join(' ');
    final candidate = sentences.isEmpty ? cleaned : sentences;
    if (candidate.length <= 270) return candidate;
    final clipped = candidate.substring(0, 270);
    final lastSpace = clipped.lastIndexOf(' ');
    return '${clipped.substring(0, lastSpace > 180 ? lastSpace : 270).trim()}...';
  }
}

class _ShareLocationLink {
  final String label;
  final String url;

  const _ShareLocationLink(this.label, this.url);
}

class _ShareBadge extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;

  const _ShareBadge({
    required this.label,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 104),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: AppTheme.black, width: 2),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: GoogleFonts.spaceMono(
          color: textColor,
          fontSize: 8,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _ShareHeader extends StatelessWidget {
  final String contentType;

  const _ShareHeader({required this.contentType});

  @override
  Widget build(BuildContext context) {
    final typeLabel = switch (contentType) {
      'reel' => 'REEL',
      'carousel' => 'CAROUSEL',
      _ => 'POST',
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFFFFD600),
            border: Border.all(color: AppTheme.black, width: 3),
            boxShadow: AppTheme.inkShadowSmall,
          ),
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: Image.asset(
              'assets/images/app_icon.png',
              fit: BoxFit.contain,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'REELPIN',
                style: GoogleFonts.spaceMono(
                  color: AppTheme.black,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  height: 1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Pinned ${typeLabel.toLowerCase()} brief',
                style: GoogleFonts.spaceMono(
                  color: AppTheme.textSecondary,
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.7,
                ),
              ),
            ],
          ),
        ),
        _ShareBadge(
          label: typeLabel,
          color: AppTheme.hotPink,
          textColor: AppTheme.white,
        ),
      ],
    );
  }
}

class _PinnedNote extends StatelessWidget {
  final Widget child;
  final Color color;
  final Alignment pinAlignment;
  final double angle;
  final EdgeInsets childPadding;
  final double? height;

  const _PinnedNote({
    required this.child,
    required this.color,
    required this.pinAlignment,
    required this.angle,
    required this.childPadding,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angle,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            top: 8,
            left: 8,
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.black.withAlpha(70),
                border: Border.all(color: AppTheme.black, width: 2),
              ),
            ),
          ),
          ClipPath(
            clipper: _ShareStickyNoteClipper(),
            child: Container(
              width: double.infinity,
              height: height,
              decoration: BoxDecoration(
                color: color,
                border: Border.all(color: AppTheme.black, width: 3),
                boxShadow: AppTheme.inkShadowSmall,
              ),
              child: Padding(padding: childPadding, child: child),
            ),
          ),
          Align(
            alignment: pinAlignment,
            child: Transform.translate(
              offset: const Offset(20, -26),
              child: Transform.rotate(
                angle: 0.28,
                child: Image.asset(
                  'assets/images/pin.png',
                  width: 42,
                  height: 42,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShareSummaryNote extends StatelessWidget {
  final String summary;
  final int maxLines;

  const _ShareSummaryNote({required this.summary, required this.maxLines});

  @override
  Widget build(BuildContext context) {
    return _PinnedNote(
      color: const Color(0xFFFFF2A8),
      angle: 0.012,
      pinAlignment: Alignment.topRight,
      childPadding: const EdgeInsets.fromLTRB(14, 16, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _NoteTitle(label: 'SUMMARY', color: AppTheme.black, fontSize: 10),
          const SizedBox(height: 6),
          Expanded(
            child: Text(
              summary,
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
              softWrap: true,
              textWidthBasis: TextWidthBasis.parent,
              style: GoogleFonts.spaceMono(
                color: const Color(0xFF242424),
                fontSize: 10.5,
                height: 1.18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoteTitle extends StatelessWidget {
  final String label;
  final Color color;
  final double fontSize;

  const _NoteTitle({
    required this.label,
    required this.color,
    this.fontSize = 12,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 5, height: 18, color: color),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.spaceMono(
            color: color,
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }
}

class _KeyFactsBoard extends StatelessWidget {
  final List<String> facts;

  const _KeyFactsBoard({required this.facts});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.black,
        border: Border.all(color: AppTheme.black, width: 3),
        boxShadow: AppTheme.inkShadowSmall,
      ),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'KEY FACTS',
            style: GoogleFonts.spaceMono(
              color: const Color(0xFF39FF14),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 5),
          Expanded(
            child: ClipRect(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: facts.map((fact) {
                  return _ShareFactRow(text: fact);
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShareFactRow extends StatelessWidget {
  final String text;

  const _ShareFactRow({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 5),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: AppTheme.red,
              border: Border.all(color: AppTheme.white, width: 1),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              softWrap: true,
              textWidthBasis: TextWidthBasis.parent,
              style: GoogleFonts.spaceMono(
                color: AppTheme.white,
                fontSize: 9.6,
                height: 1.12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShareActionNote extends StatelessWidget {
  final List<String> actions;
  final bool isPrimary;

  const _ShareActionNote({required this.actions, this.isPrimary = false});

  @override
  Widget build(BuildContext context) {
    return _ShareMiniNote(
      label: 'TOP ACTIONS',
      items: actions,
      color: const Color(0xFF19D6C8),
      textColor: AppTheme.black,
      angle: -0.018,
      height: isPrimary ? 190 : null,
      fontSize: 10.5,
    );
  }
}

class _ShareMiniNote extends StatelessWidget {
  final String label;
  final List<String> items;
  final Color color;
  final Color textColor;
  final double angle;
  final double? height;
  final double fontSize;

  const _ShareMiniNote({
    required this.label,
    required this.items,
    required this.color,
    required this.textColor,
    required this.angle,
    required this.height,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angle,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            top: 7,
            left: 7,
            child: Container(color: AppTheme.black.withAlpha(70)),
          ),
          ClipPath(
            clipper: _ShareStickyNoteClipper(),
            child: Container(
              width: double.infinity,
              height: height ?? _heightForItems(items.length),
              decoration: BoxDecoration(
                color: color,
                border: Border.all(color: AppTheme.black, width: 3),
              ),
              padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _NoteTitle(
                    label: label,
                    color: textColor,
                    fontSize: fontSize,
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: ClipRect(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: items.take(3).map((item) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  margin: const EdgeInsets.only(top: 3),
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: AppTheme.white,
                                    border: Border.all(
                                      color: AppTheme.black,
                                      width: 1,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    item,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    softWrap: true,
                                    textWidthBasis: TextWidthBasis.parent,
                                    style: GoogleFonts.spaceMono(
                                      color: textColor,
                                      fontSize: 10,
                                      height: 1.12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 30,
            bottom: -2,
            child: Transform.rotate(
              angle: -0.08,
              child: Container(
                width: 64,
                height: 13,
                decoration: BoxDecoration(
                  color: color,
                  border: Border.all(color: AppTheme.black, width: 2),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _heightForItems(int itemCount) {
    return switch (itemCount) {
      <= 1 => 66,
      2 => 94,
      _ => 120,
    };
  }
}

class _ShareFooter extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Text(
            'Saved, summarized, and pinned with ReelPin',
            style: GoogleFonts.spaceMono(
              color: AppTheme.black,
              fontSize: 8.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
              height: 1.15,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFFFD600),
            border: Border.all(color: AppTheme.black, width: 3),
            boxShadow: AppTheme.inkShadowSmall,
          ),
          child: Text(
            'GET REELPIN',
            style: GoogleFonts.spaceMono(
              color: AppTheme.black,
              fontSize: 8.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ),
      ],
    );
  }
}

class _ShareStickyNoteClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    return Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width - 10, size.height - 18)
      ..quadraticBezierTo(
        size.width * 0.55,
        size.height + 8,
        0,
        size.height - 8,
      )
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
