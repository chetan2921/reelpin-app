part of '../collection_detail_screen.dart';

/// PINS / CHATS, drawn like the ALL / SAVED tabs in the map search sheet: one
/// bordered bar split down the middle, the selected half filled yellow. They
/// switch between two screens inside one collection, not two filters over one
/// list.
class _CollectionTabBar extends StatelessWidget {
  const _CollectionTabBar({required this.chatSelected, required this.onSelect});

  final bool chatSelected;

  /// Called with true for CHATS, false for PINS.
  final ValueChanged<bool> onSelect;

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);

    return Container(
      decoration: AppTheme.brutalBox(context, shadow: false),
      child: Row(
        children: [
          Expanded(
            child: _tab(
              context,
              label: 'PINS',
              selected: !chatSelected,
              onTap: () => onSelect(false),
            ),
          ),
          Container(
            width: AppTheme.borderWidth,
            height: layout.inset(42),
            color: AppColors.fg(context),
          ),
          Expanded(
            child: _tab(
              context,
              label: 'CHATS',
              selected: chatSelected,
              onTap: () => onSelect(true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tab(
    BuildContext context, {
    required String label,
    required bool selected,
    required VoidCallback onTap,
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
