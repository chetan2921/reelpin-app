import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:reelpin/constants/app_colors.dart';
import 'package:reelpin/constants/app_layout.dart';
import 'package:reelpin/constants/app_theme.dart';
import 'package:reelpin/data_models/app_config/remote_config.dart';
import 'package:reelpin/utils/app_logger.dart';
import 'package:reelpin/utils/app_store_links.dart';

/// Asks for a store update. A hard requirement has no way past: no close
/// button, back does nothing, and the store button is the only action. A soft
/// one is a dismissible nudge.
class UpdateRequiredScreen extends StatelessWidget {
  const UpdateRequiredScreen({super.key, required this.requirement});

  final UpdateRequirement requirement;

  bool get _isHard => requirement.hard;

  Future<void> _openStore() async {
    final configured = Uri.tryParse(
      requirement.storeUrlFor(defaultTargetPlatform),
    );
    try {
      if (configured != null && configured.hasScheme) {
        await launchUrl(configured, mode: LaunchMode.externalApplication);
      } else {
        await launchStoreListing();
      }
    } catch (e) {
      AppLogger.error('Store listing launch failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);

    return PopScope(
      canPop: !_isHard,
      child: Scaffold(
        backgroundColor: AppColors.bg(context),
        body: SafeArea(
          child: Padding(
            padding: layout.pagePadding(horizontal: 22, top: 18, bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: _isHard
                      ? SizedBox(height: layout.inset(48))
                      : IconButton(
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
                                    Icons.system_update_outlined,
                                    color: AppColors.black,
                                    size: 38,
                                  ),
                                ),
                                SizedBox(height: layout.gap(28)),
                                Text(
                                  requirement.title.isEmpty
                                      ? 'UPDATE REELPIN'
                                      : requirement.title,
                                  style: GoogleFonts.spaceMono(
                                    color: AppColors.fg(context),
                                    fontSize: layout.font(28),
                                    fontWeight: FontWeight.w700,
                                    height: 1.2,
                                  ),
                                ),
                                SizedBox(height: layout.gap(16)),
                                Text(
                                  requirement.body.isNotEmpty
                                      ? requirement.body
                                      : _isHard
                                      ? 'THIS VERSION OF REELPIN IS NO LONGER SUPPORTED. UPDATE TO KEEP USING IT.'
                                      : 'A NEWER VERSION OF REELPIN IS READY IN THE STORE.',
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
                    onPressed: _openStore,
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
                      'UPDATE NOW',
                      style: GoogleFonts.spaceMono(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                if (!_isHard) ...[
                  SizedBox(height: layout.gap(10)),
                  SizedBox(
                    width: double.infinity,
                    height: layout.gap(48),
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        'NOT NOW',
                        style: GoogleFonts.spaceMono(
                          color: AppColors.fg(context),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
