import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/reel.dart';
import '../theme/app_theme.dart';

class ReelCard extends StatefulWidget {
  final Reel reel;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const ReelCard({
    super.key,
    required this.reel,
    required this.onTap,
    this.onDelete,
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
    final catColor = AppTheme.getCategoryColor(reel.category);
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
      onLongPress: widget.onDelete != null
          ? () => _showDeleteSheet(context)
          : null,
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
                color: AppTheme.bg(context),
                border: Border.all(
                  color: AppTheme.fg(context),
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
                  color: AppTheme.black,
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
          ],
        ),
      ),
    );
  }

  Color _contrastText(Color bg) {
    return bg.computeLuminance() > 0.5 ? AppTheme.black : AppTheme.white;
  }

  Widget _buildThumbnailCard(BuildContext context, Reel reel, Color catColor) {
    final layout = AppLayout.of(context);
    final textShadow = [
      Shadow(
        color: AppTheme.black.withAlpha(190),
        offset: const Offset(1, 1),
        blurRadius: 2,
      ),
    ];

    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: AppTheme.black),
        Opacity(
          opacity: 0.32,
          child: Image.network(
            reel.thumbnailUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(color: catColor),
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(color: catColor.withAlpha(90));
            },
          ),
        ),
        Image.network(
          reel.thumbnailUrl,
          fit: BoxFit.contain,
          alignment: Alignment.center,
          errorBuilder: (_, _, _) => Container(color: catColor),
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(color: catColor.withAlpha(90));
          },
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppTheme.black.withAlpha(70),
                AppTheme.black.withAlpha(115),
                AppTheme.black.withAlpha(225),
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
              const Spacer(),
              Text(
                reel.title.isNotEmpty ? reel.title : 'UNTITLED REEL',
                style: GoogleFonts.spaceMono(
                  color: AppTheme.white,
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
                textColor: AppTheme.white,
                secondaryColor: AppTheme.white.withAlpha(210),
                borderColor: AppTheme.white,
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
                SizedBox(height: layout.gap(8)),
                Text(
                  reel.title.isNotEmpty ? reel.title : 'UNTITLED REEL',
                  style: GoogleFonts.spaceMono(
                    color: AppTheme.fg(context),
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
                        color: AppTheme.textSec(context),
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
                  textColor: AppTheme.fg(context),
                  secondaryColor: AppTheme.textSec(context),
                  borderColor: AppTheme.fg(context),
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
    return Container(
      padding: EdgeInsets.only(top: layout.gap(6)),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: borderColor, width: 1.0)),
      ),
      child: Row(
        children: [
          if (reel.hasMapLocations) ...[
            Icon(Icons.location_on, size: layout.inset(12), color: textColor),
            SizedBox(width: layout.inset(2)),
          ],
          Expanded(
            child: Text(
              reel.hasMapLocations
                  ? reel.primaryLocationLabel.toUpperCase()
                  : reel.relativeDate.toUpperCase(),
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
          if (reel.hasMapLocations && reel.relativeDate.isNotEmpty)
            Text(
              reel.relativeDate.toUpperCase(),
              style: GoogleFonts.spaceMono(
                color: secondaryColor,
                fontSize: layout.font(9),
                fontWeight: FontWeight.w700,
                shadows: shadows,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCategoryTag(BuildContext context, String label, Color catColor) {
    final layout = AppLayout.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: catColor,
          border: Border.all(color: AppTheme.fg(context), width: 1.5),
        ),
        child: Text(
          label.toUpperCase(),
          style: GoogleFonts.spaceMono(
            color: _contrastText(catColor),
            fontSize: layout.font(8, minFactor: 0.9),
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  void _showDeleteSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
        decoration: AppTheme.brutalCard(ctx, color: AppTheme.bg(ctx)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, color: AppTheme.fg(ctx)),
            const SizedBox(height: 20),
            Text(
              widget.reel.title.toUpperCase(),
              style: GoogleFonts.spaceMono(
                color: AppTheme.fg(ctx),
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
                    color: AppTheme.destructive,
                    shadow: true,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'DELETE REEL',
                    style: GoogleFonts.spaceMono(
                      color: AppTheme.white,
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
                    color: AppTheme.bg(ctx),
                    shadow: false,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'CANCEL',
                    style: GoogleFonts.spaceMono(
                      color: AppTheme.fg(ctx),
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

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bg(ctx),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(0),
          side: BorderSide(
            color: AppTheme.fg(ctx),
            width: AppTheme.borderWidth,
          ),
        ),
        title: Text(
          'DELETE THIS REEL?',
          style: GoogleFonts.spaceMono(
            color: AppTheme.fg(ctx),
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'This action cannot be undone.',
          style: GoogleFonts.spaceMono(
            color: AppTheme.textSec(ctx),
            fontSize: 13,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'CANCEL',
              style: GoogleFonts.spaceMono(
                color: AppTheme.textSec(ctx),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              Navigator.pop(ctx);
              widget.onDelete?.call();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.destructive,
                border: Border.all(color: AppTheme.fg(ctx), width: 2),
                boxShadow: AppTheme.brutalShadowSmall(ctx),
              ),
              child: Text(
                'DELETE',
                style: GoogleFonts.spaceMono(
                  color: AppTheme.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
