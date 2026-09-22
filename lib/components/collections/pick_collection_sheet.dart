import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:reelpin/components/collections/collection_folder_tile.dart';
import 'package:reelpin/components/collections/selection_tick.dart';
import 'package:reelpin/constants/app_colors.dart';
import 'package:reelpin/constants/app_layout.dart';
import 'package:reelpin/constants/app_theme.dart';
import 'package:reelpin/data_models/collections/collection_models.dart';
import 'package:reelpin/providers.dart';

/// Picks one or more collections an answer gets added to. Returns null if the
/// sheet is dismissed with nothing selected.
Future<List<CollectionSummary>?> showPickCollectionSheet(
  BuildContext context, {
  String? excludeCollectionId,
}) {
  return showModalBottomSheet<List<CollectionSummary>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) =>
        PickCollectionSheet(excludeCollectionId: excludeCollectionId),
  );
}

/// Multi-select, same tap-to-check-then-confirm shape as
/// `AddToCollectionSheet`: a tap ticks a folder, nothing is written until
/// SAVE, so a mis-tap costs nothing.
class PickCollectionSheet extends ConsumerStatefulWidget {
  const PickCollectionSheet({super.key, this.excludeCollectionId});

  /// The collection the answer is already in, when adding from a collection's
  /// own chat. Left out, since adding it there again would only duplicate it.
  final String? excludeCollectionId;

  @override
  ConsumerState<PickCollectionSheet> createState() =>
      _PickCollectionSheetState();
}

class _PickCollectionSheetState extends ConsumerState<PickCollectionSheet> {
  final Set<String> _selected = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(collectionsViewModelProvider).loadCollections();
    });
  }

  void _toggle(String collectionId) {
    setState(() {
      if (!_selected.remove(collectionId)) _selected.add(collectionId);
    });
  }

  void _save(List<CollectionSummary> editable) {
    if (_selected.isEmpty) return;
    final picked = editable.where((c) => _selected.contains(c.id)).toList();
    Navigator.of(context).pop(picked);
  }

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    final vm = ref.watch(collectionsViewModelProvider);
    // A viewer's post is refused by the server, so offering a collection you
    // can only read would be offering a guaranteed failure.
    final editable = vm.collections
        .where((c) => c.canEdit && c.id != widget.excludeCollectionId)
        .toList();
    // Built from every collection, not just the editable ones, so each folder
    // keeps the colour it has on SAVED.
    final accents = CollectionFolderTile.accentsFor(vm.collections);
    final maxHeight = MediaQuery.of(context).size.height * 0.72;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Container(
        padding: EdgeInsets.fromLTRB(
          layout.inset(24),
          layout.gap(18),
          layout.inset(24),
          layout.gap(24),
        ),
        decoration: BoxDecoration(color: AppColors.bg(context)),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
              Text(
                'ADD TO COLLECTION',
                style: GoogleFonts.spaceMono(
                  color: AppColors.fg(context),
                  fontSize: layout.font(17),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
              SizedBox(height: layout.gap(6)),
              Text(
                "IT GOES INTO EACH COLLECTION'S CHAT, FOR EVERYONE IN IT.",
                style: GoogleFonts.spaceMono(
                  color: AppColors.textSec(context),
                  fontSize: layout.font(10),
                  letterSpacing: 1,
                ),
              ),
              SizedBox(height: layout.gap(16)),
              Flexible(
                child: _buildBody(
                  context,
                  vm.isLoadingCollections,
                  editable,
                  accents,
                ),
              ),
              if (editable.isNotEmpty) ...[
                SizedBox(height: layout.gap(16)),
                _SaveButton(
                  count: _selected.length,
                  onTap: _selected.isEmpty ? null : () => _save(editable),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    bool isLoading,
    List<CollectionSummary> editable,
    Map<String, Color> accents,
  ) {
    final layout = AppLayout.of(context);

    if (isLoading && editable.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: layout.gap(28)),
        child: Center(
          child: CircularProgressIndicator(
            color: AppColors.fg(context),
            strokeWidth: 2.5,
          ),
        ),
      );
    }

    if (editable.isEmpty) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(layout.inset(16)),
        decoration: AppTheme.brutalBox(
          context,
          color: AppColors.surfaceElevatedColor(context),
          shadow: false,
        ),
        child: Text(
          'NO COLLECTIONS YOU CAN POST IN. YOU NEED TO OWN OR EDIT ONE.',
          textAlign: TextAlign.center,
          style: GoogleFonts.spaceMono(
            color: AppColors.textSec(context),
            fontSize: layout.font(11),
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      padding: EdgeInsets.only(top: layout.gap(4)),
      itemCount: editable.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: layout.gap(12),
        crossAxisSpacing: layout.inset(12),
        childAspectRatio: 1.2,
      ),
      itemBuilder: (context, index) {
        final collection = editable[index];
        return CollectionFolderTile(
          collection: collection,
          accent: accents[collection.id]!,
          onTap: () => _toggle(collection.id),
          overlay: _selected.contains(collection.id)
              ? const SelectionTick()
              : null,
        );
      },
    );
  }
}

/// The confirm step. Nothing is written until this is tapped, so a mis-tap on
/// a folder costs nothing.
class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.count, required this.onTap});

  final int count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    final label = switch (count) {
      0 => 'SELECT A COLLECTION',
      1 => 'ADD TO 1 COLLECTION',
      _ => 'ADD TO $count COLLECTIONS',
    };
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Opacity(
        opacity: onTap == null ? 0.5 : 1,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: layout.gap(14)),
          alignment: Alignment.center,
          decoration: AppTheme.brutalBox(context, color: AppColors.yellow),
          child: Text(
            label,
            style: GoogleFonts.spaceMono(
              color: AppColors.black,
              fontSize: layout.font(13),
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
        ),
      ),
    );
  }
}
