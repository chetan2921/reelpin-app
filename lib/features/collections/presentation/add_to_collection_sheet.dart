import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:reelpin/app/providers.dart';
import 'package:reelpin/features/collections/presentation/collections_screen.dart'
    show promptCollectionName;

Future<void> showAddToCollectionSheet(BuildContext context, String reelId) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => AddToCollectionSheet(reelId: reelId),
  );
}

class AddToCollectionSheet extends ConsumerStatefulWidget {
  const AddToCollectionSheet({super.key, required this.reelId});

  final String reelId;

  @override
  ConsumerState<AddToCollectionSheet> createState() => _AddToCollectionSheetState();
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
      await ref.read(collectionsViewModelProvider).addReels(
        collectionId: collectionId,
        reelIds: [widget.reelId],
      );
      if (mounted) setState(() => _added.add(collectionId));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Could not add to that collection.')));
      }
    } finally {
      if (mounted) setState(() => _busy.remove(collectionId));
    }
  }

  Future<void> _createAndAdd() async {
    final name = await promptCollectionName(context);
    if (name == null || name.trim().isEmpty) return;
    final created = await ref
        .read(collectionsViewModelProvider)
        .createCollection(name: name.trim(), reelIds: [widget.reelId]);
    if (created != null && mounted) {
      setState(() => _added.add(created.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vm = ref.watch(collectionsViewModelProvider);
    final editable = vm.collections.where((c) => c.canEdit).toList();

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
              child: Text('Add to collection', style: theme.textTheme.titleLarge),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                'A reel can live in as many collections as you like.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.add)),
                    title: const Text('New collection'),
                    onTap: _createAndAdd,
                  ),
                  if (vm.isLoadingCollections && editable.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ...editable.map((c) {
                    final added = _added.contains(c.id);
                    final busy = _busy.contains(c.id);
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: theme.colorScheme.primaryContainer,
                        child: const Icon(Icons.collections_bookmark_outlined, size: 18),
                      ),
                      title: Text(c.name),
                      subtitle: Text('${c.itemCount} reels'),
                      trailing: busy
                          ? const SizedBox(
                              width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : Icon(
                              added ? Icons.check_circle : Icons.add_circle_outline,
                              color: added ? theme.colorScheme.primary : null,
                            ),
                      onTap: () => _addTo(c.id),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
