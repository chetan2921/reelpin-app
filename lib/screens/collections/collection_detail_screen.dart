import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:reelpin/providers.dart';
import 'package:reelpin/data_models/collections/collection_models.dart';
import 'package:reelpin/screens/collections/collections_screen.dart'
    show promptCollectionName;
import 'package:reelpin/view_models/collections_view_model.dart';
import 'package:reelpin/screens/collections/share_collection_sheet.dart';
import 'package:reelpin/data_models/reels/reel.dart';
import 'package:reelpin/screens/reel_detail/reel_detail_loader_screen.dart';
import 'package:reelpin/components/reels/reel_card.dart';

class CollectionDetailScreen extends ConsumerStatefulWidget {
  const CollectionDetailScreen({
    super.key,
    required this.collectionId,
    this.sharedToken,
    this.initialName,
  });

  final String collectionId;

  /// When set, the screen renders a read-only shared collection fetched with
  /// the capability token (the viewer may not be a member).
  final String? sharedToken;
  final String? initialName;

  bool get isShared => sharedToken != null;

  @override
  ConsumerState<CollectionDetailScreen> createState() => _CollectionDetailScreenState();
}

class _CollectionDetailScreenState extends ConsumerState<CollectionDetailScreen> {
  CollectionDetail? _shared;
  bool _loadingShared = false;
  String? _sharedError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.isShared) {
        _loadShared();
      } else {
        ref.read(collectionsViewModelProvider).loadCollectionDetail(widget.collectionId);
      }
    });
  }

  Future<void> _loadShared() async {
    setState(() {
      _loadingShared = true;
      _sharedError = null;
    });
    try {
      final detail =
          await ref.read(collectionsHttpProvider).getSharedCollection(widget.sharedToken!);
      if (mounted) setState(() => _shared = detail);
    } catch (e) {
      if (mounted) setState(() => _sharedError = 'Could not open this shared collection.');
    } finally {
      if (mounted) setState(() => _loadingShared = false);
    }
  }

  Future<void> _saveToLibrary(Reel reel) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(reelRepositoryProvider).enqueueReelProcessing(reel.url);
      messenger.showSnackBar(const SnackBar(content: Text('Saving to your library...')));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Could not save this reel.')));
    }
  }

  Future<void> _rename(CollectionSummary collection) async {
    final name = await promptCollectionName(context, initial: collection.name);
    if (name == null || name.trim().isEmpty) return;
    await ref
        .read(collectionsViewModelProvider)
        .updateCollection(collectionId: collection.id, name: name.trim());
  }

  Future<void> _confirmDelete(CollectionSummary collection) async {
    final ok = await _confirm(context, 'Delete collection?',
        'This removes the collection for everyone. Saved reels stay in your library.');
    if (ok != true) return;
    await ref.read(collectionsViewModelProvider).deleteCollection(collection.id);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _confirmLeave(CollectionSummary collection) async {
    final ok = await _confirm(context, 'Leave collection?', 'You will lose access to it.');
    if (ok != true) return;
    await ref.read(collectionsViewModelProvider).leave(collection.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isShared) return _buildShared();

    final vm = ref.watch(collectionsViewModelProvider);
    final detail = vm.detailFor(widget.collectionId);
    final collection = detail?.collection;
    final title = collection?.name ?? widget.initialName ?? 'Collection';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (collection != null && collection.isOwner)
            IconButton(
              icon: const Icon(Icons.ios_share),
              tooltip: 'Share',
              onPressed: () => showShareCollectionSheet(context, collection.id),
            ),
          if (collection != null)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'rename') _rename(collection);
                if (value == 'delete') _confirmDelete(collection);
                if (value == 'leave') _confirmLeave(collection);
              },
              itemBuilder: (context) => [
                if (collection.isOwner)
                  const PopupMenuItem(value: 'rename', child: Text('Rename')),
                if (collection.isOwner)
                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
                if (!collection.isOwner)
                  const PopupMenuItem(value: 'leave', child: Text('Leave')),
              ],
            ),
        ],
      ),
      body: _buildOwnedBody(vm, detail),
    );
  }

  Widget _buildOwnedBody(CollectionsViewModel vm, CollectionDetail? detail) {
    if (detail == null) {
      if (vm.isLoadingDetail) return const Center(child: CircularProgressIndicator());
      if (vm.detailError != null) {
        return _centeredMessage(vm.detailError!, onRetry: () {
          ref
              .read(collectionsViewModelProvider)
              .loadCollectionDetail(widget.collectionId, forceRefresh: true);
        });
      }
      return const Center(child: CircularProgressIndicator());
    }
    if (detail.reels.isEmpty) {
      return _centeredMessage(
        detail.canEdit
            ? 'No reels yet. Add reels from any reel’s menu.'
            : 'This collection has no reels yet.',
      );
    }
    return RefreshIndicator(
      onRefresh: () => ref
          .read(collectionsViewModelProvider)
          .loadCollectionDetail(widget.collectionId, forceRefresh: true),
      child: _reelGrid(
        detail.reels,
        onTap: (reel) => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ReelDetailLoaderScreen(reelId: reel.id),
          ),
        ),
        onDelete: detail.canEdit
            ? (reel) => ref.read(collectionsViewModelProvider).removeReel(
                  collectionId: widget.collectionId,
                  reelId: reel.id,
                )
            : null,
      ),
    );
  }

  Widget _buildShared() {
    return Scaffold(
      appBar: AppBar(title: Text(_shared?.collection.name ?? 'Shared collection')),
      body: Builder(
        builder: (context) {
          if (_loadingShared) return const Center(child: CircularProgressIndicator());
          if (_sharedError != null) {
            return _centeredMessage(_sharedError!, onRetry: _loadShared);
          }
          final detail = _shared;
          if (detail == null) return const Center(child: CircularProgressIndicator());
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.link, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        detail.ownerName != null
                            ? 'Shared by ${detail.ownerName} · view only'
                            : 'Shared collection · view only',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 0.72,
                ),
                itemCount: detail.reels.length,
                itemBuilder: (context, index) => _SharedReelTile(
                  reel: detail.reels[index],
                  onSave: () => _saveToLibrary(detail.reels[index]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _reelGrid(
    List<Reel> reels, {
    required void Function(Reel) onTap,
    void Function(Reel)? onDelete,
  }) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.72,
      ),
      itemCount: reels.length,
      itemBuilder: (context, index) {
        final reel = reels[index];
        return ReelCard(
          reel: reel,
          onTap: () => onTap(reel),
          onDelete: onDelete == null ? null : () => onDelete(reel),
        );
      },
    );
  }

  Widget _centeredMessage(String message, {VoidCallback? onRetry}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              FilledButton(onPressed: onRetry, child: const Text('Try again')),
            ],
          ],
        ),
      ),
    );
  }
}

Future<bool?> _confirm(BuildContext context, String title, String body) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Confirm')),
      ],
    ),
  );
}

class _SharedReelTile extends StatelessWidget {
  const _SharedReelTile({required this.reel, required this.onSave});

  final Reel reel;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (reel.thumbnailUrl.isNotEmpty)
            Image.network(
              reel.thumbnailUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(color: Colors.black12),
            )
          else
            Container(color: Colors.black12),
          Positioned(
            left: 8,
            right: 8,
            bottom: 8,
            child: Text(
              reel.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 12,
                shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
              ),
            ),
          ),
          Positioned(
            top: 6,
            right: 6,
            child: Material(
              color: Colors.white,
              shape: const CircleBorder(),
              child: IconButton(
                iconSize: 18,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.bookmark_add_outlined),
                tooltip: 'Save to my library',
                onPressed: onSave,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
