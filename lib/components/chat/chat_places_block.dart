import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:reelpin/constants/app_colors.dart';
import 'package:reelpin/constants/app_theme.dart';
import 'package:reelpin/data_models/chat/answer_block.dart';
import 'package:reelpin/utils/category_marker_icon.dart';
import 'package:reelpin/utils/location_maps_uri.dart';

/// The places in an answer, as small swipeable cards — one per location,
/// each a lite-mode map snippet (like the Map tab's own pins) plus the place
/// name, opening straight to that place in the user's own Maps app on tap.
/// Mirrors `ChatReelStrip`'s layout so a "from your saves" strip reads the
/// same way whether it's reels or places.
class ChatPlacesBlockView extends StatelessWidget {
  const ChatPlacesBlockView({super.key, required this.places});

  final List<AnswerPlace> places;

  static const _cardWidth = 140.0;
  static const _cardHeight = 118.0;

  @override
  Widget build(BuildContext context) {
    // A place without real coordinates would open a Maps search at 0,0 — off
    // the coast of West Africa, not somewhere the user saved anything.
    final mappable = places
        .where((place) => place.latitude != 0 || place.longitude != 0)
        .toList();
    // The label reflects what actually renders, so it never claims a place
    // count above a strip that has collapsed to nothing.
    if (mappable.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            mappable.length > 1
                ? '${mappable.length} PLACES FROM YOUR SAVES · SWIPE →'
                : '${mappable.length} PLACES FROM YOUR SAVES',
            style: GoogleFonts.spaceMono(
              color: AppColors.textSec(context),
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
            ),
          ),
        ),
        SizedBox(
          height: _cardHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 2),
            itemCount: mappable.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              return SizedBox(
                width: _cardWidth,
                child: _PlaceCard(place: mappable[index]),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PlaceCard extends StatefulWidget {
  const _PlaceCard({required this.place});

  final AnswerPlace place;

  @override
  State<_PlaceCard> createState() => _PlaceCardState();
}

class _PlaceCardState extends State<_PlaceCard> {
  // Lite mode's "open in Maps" icon renders at a roughly fixed pixel size
  // regardless of the requested image size. Rendering the map this many
  // times larger than its visible footprint, then scaling the whole result
  // back down, shrinks that icon by the same factor along with it — a
  // supersample-then-downscale trick, not a fixed-position cover-up.
  static const _superSample = 2.0;
  // Capturing `_superSample` times the pixels at the same zoom level also
  // captures that much more *area* — the pin then reads smaller, with more
  // empty map padded around it once the whole thing is scaled back down.
  // Zooming in by log2(_superSample) cancels that out; the extra +0.4 pulls
  // in past a plain cancel-out to close up what was still left as padding
  // around the pin at the exact compensated zoom.
  static const _zoom = 15.0;
  static final _superSampledZoom =
      _zoom + (math.log(_superSample) / math.ln2) + 0.4;

  // Drawn as a plain overlay image, not a native Marker: a lite mode map
  // bakes its own "directions" / "open in Maps" icons around any real
  // marker regardless of the marker's own icon, so the only way to keep the
  // map clean is to never give it a marker to decorate in the first place.
  Uint8List? _iconBytes;

  @override
  void initState() {
    super.initState();
    unawaited(_loadIcon());
  }

  @override
  void didUpdateWidget(covariant _PlaceCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.place.category != widget.place.category) {
      _iconBytes = null;
      unawaited(_loadIcon());
    }
  }

  Future<void> _loadIcon() async {
    final bytes = await createCategoryMarkerPng(widget.place.category);
    if (!mounted) return;
    setState(() => _iconBytes = bytes);
  }

  @override
  Widget build(BuildContext context) {
    final place = widget.place;
    final uri = locationMapsSearchUri(
      name: place.name,
      latitude: place.latitude,
      longitude: place.longitude,
    );
    final position = LatLng(place.latitude, place.longitude);
    final iconBytes = _iconBytes;

    return GestureDetector(
      onTap: uri == null ? null : () => _openInMaps(uri),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.bg(context),
          border: Border.all(color: AppColors.fg(context)),
          boxShadow: AppTheme.brutalShadowSmall(context),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              // Lite mode, no markers, gestures absorbed: a still snapshot
              // of the map only — see _iconBytes above for why the pin
              // itself is drawn separately, on top, rather than as a
              // Marker.
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRect(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth * _superSample;
                        final height = constraints.maxHeight * _superSample;
                        return Transform.scale(
                          scale: 1 / _superSample,
                          child: OverflowBox(
                            maxWidth: width,
                            maxHeight: height,
                            minWidth: width,
                            minHeight: height,
                            child: AbsorbPointer(
                              child: GoogleMap(
                                initialCameraPosition: CameraPosition(
                                  target: position,
                                  zoom: _superSampledZoom,
                                ),
                                liteModeEnabled: true,
                                zoomControlsEnabled: false,
                                myLocationButtonEnabled: false,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  if (iconBytes != null)
                    Center(
                      // The camera is centred on `position`, so the pin's
                      // tip — not its middle — has to land on the widget's
                      // centre; shifting up by half its own height does
                      // that.
                      child: FractionalTranslation(
                        translation: const Offset(0, -0.5),
                        child: Image.memory(iconBytes, width: 26, height: 34),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Text(
                place.name.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.spaceMono(
                  color: AppColors.fg(context),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openInMaps(Uri uri) async {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
