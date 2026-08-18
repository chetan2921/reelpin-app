import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:reelpin/constants/app_colors.dart';
import 'package:reelpin/constants/app_layout.dart';
import 'package:reelpin/constants/app_theme.dart';
import 'package:reelpin/data_models/collections/collection_models.dart';
import 'package:reelpin/providers.dart';
import 'package:reelpin/utils/error_message.dart';

/// Name + note sheet used for both creating and editing a collection. Returns
/// the saved collection, or null when the sheet was dismissed.
Future<CollectionSummary?> showCollectionFormSheet(
  BuildContext context, {
  CollectionSummary? collection,
}) {
  return showModalBottomSheet<CollectionSummary>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => CollectionFormSheet(collection: collection),
  );
}

class CollectionFormSheet extends ConsumerStatefulWidget {
  const CollectionFormSheet({super.key, this.collection});

  /// Null when creating.
  final CollectionSummary? collection;

  @override
  ConsumerState<CollectionFormSheet> createState() =>
      _CollectionFormSheetState();
}

class _CollectionFormSheetState extends ConsumerState<CollectionFormSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _noteController;
  bool _isSaving = false;
  String? _error;

  bool get _isEditing => widget.collection != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.collection?.name ?? '',
    );
    _noteController = TextEditingController(
      text: widget.collection?.description ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
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
                _isEditing ? 'EDIT COLLECTION' : 'NEW COLLECTION',
                style: GoogleFonts.spaceMono(
                  color: AppColors.fg(context),
                  fontSize: layout.font(17),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
              SizedBox(height: layout.gap(16)),
              _buildField(
                context,
                controller: _nameController,
                label: 'COLLECTION NAME',
                maxLength: 20,
                maxLines: 1,
                autofocus: !_isEditing,
              ),
              SizedBox(height: layout.gap(12)),
              _buildField(
                context,
                controller: _noteController,
                label: 'STICKY NOTE (OPTIONAL)',
                maxLength: 80,
                maxLines: 3,
              ),
              if (_error != null) ...[
                SizedBox(height: layout.gap(12)),
                Text(
                  _error!.toUpperCase(),
                  style: GoogleFonts.spaceMono(
                    color: AppColors.destructive,
                    fontSize: layout.font(10),
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                ),
              ],
              SizedBox(height: layout.gap(18)),
              GestureDetector(
                onTap: _isSaving ? null : _save,
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(vertical: layout.gap(14)),
                  decoration: AppTheme.brutalBox(
                    context,
                    color: _isSaving
                        ? AppColors.surfaceElevatedColor(context)
                        : AppColors.yellow,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _isSaving
                        ? 'SAVING...'
                        : (_isEditing
                              ? 'SAVE COLLECTION'
                              : 'CREATE COLLECTION'),
                    style: GoogleFonts.spaceMono(
                      color: AppColors.black,
                      fontSize: layout.font(13),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(
    BuildContext context, {
    required TextEditingController controller,
    required String label,
    required int maxLength,
    required int maxLines,
    bool autofocus = false,
  }) {
    final layout = AppLayout.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.spaceMono(
            color: AppColors.fg(context),
            fontSize: layout.font(10),
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
        SizedBox(height: layout.gap(6)),
        Container(
          decoration: AppTheme.brutalBox(context, shadow: false),
          child: TextField(
            controller: controller,
            autofocus: autofocus,
            maxLength: maxLength,
            maxLines: maxLines,
            textCapitalization: TextCapitalization.sentences,
            style: GoogleFonts.spaceMono(
              color: AppColors.fg(context),
              fontSize: layout.font(13),
              fontWeight: FontWeight.w600,
            ),
            cursorColor: AppColors.fg(context),
            decoration: InputDecoration(
              border: InputBorder.none,
              // The built-in counter renders inside the field's own box, so the
              // bordered container looked like it held a second stacked box
              // under the text. Drawn below the field instead.
              counterText: '',
              contentPadding: EdgeInsets.symmetric(
                horizontal: layout.inset(12),
                vertical: layout.gap(10),
              ),
            ),
          ),
        ),
        SizedBox(height: layout.gap(4)),
        Align(
          alignment: Alignment.centerRight,
          child: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (_, value, _) => Text(
              '${value.text.characters.length}/$maxLength',
              style: GoogleFonts.spaceMono(
                color: AppColors.textSec(context),
                fontSize: layout.font(10),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final note = _noteController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Collection name is required.');
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    final vm = ref.read(collectionsViewModelProvider);
    try {
      final CollectionSummary? saved;
      if (_isEditing) {
        await vm.updateCollection(
          collectionId: widget.collection!.id,
          name: name,
          description: note,
        );
        saved = vm.collections
            .where((c) => c.id == widget.collection!.id)
            .firstOrNull;
      } else {
        saved = await vm.createCollection(name: name, description: note);
      }
      if (mounted) Navigator.of(context).pop(saved);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _error = userFacingErrorMessage(
          e,
          fallbackMessage: 'Could not save the collection.',
        );
      });
    }
  }
}
