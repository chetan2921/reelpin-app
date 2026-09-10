import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import 'package:reelpin/components/common/app_bottom_sheet.dart';
import 'package:reelpin/constants/app_colors.dart';
import 'package:reelpin/data_models/chat/chat_attachment.dart';
import 'package:reelpin/data_models/reels/reel.dart';
import 'package:reelpin/utils/app_logger.dart';

/// One row per source, so adding Google Photos or voice later is a row and a
/// colour rather than a redesign.
Future<ChatAttachment?> showChatAttachmentSheet(
  BuildContext context, {
  required List<Reel> library,
}) {
  return showAppBottomSheet<ChatAttachment>(
    context: context,
    builder: (sheetContext) => AppBottomSheet(
      title: 'Add to this chat',
      subtitle: 'Anything you add becomes context for your next question.',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _row(
            sheetContext,
            colour: AppColors.blue,
            icon: Icons.photo_camera_outlined,
            label: 'CAMERA',
            onTap: () => _pickImage(sheetContext, ImageSource.camera),
          ),
          _row(
            sheetContext,
            colour: AppColors.orange,
            icon: Icons.photo_library_outlined,
            label: 'PHOTO LIBRARY',
            onTap: () => _pickImage(sheetContext, ImageSource.gallery),
          ),
          _row(
            sheetContext,
            colour: AppColors.cyan,
            icon: Icons.description_outlined,
            label: 'FILE / DOCUMENT',
            onTap: () => _pickFile(sheetContext),
          ),
          _row(
            sheetContext,
            colour: AppColors.yellow,
            icon: Icons.push_pin_outlined,
            label: 'ONE OF MY SAVES',
            onTap: () => _pickSave(sheetContext, library),
          ),
          _row(
            sheetContext,
            colour: AppColors.lime,
            icon: Icons.link,
            label: 'PASTE A LINK',
            onTap: () => _pasteLink(sheetContext),
          ),
          _row(
            sheetContext,
            colour: AppColors.surfaceElevated,
            icon: Icons.add,
            label: 'CONNECT AN APP · SOON',
            onTap: null,
          ),
        ],
      ),
    ),
  );
}

Widget _row(
  BuildContext context, {
  required Color colour,
  required IconData icon,
  required String label,
  required VoidCallback? onTap,
}) {
  final disabled = onTap == null;
  return GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: colour,
              border: Border.all(
                color: disabled
                    ? AppColors.textTertiary
                    : AppColors.fg(context),
              ),
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: 15,
              color: disabled ? AppColors.textTertiary : AppColors.black,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: GoogleFonts.spaceMono(
              color: disabled ? AppColors.textTertiary : AppColors.fg(context),
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    ),
  );
}

Future<void> _pickImage(BuildContext context, ImageSource source) async {
  final navigator = Navigator.of(context);
  final messenger = ScaffoldMessenger.of(context);
  try {
    final picked = await ImagePicker().pickImage(source: source);
    if (picked == null) return;
    navigator.pop(
      ChatAttachment(
        kind: source == ImageSource.camera
            ? AttachmentKind.camera
            : AttachmentKind.photo,
        displayName: picked.name,
        localPath: picked.path,
      ),
    );
  } catch (e) {
    // A null `picked` above is a genuine cancel and returns quietly; landing
    // here means the picker itself threw (e.g. a denied permission), which
    // otherwise left the sheet open with a dead tap and no explanation.
    AppLogger.error('Image attachment failed: $e');
    navigator.pop();
    _showAttachmentError(messenger);
  }
}

Future<void> _pickFile(BuildContext context) async {
  final navigator = Navigator.of(context);
  final messenger = ScaffoldMessenger.of(context);
  try {
    final result = await FilePicker.platform.pickFiles();
    final file = result?.files.singleOrNull;
    if (file?.path == null) return;
    navigator.pop(
      ChatAttachment(
        kind: AttachmentKind.file,
        displayName: file!.name,
        localPath: file.path,
      ),
    );
  } catch (e) {
    AppLogger.error('File attachment failed: $e');
    navigator.pop();
    _showAttachmentError(messenger);
  }
}

void _showAttachmentError(ScaffoldMessengerState messenger) {
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        "Couldn't add that. Check the permission and try again.",
        style: GoogleFonts.spaceMono(
          color: AppColors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
      backgroundColor: AppColors.destructive,
    ),
  );
}

Future<void> _pickSave(BuildContext context, List<Reel> library) async {
  final navigator = Navigator.of(context);
  final reel = await showAppBottomSheet<Reel>(
    context: context,
    builder: (pickerContext) => AppBottomSheet(
      title: 'Pick a save',
      fillHeight: true,
      child: ListView.builder(
        itemCount: library.length,
        itemBuilder: (_, index) => ListTile(
          onTap: () => Navigator.of(pickerContext).pop(library[index]),
          title: Text(
            library[index].title.isEmpty ? 'Untitled' : library[index].title,
            style: GoogleFonts.spaceMono(
              color: AppColors.fg(pickerContext),
              fontSize: 12,
            ),
          ),
        ),
      ),
    ),
  );
  if (reel == null) return;
  navigator.pop(
    ChatAttachment(
      kind: AttachmentKind.savedReel,
      displayName: reel.title.isEmpty ? 'Untitled save' : reel.title,
      reelId: reel.id,
    ),
  );
}

Future<void> _pasteLink(BuildContext context) async {
  final navigator = Navigator.of(context);

  final url = await showAppBottomSheet<String>(
    context: context,
    builder: (linkContext) => const _LinkEntrySheet(),
  );

  if (url == null || url.isEmpty) return;
  navigator.pop(
    ChatAttachment(kind: AttachmentKind.link, displayName: url, url: url),
  );
}

/// Its own widget so the [TextEditingController] is disposed by `State`
/// lifecycle rather than by hand right after `pop()` — disposing it manually
/// races the sheet's exit animation, which still rebuilds the field while it
/// closes and throws "used after being disposed".
class _LinkEntrySheet extends StatefulWidget {
  const _LinkEntrySheet();

  @override
  State<_LinkEntrySheet> createState() => _LinkEntrySheetState();
}

class _LinkEntrySheetState extends State<_LinkEntrySheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppBottomSheet(
      title: 'Paste a link',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.url,
            style: GoogleFonts.spaceMono(
              color: AppColors.fg(context),
              fontSize: 12,
            ),
            decoration: const InputDecoration(hintText: 'https://…'),
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () => Navigator.of(context).pop(_controller.text.trim()),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                color: AppColors.yellow,
                border: Border.all(color: AppColors.black),
              ),
              alignment: Alignment.center,
              child: Text(
                'ADD',
                style: GoogleFonts.spaceMono(
                  color: AppColors.black,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
