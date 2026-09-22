part of '../collection_detail_screen.dart';

/// PINS / ASK, drawn like the ALL / SAVED tabs in the map search sheet: one
/// bordered bar split down the middle. PINS is this screen; ASK opens the
/// collection's own chat screen on top of it, so PINS is always the half
/// shown selected here. Labelled ASK rather than CHATS: this is where the
/// collection is brainstormed over, and "chats" would be confused with the
/// app's own private ASK YOUR SAVES screen.
class _CollectionTabBar extends StatelessWidget {
  const _CollectionTabBar({required this.onAsk});

  final VoidCallback onAsk;

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);

    return Container(
      decoration: AppTheme.brutalBox(context, shadow: false),
      child: Row(
        children: [
          Expanded(
            child: _tab(context, label: 'PINS', selected: true, onTap: null),
          ),
          Container(
            width: AppTheme.borderWidth,
            height: layout.inset(42),
            color: AppColors.fg(context),
          ),
          Expanded(
            child: _tab(context, label: 'ASK', selected: false, onTap: onAsk),
          ),
        ],
      ),
    );
  }

  Widget _tab(
    BuildContext context, {
    required String label,
    required bool selected,
    required VoidCallback? onTap,
  }) {
    final layout = AppLayout.of(context);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: layout.inset(42),
        color: selected ? AppColors.yellow : AppColors.bg(context),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.spaceMono(
            color: selected ? AppColors.black : AppColors.fg(context),
            fontSize: layout.font(11),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
