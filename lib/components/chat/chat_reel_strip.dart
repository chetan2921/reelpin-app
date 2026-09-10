import 'dart:async';

import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:reelpin/components/chat/chat_reel_strip_card.dart';
import 'package:reelpin/constants/app_colors.dart';
import 'package:reelpin/constants/app_layout.dart';
import 'package:reelpin/data_models/reels/reel.dart';
import 'package:reelpin/services/chat/chat_reel_cache.dart';

/// The saves an answer drew from, as the app's own cards.
///
/// The backend searches the user's *entire* library and can cite any reel,
/// but `library` is only whatever the paginated grid has cached — so a
/// cited id missing from it isn't necessarily deleted, just not paged in
/// yet. Anything not in `library` is fetched through [reelCache] instead of
/// being dropped outright; only a fetch that actually fails (a genuinely
/// deleted reel 404s) still drops silently, which is the original,
/// intentional behaviour for that case.
class ChatReelStrip extends StatefulWidget {
  const ChatReelStrip({
    super.key,
    required this.reelIds,
    required this.library,
    required this.onTapReel,
    required this.reelCache,
  });

  final List<String> reelIds;
  final List<Reel> library;
  final ValueChanged<Reel> onTapReel;
  final ChatReelCache reelCache;

  static const _cardWidth = 118.0;
  static const _stripHeight = 152.0;

  @override
  State<ChatReelStrip> createState() => _ChatReelStripState();
}

class _ChatReelStripState extends State<ChatReelStrip> {
  /// Reels this widget instance fetched itself, keyed by id. Separate from
  /// `reelCache`'s own cache — that one is shared and long-lived; this is
  /// just what's needed to paint this build.
  final Map<String, Reel> _fetched = {};

  /// The id sets `_resolveMissing` last acted on. `library`'s identity
  /// changes on nearly every rebuild of the enclosing `ChatScreen` —
  /// `ReelRepository.cachedReels` returns a fresh `List.unmodifiable` copy
  /// each call — so comparing `oldWidget.library != widget.library` was
  /// true on essentially every rebuild. Comparing the actual id sets means a
  /// rebuild that changes nothing about the citations does no work at all.
  Set<String> _lastReelIds = const {};
  Set<String> _lastLibraryIds = const {};

  @override
  void initState() {
    super.initState();
    _resolveMissing();
  }

  @override
  void didUpdateWidget(covariant ChatReelStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    final reelIds = widget.reelIds.toSet();
    final libraryIds = {for (final reel in widget.library) reel.id};
    if (!setEquals(reelIds, _lastReelIds) ||
        !setEquals(libraryIds, _lastLibraryIds)) {
      _resolveMissing();
    }
  }

  void _resolveMissing() {
    final cache = widget.reelCache;
    final libraryIds = {for (final reel in widget.library) reel.id};
    _lastReelIds = widget.reelIds.toSet();
    _lastLibraryIds = libraryIds;
    for (final id in widget.reelIds) {
      if (libraryIds.contains(id) || _fetched.containsKey(id)) continue;

      // A synchronous hit paints on this very frame; nothing to await.
      final hit = cache.cached(id);
      if (hit != null) {
        _fetched[id] = hit;
        continue;
      }

      // Fired without awaiting, so ids resolve in parallel rather than one
      // at a time — a fetch that fails resolves to null and is dropped.
      unawaited(
        cache.resolve(id).then((reel) {
          if (!mounted || reel == null) return;
          setState(() => _fetched[id] = reel);
        }),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final byId = {
      for (final reel in widget.library) reel.id: reel,
      ..._fetched,
    };
    final resolved = widget.reelIds
        .map((id) => byId[id])
        .whereType<Reel>()
        .toList();

    // Owns its own label rather than letting a caller print one above a
    // strip that may render nothing when every id fails to resolve.
    if (resolved.isEmpty) return const SizedBox.shrink();

    final layout = AppLayout.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            'FROM YOUR SAVES · SWIPE →',
            style: GoogleFonts.spaceMono(
              color: AppColors.textSec(context),
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
            ),
          ),
        ),
        SizedBox(
          height: ChatReelStrip._stripHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            // Room for the pin, which overhangs the card's top-right corner
            // by exactly layout.inset(4)/layout.gap(4) — the same scale
            // ChatReelStripCard uses to position it — so it is never
            // clipped.
            padding: EdgeInsets.fromLTRB(4, layout.gap(4), layout.inset(4), 6),
            itemCount: resolved.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final reel = resolved[index];
              return SizedBox(
                width: ChatReelStrip._cardWidth,
                child: ChatReelStripCard(
                  reel: reel,
                  onTap: () => widget.onTapReel(reel),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
