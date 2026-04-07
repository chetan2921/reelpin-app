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
                color: AppTheme.white,
                border: Border.all(
                  color: AppTheme.black,
                  width: AppTheme.borderWidth,
                ),
                boxShadow: _isPressed ? null : AppTheme.brutalShadow,
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Top accent bar (solid, no gradient) ──
                  Container(height: 6, color: catColor),

                  // ── Content ──
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Category tag
                          Padding(
                            padding: const EdgeInsets.only(right: 32),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: catColor,
                                border: Border.all(
                                  color: AppTheme.black,
                                  width: 1.5,
                                ),
                              ),
                              child: Text(
                                reel.subCategory.toUpperCase(),
                                style: GoogleFonts.spaceMono(
                                  color: _contrastText(catColor),
                                  fontSize: 8,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Title
                          Text(
                            reel.title.isNotEmpty
                                ? reel.title
                                : 'UNTITLED REEL',
                            style: GoogleFonts.spaceMono(
                              color: AppTheme.black,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),

                          // Summary
                          if (reel.summary.isNotEmpty)
                            Expanded(
                              child: Text(
                                reel.summary,
                                style: GoogleFonts.spaceMono(
                                  color: AppTheme.textSecondary,
                                  fontSize: 10,
                                  height: 1.4,
                                ),
                                maxLines: 6,
                                overflow: TextOverflow.ellipsis,
                              ),
                            )
                          else
                            const Spacer(),

                          // ── Bottom info row ──
                          Container(
                            padding: const EdgeInsets.only(top: 6),
                            decoration: const BoxDecoration(
                              border: Border(
                                top: BorderSide(
                                  color: AppTheme.black,
                                  width: 1,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                if (reel.hasMapLocations) ...[
                                  const Icon(
                                    Icons.location_on,
                                    size: 12,
                                    color: AppTheme.black,
                                  ),
                                  const SizedBox(width: 2),
                                ],
                                Expanded(
                                  child: Text(
                                    reel.hasMapLocations
                                        ? reel.locations.first.name
                                              .toUpperCase()
                                        : reel.relativeDate.toUpperCase(),
                                    style: GoogleFonts.spaceMono(
                                      color: AppTheme.black,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (reel.hasMapLocations &&
                                    reel.relativeDate.isNotEmpty)
                                  Text(
                                    reel.relativeDate.toUpperCase(),
                                    style: GoogleFonts.spaceMono(
                                      color: AppTheme.textSecondary,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // The tiny hole indicating pierced paper
            Positioned(
              right: 14,
              top: 14,
              child: Container(
                width: 5,
                height: 5,
                decoration: const BoxDecoration(
                  color: AppTheme.black,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            // The pin
            Positioned(
              right: -6,
              top: -6,
              child: Image.asset(
                'assets/images/pin.png',
                width: 26,
                height: 26,
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

  void _showDeleteSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
        decoration: BoxDecoration(
          color: AppTheme.white,
          border: Border.all(
            color: AppTheme.black,
            width: AppTheme.borderWidth,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, color: AppTheme.black),
            const SizedBox(height: 20),
            Text(
              widget.reel.title.toUpperCase(),
              style: GoogleFonts.spaceMono(
                color: AppTheme.black,
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
                    color: AppTheme.white,
                    shadow: false,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'CANCEL',
                    style: GoogleFonts.spaceMono(
                      color: AppTheme.black,
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
        backgroundColor: AppTheme.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(0),
          side: const BorderSide(
            color: AppTheme.black,
            width: AppTheme.borderWidth,
          ),
        ),
        title: Text(
          'DELETE THIS REEL?',
          style: GoogleFonts.spaceMono(
            color: AppTheme.black,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'This action cannot be undone.',
          style: GoogleFonts.spaceMono(
            color: AppTheme.textSecondary,
            fontSize: 13,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'CANCEL',
              style: GoogleFonts.spaceMono(
                color: AppTheme.textSecondary,
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
                border: Border.all(color: AppTheme.black, width: 2),
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
