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
    final layout = AppLayout.of(context);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ReelDetailScreen.withProviders(context, reel: reel),
          ),
        );
      },
      child: Container(
        padding: EdgeInsets.all(layout.inset(14)),
        decoration: AppTheme.brutalCard(context),
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
                        border: Border.all(
                          color: AppTheme.fg(context),
                          width: 2,
                        ),
                      ),
                      child: Text(
                        reel.category.toUpperCase(),
                        style: GoogleFonts.spaceMono(
                          color: _contrastText(catColor),
                          fontSize: layout.font(9),
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: layout.gap(12)),

            // Title
            Text(
              reel.title.isNotEmpty ? reel.title : 'UNTITLED',
              style: GoogleFonts.spaceMono(
                color: AppTheme.fg(context),
                fontSize: layout.font(14),
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            // Summary
            if (reel.summary.isNotEmpty) ...[
              SizedBox(height: layout.gap(6)),
              Text(
                reel.summary,
                style: GoogleFonts.spaceMono(
                  color: AppTheme.textSec(context),
                  fontSize: layout.font(11),
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            // Relevance bar (thick, flat, no rounded ends)
            SizedBox(height: layout.gap(12)),
            Container(
              height: layout.gap(4),
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppTheme.surfaceElevatedColor(context),
                border: Border.all(color: AppTheme.fg(context), width: 1),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: score.clamp(0.0, 1.0),
                child: Container(color: _scoreColor(score)),
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
