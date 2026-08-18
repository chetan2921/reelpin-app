import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:reelpin/constants/app_colors.dart';
import 'package:reelpin/constants/app_layout.dart';

/// The app's one bottom sheet: brutal card chrome, a solid drag handle and a
/// monospace title.
///
/// Sheets had drifted — most used brutalCard on a transparent barrier, while
/// the share sheet used Material's showDragHandle and so arrived with rounded
/// corners and a grey pill, looking like a different app.
///
/// Pair with [showAppBottomSheet], which supplies the transparent background
/// the card needs to be the visible edge.
class AppBottomSheet extends StatelessWidget {
  const AppBottomSheet({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
    this.maxHeightFactor = 0.72,
    this.fillHeight = false,
  });

  final String title;
  final Widget child;

  /// One line under the title, for sheets that need a word of explanation.
  final String? subtitle;

  /// Optional action aligned with the title, e.g. a "+ NEW" button.
  final Widget? trailing;

  final double maxHeightFactor;

  /// Fill whatever height the sheet is given instead of hugging its content.
  /// For lists that can be any length, where a short list would otherwise
  /// leave a sheet too small to drag open.
  final bool fillHeight;

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: fillHeight
            ? double.infinity
            : MediaQuery.of(context).size.height * maxHeightFactor,
      ),
      child: Container(
        padding: EdgeInsets.fromLTRB(
          layout.inset(24),
          layout.gap(18),
          layout.inset(24),
          layout.gap(24),
        ),
        // No border: brutalCard outlines in AppColors.fg, which is white in
        // dark mode and drew a hard white frame around every sheet.
        decoration: BoxDecoration(color: AppColors.bg(context)),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: fillHeight ? MainAxisSize.max : MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: layout.inset(40),
                  height: layout.gap(4),
                  color: AppColors.fg(context),
                ),
              ),
              SizedBox(height: layout.gap(18)),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title.toUpperCase(),
                      style: GoogleFonts.spaceMono(
                        color: AppColors.fg(context),
                        fontSize: layout.font(17),
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  ?trailing,
                ],
              ),
              if (subtitle != null) ...[
                SizedBox(height: layout.gap(6)),
                Text(
                  subtitle!,
                  style: GoogleFonts.spaceMono(
                    color: AppColors.textSec(context),
                    fontSize: layout.font(11),
                    height: 1.4,
                  ),
                ),
              ],
              SizedBox(height: layout.gap(18)),
              if (fillHeight)
                Expanded(child: child)
              else
                Flexible(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

/// Presents [builder] with the transparent barrier the card chrome expects.
Future<T?> showAppBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: builder,
  );
}

/// A sheet the user can drag up to fill the screen, for content whose length
/// is unknown — a list of collaborators is one row or a hundred.
///
/// [builder] receives the controller its scrollable must use, or dragging the
/// sheet and scrolling the list fight each other.
Future<T?> showExpandableAppBottomSheet<T>({
  required BuildContext context,
  required Widget Function(ScrollController controller) builder,
  double initialSize = 0.55,
  double minSize = 0.3,
  double maxSize = 0.94,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: initialSize,
      minChildSize: minSize,
      maxChildSize: maxSize,
      builder: (context, controller) => builder(controller),
    ),
  );
}
