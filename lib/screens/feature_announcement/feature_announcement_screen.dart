import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:reelpin/constants/app_layout.dart';
import 'package:reelpin/constants/app_colors.dart';
import 'package:reelpin/constants/app_theme.dart';

class FeatureAnnouncementScreen extends StatelessWidget {
  const FeatureAnnouncementScreen({
    super.key,
    required this.title,
    required this.body,
  });

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);

    return Scaffold(
      backgroundColor: AppColors.bg(context),
      body: SafeArea(
        child: Padding(
          padding: layout.pagePadding(horizontal: 22, top: 18, bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close, color: AppColors.fg(context)),
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: IntrinsicHeight(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Spacer(),
                              Container(
                                width: layout.inset(76),
                                height: layout.inset(76),
                                decoration: AppTheme.brutalBox(
                                  context,
                                  color: AppColors.yellow,
                                ),
                                child: const Icon(
                                  Icons.campaign_outlined,
                                  color: AppColors.black,
                                  size: 38,
                                ),
                              ),
                              SizedBox(height: layout.gap(28)),
                              Text(
                                title.trim().isEmpty
                                    ? 'WHAT\'S NEW IN REELPIN'
                                    : title,
                                style: GoogleFonts.spaceMono(
                                  color: AppColors.fg(context),
                                  fontSize: layout.font(28),
                                  fontWeight: FontWeight.w700,
                                  height: 1.2,
                                ),
                              ),
                              SizedBox(height: layout.gap(16)),
                              Text(
                                body.trim().isEmpty
                                    ? 'OPEN REELPIN TO SEE THE LATEST UPDATE.'
                                    : body,
                                style: GoogleFonts.spaceMono(
                                  color: AppColors.textSec(context),
                                  fontSize: layout.font(15),
                                  fontWeight: FontWeight.w700,
                                  height: 1.5,
                                ),
                              ),
                              const Spacer(flex: 2),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              SizedBox(
                width: double.infinity,
                height: layout.gap(54),
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.yellow,
                    foregroundColor: AppColors.black,
                    shape: RoundedRectangleBorder(
                      side: BorderSide(
                        color: AppColors.fg(context),
                        width: AppTheme.borderWidth,
                      ),
                    ),
                  ),
                  child: Text(
                    'BACK TO REELPIN',
                    style: GoogleFonts.spaceMono(fontWeight: FontWeight.w700),
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
