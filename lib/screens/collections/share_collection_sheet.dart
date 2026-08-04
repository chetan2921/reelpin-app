import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:reelpin/providers.dart';
import 'package:reelpin/data_models/collections/collection_models.dart';

Future<void> showShareCollectionSheet(BuildContext context, String collectionId) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => ShareCollectionSheet(collectionId: collectionId),
  );
}

class ShareCollectionSheet extends ConsumerStatefulWidget {
  const ShareCollectionSheet({super.key, required this.collectionId});

  final String collectionId;

  @override
  ConsumerState<ShareCollectionSheet> createState() => _ShareCollectionSheetState();
}

class _ShareCollectionSheetState extends ConsumerState<ShareCollectionSheet> {
  String? _linkUrl;
  bool _busy = false;
  CollectionMembers? _members;

  @override
  void initState() {
    super.initState();
    final detail = ref.read(collectionsViewModelProvider).detailFor(widget.collectionId);
    if (detail != null && detail.collection.hasLink) {
      // The URL is only returned when (re)generated; show a placeholder until then.
      _linkUrl = null;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMembers());
  }

  Future<void> _loadMembers() async {
    final members = await ref.read(collectionsViewModelProvider).loadMembers(widget.collectionId);
    if (mounted) setState(() => _members = members);
  }

  CollectionSummary? get _collection =>
      ref.read(collectionsViewModelProvider).detailFor(widget.collectionId)?.collection;

  Future<void> _toggleLink(bool enabled) async {
    setState(() => _busy = true);
    final vm = ref.read(collectionsViewModelProvider);
    try {
      if (enabled) {
        final link = await vm.enableLink(widget.collectionId);
        setState(() => _linkUrl = link?.url);
      } else {
        await vm.disableLink(widget.collectionId);
        setState(() => _linkUrl = null);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copy(String value, String label) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label copied')));
    }
  }

  Future<void> _invite() async {
    final role = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (_) => const _InviteRoleSheet(),
    );
    if (role == null) return;
    setState(() => _busy = true);
    try {
      final invite = await ref
          .read(collectionsViewModelProvider)
          .createInvite(collectionId: widget.collectionId, role: role);
      if (invite != null && mounted) {
        await _copy(invite.url, 'Invite link');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final collection = ref.watch(collectionsViewModelProvider).detailFor(widget.collectionId)?.collection;
    final hasLink = collection?.hasLink ?? false;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Share collection', style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text('Choose how people reach this collection.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 12),

            _OptionRow(
              icon: Icons.lock_outline,
              title: 'Private',
              subtitle: 'Only you',
              trailing: Radio<bool>(
                value: true,
                groupValue: !hasLink,
                onChanged: _busy ? null : (_) => _toggleLink(false),
              ),
            ),

            _OptionRow(
              icon: Icons.link,
              title: 'Share link',
              subtitle: 'Anyone with the link can view',
              trailing: Switch(
                value: hasLink,
                onChanged: _busy ? null : _toggleLink,
              ),
            ),
            if (hasLink)
              Padding(
                padding: const EdgeInsets.only(left: 50, bottom: 8),
                child: _LinkChip(
                  url: _linkUrl,
                  onCopy: _linkUrl == null ? null : () => _copy(_linkUrl!, 'Link'),
                  onRegenerate: _busy ? null : () => _toggleLink(true),
                ),
              ),

            const Divider(height: 24),
            _OptionRow(
              icon: Icons.group_outlined,
              title: 'Collaborators',
              subtitle: 'Invite people to add reels',
              trailing: TextButton.icon(
                onPressed: _busy ? null : _invite,
                icon: const Icon(Icons.person_add_alt),
                label: const Text('Invite'),
              ),
            ),
            if (_members != null && _members!.members.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 50, top: 4),
                child: Column(
                  children: _members!.members
                      .map((m) => _MemberRow(
                            member: m,
                            canManage: (collection?.isOwner ?? false),
                            onRemove: () async {
                              await ref.read(collectionsViewModelProvider).removeMember(
                                    collectionId: widget.collectionId,
                                    memberUserId: m.userId,
                                  );
                              _loadMembers();
                            },
                          ))
                      .toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleSmall),
                Text(subtitle,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}

class _LinkChip extends StatelessWidget {
  const _LinkChip({required this.url, this.onCopy, this.onRegenerate});

  final String? url;
  final VoidCallback? onCopy;
  final VoidCallback? onRegenerate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              url ?? 'Link is active. Regenerate to copy it.',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ),
          if (onCopy != null)
            IconButton(
              iconSize: 18,
              icon: const Icon(Icons.copy),
              tooltip: 'Copy',
              onPressed: onCopy,
            )
          else
            TextButton(onPressed: onRegenerate, child: const Text('Get link')),
        ],
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({required this.member, required this.canManage, required this.onRemove});

  final CollectionMember member;
  final bool canManage;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const CircleAvatar(radius: 12, child: Icon(Icons.person, size: 14)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(member.userId, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          Text(
            member.role.toUpperCase(),
            style: theme.textTheme.labelSmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          if (canManage)
            IconButton(
              iconSize: 18,
              icon: const Icon(Icons.close),
              tooltip: 'Remove',
              onPressed: onRemove,
            ),
        ],
      ),
    );
  }
}

class _InviteRoleSheet extends StatelessWidget {
  const _InviteRoleSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Invite collaborators'),
          ),
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Can edit'),
            subtitle: const Text('Add and remove reels'),
            onTap: () => Navigator.of(context).pop('editor'),
          ),
          ListTile(
            leading: const Icon(Icons.visibility_outlined),
            title: const Text('Can view'),
            subtitle: const Text('Look only'),
            onTap: () => Navigator.of(context).pop('viewer'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
