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
import 'package:reelpin/components/collections/collection_form_sheet.dart';
import 'package:reelpin/utils/error_message.dart';

Future<void> showAddToCollectionSheet(
  BuildContext context,
  List<String> reelIds,
) {
  if (reelIds.isEmpty) return Future<void>.value();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => AddToCollectionSheet(reelIds: reelIds),
  );
}

class AddToCollectionSheet extends ConsumerStatefulWidget {
  const AddToCollectionSheet({super.key, required this.reelIds});

  final List<String> reelIds;

  @override
  ConsumerState<AddToCollectionSheet> createState() =>
      _AddToCollectionSheetState();
}

class _AddToCollectionSheetState extends ConsumerState<AddToCollectionSheet> {
  final Set<String> _selected = {};
  bool _saving = false;

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

  Future<void> _save() async {
    if (_selected.isEmpty || _saving) return;
    setState(() => _saving = true);
    final vm = ref.read(collectionsViewModelProvider);
    try {
      for (final collectionId in _selected) {
        await vm.addReels(collectionId: collectionId, reelIds: widget.reelIds);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
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
  }

  Future<void> _createAndAdd() async {
    final created = await showCollectionFormSheet(context);
    if (created == null || !mounted) return;
    setState(() => _selected.add(created.id));
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
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.reelIds.length == 1
                          ? 'ADD TO COLLECTION'
                          : 'ADD ${widget.reelIds.length} TO COLLECTION',
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
              if (editable.isNotEmpty) ...[
                SizedBox(height: layout.gap(16)),
                _SaveButton(
                  count: _selected.length,
                  saving: _saving,
                  onTap: _selected.isEmpty || _saving ? null : _save,
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
        childAspectRatio: 1.2,
      ),
      itemBuilder: (context, index) {
        final collection = editable[index];
        return CollectionFolderTile(
          collection: collection,
          index: index,
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
  const _SaveButton({
    required this.count,
    required this.saving,
    required this.onTap,
  });

  final int count;
  final bool saving;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    final label = switch (count) {
      0 => 'SELECT A COLLECTION',
      1 => 'SAVE TO 1 COLLECTION',
      _ => 'SAVE TO $count COLLECTIONS',
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
          child: saving
              ? SizedBox(
                  width: layout.inset(16),
                  height: layout.inset(16),
                  child: const CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AppColors.black,
                  ),
                )
              : Text(
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
