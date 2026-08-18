import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:reelpin/constants/app_colors.dart';
import 'package:reelpin/constants/app_theme.dart';
import 'package:reelpin/data_models/reels/reel.dart';

class ReelShareCard extends StatelessWidget {
  final Reel reel;

  const ReelShareCard({super.key, required this.reel});

  @override
  Widget build(BuildContext context) {
    final title = reel.title.trim().isEmpty
        ? reel.sourcePlatform == 'x'
              ? 'Untitled post'
              : 'Untitled reel'
        : reel.title;
    final summary = _shareSummary(reel.summary);
    final actions = reel.actionableItems
        .where((item) => item.trim().isNotEmpty)
        .take(3)
        .toList();
    final typeLabel = _typeLabel(reel);
    final hasSummary = summary.isNotEmpty;
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
                      border: Border.all(color: AppColors.black, width: 3),
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
                      border: Border.all(color: AppColors.black, width: 3),
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
                    color: AppColors.white,
                    border: Border.all(color: AppColors.black, width: 4),
                    boxShadow: const [
                      BoxShadow(
                        color: AppColors.black,
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
                        _ShareHeader(
                          kicker: 'Pinned ${typeLabel.toLowerCase()} brief',
                          badge: typeLabel,
                        ),
                        const SizedBox(height: 5),
                        Container(height: 4, color: AppColors.black),
                        const SizedBox(height: 5),
                        SizedBox(
                          height: 96,
                          child: _PinnedNote(
                            height: 96,
                            color: AppColors.white,
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
                                        color: AppColors.black,
                                        fontSize: 22,
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
                        if (hasSummary)
                          Expanded(
                            child: _ShareSummaryNote(
                              summary: summary,
                              maxLines: hasActions ? 9 : 13,
                            ),
                          )
                        else
                          const Spacer(),
                        if (hasActions) ...[
                          SizedBox(height: hasSummary ? 8 : 0),
                          _ShareActionNote(
                            actions: actions,
                            isPrimary: !hasSummary,
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

  static String _typeLabel(Reel reel) {
    final contentType = switch (reel.contentType) {
      'reel' => 'REEL',
      'carousel' => 'CAROUSEL',
      _ => 'POST',
    };
    return reel.sourcePlatform == 'x' ? 'X $contentType' : contentType;
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

/// The same poster for a collection link or a collaborator invite: the header,
/// the pinned note and the footer are the reel card's, only the middle differs.
class CollectionShareCard extends StatelessWidget {
  const CollectionShareCard({
    super.key,
    required this.name,
    required this.note,
    required this.itemCount,
    required this.role,
    this.ownerName,
    this.memberCount = 0,
  });

  final String name;
  final String note;
  final int itemCount;

  /// 'editor' or 'viewer' for an invite; null for a plain view link. It only
  /// changes the badge and the line under the count.
  final String? role;

  /// Who is sending it, when known.
  final String? ownerName;

  /// People already in the collection, the sender included.
  final int memberCount;

  @override
  Widget build(BuildContext context) {
    final title = name.trim().isEmpty ? 'Untitled collection' : name.trim();
    final noteText = note.trim();
    final owner = ownerName?.trim();
    final promise = switch (role) {
      'editor' => 'YOU CAN ADD AND REMOVE PINS',
      'viewer' => 'YOU CAN BROWSE EVERYTHING INSIDE',
      _ => 'OPEN THE LINK TO BROWSE IT ALL',
    };

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
                      border: Border.all(color: AppColors.black, width: 3),
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
                      border: Border.all(color: AppColors.black, width: 3),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    border: Border.all(color: AppColors.black, width: 4),
                    boxShadow: const [
                      BoxShadow(
                        color: AppColors.black,
                        offset: Offset(7, 7),
                        blurRadius: 0,
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ShareHeader(
                          kicker: role == null
                              ? 'Shared collection'
                              : 'Collection invite',
                          badge: role == null ? 'COLLECTION' : 'INVITE',
                        ),
                        const SizedBox(height: 10),
                        Container(height: 4, color: AppColors.black),
                        const SizedBox(height: 16),
                        Text(
                          title.toUpperCase(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          softWrap: true,
                          textWidthBasis: TextWidthBasis.parent,
                          style: GoogleFonts.spaceMono(
                            color: AppColors.black,
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            height: 1.05,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(width: 96, height: 6, color: AppColors.red),
                        if (owner != null && owner.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            'FROM ${owner.toUpperCase()}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.spaceMono(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ],
                        // The note is only drawn when there is one. Stretching
                        // a stock line across half the poster read as a card
                        // that had failed to load.
                        if (noteText.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Flexible(
                            child: _PinnedNote(
                              color: const Color(0xFFFFF2A8),
                              angle: 0.012,
                              pinAlignment: Alignment.topRight,
                              childPadding: const EdgeInsets.fromLTRB(
                                16,
                                18,
                                16,
                                14,
                              ),
                              child: Text(
                                noteText,
                                maxLines: 4,
                                overflow: TextOverflow.ellipsis,
                                softWrap: true,
                                textWidthBasis: TextWidthBasis.parent,
                                style: GoogleFonts.spaceMono(
                                  color: const Color(0xFF242424),
                                  fontSize: 15,
                                  height: 1.3,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                        const Spacer(),
                        _CollectionStats(
                          itemCount: itemCount,
                          memberCount: memberCount,
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF19D6C8),
                            border: Border.all(
                              color: AppColors.black,
                              width: 3,
                            ),
                          ),
                          child: Text(
                            promise,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.spaceMono(
                              color: AppColors.black,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              height: 1.2,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
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
}

/// The two numbers worth knowing before opening someone else's collection.
class _CollectionStats extends StatelessWidget {
  const _CollectionStats({required this.itemCount, required this.memberCount});

  final int itemCount;
  final int memberCount;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 74,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _StatBlock(
              value: '$itemCount',
              label: itemCount == 1 ? 'PIN' : 'PINS',
            ),
          ),
          if (memberCount > 0) ...[
            const SizedBox(width: 12),
            Expanded(
              child: _StatBlock(
                value: '$memberCount',
                label: memberCount == 1 ? 'PERSON' : 'PEOPLE',
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatBlock extends StatelessWidget {
  const _StatBlock({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.black,
        boxShadow: AppTheme.inkShadowSmall,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: GoogleFonts.spaceMono(
              color: const Color(0xFF39FF14),
              fontSize: 30,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.spaceMono(
              color: AppColors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
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
      constraints: const BoxConstraints(maxWidth: 120),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: AppColors.black, width: 2),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: GoogleFonts.spaceMono(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _ShareHeader extends StatelessWidget {
  final String kicker;
  final String badge;

  const _ShareHeader({required this.kicker, required this.badge});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFFFFD600),
            border: Border.all(color: AppColors.black, width: 3),
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
                  color: AppColors.black,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  height: 1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                kicker,
                style: GoogleFonts.spaceMono(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.7,
                ),
              ),
            ],
          ),
        ),
        _ShareBadge(
          label: badge,
          color: AppColors.hotPink,
          textColor: AppColors.white,
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
                color: AppColors.black.withAlpha(70),
                border: Border.all(color: AppColors.black, width: 2),
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
                border: Border.all(color: AppColors.black, width: 3),
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
          _NoteTitle(label: 'SUMMARY', color: AppColors.black, fontSize: 10),
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
      textColor: AppColors.black,
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
            child: Container(color: AppColors.black.withAlpha(70)),
          ),
          ClipPath(
            clipper: _ShareStickyNoteClipper(),
            child: Container(
              width: double.infinity,
              height: height ?? _heightForItems(items.length),
              decoration: BoxDecoration(
                color: color,
                border: Border.all(color: AppColors.black, width: 3),
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
                                    color: AppColors.white,
                                    border: Border.all(
                                      color: AppColors.black,
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
                  border: Border.all(color: AppColors.black, width: 2),
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
              color: AppColors.black,
              fontSize: 10,
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
            border: Border.all(color: AppColors.black, width: 3),
            boxShadow: AppTheme.inkShadowSmall,
          ),
          child: Text(
            'GET REELPIN',
            style: GoogleFonts.spaceMono(
              color: AppColors.black,
              fontSize: 10,
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
