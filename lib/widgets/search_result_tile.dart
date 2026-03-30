import 'package:flutter/material.dart';

import '../models/search_result.dart';
import '../theme/app_theme.dart';
import '../widgets/category_badge.dart';
import '../screens/reel_detail_screen.dart';

class SearchResultTile extends StatelessWidget {
  final SearchResult result;

  const SearchResultTile({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final reel = result.reel;
    final catColor = AppTheme.getCategoryColor(reel.category);
    final score = result.relevanceScore;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ReelDetailScreen(reel: reel)),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.deepIndigo.withAlpha(200),
              AppTheme.amethyst.withAlpha(80),
            ],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.cream.withAlpha(15)),
          boxShadow: [
            BoxShadow(
              color: AppTheme.midnightPlum.withAlpha(60),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top row: badge + relevance ──
            Row(
              children: [
                CategoryBadge(category: reel.category, small: true),
                const Spacer(),
                // Relevance indicator with glow
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _scoreColor(score).withAlpha(40),
                        _scoreColor(score).withAlpha(20),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _scoreColor(score).withAlpha(50),
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        size: 11,
                        color: _scoreColor(score),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        result.relevancePercent,
                        style: TextStyle(
                          color: _scoreColor(score),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Title ──
            Text(
              reel.title.isNotEmpty ? reel.title : 'Untitled',
              style: TextStyle(
                color: AppTheme.cream,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            // ── Summary snippet ──
            if (reel.summary.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                reel.summary,
                style: TextStyle(
                  color: AppTheme.cream.withAlpha(120),
                  fontSize: 13,
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            // ── Footer ──
            if (reel.keyFacts.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    size: 13,
                    color: catColor.withAlpha(180),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${reel.keyFacts.length} key fact${reel.keyFacts.length == 1 ? '' : 's'}',
                      style: TextStyle(
                        color: AppTheme.cream.withAlpha(70),
                        fontSize: 11,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    size: 16,
                    color: AppTheme.cream.withAlpha(50),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _scoreColor(double score) {
    if (score >= 0.8) return const Color(0xFF7DC4A5); // warm green
    if (score >= 0.5) return AppTheme.dustyRose;
    return const Color(0xFFE8926F); // warm orange
  }
}
