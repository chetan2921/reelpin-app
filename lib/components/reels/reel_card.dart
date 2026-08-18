import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:reelpin/data_models/reels/reel.dart';
import 'package:reelpin/constants/app_layout.dart';
import 'package:reelpin/components/collections/selection_tick.dart';
import 'package:reelpin/components/common/confirm_dialog.dart';
import 'package:reelpin/constants/app_colors.dart';
import 'package:reelpin/constants/app_theme.dart';
import 'package:reelpin/constants/source_platforms.dart';

class ReelCard extends StatefulWidget {
  final Reel reel;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  /// Takes over the long press when set, so callers can offer more than the
  /// built-in delete sheet. Falls back to that sheet when null.
  final VoidCallback? onLongPress;

  /// Null outside selection mode. True or false puts a checkbox on the card,
  /// so an unpicked card still reads as selectable.
  final bool? selected;

  const ReelCard({
    super.key,
    required this.reel,
    required this.onTap,
    this.onDelete,
    this.onLongPress,
    this.selected,
  });

  @override
  State<ReelCard> createState() => _ReelCardState();
}

class _ReelCardState extends State<ReelCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnim;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
    );
    _scaleAnim = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reel = widget.reel;
    final catColor = AppColors.getCategoryColor(reel.category);
    final layout = AppLayout.of(context);
    final hasThumbnail = reel.thumbnailUrl.trim().isNotEmpty;

    return GestureDetector(
      onTapDown: (_) {
        _controller.forward();
        setState(() => _isPressed = true);
      },
      onTapUp: (_) {
        _controller.reverse();
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () {
        _controller.reverse();
        setState(() => _isPressed = false);
      },
      onLongPress:
          widget.onLongPress ??
          (widget.onDelete != null ? () => _showDeleteSheet(context) : null),
      child: AnimatedBuilder(
        animation: _scaleAnim,
        builder: (context, child) {
          return Transform.scale(scale: _scaleAnim.value, child: child);
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              decoration: BoxDecoration(
                color: AppColors.bg(context),
                border: Border.all(
                  color: AppColors.fg(context),
                  width: AppTheme.borderWidth,
                ),
                boxShadow: _isPressed ? null : AppTheme.brutalShadow(context),
              ),
              clipBehavior: Clip.antiAlias,
              child: hasThumbnail
                  ? _buildThumbnailCard(context, reel, catColor)
                  : _buildTextCard(context, reel, catColor),
            ),
            // The tiny hole indicating pierced paper
            Positioned(
              right: layout.inset(14),
              top: layout.gap(14),
              child: Container(
                width: layout.inset(5),
                height: layout.inset(5),
                decoration: const BoxDecoration(
                  color: AppColors.black,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            // The pin
            Positioned(
              right: -layout.inset(6),
              top: -layout.gap(6),
              child: Image.asset(
                'assets/images/pin.png',
                width: layout.inset(26),
                height: layout.inset(26),
              ),
            ),
            if (widget.selected != null)
              Positioned.fill(
                child: widget.selected == true
                    ? const SelectionTick()
                    : const _UnselectedTick(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnailCard(BuildContext context, Reel reel, Color catColor) {
    final layout = AppLayout.of(context);
    final textShadow = [
      Shadow(
        color: AppColors.black.withAlpha(190),
        offset: const Offset(1, 1),
        blurRadius: 2,
      ),
    ];

    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: AppColors.black),
        // Both layers share one URL, so they share one cache entry and one
        // decode — the backdrop costs nothing extra.
        Opacity(
          opacity: 0.32,
          child: _ReelThumbnail(
            url: reel.thumbnailUrl,
            fallbackColor: catColor,
          ),
        ),
        _ReelThumbnail(url: reel.thumbnailUrl, fallbackColor: catColor),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.black.withAlpha(70),
                AppColors.black.withAlpha(115),
                AppColors.black.withAlpha(225),
              ],
              stops: const [0.0, 0.42, 1.0],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            layout.inset(10),
            layout.gap(10),
            layout.inset(10),
            layout.gap(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 32),
                child: _buildCategoryTag(context, reel.subCategory, catColor),
              ),
              if (reel.isUnparsed) _buildUnparsedBadge(context),
              const Spacer(),
              Text(
                reel.title.isNotEmpty ? reel.title : _untitledLabel(reel),
                style: GoogleFonts.spaceMono(
                  color: AppColors.white,
                  fontSize: layout.font(11),
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                  shadows: textShadow,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: layout.gap(8)),
              _buildBottomInfoRow(
                context,
                reel,
                textColor: AppColors.white,
                secondaryColor: AppColors.white.withAlpha(210),
                borderColor: AppColors.white,
                shadows: textShadow,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTextCard(BuildContext context, Reel reel, Color catColor) {
    final layout = AppLayout.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              layout.inset(10),
              layout.gap(10),
              layout.inset(10),
              layout.gap(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 32),
                  child: _buildCategoryTag(context, reel.subCategory, catColor),
                ),
                if (reel.isUnparsed) _buildUnparsedBadge(context),
                SizedBox(height: layout.gap(8)),
                Text(
                  reel.title.isNotEmpty ? reel.title : _untitledLabel(reel),
                  style: GoogleFonts.spaceMono(
                    color: AppColors.fg(context),
                    fontSize: layout.font(10.5),
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: layout.gap(4)),
                if (reel.summary.isNotEmpty)
                  Expanded(
                    child: Text(
                      reel.summary,
                      style: GoogleFonts.spaceMono(
                        color: AppColors.textSec(context),
                        fontSize: layout.font(10),
                        height: 1.4,
                      ),
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                    ),
                  )
                else
                  const Spacer(),
                _buildBottomInfoRow(
                  context,
                  reel,
                  textColor: AppColors.fg(context),
                  secondaryColor: AppColors.textSec(context),
                  borderColor: AppColors.fg(context),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomInfoRow(
    BuildContext context,
    Reel reel, {
    required Color textColor,
    required Color secondaryColor,
    required Color borderColor,
    List<Shadow>? shadows,
  }) {
    final layout = AppLayout.of(context);
    final sourceBadge = _sourcePlatformBadge(context, reel);
    return Container(
      padding: EdgeInsets.only(top: layout.gap(6)),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: borderColor, width: 1.0)),
      ),
      child: Row(
        children: [
          if (sourceBadge != null) ...[
            sourceBadge,
            SizedBox(width: layout.inset(4)),
          ],
          Expanded(
            child: Text(
              reel.relativeDate.toUpperCase(),
              textAlign: TextAlign.right,
              style: GoogleFonts.spaceMono(
                color: textColor,
                fontSize: layout.font(9),
                fontWeight: FontWeight.w700,
                shadows: shadows,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnparsedBadge(BuildContext context) {
    final layout = AppLayout.of(context);
    return Container(
      margin: EdgeInsets.only(top: layout.gap(4)),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      color: AppColors.black.withAlpha(130),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.link_off, size: layout.font(9), color: AppColors.white),
          SizedBox(width: layout.inset(3)),
          Text(
            'LINK ONLY',
            style: GoogleFonts.spaceMono(
              color: AppColors.white,
              fontSize: layout.font(8, minFactor: 0.9),
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget? _sourcePlatformBadge(BuildContext context, Reel reel) {
    final layout = AppLayout.of(context);
    final platform = SourcePlatform.byId(reel.sourcePlatform);
    if (platform == null) return null;

    return Semantics(
      label: '${platform.name} source platform',
      image: true,
      child: ExcludeSemantics(
        child: Image.asset(
          platform.assetPath,
          width: layout.inset(14),
          height: layout.inset(14),
        ),
      ),
    );
  }

  String _untitledLabel(Reel reel) => 'UNTITLED ${_savedItemLabel(reel)}';

  String _savedItemLabel(Reel reel) =>
      SourcePlatform.byId(reel.sourcePlatform)?.savedItemNoun ?? 'REEL';

  Widget _buildCategoryTag(BuildContext context, String label, Color catColor) {
    final layout = AppLayout.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        return Align(
          alignment: Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: constraints.maxWidth),
            child: Container(
              color: AppColors.black.withAlpha(130),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: layout.inset(4),
                    height: layout.gap(18),
                    color: catColor,
                  ),
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      child: Text(
                        label.toUpperCase(),
                        style: GoogleFonts.spaceMono(
                          color: AppColors.white,
                          fontSize: layout.font(8, minFactor: 0.9),
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showDeleteSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
        decoration: BoxDecoration(color: AppColors.bg(ctx)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, color: AppColors.fg(ctx)),
            const SizedBox(height: 20),
            Text(
              widget.reel.title.toUpperCase(),
              style: GoogleFonts.spaceMono(
                color: AppColors.fg(ctx),
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmDelete(context);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: AppTheme.brutalBox(
                    ctx,
                    color: AppColors.destructive,
                    shadow: true,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'DELETE ${_savedItemLabel(widget.reel)}',
                    style: GoogleFonts.spaceMono(
                      color: AppColors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: AppTheme.brutalBox(
                    ctx,
                    color: AppColors.bg(ctx),
                    shadow: false,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'CANCEL',
                    style: GoogleFonts.spaceMono(
                      color: AppColors.fg(ctx),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete this ${_savedItemLabel(widget.reel)}?',
      message: 'This action cannot be undone.',
    );
    if (confirmed == true) widget.onDelete?.call();
  }
}

/// Thumbnail image, tuned so a card that scrolls out of view and back in does
/// not visibly reload.
///
/// Two things make that happen:
///  * **Disk caching.** `Image.network` keeps nothing on disk, so every evicted
///    image costs another download. These are cached to disk and come back
///    instantly, even on the next cold start.
///  * **Decoding at display size.** A full-resolution thumbnail decodes to
///    several megabytes; a screenful of them blows past Flutter's image cache
///    budget and starts evicting images that are still on screen. Decoding to
///    the size actually painted cuts each one by an order of magnitude, so a
///    long scroll stays comfortably inside the cache.
class _ReelThumbnail extends StatelessWidget {
  const _ReelThumbnail({required this.url, required this.fallbackColor});

  final String url;
  final Color fallbackColor;

  /// Ceiling on decode width in physical pixels. Cards are at most half the
  /// screen wide, so this is generous even on a 3x phone, and it keeps one
  /// oversized source image from dominating the cache.
  static const _maxDecodeWidth = 720;

  @override
  Widget build(BuildContext context) {
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final targetWidth = constraints.hasBoundedWidth
            ? (constraints.maxWidth * devicePixelRatio).round()
            : _maxDecodeWidth;

        return CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          memCacheWidth: math.min(math.max(targetWidth, 1), _maxDecodeWidth),
          // Only fade the very first paint. A cache hit renders immediately,
          // which is what stops the flicker when scrolling back up.
          fadeInDuration: const Duration(milliseconds: 180),
          fadeOutDuration: Duration.zero,
          placeholderFadeInDuration: Duration.zero,
          placeholder: (_, _) => ColoredBox(color: fallbackColor.withAlpha(90)),
          errorWidget: (_, _, _) => ColoredBox(color: fallbackColor),
        );
      },
    );
  }
}

/// The empty box in the same corner, so an unpicked card still reads as
/// something that can be picked.
class _UnselectedTick extends StatelessWidget {
  const _UnselectedTick();

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    return Align(
      alignment: Alignment.bottomRight,
      child: Container(
        width: layout.inset(26),
        height: layout.inset(26),
        decoration: BoxDecoration(
          color: AppColors.bg(context).withAlpha(120),
          border: Border.all(color: AppColors.fg(context), width: 2),
        ),
      ),
    );
  }
}
