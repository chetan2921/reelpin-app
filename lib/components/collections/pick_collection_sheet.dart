import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:reelpin/components/collections/collection_folder_tile.dart';
import 'package:reelpin/constants/app_colors.dart';
import 'package:reelpin/constants/app_layout.dart';
import 'package:reelpin/constants/app_theme.dart';
import 'package:reelpin/data_models/collections/collection_models.dart';
import 'package:reelpin/providers.dart';

/// Picks the one collection an answer gets added to. Returns null if the
/// sheet is dismissed.
Future<CollectionSummary?> showPickCollectionSheet(
  BuildContext context, {
  String? excludeCollectionId,
}) {
  return showModalBottomSheet<CollectionSummary>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) =>
        PickCollectionSheet(excludeCollectionId: excludeCollectionId),
  );
}

/// Single-select, and it acts on the tap — unlike `AddToCollectionSheet`,
/// which multi-selects and then confirms. An answer lands in exactly one
/// thread, so a confirm step would be a second tap that decides nothing.
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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(collectionsViewModelProvider).loadCollections();
    });
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
                "IT GOES INTO THAT COLLECTION'S CHAT, FOR EVERYONE IN IT.",
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
          onTap: () => Navigator.of(context).pop(collection),
        );
      },
    );
  }
}
