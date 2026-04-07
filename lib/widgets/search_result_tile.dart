import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/search_result.dart';
import '../theme/app_theme.dart';
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
        padding: const EdgeInsets.all(14),
        decoration: AppTheme.brutalCard(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: catColor,
                        border: Border.all(color: AppTheme.black, width: 2),
                      ),
                      child: Text(
                        reel.category.toUpperCase(),
                        style: GoogleFonts.spaceMono(
                          color: _contrastText(catColor),
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: _scoreColor(score),
                    border: Border.all(color: AppTheme.black, width: 2),
                  ),
                  child: Text(
                    result.relevancePercent,
                    style: GoogleFonts.spaceMono(
                      color: _contrastText(_scoreColor(score)),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Title
            Text(
              reel.title.isNotEmpty ? reel.title : 'UNTITLED',
              style: GoogleFonts.spaceMono(
                color: AppTheme.black,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            // Summary
            if (reel.summary.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                reel.summary,
                style: GoogleFonts.spaceMono(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            // Relevance bar (thick, flat, no rounded ends)
            const SizedBox(height: 12),
            Container(
              height: 4,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppTheme.surfaceElevated,
                border: Border.all(color: AppTheme.black, width: 1),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: score.clamp(0.0, 1.0),
                child: Container(
                  color: _scoreColor(score),
                ),
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

  Color _scoreColor(double score) {
    if (score >= 0.8) return AppTheme.neonGreen;
    if (score >= 0.5) return AppTheme.yellow;
    return AppTheme.orange;
  }
}
