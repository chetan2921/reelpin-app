import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:reelpin/constants/app_colors.dart';
import 'package:reelpin/constants/app_layout.dart';
import 'package:reelpin/constants/app_theme.dart';
import 'package:reelpin/data_models/reels/reel.dart';

/// A stripped-down `ReelCard` for the chat citation strip.
///
/// At strip size the category tag, source badge and relative date read as
/// clutter, so this keeps only the thumbnail, the title and the overhanging
/// pin — the same border, shadow and pin geometry as `ReelCard`, so it still
/// reads as the same kind of object. Does not touch `ReelCard` itself, which
/// the Home grid still depends on for its fuller layout.
class ChatReelStripCard extends StatelessWidget {
  const ChatReelStripCard({super.key, required this.reel, required this.onTap});

  final Reel reel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    final hasThumbnail = reel.thumbnailUrl.trim().isNotEmpty;
    final catColor = AppColors.getCategoryColor(reel.category);

    return GestureDetector(
      onTap: onTap,
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
              boxShadow: AppTheme.brutalShadow(context),
            ),
            clipBehavior: Clip.antiAlias,
            child: hasThumbnail
                ? _buildThumbnail(context, catColor)
                : _buildPlain(context),
          ),
          // The pin, scaled down to this smaller card — same corner overhang
          // proportion as ReelCard, just smaller throughout.
          Positioned(
            right: -layout.inset(4),
            top: -layout.gap(4),
            child: Image.asset(
              'assets/images/pin.png',
              width: layout.inset(18),
              height: layout.inset(18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThumbnail(BuildContext context, Color catColor) {
    final layout = AppLayout.of(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: AppColors.black),
        CachedNetworkImage(
          imageUrl: reel.thumbnailUrl,
          fit: BoxFit.cover,
          fadeInDuration: const Duration(milliseconds: 180),
          fadeOutDuration: Duration.zero,
          placeholderFadeInDuration: Duration.zero,
          placeholder: (_, _) => ColoredBox(color: catColor.withAlpha(90)),
          errorWidget: (_, _, _) => ColoredBox(color: catColor),
        ),
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
          child: Align(
            alignment: Alignment.bottomLeft,
            child: _title(
              context,
              color: AppColors.white,
              shadows: [
                Shadow(
                  color: AppColors.black.withAlpha(190),
                  offset: const Offset(1, 1),
                  blurRadius: 2,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlain(BuildContext context) {
    final layout = AppLayout.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        layout.inset(10),
        layout.gap(10),
        layout.inset(10),
        layout.gap(8),
      ),
      child: Align(
        alignment: Alignment.bottomLeft,
        child: _title(context, color: AppColors.fg(context)),
      ),
    );
  }

  Widget _title(
    BuildContext context, {
    required Color color,
    List<Shadow>? shadows,
  }) {
    final layout = AppLayout.of(context);
    return Text(
      reel.title.isNotEmpty ? reel.title : 'UNTITLED',
      style: GoogleFonts.spaceMono(
        color: color,
        fontSize: layout.font(11),
        fontWeight: FontWeight.w700,
        height: 1.3,
        shadows: shadows,
      ),
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
    );
  }
}
