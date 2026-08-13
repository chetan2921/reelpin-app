import 'package:flutter/material.dart';

import 'package:reelpin/constants/app_colors.dart';
import 'package:reelpin/constants/app_layout.dart';

/// The app's one back affordance: just the arrow.
///
/// Replaces three separate implementations — a bordered box in the collection
/// detail, a thinner shadowless one in the reel detail, and a bare Material
/// IconButton in the profile — which made going back look like a different app
/// depending on where you were.
///
/// Deliberately undecorated. A brutal box here competed with the screen title
/// and the action buttons beside it, and back is the one control that should
/// never draw attention. The 40x40 footprint stays so the tap target and
/// alignment are unchanged.
class AppBackButton extends StatelessWidget {
  const AppBackButton({super.key, this.onTap});

  /// Defaults to popping the current route.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    return GestureDetector(
      onTap: onTap ?? () => Navigator.pop(context),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: layout.inset(40),
        height: layout.inset(40),
        child: Icon(
          Icons.arrow_back,
          color: AppColors.fg(context),
          size: layout.inset(22),
        ),
      ),
    );
  }
}
