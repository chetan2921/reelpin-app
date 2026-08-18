import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:google_fonts/google_fonts.dart';

import 'package:reelpin/components/common/app_bottom_sheet.dart';
import 'package:reelpin/components/common/app_switch.dart';
import 'package:reelpin/components/common/confirm_dialog.dart';
import 'package:reelpin/components/sharing/share_card.dart';
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
    final confirmed = await showConfirmDialog(
      context,
      title: 'Generate a new link?',
      message:
          'The current link will stop working straight away. Anyone you '
          'already sent it to will not be able to open this collection.',
      confirmLabel: 'GENERATE',
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
    await _presentShare(message, role: null);
  }

  /// Sends the square share card along with the message. Without an image the
  /// chat apps fall back to the link preview the web page carries.
  Future<void> _presentShare(
    CollectionShareMessage message, {
    required String? role,
  }) async {
    final card = await _renderShareCard(role);
    try {
      if (card != null) {
        await ReelShareService.shareReelCard(
          pngBytes: card,
          text: message.body,
          subject: message.subject,
        );
        return;
      }
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

  /// Draws the card in the overlay, off the side of the screen, and reads its
  /// pixels back. Null means the share goes out as text, which is still a
  /// working link — the image is the nice-to-have.
  Future<Uint8List?> _renderShareCard(String? role) async {
    final collection = _collection;
    final boundaryKey = GlobalKey();
    final entry = OverlayEntry(
      builder: (_) => Positioned(
        left: -2000,
        top: 0,
        child: RepaintBoundary(
          key: boundaryKey,
          child: CollectionShareCard(
            name: collection?.name ?? '',
            note: collection?.description ?? '',
            itemCount: collection?.itemCount ?? 0,
            role: role,
            // The sender is whoever is looking at this sheet.
            ownerName: ref.read(sessionViewModelProvider).displayName,
            memberCount: _members?.members.length ?? 0,
          ),
        ),
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(entry);
    try {
      return await _captureCard(boundaryKey).timeout(
        const Duration(seconds: 4),
        // A share that hangs on a decode is worse than one without artwork.
        onTimeout: () => null,
      );
    } catch (e) {
      AppLogger.error('Collection share card render failed: $e');
      return null;
    } finally {
      entry.remove();
    }
  }

  Future<Uint8List?> _captureCard(GlobalKey boundaryKey) async {
    // The pin and the app icon have to be decoded before the capture, or the
    // card is grabbed with holes where they belong.
    await precacheImage(
      const AssetImage('assets/images/app_icon.png'),
      context,
    );
    if (!mounted) return null;
    await precacheImage(const AssetImage('assets/images/pin.png'), context);
    if (!mounted) return null;
    await WidgetsBinding.instance.endOfFrame;
    await WidgetsBinding.instance.endOfFrame;

    final boundary =
        boundaryKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data?.buffer.asUint8List();
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

  /// The full list, on its own sheet so it can scroll however long it gets.
  Future<void> _openCollaborators(bool isOwner) async {
    final members = _members;
    if (members == null) return;
    await showExpandableAppBottomSheet<void>(
      context: context,
      builder: (controller) => _CollaboratorsSheet(
        scrollController: controller,
        members: members.members,
        canManage: isOwner,
        onRemove: (member) => ref
            .read(collectionsViewModelProvider)
            .removeMember(
              collectionId: widget.collectionId,
              memberUserId: member.userId,
            ),
      ),
    );
    if (mounted) _loadMembers();
  }

  Future<void> _invite(String role) async {
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
          role: invite.role,
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
      subtitle: 'Pick what the person you send this to is allowed to do.',
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
            // The whole sheet leads with the only decision most people are
            // here to make. Each button mints its own link and opens the OS
            // share sheet — no role picker in between.
            _InviteButton(
              icon: Icons.edit_outlined,
              label: 'INVITE TO EDIT',
              hint: 'They can add and remove pins',
              color: AppColors.yellow,
              onTap: _busy ? null : () => _invite('editor'),
            ),
            SizedBox(height: layout.gap(12)),
            _InviteButton(
              icon: Icons.visibility_outlined,
              label: 'INVITE TO VIEW',
              hint: 'They can look, not change anything',
              color: AppColors.blue,
              onTap: _busy ? null : () => _invite('viewer'),
            ),
            if (_members != null && _members!.members.isNotEmpty) ...[
              SizedBox(height: layout.gap(20)),
              _CollaboratorsRow(
                count: _members!.members.length,
                onTap: () => _openCollaborators(isOwner),
              ),
            ],
            SizedBox(height: layout.gap(20)),
            Container(height: 1, color: AppColors.fg(context)),
            SizedBox(height: layout.gap(16)),
            // Secondary: a public link anyone can open, no invite involved.
            _SheetRow(
              label: 'PUBLIC VIEW LINK',
              hint: hasLink ? 'Anyone with the link can view' : 'Off',
              trailing: AppSwitch(
                value: hasLink,
                onChanged: _busy ? null : _toggleLink,
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
          ],
        ),
      ),
    );
  }
}

/// One of the two choices the sheet is built around: a full-width button that
/// says what the recipient will be able to do.
class _InviteButton extends StatelessWidget {
  const _InviteButton({
    required this.icon,
    required this.label,
    required this.hint,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String hint;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    final textColor = color == AppColors.yellow
        ? AppColors.black
        : AppColors.white;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Opacity(
        opacity: onTap == null ? 0.5 : 1,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: layout.inset(16),
            vertical: layout.gap(14),
          ),
          decoration: AppTheme.brutalBox(context, color: color),
          child: Row(
            children: [
              Icon(icon, color: textColor, size: layout.inset(20)),
              SizedBox(width: layout.inset(12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.spaceMono(
                        color: textColor,
                        fontSize: layout.font(13),
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                    SizedBox(height: layout.gap(2)),
                    Text(
                      hint,
                      style: GoogleFonts.spaceMono(
                        color: textColor,
                        fontSize: layout.font(10),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.ios_share, color: textColor, size: layout.inset(18)),
            ],
          ),
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

/// The one-line summary in the share sheet. The list itself lives behind it.
class _CollaboratorsRow extends StatelessWidget {
  const _CollaboratorsRow({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: _SheetRow(
        label: 'COLLABORATORS',
        hint: count == 1 ? '1 person' : '$count people',
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: layout.inset(10),
                vertical: layout.gap(6),
              ),
              decoration: AppTheme.brutalBox(
                context,
                color: AppColors.surfaceElevatedColor(context),
                shadow: false,
              ),
              child: Text(
                '$count',
                style: GoogleFonts.spaceMono(
                  color: AppColors.fg(context),
                  fontSize: layout.font(12),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            SizedBox(width: layout.inset(6)),
            Icon(
              Icons.chevron_right,
              color: AppColors.fg(context),
              size: layout.inset(20),
            ),
          ],
        ),
      ),
    );
  }
}

/// Every collaborator, on a sheet of its own so the list can scroll rather
/// than pushing the invite buttons off the share sheet.
class _CollaboratorsSheet extends StatefulWidget {
  const _CollaboratorsSheet({
    required this.scrollController,
    required this.members,
    required this.canManage,
    required this.onRemove,
  });

  final ScrollController scrollController;
  final List<CollectionMember> members;
  final bool canManage;
  final Future<void> Function(CollectionMember member) onRemove;

  @override
  State<_CollaboratorsSheet> createState() => _CollaboratorsSheetState();
}

class _CollaboratorsSheetState extends State<_CollaboratorsSheet> {
  late final List<CollectionMember> _members = List.of(widget.members);
  final Set<String> _removing = {};

  Future<void> _remove(CollectionMember member) async {
    setState(() => _removing.add(member.userId));
    try {
      await widget.onRemove(member);
      if (mounted) {
        setState(() => _members.removeWhere((m) => m.userId == member.userId));
      }
    } finally {
      if (mounted) setState(() => _removing.remove(member.userId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = _members.length;
    return AppBottomSheet(
      title: 'Collaborators',
      subtitle: count == 1
          ? '1 person can open this collection.'
          : '$count people can open this collection.',
      // Fills the dragged height, so the sheet is worth dragging open even
      // when the list is short.
      fillHeight: true,
      child: ListView.builder(
        controller: widget.scrollController,
        itemCount: _members.length,
        itemBuilder: (context, index) {
          final member = _members[index];
          return _MemberRow(
            member: member,
            canManage: widget.canManage,
            isRemoving: _removing.contains(member.userId),
            onRemove: () => _remove(member),
          );
        },
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.member,
    required this.canManage,
    required this.onRemove,
    this.isRemoving = false,
  });

  final CollectionMember member;
  final bool canManage;
  final VoidCallback onRemove;
  final bool isRemoving;

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: layout.gap(6)),
      child: Row(
        children: [
          Container(
            width: layout.inset(30),
            height: layout.inset(30),
            decoration: AppTheme.brutalBox(
              context,
              color: AppColors.yellow,
              shadow: false,
            ),
            child: Icon(
              Icons.person,
              size: layout.inset(16),
              color: AppColors.black,
            ),
          ),
          SizedBox(width: layout.inset(10)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.spaceMono(
                    color: AppColors.fg(context),
                    fontSize: layout.font(12),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  member.role.toUpperCase(),
                  style: GoogleFonts.spaceMono(
                    color: AppColors.textSec(context),
                    fontSize: layout.font(10),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          if (canManage)
            IconButton(
              iconSize: layout.inset(18),
              icon: isRemoving
                  ? SizedBox(
                      width: layout.inset(14),
                      height: layout.inset(14),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.fg(context),
                      ),
                    )
                  : Icon(Icons.close, color: AppColors.fg(context)),
              tooltip: 'Remove',
              onPressed: isRemoving ? null : onRemove,
            ),
        ],
      ),
    );
  }
}
