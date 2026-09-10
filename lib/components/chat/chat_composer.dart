import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:reelpin/constants/app_colors.dart';
import 'package:reelpin/constants/app_theme.dart';
import 'package:reelpin/data_models/chat/chat_attachment.dart';

class ChatComposer extends StatefulWidget {
  const ChatComposer({
    super.key,
    required this.onSend,
    required this.enabled,
    this.onAttach,
    this.initialText = '',
    this.pending = const [],
    this.onRemoveAttachment,
  });

  final ValueChanged<String> onSend;

  /// Null hides the attach button entirely — the collection chat has nothing
  /// to attach, because the collection *is* the scope.
  final VoidCallback? onAttach;
  final bool enabled;
  final String initialText;

  /// Attachments picked but not yet sent. Shown as chips above the input row
  /// and cleared by the caller once `onSend` fires.
  final List<ChatAttachment> pending;
  final ValueChanged<int>? onRemoveAttachment;

  @override
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialText,
  );

  @override
  void didUpdateWidget(covariant ChatComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // ChatScreen lives inside AppShell's IndexedStack and is mounted once, so
    // a new seed ("ask about this reel", set after this composer already
    // exists) arrives as a widget update, not a fresh mount. Only applied
    // when it actually changes and isn't empty, so this never overwrites
    // text the user is actively typing.
    if (widget.initialText != oldWidget.initialText &&
        widget.initialText.isNotEmpty) {
      _controller.text = widget.initialText;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    if (!widget.enabled) return;
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    widget.onSend(text);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
      decoration: BoxDecoration(
        color: AppColors.bg(context),
        border: Border(top: BorderSide(color: AppColors.fg(context))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.pending.isNotEmpty) ...[
            _pendingChips(context),
            const SizedBox(height: 8),
          ],
          _inputRow(context),
        ],
      ),
    );
  }

  Widget _pendingChips(BuildContext context) {
    return Wrap(
      spacing: 5,
      runSpacing: 5,
      children: [
        for (var i = 0; i < widget.pending.length; i++)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.white,
              border: Border.all(color: AppColors.black),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // A reel title can be wider than the screen.
                Flexible(
                  child: Text(
                    '${widget.pending[i].kind.label} · ${widget.pending[i].displayName}'
                        .toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.spaceMono(
                      color: AppColors.black,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => widget.onRemoveAttachment?.call(i),
                  child: const Padding(
                    padding: EdgeInsets.only(left: 5),
                    child: Icon(Icons.close, size: 11, color: AppColors.black),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // The total height the input row occupies: the text field box is fixed to
  // exactly this, and the buttons are sized so the button *plus* its brutal
  // shadow (which paints outside the button's own box) also spans exactly
  // this — otherwise the shadow pokes out past the text field's bottom edge.
  static const _fieldHeight = 42.0;
  // Matches AppTheme.brutalShadowSmall's offset: the shadow is drawn shifted
  // this far right/down from the button, so shrinking the button by this much
  // lets the shadow fill the remainder instead of overflowing it.
  static const _shadowOffset = 3.0;
  static const _buttonBoxSize = _fieldHeight - _shadowOffset;

  Widget _inputRow(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.onAttach != null) ...[
          _button(
            context,
            color: AppColors.blue,
            child: const Icon(Icons.add, size: 18, color: AppColors.white),
            onTap: widget.onAttach!,
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: SizedBox(
            height: _fieldHeight,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.fg(context)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: TextField(
                controller: _controller,
                enabled: widget.enabled,
                expands: true,
                minLines: null,
                maxLines: null,
                textAlignVertical: TextAlignVertical.center,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                style: GoogleFonts.spaceMono(
                  color: AppColors.fg(context),
                  fontSize: 12.5,
                ),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  // The app-wide InputDecorationTheme sets its own enabled/
                  // focused borders, which win over `border: InputBorder.none`
                  // above and drew a second rectangle inside this one.
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  filled: false,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  hintText: 'ASK ANYTHING…',
                  hintStyle: GoogleFonts.spaceMono(
                    color: AppColors.textTertiary,
                    fontSize: 11,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        _button(
          context,
          // Yellow, not an accent colour: sending is the app's primary action.
          color: AppColors.yellow,
          child: const Icon(
            Icons.arrow_upward,
            size: 18,
            color: AppColors.black,
          ),
          onTap: _send,
        ),
      ],
    );
  }

  Widget _button(
    BuildContext context, {
    required Color color,
    required Widget child,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: widget.enabled ? onTap : null,
      child: Opacity(
        opacity: widget.enabled ? 1 : 0.4,
        child: Container(
          width: _buttonBoxSize,
          height: _buttonBoxSize,
          decoration: BoxDecoration(
            color: color,
            border: Border.all(color: AppColors.fg(context)),
            boxShadow: AppTheme.brutalShadowSmall(context),
          ),
          alignment: Alignment.center,
          child: child,
        ),
      ),
    );
  }
}
