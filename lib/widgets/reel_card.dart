import 'package:flutter/material.dart';

import '../models/reel.dart';
import '../theme/app_theme.dart';
import '../widgets/category_badge.dart';

class ReelCard extends StatefulWidget {
  final Reel reel;
  final VoidCallback onTap;

  const ReelCard({super.key, required this.reel, required this.onTap});

  @override
  State<ReelCard> createState() => _ReelCardState();
}

class _ReelCardState extends State<ReelCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
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
    final categoryColor = AppTheme.getCategoryColor(reel.category);

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnim,
        builder: (context, child) {
          return Transform.scale(scale: _scaleAnim.value, child: child);
        },
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.deepIndigo.withAlpha(200),
                AppTheme.amethyst.withAlpha(80),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.cream.withAlpha(15)),
            boxShadow: [
              BoxShadow(
                color: AppTheme.midnightPlum.withAlpha(80),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Gradient accent strip ──
              Container(
                height: 5,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [categoryColor, categoryColor.withAlpha(60)],
                  ),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                ),
              ),

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Category badge ──
                      CategoryBadge(category: reel.category, small: true),
                      const SizedBox(height: 10),

                      // ── Title ──
                      Text(
                        reel.title.isNotEmpty ? reel.title : 'Untitled Reel',
                        style: TextStyle(
                          color: AppTheme.cream,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),

                      // ── Summary ──
                      if (reel.summary.isNotEmpty)
                        Expanded(
                          child: Text(
                            reel.summary,
                            style: TextStyle(
                              color: AppTheme.cream.withAlpha(130),
                              fontSize: 12,
                              height: 1.4,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),

                      const SizedBox(height: 8),

                      // ── Footer row ──
                      Row(
                        children: [
                          if (reel.hasMapLocations) ...[
                            Icon(
                              Icons.location_on,
                              size: 13,
                              color: categoryColor.withAlpha(200),
                            ),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                reel.locations.first.name,
                                style: TextStyle(
                                  color: AppTheme.cream.withAlpha(90),
                                  fontSize: 11,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ] else
                            const Spacer(),
                          if (reel.displayDate.isNotEmpty)
                            Text(
                              reel.displayDate,
                              style: TextStyle(
                                color: AppTheme.cream.withAlpha(70),
                                fontSize: 11,
                              ),
                            ),
                        ],
                      ),
                    ],
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
