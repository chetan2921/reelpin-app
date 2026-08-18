import 'package:flutter/material.dart';

import 'package:reelpin/constants/app_colors.dart';
import 'package:reelpin/constants/app_theme.dart';

/// The app's toggle: a hard-edged track with a square thumb.
///
/// Material's Switch is a rounded pill with a circular thumb, which is the one
/// shape this design does not use anywhere else.
class AppSwitch extends StatelessWidget {
  const AppSwitch({super.key, required this.value, required this.onChanged});

  final bool value;

  /// Null disables the toggle, matching Switch's own contract.
  final ValueChanged<bool>? onChanged;

  static const double _width = 52;
  static const double _height = 30;
  static const double _padding = 3;

  @override
  Widget build(BuildContext context) {
    final isEnabled = onChanged != null;
    final thumbSize = _height - _padding * 2 - AppTheme.borderWidth * 2;

    return Semantics(
      toggled: value,
      child: GestureDetector(
        onTap: isEnabled ? () => onChanged!(!value) : null,
        behavior: HitTestBehavior.opaque,
        child: Opacity(
          opacity: isEnabled ? 1 : 0.5,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOut,
            width: _width,
            height: _height,
            padding: const EdgeInsets.all(_padding),
            decoration: AppTheme.brutalBox(
              context,
              color: value
                  ? AppColors.yellow
                  : AppColors.surfaceElevatedColor(context),
              shadow: false,
            ),
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOut,
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: thumbSize,
                height: thumbSize,
                color: value ? AppColors.black : AppColors.fg(context),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
