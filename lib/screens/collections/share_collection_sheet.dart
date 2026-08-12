import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:reelpin/providers.dart';
import 'package:reelpin/data_models/collections/collection_models.dart';
import 'package:reelpin/services/sharing/collection_link_cache.dart';
import 'package:reelpin/services/sharing/collection_share_message.dart';
import 'package:reelpin/services/sharing/reel_share_service.dart';
import 'package:reelpin/utils/app_logger.dart';

Future<void> showShareCollectionSheet(
  BuildContext context,
  String collectionId,
) {
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
  ConsumerState<ShareCollectionSheet> createState() =>
      _ShareCollectionSheetState();
}

class _ShareCollectionSheetState extends ConsumerState<ShareCollectionSheet> {
  String? _linkUrl;
  bool _busy = false;
  CollectionMembers? _members;

  /// What was last copied, shown inline for a couple of seconds. A
  /// ScaffoldMessenger snackbar is useless here — it renders *behind* the modal
  /// sheet, so the copy looked like it silently failed.
  String? _copiedLabel;
  Timer? _copiedResetTimer;

  @override
  void initState() {
    super.initState();
    // Restore unconditionally: the sheet can open before the detail has loaded,
    // and gating on it meant a cached url was silently skipped, leaving the
    // owner with no copy button. Safe because the chip only renders when the
    // collection actually reports hasLink.
    unawaited(_restoreCachedLink());
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMembers());
  }

  @override
  void dispose() {
    _copiedResetTimer?.cancel();
    super.dispose();
  }

  Future<void> _restoreCachedLink() async {
    final cached = await CollectionLinkCache.instance.read(widget.collectionId);
    if (cached != null && mounted) setState(() => _linkUrl = cached);
  }

  Future<void> _loadMembers() async {
    final members = await ref
        .read(collectionsViewModelProvider)
        .loadMembers(widget.collectionId);
    if (mounted) setState(() => _members = members);
  }

  CollectionSummary? get _collection => ref
      .read(collectionsViewModelProvider)
      .detailFor(widget.collectionId)
      ?.collection;

  Future<void> _toggleLink(bool enabled) async {
    setState(() => _busy = true);
    final vm = ref.read(collectionsViewModelProvider);
    try {
      if (enabled) {
        final link = await vm.enableLink(widget.collectionId);
        final url = link?.url;
        if (url != null && url.isNotEmpty) {
          await CollectionLinkCache.instance.write(widget.collectionId, url);
        }
        if (mounted) setState(() => _linkUrl = url);
      } else {
        await vm.disableLink(widget.collectionId);
        await CollectionLinkCache.instance.clear(widget.collectionId);
        if (mounted) setState(() => _linkUrl = null);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Regenerating mints a new token and invalidates the old one server-side, so
  /// anyone already holding the previous link loses access. Confirm first.
  Future<void> _regenerateLink() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Generate a new link?'),
        content: const Text(
          'The current link will stop working straight away. Anyone you already '
          'sent it to will not be able to open this collection.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Generate'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _toggleLink(true);
  }

  /// Hands the link to the OS share sheet with a message that also explains
  /// what ReelPin is, so a recipient without the app has some context.
  Future<void> _shareLink() async {
    final url = _linkUrl;
    if (url == null || url.isEmpty) return;
    final collection = _collection;
    final message = CollectionShareMessage.forLink(
      collectionName: collection?.name ?? '',
      url: url,
      itemCount: collection?.itemCount ?? 0,
    );
    await _presentShare(message);
  }

  Future<void> _presentShare(CollectionShareMessage message) async {
    try {
      await ReelShareService.shareText(
        text: message.body,
        subject: message.subject,
      );
    } catch (e) {
      // The link is already on screen and copyable, so a failed share sheet is
      // not worth blocking on.
      AppLogger.error('Collection share sheet failed: $e');
    }
  }

  Future<void> _copy(String value, String label) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    setState(() => _copiedLabel = label);
    _copiedResetTimer?.cancel();
    _copiedResetTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _copiedLabel = null);
    });
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
        // Copy first so the link is never lost if the share sheet is dismissed.
        await _copy(invite.url, 'Invite link');
        await _presentShare(
          CollectionShareMessage.forInvite(
            collectionName: _collection?.name ?? '',
            url: invite.url,
            role: invite.role,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final collection = ref
        .watch(collectionsViewModelProvider)
        .detailFor(widget.collectionId)
        ?.collection;
    final hasLink = collection?.hasLink ?? false;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Share collection',
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                if (_copiedLabel != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$_copiedLabel copied',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Choose how people reach this collection.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),

            RadioGroup<bool>(
              groupValue: !hasLink,
              onChanged: (selected) {
                if (_busy || selected != true) return;
                _toggleLink(false);
              },
              child: const _OptionRow(
                icon: Icons.lock_outline,
                title: 'Private',
                subtitle: 'Only you',
                trailing: Radio<bool>(value: true),
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
                  justCopied: _copiedLabel == 'Link',
                  onCopy: _linkUrl == null
                      ? null
                      : () => _copy(_linkUrl!, 'Link'),
                  onShare: _linkUrl == null ? null : _shareLink,
                  // Both paths rotate the token. Even the cache-miss "get a
                  // link" case kills a link that may already be circulating,
                  // so neither is allowed to fire without the warning.
                  onRegenerate: _busy ? null : _regenerateLink,
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
                      .map(
                        (m) => _MemberRow(
                          member: m,
                          canManage: (collection?.isOwner ?? false),
                          onRemove: () async {
                            await ref
                                .read(collectionsViewModelProvider)
                                .removeMember(
                                  collectionId: widget.collectionId,
                                  memberUserId: m.userId,
                                );
                            _loadMembers();
                          },
                        ),
                      )
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
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
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
  const _LinkChip({
    required this.url,
    this.justCopied = false,
    this.onCopy,
    this.onShare,
    this.onRegenerate,
  });

  final String? url;
  final bool justCopied;
  final VoidCallback? onCopy;
  final VoidCallback? onShare;
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
              url ?? 'Link is active, but not saved on this device.',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ),
          if (onCopy != null) ...[
            IconButton(
              iconSize: 18,
              icon: Icon(justCopied ? Icons.check : Icons.copy),
              color: justCopied ? theme.colorScheme.primary : null,
              tooltip: 'Copy',
              onPressed: onCopy,
            ),
            IconButton(
              iconSize: 18,
              icon: const Icon(Icons.ios_share),
              tooltip: 'Share',
              onPressed: onShare,
            ),
            IconButton(
              iconSize: 18,
              icon: const Icon(Icons.refresh),
              tooltip: 'Generate a new link',
              onPressed: onRegenerate,
            ),
          ] else
            TextButton(
              onPressed: onRegenerate,
              child: const Text('New link'),
            ),
        ],
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.member,
    required this.canManage,
    required this.onRemove,
  });

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
            child: Text(
              member.userId,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            member.role.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
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
