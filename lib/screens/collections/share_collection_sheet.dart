import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:google_fonts/google_fonts.dart';

import 'package:reelpin/components/common/app_bottom_sheet.dart';
import 'package:reelpin/constants/app_colors.dart';
import 'package:reelpin/constants/app_layout.dart';
import 'package:reelpin/constants/app_theme.dart';
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
  return showAppBottomSheet<void>(
    context: context,
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
    final role = await showAppBottomSheet<String>(
      context: context,
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
    final layout = AppLayout.of(context);
    final collection = ref
        .watch(collectionsViewModelProvider)
        .detailFor(widget.collectionId)
        ?.collection;
    final hasLink = collection?.hasLink ?? false;
    final isOwner = collection?.isOwner ?? false;

    return AppBottomSheet(
      title: 'Share collection',
      subtitle: hasLink
          ? 'Anyone with this link can view the collection.'
          : 'Turn on a link to let anyone view this collection.',
      trailing: _copiedLabel == null
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_circle,
                  size: layout.inset(15),
                  color: AppColors.fg(context),
                ),
                SizedBox(width: layout.inset(5)),
                Text(
                  'COPIED',
                  style: GoogleFonts.spaceMono(
                    color: AppColors.fg(context),
                    fontSize: layout.font(10),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // One control for one decision. There used to be a "Private" radio
            // beside this switch, two widgets fighting over the same boolean.
            _SheetRow(
              label: 'SHARE LINK',
              hint: hasLink ? 'On' : 'Off',
              trailing: Switch(
                value: hasLink,
                onChanged: _busy ? null : _toggleLink,
                activeThumbColor: AppColors.black,
                activeTrackColor: AppColors.yellow,
              ),
            ),
            if (hasLink) ...[
              SizedBox(height: layout.gap(10)),
              _LinkChip(
                url: _linkUrl,
                onCopy: _linkUrl == null
                    ? null
                    : () => _copy(_linkUrl!, 'Link'),
                onShare: _linkUrl == null ? null : _shareLink,
                // Both paths rotate the token, killing a link that may already
                // be circulating, so neither fires without the warning.
                onRegenerate: _busy ? null : _regenerateLink,
              ),
            ],
            SizedBox(height: layout.gap(20)),
            Container(height: 1, color: AppColors.fg(context)),
            SizedBox(height: layout.gap(20)),
            _SheetRow(
              label: 'COLLABORATORS',
              hint: 'They can add reels too',
              trailing: GestureDetector(
                onTap: _busy ? null : _invite,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: layout.inset(12),
                    vertical: layout.gap(8),
                  ),
                  decoration: AppTheme.brutalBox(
                    context,
                    color: AppColors.yellow,
                  ),
                  child: Text(
                    'INVITE',
                    style: GoogleFonts.spaceMono(
                      color: AppColors.black,
                      fontSize: layout.font(11),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            ),
            if (_members != null && _members!.members.isNotEmpty) ...[
              SizedBox(height: layout.gap(12)),
              ..._members!.members.map(
                (m) => _MemberRow(
                  member: m,
                  canManage: isOwner,
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
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Label + hint on the left, control on the right. Used by every row in the
/// sheet so they line up and read the same.
class _SheetRow extends StatelessWidget {
  const _SheetRow({
    required this.label,
    required this.hint,
    required this.trailing,
  });

  final String label;
  final String hint;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.spaceMono(
                  color: AppColors.fg(context),
                  fontSize: layout.font(13),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
              SizedBox(height: layout.gap(2)),
              Text(
                hint,
                style: GoogleFonts.spaceMono(
                  color: AppColors.textSec(context),
                  fontSize: layout.font(10),
                ),
              ),
            ],
          ),
        ),
        trailing,
      ],
    );
  }
}

class _LinkChip extends StatelessWidget {
  const _LinkChip({
    required this.url,
    this.onCopy,
    this.onShare,
    this.onRegenerate,
  });

  final String? url;
  final VoidCallback? onCopy;
  final VoidCallback? onShare;
  final VoidCallback? onRegenerate;

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    return Container(
      padding: EdgeInsets.fromLTRB(
        layout.inset(12),
        layout.gap(6),
        layout.inset(4),
        layout.gap(6),
      ),
      decoration: AppTheme.brutalBox(context, shadow: false),
      child: Row(
        children: [
          Expanded(
            child: Text(
              url ?? 'Link is on, but not saved on this device.',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.spaceMono(
                color: AppColors.fg(context),
                fontSize: layout.font(10),
              ),
            ),
          ),
          if (onCopy != null) ...[
            _ChipAction(icon: Icons.copy, tooltip: 'Copy', onTap: onCopy),
            _ChipAction(
              icon: Icons.ios_share,
              tooltip: 'Share',
              onTap: onShare,
            ),
          ],
          _ChipAction(
            icon: Icons.refresh,
            tooltip: 'New link',
            onTap: onRegenerate,
          ),
        ],
      ),
    );
  }
}

class _ChipAction extends StatelessWidget {
  const _ChipAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    return IconButton(
      iconSize: layout.inset(18),
      icon: Icon(icon, color: AppColors.fg(context)),
      tooltip: tooltip,
      onPressed: onTap,
      constraints: BoxConstraints.tightFor(
        width: layout.inset(34),
        height: layout.inset(34),
      ),
      padding: EdgeInsets.zero,
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
    return AppBottomSheet(
      title: 'Invite collaborators',
      subtitle: 'Pick what they are allowed to do.',
      maxHeightFactor: 0.4,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _RoleTile(
            icon: Icons.edit_outlined,
            label: 'CAN EDIT',
            hint: 'Add and remove reels',
            onTap: () => Navigator.of(context).pop('editor'),
          ),
          _RoleTile(
            icon: Icons.visibility_outlined,
            label: 'CAN VIEW',
            hint: 'Look only',
            onTap: () => Navigator.of(context).pop('viewer'),
          ),
        ],
      ),
    );
  }
}

class _RoleTile extends StatelessWidget {
  const _RoleTile({
    required this.icon,
    required this.label,
    required this.hint,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: EdgeInsets.only(bottom: layout.gap(10)),
        padding: EdgeInsets.all(layout.inset(14)),
        decoration: AppTheme.brutalBox(context),
        child: Row(
          children: [
            Icon(icon, color: AppColors.fg(context), size: layout.inset(18)),
            SizedBox(width: layout.inset(12)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.spaceMono(
                      color: AppColors.fg(context),
                      fontSize: layout.font(12),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                  Text(
                    hint,
                    style: GoogleFonts.spaceMono(
                      color: AppColors.textSec(context),
                      fontSize: layout.font(10),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
