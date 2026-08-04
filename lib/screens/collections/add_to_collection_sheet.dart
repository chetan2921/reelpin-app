import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:reelpin/components/collections/collection_folder_tile.dart';
import 'package:reelpin/constants/app_colors.dart';
import 'package:reelpin/constants/app_layout.dart';
import 'package:reelpin/constants/app_theme.dart';
import 'package:reelpin/data_models/collections/collection_models.dart';
import 'package:reelpin/providers.dart';
import 'package:reelpin/screens/collections/collection_form_sheet.dart';
import 'package:reelpin/utils/error_message.dart';

Future<void> showAddToCollectionSheet(BuildContext context, String reelId) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => AddToCollectionSheet(reelId: reelId),
  );
}

class AddToCollectionSheet extends ConsumerStatefulWidget {
  const AddToCollectionSheet({super.key, required this.reelId});

  final String reelId;

  @override
  ConsumerState<AddToCollectionSheet> createState() =>
      _AddToCollectionSheetState();
}

class _AddToCollectionSheetState extends ConsumerState<AddToCollectionSheet> {
  final Set<String> _added = {};
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(collectionsViewModelProvider).loadCollections();
    });
  }

  Future<void> _addTo(String collectionId) async {
    if (_busy.contains(collectionId) || _added.contains(collectionId)) return;
    setState(() => _busy.add(collectionId));
    try {
      await ref
          .read(collectionsViewModelProvider)
          .addReels(collectionId: collectionId, reelIds: [widget.reelId]);
      if (mounted) setState(() => _added.add(collectionId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              userFacingErrorMessage(
                e,
                fallbackMessage: 'Could not add to that collection.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy.remove(collectionId));
    }
  }

  Future<void> _createAndAdd() async {
    final created = await showCollectionFormSheet(context);
    if (created == null || !mounted) return;
    // _addTo marks it added on success.
    await _addTo(created.id);
  }

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    final vm = ref.watch(collectionsViewModelProvider);
    final editable = vm.collections.where((c) => c.canEdit).toList();
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
        decoration: AppTheme.brutalCard(context, color: AppColors.bg(context)),
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
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'ADD TO COLLECTION',
                      style: GoogleFonts.spaceMono(
                        color: AppColors.fg(context),
                        fontSize: layout.font(17),
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: vm.isMutating ? null : _createAndAdd,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: layout.inset(12),
                        vertical: layout.gap(8),
                      ),
                      decoration: AppTheme.brutalBox(
                        context,
                        color: AppColors.yellow,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.add,
                            color: AppColors.black,
                            size: layout.inset(14),
                          ),
                          SizedBox(width: layout.inset(4)),
                          Text(
                            'NEW',
                            style: GoogleFonts.spaceMono(
                              color: AppColors.black,
                              fontSize: layout.font(10),
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: layout.gap(16)),
              Flexible(
                child: _buildBody(context, vm.isLoadingCollections, editable),
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
          'NO COLLECTIONS YET. TAP NEW TO MAKE ONE.',
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
        childAspectRatio: 1.22,
      ),
      itemBuilder: (context, index) {
        final collection = editable[index];
        final isAdded = _added.contains(collection.id);
        final isBusy = _busy.contains(collection.id);
        return CollectionFolderTile(
          collection: collection,
          index: index,
          compact: true,
          onTap: isBusy || isAdded ? null : () => _addTo(collection.id),
          overlay: isBusy || isAdded ? _TileOverlay(isAdded: isAdded) : null,
        );
      },
    );
  }
}

/// Covers the folder body while a add is in flight, or once it has landed.
class _TileOverlay extends StatelessWidget {
  const _TileOverlay({required this.isAdded});

  final bool isAdded;

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    return Container(
      margin: const EdgeInsets.only(top: 15),
      color: AppColors.bg(context).withAlpha(200),
      alignment: Alignment.center,
      child: isAdded
          ? Icon(
              Icons.check,
              color: AppColors.fg(context),
              size: layout.inset(28),
            )
          : SizedBox(
              width: layout.inset(18),
              height: layout.inset(18),
              child: CircularProgressIndicator(
                color: AppColors.fg(context),
                strokeWidth: 2.5,
              ),
            ),
    );
  }
}
