part of '../home_screen.dart';

/// One selectable social in the filter sheet: artwork, name, and how many saves
/// it holds. [platformId] is null for the "all platforms" tile.
///
/// The label comes from the backend rather than [SourcePlatform] so a platform
/// the app has no artwork for — the `other` bucket that holds legacy saves —
/// still renders with the right name instead of being dropped.
class _PlatformFilterTile extends StatelessWidget {
  const _PlatformFilterTile({
    required this.platformId,
    required this.label,
    required this.count,
    required this.isSelected,
    required this.onTap,
  });

  final String? platformId;
  final String label;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    final accent = _platformAccentColor(platformId);
    final background = isSelected ? accent : AppColors.bg(context);
    final foreground = isSelected
        ? (accent.computeLuminance() > 0.5 ? AppColors.black : AppColors.white)
        : AppColors.fg(context);

    return Semantics(
      button: true,
      selected: isSelected,
      label: '$label, $count saved',
      child: ExcludeSemantics(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: layout.inset(10),
              vertical: layout.gap(8),
            ),
            decoration: AppTheme.brutalBox(
              context,
              color: background,
              shadow: isSelected,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _PlatformArtwork(
                  platformId: platformId,
                  size: layout.inset(20),
                ),
                SizedBox(width: layout.inset(8)),
                Text(
                  label,
                  style: GoogleFonts.spaceMono(
                    color: foreground,
                    fontSize: layout.font(10.5),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(width: layout.inset(8)),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: layout.inset(6),
                    vertical: layout.gap(2),
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.bg(context)
                        : AppColors.surfaceElevatedColor(context),
                    border: Border.all(color: AppColors.fg(context), width: 1.5),
                  ),
                  child: Text(
                    '$count',
                    style: GoogleFonts.spaceMono(
                      color: AppColors.fg(context),
                      fontSize: layout.font(9),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The platform's logo, or a neutral mark when the app has no artwork for it
/// (the `other` bucket, or a platform the backend adds before the app ships
/// an icon for it).
class _PlatformArtwork extends StatelessWidget {
  const _PlatformArtwork({required this.platformId, required this.size});

  final String? platformId;
  final double size;

  @override
  Widget build(BuildContext context) {
    final platform = SourcePlatform.byId(platformId);
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.12),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: AppColors.black, width: 1.5),
      ),
      child: platform != null
          ? Image.asset(platform.assetPath)
          : Icon(
              platformId == null ? Icons.apps : Icons.link,
              color: AppColors.black,
              size: size * 0.62,
            ),
    );
  }
}

/// Stable per-platform colour from the shared brutalist palette. Keying it on
/// the platform id means the same social always reads the same colour across
/// the sheet.
Color _platformAccentColor(String? platformId) {
  if (platformId == null) return AppColors.yellow;
  return AppColors.getCategoryColor(platformId);
}
