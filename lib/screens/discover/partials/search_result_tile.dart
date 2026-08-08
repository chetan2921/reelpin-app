import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:reelpin/data_models/discover/search_result.dart';
import 'package:reelpin/constants/app_layout.dart';
import 'package:reelpin/constants/app_colors.dart';
import 'package:reelpin/constants/app_theme.dart';
import 'package:reelpin/router.dart';

class SearchResultTile extends StatelessWidget {
  final SearchResult result;

  const SearchResultTile({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final reel = result.reel;
    final catColor = AppColors.getCategoryColor(reel.category);
    final layout = AppLayout.of(context);

    return GestureDetector(
      onTap: () {
        Navigator.push(context, reelDetailRoute(reel));
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
                          color: AppColors.fg(context),
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
                color: AppColors.fg(context),
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
                  color: AppColors.textSec(context),
                  fontSize: layout.font(11),
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _contrastText(Color bg) {
    return bg.computeLuminance() > 0.5 ? AppColors.black : AppColors.white;
  }
}
