import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:reelpin/constants/app_colors.dart';
import 'package:reelpin/constants/app_layout.dart';

/// The bottom-right selection mark, drawn the same everywhere something can be
/// picked: the collection picker, the Home grid in selection mode, and the
/// native share sheets (which draw their own copy of this in Kotlin/Swift).
///
/// A solid square in the foreground colour with the tick punched out of it in
/// the background colour, hard-edged like the rest of the app.
class SelectionTick extends StatelessWidget {
  const SelectionTick({super.key});

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    return Align(
      alignment: Alignment.bottomRight,
      child: Container(
        width: layout.inset(26),
        height: layout.inset(26),
        color: AppColors.fg(context),
        alignment: Alignment.center,
        child: Text(
          '✓',
          style: GoogleFonts.spaceMono(
            color: AppColors.bg(context),
            fontSize: layout.font(15),
            fontWeight: FontWeight.w700,
            height: 1,
          ),
        ),
      ),
    );
  }
}
