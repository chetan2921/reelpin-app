import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:reelpin/app/providers.dart';
import 'package:reelpin/features/collections/domain/collection.dart';
import 'package:reelpin/features/collections/presentation/collection_detail_screen.dart';
import 'package:reelpin/features/collections/presentation/collections_viewmodel.dart';

class CollectionsScreen extends ConsumerStatefulWidget {
  const CollectionsScreen({super.key});

  @override
  ConsumerState<CollectionsScreen> createState() => _CollectionsScreenState();
}

class _CollectionsScreenState extends ConsumerState<CollectionsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(collectionsViewModelProvider).loadCollections();
    });
  }

  Future<void> _createCollection() async {
    final name = await promptCollectionName(context);
    if (name == null || name.trim().isEmpty) return;
    final vm = ref.read(collectionsViewModelProvider);
    final created = await vm.createCollection(name: name.trim());
    if (created != null && mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => CollectionDetailScreen(collectionId: created.id),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = ref.watch(collectionsViewModelProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Collections')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: vm.isMutating ? null : _createCollection,
        icon: const Icon(Icons.add),
        label: const Text('New'),
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(collectionsViewModelProvider).loadCollections(forceRefresh: true),
        child: _buildBody(vm),
      ),
    );
  }

  Widget _buildBody(CollectionsViewModel vm) {
    if (vm.isLoadingCollections && vm.collections.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (vm.collectionsError != null && vm.collections.isEmpty) {
      return _ErrorState(
        message: vm.collectionsError!,
        onRetry: () =>
            ref.read(collectionsViewModelProvider).loadCollections(forceRefresh: true),
      );
    }
    if (vm.collections.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 120),
          _EmptyState(),
        ],
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 0.82,
      ),
      itemCount: vm.collections.length,
      itemBuilder: (context, index) {
        final collection = vm.collections[index];
        return _CollectionCard(
          collection: collection,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => CollectionDetailScreen(collectionId: collection.id),
            ),
          ),
        );
      },
    );
  }
}

Future<String?> promptCollectionName(BuildContext context, {String initial = ''}) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('New collection'),
      content: TextField(
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(hintText: 'Name (e.g. South India 2026)'),
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(controller.text),
          child: const Text('Create'),
        ),
      ],
    ),
  );
}

class _CollectionCard extends StatelessWidget {
  const _CollectionCard({required this.collection, required this.onTap});

  final CollectionSummary collection;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    theme.colorScheme.primary.withValues(alpha: 0.85),
                    theme.colorScheme.primary.withValues(alpha: 0.45),
                  ],
                ),
              ),
              child: const Center(
                child: Icon(Icons.collections_bookmark_outlined,
                    color: Colors.white, size: 34),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            collection.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              _StateChip(collection: collection),
              const Spacer(),
              Text(
                '${collection.itemCount}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StateChip extends StatelessWidget {
  const _StateChip({required this.collection});

  final CollectionSummary collection;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    IconData icon;
    String label;
    if (collection.memberCount > 0) {
      icon = Icons.group_outlined;
      label = '${collection.memberCount}';
    } else if (collection.hasLink) {
      icon = Icons.link;
      label = 'Link';
    } else {
      icon = Icons.lock_outline;
      label = 'Private';
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 3),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          children: [
            Icon(Icons.collections_bookmark_outlined,
                size: 48, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text('No collections yet', style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              'Group your saved reels into collections you can keep private, share by link, or build with others.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 140),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                Text(message, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton(onPressed: onRetry, child: const Text('Try again')),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
