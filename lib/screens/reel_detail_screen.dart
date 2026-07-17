import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/reel.dart';
import '../providers/app_providers.dart';
import '../services/api_service.dart';
import '../services/reel_share_service.dart';
import '../theme/app_theme.dart';
import 'paywall_screen.dart';

const String _appStoreUrl =
    'https://apps.apple.com/us/app/reelpin/id6777110022';
const String _playStoreUrl =
    'https://play.google.com/store/apps/details?id=com.chetanjain.reelpin';

Uri? locationMapsUri(Location loc) {
  return locationMapsSearchUri(
    name: loc.name,
    displayLabel: loc.displayLabel,
    address: loc.address,
    backendUrl: loc.googleMapsUrl,
    latitude: loc.latitude,
    longitude: loc.longitude,
  );
}

Uri? locationMapsSearchUri({
  String? name,
  String? displayLabel,
  String? address,
  String? backendUrl,
  double? latitude,
  double? longitude,
}) {
  final placeQuery = _firstNonEmpty([name, displayLabel, address]);
  if (placeQuery != null) {
    return Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(placeQuery)}',
    );
  }

  final fallbackUri = _externalLocationUri(backendUrl);
  if (fallbackUri != null) {
    return fallbackUri;
  }

  if (latitude != null && longitude != null) {
    return Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
    );
  }
  return null;
}

Uri? _externalLocationUri(String? rawUrl) {
  final trimmed = rawUrl?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;

  final uri = Uri.tryParse(trimmed);
  if (uri == null) return null;
  if (!uri.hasScheme) return null;
  final scheme = uri.scheme.toLowerCase();
  if (scheme != 'http' && scheme != 'https') return null;
  if (uri.host.trim().isEmpty) return null;
  return uri;
}

String? _firstNonEmpty(List<String?> values) {
  for (final value in values) {
    final trimmed = value?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      return trimmed;
    }
  }
  return null;
}

class ReelDetailScreen extends ConsumerStatefulWidget {
  final Reel reel;

  const ReelDetailScreen({super.key, required this.reel});

  @override
  ConsumerState<ReelDetailScreen> createState() => _ReelDetailScreenState();
}

class _ReelDetailScreenState extends ConsumerState<ReelDetailScreen> {
  final GlobalKey _shareCardKey = GlobalKey();
  bool _transcriptExpanded = false;
  late Reel _activeReel;
  bool _isRefreshingReel = false;
  bool _isSharingReel = false;
  ApiException? _reelAccessError;
  String? _reelLoadError;

  Reel get reel => _activeReel;
  String get _openSourceLabel => 'OPEN $_openSourceNoun';
  String get _openSourceErrorLabel => 'COULD NOT OPEN $_openSourceNoun';
  String get _openSourceNoun {
    final platform = _sourcePlatform;
    if (platform == 'youtube') {
      if (_isShortsSource) return 'SHORTS';
      return 'VIDEO';
    }
    if (platform == 'instagram') {
      if (_isInstagramPostSource) return 'POST';
      return 'REEL';
    }
    return 'REEL';
  }

  String? get _sourcePlatform {
    final explicit = reel.sourcePlatform?.trim().toLowerCase();
    if (explicit == 'youtube' || explicit == 'instagram') return explicit;
    if (_hasSourceUri(_isYoutubeUri)) return 'youtube';
    if (_hasSourceUri(_isInstagramUri)) return 'instagram';
    return explicit?.isEmpty == true ? null : explicit;
  }

  bool get _isShortsSource {
    final contentType = reel.sourceContentType?.trim().toLowerCase();
    if (contentType == 'short' || contentType == 'shorts') return true;
    return _hasSourceUri(_isYoutubeShortsUri);
  }

  bool get _isInstagramPostSource {
    final contentType = reel.sourceContentType?.trim().toLowerCase();
    if (contentType == 'post' ||
        contentType == 'carousel' ||
        contentType == 'carousal') {
      return true;
    }
    if (contentType == 'reel') return false;
    if (_hasSourceUri(_isInstagramPostUri)) return true;
    if (_hasSourceUri(_isInstagramReelUri)) return false;

    final fallbackType = reel.contentType.trim().toLowerCase();
    if (fallbackType == 'carousel' || fallbackType == 'carousal') return true;
    return _sourcePlatform == 'instagram' && fallbackType == 'post';
  }

  Iterable<Uri> get _sourceUris sync* {
    for (final rawUrl in [
      reel.sourceUrl,
      reel.originalUrl,
      reel.normalizedUrl,
      reel.url,
    ]) {
      final uri = Uri.tryParse(rawUrl.trim());
      if (uri != null && uri.hasScheme && uri.host.trim().isNotEmpty) {
        yield uri;
      }
    }
  }

  bool _hasSourceUri(bool Function(Uri uri) test) => _sourceUris.any(test);

  bool _isYoutubeUri(Uri uri) {
    final host = uri.host.toLowerCase();
    return host == 'youtube.com' ||
        host == 'www.youtube.com' ||
        host == 'm.youtube.com' ||
        host == 'youtu.be';
  }

  bool _isYoutubeShortsUri(Uri uri) {
    if (!_isYoutubeUri(uri)) return false;
    return uri.pathSegments.isNotEmpty &&
        uri.pathSegments.first.toLowerCase() == 'shorts';
  }

  bool _isInstagramUri(Uri uri) {
    final host = uri.host.toLowerCase();
    return host == 'instagram.com' || host == 'www.instagram.com';
  }

  bool _isInstagramPostUri(Uri uri) {
    if (!_isInstagramUri(uri) || uri.pathSegments.isEmpty) return false;
    final firstSegment = uri.pathSegments.first.toLowerCase();
    return firstSegment == 'p' || firstSegment == 'tv';
  }

  bool _isInstagramReelUri(Uri uri) {
    if (!_isInstagramUri(uri) || uri.pathSegments.isEmpty) return false;
    final firstSegment = uri.pathSegments.first.toLowerCase();
    return firstSegment == 'reel' || firstSegment == 'reels';
  }

  Color get _detailTextColor => Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFFD0D0D0)
      : AppTheme.textSecondary;

  @override
  void initState() {
    super.initState();
    _activeReel = widget.reel;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshReel();
    });
  }

  @override
  Widget build(BuildContext context) {
    final catColor = AppTheme.getCategoryColor(reel.category);
    final layout = AppLayout.of(context);
    final hasOpenableReel = _openReelUrl != null;

    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      body: Stack(
        clipBehavior: Clip.none,
        children: [
          CustomScrollView(
            slivers: [
              // ── App Bar ──
              SliverAppBar(
                pinned: true,
                backgroundColor: AppTheme.bg(context),
                surfaceTintColor: Colors.transparent,
                leading: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.fg(context), width: 2),
                    ),
                    child: Icon(
                      Icons.arrow_back,
                      color: AppTheme.fg(context),
                      size: 20,
                    ),
                  ),
                ),
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(3),
                  child: Container(
                    height: AppTheme.borderWidth,
                    color: AppTheme.fg(context),
                  ),
                ),
                actions: [
                  // Open source reel
                  GestureDetector(
                    onTap: hasOpenableReel ? _openReel : null,
                    child: Container(
                      margin: EdgeInsets.only(right: layout.inset(12)),
                      padding: EdgeInsets.symmetric(
                        horizontal: layout.inset(14),
                      ),
                      height: layout.inset(36),
                      decoration: BoxDecoration(
                        color: hasOpenableReel
                            ? AppTheme.yellow
                            : AppTheme.surfaceElevatedColor(context),
                        border: Border.all(
                          color: AppTheme.fg(context),
                          width: 2,
                        ),
                        boxShadow: AppTheme.brutalShadowSmall(context),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _openSourceLabel,
                        style: GoogleFonts.spaceMono(
                          color: hasOpenableReel
                              ? AppTheme.black
                              : AppTheme.textSec(context),
                          fontSize: layout.font(10),
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),

                  // Delete
                  GestureDetector(
                    onTap: () => _confirmDelete(context),
                    child: Container(
                      margin: EdgeInsets.only(right: layout.inset(12)),
                      width: layout.inset(36),
                      height: layout.inset(36),
                      decoration: BoxDecoration(
                        color: AppTheme.destructive,
                        border: Border.all(
                          color: AppTheme.fg(context),
                          width: 2,
                        ),
                        boxShadow: AppTheme.brutalShadowSmall(context),
                      ),
                      child: const Icon(
                        Icons.delete,
                        color: AppTheme.white,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),

              // ── Content ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    layout.inset(20),
                    layout.gap(16),
                    layout.inset(20),
                    layout.gap(40),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_isRefreshingReel) ...[
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: layout.inset(10),
                            vertical: layout.gap(8),
                          ),
                          decoration: AppTheme.brutalBox(
                            context,
                            color: AppTheme.bg(context),
                            shadow: true,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: layout.inset(14),
                                height: layout.inset(14),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppTheme.fg(context),
                                ),
                              ),
                              SizedBox(width: layout.inset(8)),
                              Text(
                                'CHECKING ACCESS...',
                                style: GoogleFonts.spaceMono(
                                  color: AppTheme.fg(context),
                                  fontSize: layout.font(10),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: layout.gap(16)),
                      ],

                      if (_reelAccessError?.isHistoryUpgradeRequired ==
                          true) ...[
                        _buildLockedHistoryState(context),
                      ] else ...[
                        if (_reelLoadError != null) ...[
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(layout.inset(14)),
                            decoration: AppTheme.brutalBox(
                              context,
                              color: const Color(0xFFFFF2B6),
                              shadow: true,
                            ),
                            child: Text(
                              _reelLoadError!,
                              style: GoogleFonts.spaceMono(
                                color: AppTheme.black,
                                fontSize: layout.font(11),
                                fontWeight: FontWeight.w700,
                                height: 1.4,
                              ),
                            ),
                          ),
                          SizedBox(height: layout.gap(16)),
                        ],

                        // Category + share
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Wrap(
                                spacing: layout.inset(8),
                                runSpacing: layout.gap(8),
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: catColor,
                                      border: Border.all(
                                        color: AppTheme.fg(context),
                                        width: 2,
                                      ),
                                    ),
                                    child: Text(
                                      reel.category.toUpperCase(),
                                      style: GoogleFonts.spaceMono(
                                        color: _contrastText(catColor),
                                        fontSize: layout.font(10),
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ),
                                  if (reel.subCategory != reel.category)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppTheme.bg(context),
                                        border: Border.all(
                                          color: AppTheme.fg(context),
                                          width: 2,
                                        ),
                                      ),
                                      child: Text(
                                        reel.subCategory.toUpperCase(),
                                        style: GoogleFonts.spaceMono(
                                          color: AppTheme.fg(context),
                                          fontSize: layout.font(10),
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            SizedBox(width: layout.inset(8)),
                            Padding(
                              padding: EdgeInsets.only(top: layout.gap(1)),
                              child: _shareButton(
                                layout,
                                margin: EdgeInsets.zero,
                              ),
                            ),
                          ],
                        ),
                        if (reel.relativeDate.isNotEmpty) ...[
                          SizedBox(height: layout.gap(8)),
                          Text(
                            reel.relativeDate.toUpperCase(),
                            style: GoogleFonts.spaceMono(
                              color: _detailTextColor,
                              fontSize: layout.font(11),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                        SizedBox(height: layout.gap(16)),

                        // Title
                        Text(
                          reel.title.isNotEmpty
                              ? reel.title.toUpperCase()
                              : 'UNTITLED REEL',
                          style: GoogleFonts.spaceMono(
                            color: AppTheme.fg(context),
                            fontSize: layout.font(22, maxFactor: 1.1),
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                            letterSpacing: -0.5,
                          ),
                        ),

                        SizedBox(height: layout.gap(4)),
                        Container(
                          height: layout.gap(4),
                          width: layout.inset(60),
                          color: AppTheme.yellow,
                        ),

                        SizedBox(height: layout.gap(20)),

                        // ── Sections ──
                        if (reel.summary.isNotEmpty) ...[
                          _section('SUMMARY', reel.summary),
                          const SizedBox(height: 20),
                        ],

                        if (reel.keyFacts.isNotEmpty) ...[
                          _sectionTitle('KEY FACTS'),
                          const SizedBox(height: 10),
                          ...reel.keyFacts.map(
                            (f) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    margin: const EdgeInsets.only(top: 4),
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: AppTheme.red,
                                      border: Border.all(
                                        color: AppTheme.fg(context),
                                        width: 1,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      f,
                                      style: GoogleFonts.spaceMono(
                                        color: _detailTextColor,
                                        fontSize: 13,
                                        height: 1.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        if (reel.locations.isNotEmpty) ...[
                          _sectionTitle('LOCATIONS'),
                          const SizedBox(height: 10),
                          ...reel.locations.map((loc) {
                            final mapsUri = _locationMapsUri(loc);
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: GestureDetector(
                                onTap: mapsUri == null
                                    ? null
                                    : () => _openLocation(mapsUri),
                                child: Container(
                                  decoration: AppTheme.brutalCard(context),
                                  child: Row(
                                    children: [
                                      // Green accent bar
                                      Container(
                                        width: 6,
                                        height: 56,
                                        color: AppTheme.neonGreen,
                                      ),
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 10,
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                loc.name.toUpperCase(),
                                                style: GoogleFonts.spaceMono(
                                                  color: AppTheme.fg(context),
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              if (loc.address != null) ...[
                                                const SizedBox(height: 2),
                                                Text(
                                                  loc.address!,
                                                  style: GoogleFonts.spaceMono(
                                                    color: _detailTextColor,
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ),
                                      if (mapsUri != null)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            right: 12,
                                          ),
                                          child: Container(
                                            width: 40,
                                            height: 40,
                                            decoration: BoxDecoration(
                                              color: AppTheme.red,
                                              border: Border.all(
                                                color: AppTheme.fg(context),
                                                width: 2,
                                              ),
                                            ),
                                            alignment: Alignment.center,
                                            child: Icon(
                                              Icons.navigation,
                                              size: 22,
                                              color: AppTheme.white,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                          const SizedBox(height: 16),
                        ],

                        if (reel.peopleMentioned.isNotEmpty) ...[
                          _sectionTitle('PEOPLE MENTIONED'),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: reel.peopleMentioned.map((person) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.yellow,
                                  border: Border.all(
                                    color: AppTheme.fg(context),
                                    width: 2,
                                  ),
                                  boxShadow: AppTheme.brutalShadowSmall(
                                    context,
                                  ),
                                ),
                                child: Text(
                                  person.toUpperCase(),
                                  style: GoogleFonts.spaceMono(
                                    color: AppTheme.black,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 16),
                        ],

                        if (reel.actionableItems.isNotEmpty) ...[
                          _sectionTitle('ACTION ITEMS'),
                          const SizedBox(height: 10),
                          ...reel.actionableItems.map(
                            (item) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    margin: const EdgeInsets.only(top: 2),
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      color: AppTheme.neonGreen,
                                      border: Border.all(
                                        color: AppTheme.fg(context),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.arrow_forward,
                                      size: 12,
                                      color: AppTheme.black,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      item,
                                      style: GoogleFonts.spaceMono(
                                        color: _detailTextColor,
                                        fontSize: 13,
                                        height: 1.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Transcript
                        if (reel.transcript.isNotEmpty) ...[
                          _sectionTitle('TRANSCRIPT'),
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceElevated,
                              border: Border.all(
                                color: AppTheme.fg(context),
                                width: 2,
                              ),
                            ),
                            child: AnimatedCrossFade(
                              duration: const Duration(milliseconds: 250),
                              firstChild: Text(
                                reel.transcript,
                                maxLines: 4,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.spaceMono(
                                  color: AppTheme.black,
                                  fontSize: 12,
                                  height: 1.6,
                                ),
                              ),
                              secondChild: Text(
                                reel.transcript,
                                style: GoogleFonts.spaceMono(
                                  color: AppTheme.black,
                                  fontSize: 12,
                                  height: 1.6,
                                ),
                              ),
                              crossFadeState: _transcriptExpanded
                                  ? CrossFadeState.showSecond
                                  : CrossFadeState.showFirst,
                            ),
                          ),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: () => setState(
                              () => _transcriptExpanded = !_transcriptExpanded,
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.blue,
                                border: Border.all(
                                  color: AppTheme.fg(context),
                                  width: 2,
                                ),
                                boxShadow: AppTheme.brutalShadowSmall(context),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _transcriptExpanded
                                        ? 'SHOW LESS'
                                        : 'SHOW FULL TRANSCRIPT',
                                    style: GoogleFonts.spaceMono(
                                      color: AppTheme.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  AnimatedRotation(
                                    duration: const Duration(milliseconds: 250),
                                    turns: _transcriptExpanded ? 0.5 : 0,
                                    child: const Icon(
                                      Icons.keyboard_arrow_down,
                                      size: 18,
                                      color: AppTheme.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (_isSharingReel)
            Positioned(
              left: -1400,
              top: 0,
              child: UnconstrainedBox(
                alignment: Alignment.topLeft,
                child: RepaintBoundary(
                  key: _shareCardKey,
                  child: ReelShareCard(reel: reel),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _contrastText(Color bg) {
    return bg.computeLuminance() > 0.5 ? AppTheme.black : AppTheme.white;
  }

  Widget _sectionTitle(String title) {
    final layout = AppLayout.of(context);
    return Row(
      children: [
        Container(
          width: layout.inset(4),
          height: layout.gap(18),
          color: AppTheme.fg(context),
        ),
        SizedBox(width: layout.inset(8)),
        Text(
          title,
          style: GoogleFonts.spaceMono(
            color: AppTheme.fg(context),
            fontSize: layout.font(14),
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  Widget _section(String title, String body) {
    final layout = AppLayout.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(title),
        SizedBox(height: layout.gap(10)),
        Text(
          body,
          style: GoogleFonts.spaceMono(
            color: _detailTextColor,
            fontSize: layout.font(13),
            height: 1.6,
          ),
        ),
      ],
    );
  }

  Widget _buildLockedHistoryState(BuildContext context) {
    final layout = AppLayout.of(context);
    return Container(
      width: double.infinity,
      decoration: AppTheme.brutalCard(context, color: const Color(0xFFFFF2B6)),
      child: Padding(
        padding: EdgeInsets.all(layout.inset(18)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'FULL HISTORY IS PRO',
              style: GoogleFonts.spaceMono(
                color: AppTheme.black,
                fontSize: layout.font(18),
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: layout.gap(10)),
            Text(
              'This saved reel is outside the Free history window. Upgrade to Pro to open older saves again.',
              style: GoogleFonts.spaceMono(
                color: AppTheme.black,
                fontSize: layout.font(12),
                fontWeight: FontWeight.w600,
                height: 1.5,
              ),
            ),
            SizedBox(height: layout.gap(14)),
            GestureDetector(
              onTap: () =>
                  openPaywall(context, entryPoint: PaywallEntryPoint.history),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: layout.inset(12),
                  vertical: layout.gap(10),
                ),
                decoration: AppTheme.brutalBox(
                  context,
                  color: AppTheme.hotPink,
                  shadow: true,
                ),
                child: Text(
                  'VIEW PRO',
                  style: GoogleFonts.spaceMono(
                    color: AppTheme.white,
                    fontSize: layout.font(11),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _shareReel() async {
    if (_isSharingReel) return;

    setState(() {
      _isSharingReel = true;
    });

    try {
      await precacheImage(
        const AssetImage('assets/images/app_icon.png'),
        context,
      );
      if (!mounted) return;
      await precacheImage(const AssetImage('assets/images/pin.png'), context);
      if (!mounted) return;
      await WidgetsBinding.instance.endOfFrame;
      await WidgetsBinding.instance.endOfFrame;

      final boundary =
          _shareCardKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) {
        throw StateError('Share card is not ready.');
      }

      final image = await boundary.toImage(pixelRatio: 2);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw StateError('Could not prepare share image.');
      }

      final reelUrl = _shareReelUrl;
      await ReelShareService.shareReelCard(
        pngBytes: byteData.buffer.asUint8List(),
        subject: _shareTitle,
        text: _shareText(reelUrl),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'COULD NOT SHARE REEL',
            style: GoogleFonts.spaceMono(
              color: AppTheme.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          backgroundColor: AppTheme.destructive,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSharingReel = false;
        });
      }
    }
  }

  String get _shareTitle {
    final title = reel.title.trim();
    return title.isEmpty ? 'ReelPin saved reel' : title;
  }

  String _shareText(String? reelUrl) {
    final buffer = StringBuffer()
      ..writeln(_shareTitle)
      ..writeln()
      ..writeln('Saved and summarized with ReelPin.');

    final locationLinks = _shareLocationLinks();
    if (locationLinks.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln()
        ..writeln('Locations on Google Maps:');
      for (final link in locationLinks) {
        buffer.writeln('${link.label}: ${link.url}');
      }
    }

    if (reelUrl != null) {
      buffer
        ..writeln()
        ..writeln(reelUrl);
    }

    buffer
      ..writeln()
      ..writeln()
      ..writeln('Download ReelPin:')
      ..writeln('iOS: $_appStoreUrl')
      ..write('Android: $_playStoreUrl');
    return buffer.toString();
  }

  List<_ShareLocationLink> _shareLocationLinks() {
    final locations = reel.mappableLocations.isNotEmpty
        ? reel.mappableLocations
        : reel.locations;
    final links = <_ShareLocationLink>[];
    final seenUrls = <String>{};
    for (final location in locations) {
      final uri = _locationMapsUri(location);
      if (uri == null) continue;
      final url = uri.toString();
      if (!seenUrls.add(url)) continue;
      links.add(_ShareLocationLink(_shareLocationLabel(location), url));
    }
    return links;
  }

  String _shareLocationLabel(Location location) {
    final label = _firstNonEmpty([
      location.displayLabel,
      location.name,
      location.address,
    ]);
    return label ?? 'Location';
  }

  String? get _shareReelUrl {
    for (final candidate in [
      reel.sourceUrl,
      reel.originalUrl,
      reel.normalizedUrl,
      reel.url,
    ]) {
      final uri = _externalUri(candidate);
      if (uri != null) {
        return uri.toString();
      }
    }
    return null;
  }

  Widget _shareButton(AppLayout layout, {required EdgeInsetsGeometry margin}) {
    return GestureDetector(
      onTap: _isSharingReel ? null : _shareReel,
      child: Container(
        margin: margin,
        padding: EdgeInsets.symmetric(horizontal: layout.inset(9)),
        height: layout.inset(30),
        decoration: BoxDecoration(
          color: _isSharingReel
              ? AppTheme.surfaceElevatedColor(context)
              : AppTheme.blue,
          border: Border.all(color: AppTheme.fg(context), width: 2),
          boxShadow: AppTheme.brutalShadowSmall(context),
        ),
        alignment: Alignment.center,
        child: _isSharingReel
            ? SizedBox(
                width: layout.inset(12),
                height: layout.inset(12),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.fg(context),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.share, color: AppTheme.white, size: 16),
                  SizedBox(width: layout.inset(5)),
                  Text(
                    'SHARE',
                    style: GoogleFonts.spaceMono(
                      color: AppTheme.white,
                      fontSize: layout.font(9),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bg(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(0),
          side: BorderSide(
            color: AppTheme.fg(context),
            width: AppTheme.borderWidth,
          ),
        ),
        title: Text(
          'DELETE THIS REEL?',
          style: GoogleFonts.spaceMono(
            color: AppTheme.fg(context),
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'This action cannot be undone.',
          style: GoogleFonts.spaceMono(color: _detailTextColor, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'CANCEL',
              style: GoogleFonts.spaceMono(
                color: _detailTextColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(reelRepositoryProvider).deleteReel(reel.id);
                if (context.mounted) {
                  _maybeRead(homeViewModelProvider)?.removeReel(reel.id);
                  _maybeRead(mapViewModelProvider)?.removeReel(reel.id);
                  _maybeRead(discoverViewModelProvider)?.removeReel(reel.id);
                  _maybeRead(searchViewModelProvider)?.removeReel(reel.id);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'REEL DELETED',
                        style: GoogleFonts.spaceMono(
                          color: AppTheme.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      backgroundColor: AppTheme.black,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'FAILED TO DELETE: $e',
                        style: GoogleFonts.spaceMono(
                          color: AppTheme.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      backgroundColor: AppTheme.destructive,
                    ),
                  );
                }
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.destructive,
                border: Border.all(color: AppTheme.fg(context), width: 2),
                boxShadow: AppTheme.brutalShadowSmall(context),
              ),
              child: Text(
                'DELETE',
                style: GoogleFonts.spaceMono(
                  color: AppTheme.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  T? _maybeRead<T>(ProviderListenable<T> provider) {
    try {
      return ref.read(provider);
    } catch (_) {
      return null;
    }
  }

  Uri? _locationMapsUri(Location loc) {
    return locationMapsUri(loc);
  }

  Future<void> _openLocation(Uri uri) async {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openReel() async {
    final uri = _openReelUrl;
    if (uri == null) {
      if (!mounted) return;
      _showOpenReelError();
      return;
    }

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      _showOpenReelError();
    }
  }

  Uri? get _openReelUrl {
    for (final candidate in [
      reel.sourceUrl,
      reel.originalUrl,
      reel.normalizedUrl,
      reel.url,
    ]) {
      final uri = _externalUri(candidate);
      if (uri != null) {
        return uri;
      }
    }
    return null;
  }

  Uri? _externalUri(String rawUrl) {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return null;

    final uri = Uri.tryParse(trimmed);
    if (uri == null) return null;
    if (!uri.hasScheme) return null;
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') return null;
    if ((uri.host).trim().isEmpty) return null;
    return uri;
  }

  void _showOpenReelError() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _openSourceErrorLabel,
          style: GoogleFonts.spaceMono(
            color: AppTheme.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: AppTheme.destructive,
      ),
    );
  }

  Future<void> _refreshReel() async {
    setState(() {
      _isRefreshingReel = true;
      _reelAccessError = null;
      _reelLoadError = null;
    });

    try {
      final latest = await ref
          .read(reelRepositoryProvider)
          .getReel(widget.reel.id, forceRefresh: true);
      if (!mounted) {
        return;
      }
      setState(() {
        _activeReel = latest;
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        if (error.isHistoryUpgradeRequired) {
          _reelAccessError = error;
        } else {
          _reelLoadError = userFacingErrorMessage(
            error,
            fallbackMessage: 'Could not load this reel right now.',
          );
        }
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _reelLoadError = userFacingErrorMessage(
          error,
          fallbackMessage: 'Could not load this reel right now.',
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshingReel = false;
        });
      }
    }
  }
}

class ReelShareCard extends StatelessWidget {
  final Reel reel;

  const ReelShareCard({super.key, required this.reel});

  @override
  Widget build(BuildContext context) {
    final title = reel.title.trim().isEmpty ? 'Untitled reel' : reel.title;
    final summary = _shareSummary(reel.summary);
    final facts = _shareItems(reel.keyFacts, 4);
    final actions = reel.actionableItems
        .where((item) => item.trim().isNotEmpty)
        .take(3)
        .toList();
    final hasSummary = summary.isNotEmpty;
    final hasFacts = facts.isNotEmpty;
    final hasActions = actions.isNotEmpty;

    return Material(
      color: Colors.transparent,
      child: SizedBox(
        width: 540,
        height: 540,
        child: Container(
          color: const Color(0xFFFFDF36),
          padding: const EdgeInsets.all(12),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                right: -10,
                top: 20,
                child: Transform.rotate(
                  angle: 0.08,
                  child: Container(
                    width: 92,
                    height: 116,
                    decoration: BoxDecoration(
                      color: const Color(0xFF16D7C8),
                      border: Border.all(color: AppTheme.black, width: 3),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: -18,
                bottom: 78,
                child: Transform.rotate(
                  angle: -0.12,
                  child: Container(
                    width: 92,
                    height: 72,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF4AA4),
                      border: Border.all(color: AppTheme.black, width: 3),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 18,
                bottom: 16,
                child: Opacity(
                  opacity: 0.07,
                  child: Transform.rotate(
                    angle: -0.34,
                    child: Image.asset(
                      'assets/images/pin.png',
                      width: 132,
                      height: 132,
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.white,
                    border: Border.all(color: AppTheme.black, width: 4),
                    boxShadow: const [
                      BoxShadow(
                        color: AppTheme.black,
                        offset: Offset(7, 7),
                        blurRadius: 0,
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ShareHeader(contentType: reel.contentType),
                        const SizedBox(height: 5),
                        Container(height: 4, color: AppTheme.black),
                        const SizedBox(height: 5),
                        SizedBox(
                          height: 96,
                          child: _PinnedNote(
                            height: 96,
                            color: AppTheme.white,
                            angle: -0.018,
                            pinAlignment: Alignment.topRight,
                            childPadding: const EdgeInsets.fromLTRB(
                              14,
                              14,
                              14,
                              9,
                            ),
                            child: ClipRect(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      title.toUpperCase(),
                                      maxLines: 3,
                                      overflow: TextOverflow.clip,
                                      softWrap: true,
                                      textWidthBasis: TextWidthBasis.parent,
                                      style: GoogleFonts.spaceMono(
                                        color: AppTheme.black,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        height: 1.02,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    width: 84,
                                    height: 5,
                                    color: const Color(0xFFFF3D00),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 5),
                        if (hasSummary || hasFacts)
                          Expanded(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (hasSummary)
                                  Expanded(
                                    flex: hasFacts ? 8 : 1,
                                    child: _ShareSummaryNote(
                                      summary: summary,
                                      maxLines: hasFacts ? 8 : 7,
                                    ),
                                  ),
                                if (hasSummary && hasFacts)
                                  const SizedBox(width: 10),
                                if (hasFacts)
                                  Expanded(
                                    flex: hasSummary ? 7 : 1,
                                    child: _KeyFactsBoard(facts: facts),
                                  ),
                              ],
                            ),
                          )
                        else
                          const Spacer(),
                        if (hasActions) ...[
                          SizedBox(height: hasSummary || hasFacts ? 7 : 0),
                          _ShareActionNote(
                            actions: actions,
                            isPrimary: !hasSummary && !hasFacts,
                          ),
                        ],
                        SizedBox(height: hasActions ? 8 : 10),
                        _ShareFooter(),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static List<String> _shareItems(List<String> values, int limit) {
    return values
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .take(limit)
        .toList(growable: false);
  }

  static String _shareSummary(String value) {
    final cleaned = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (cleaned.isEmpty) return '';
    final sentences = cleaned
        .split(RegExp(r'(?<=[.!?])\s+'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .take(3)
        .join(' ');
    final candidate = sentences.isEmpty ? cleaned : sentences;
    if (candidate.length <= 270) return candidate;
    final clipped = candidate.substring(0, 270);
    final lastSpace = clipped.lastIndexOf(' ');
    return '${clipped.substring(0, lastSpace > 180 ? lastSpace : 270).trim()}...';
  }
}

class _ShareLocationLink {
  final String label;
  final String url;

  const _ShareLocationLink(this.label, this.url);
}

class _ShareBadge extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;

  const _ShareBadge({
    required this.label,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 104),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: AppTheme.black, width: 2),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: GoogleFonts.spaceMono(
          color: textColor,
          fontSize: 8,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _ShareHeader extends StatelessWidget {
  final String contentType;

  const _ShareHeader({required this.contentType});

  @override
  Widget build(BuildContext context) {
    final typeLabel = switch (contentType) {
      'reel' => 'REEL',
      'carousel' => 'CAROUSEL',
      _ => 'POST',
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFFFFD600),
            border: Border.all(color: AppTheme.black, width: 3),
            boxShadow: AppTheme.inkShadowSmall,
          ),
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: Image.asset(
              'assets/images/app_icon.png',
              fit: BoxFit.contain,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'REELPIN',
                style: GoogleFonts.spaceMono(
                  color: AppTheme.black,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  height: 1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Pinned ${typeLabel.toLowerCase()} brief',
                style: GoogleFonts.spaceMono(
                  color: AppTheme.textSecondary,
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.7,
                ),
              ),
            ],
          ),
        ),
        _ShareBadge(
          label: typeLabel,
          color: AppTheme.hotPink,
          textColor: AppTheme.white,
        ),
      ],
    );
  }
}

class _PinnedNote extends StatelessWidget {
  final Widget child;
  final Color color;
  final Alignment pinAlignment;
  final double angle;
  final EdgeInsets childPadding;
  final double? height;

  const _PinnedNote({
    required this.child,
    required this.color,
    required this.pinAlignment,
    required this.angle,
    required this.childPadding,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angle,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            top: 8,
            left: 8,
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.black.withAlpha(70),
                border: Border.all(color: AppTheme.black, width: 2),
              ),
            ),
          ),
          ClipPath(
            clipper: _ShareStickyNoteClipper(),
            child: Container(
              width: double.infinity,
              height: height,
              decoration: BoxDecoration(
                color: color,
                border: Border.all(color: AppTheme.black, width: 3),
                boxShadow: AppTheme.inkShadowSmall,
              ),
              child: Padding(padding: childPadding, child: child),
            ),
          ),
          Align(
            alignment: pinAlignment,
            child: Transform.translate(
              offset: const Offset(20, -26),
              child: Transform.rotate(
                angle: 0.28,
                child: Image.asset(
                  'assets/images/pin.png',
                  width: 42,
                  height: 42,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShareSummaryNote extends StatelessWidget {
  final String summary;
  final int maxLines;

  const _ShareSummaryNote({required this.summary, required this.maxLines});

  @override
  Widget build(BuildContext context) {
    return _PinnedNote(
      color: const Color(0xFFFFF2A8),
      angle: 0.012,
      pinAlignment: Alignment.topRight,
      childPadding: const EdgeInsets.fromLTRB(14, 16, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _NoteTitle(label: 'SUMMARY', color: AppTheme.black, fontSize: 10),
          const SizedBox(height: 6),
          Expanded(
            child: Text(
              summary,
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
              softWrap: true,
              textWidthBasis: TextWidthBasis.parent,
              style: GoogleFonts.spaceMono(
                color: const Color(0xFF242424),
                fontSize: 10.5,
                height: 1.18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoteTitle extends StatelessWidget {
  final String label;
  final Color color;
  final double fontSize;

  const _NoteTitle({
    required this.label,
    required this.color,
    this.fontSize = 12,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 5, height: 18, color: color),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.spaceMono(
            color: color,
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }
}

class _KeyFactsBoard extends StatelessWidget {
  final List<String> facts;

  const _KeyFactsBoard({required this.facts});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.black,
        border: Border.all(color: AppTheme.black, width: 3),
        boxShadow: AppTheme.inkShadowSmall,
      ),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'KEY FACTS',
            style: GoogleFonts.spaceMono(
              color: const Color(0xFF39FF14),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 5),
          Expanded(
            child: ClipRect(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: facts.map((fact) {
                  return _ShareFactRow(text: fact);
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShareFactRow extends StatelessWidget {
  final String text;

  const _ShareFactRow({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 5),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: AppTheme.red,
              border: Border.all(color: AppTheme.white, width: 1),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              softWrap: true,
              textWidthBasis: TextWidthBasis.parent,
              style: GoogleFonts.spaceMono(
                color: AppTheme.white,
                fontSize: 9.6,
                height: 1.12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShareActionNote extends StatelessWidget {
  final List<String> actions;
  final bool isPrimary;

  const _ShareActionNote({required this.actions, this.isPrimary = false});

  @override
  Widget build(BuildContext context) {
    return _ShareMiniNote(
      label: 'TOP ACTIONS',
      items: actions,
      color: const Color(0xFF19D6C8),
      textColor: AppTheme.black,
      angle: -0.018,
      height: isPrimary ? 190 : null,
      fontSize: 10.5,
    );
  }
}

class _ShareMiniNote extends StatelessWidget {
  final String label;
  final List<String> items;
  final Color color;
  final Color textColor;
  final double angle;
  final double? height;
  final double fontSize;

  const _ShareMiniNote({
    required this.label,
    required this.items,
    required this.color,
    required this.textColor,
    required this.angle,
    required this.height,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angle,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            top: 7,
            left: 7,
            child: Container(color: AppTheme.black.withAlpha(70)),
          ),
          ClipPath(
            clipper: _ShareStickyNoteClipper(),
            child: Container(
              width: double.infinity,
              height: height ?? _heightForItems(items.length),
              decoration: BoxDecoration(
                color: color,
                border: Border.all(color: AppTheme.black, width: 3),
              ),
              padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _NoteTitle(
                    label: label,
                    color: textColor,
                    fontSize: fontSize,
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: ClipRect(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: items.take(3).map((item) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  margin: const EdgeInsets.only(top: 3),
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: AppTheme.white,
                                    border: Border.all(
                                      color: AppTheme.black,
                                      width: 1,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    item,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    softWrap: true,
                                    textWidthBasis: TextWidthBasis.parent,
                                    style: GoogleFonts.spaceMono(
                                      color: textColor,
                                      fontSize: 10,
                                      height: 1.12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 30,
            bottom: -2,
            child: Transform.rotate(
              angle: -0.08,
              child: Container(
                width: 64,
                height: 13,
                decoration: BoxDecoration(
                  color: color,
                  border: Border.all(color: AppTheme.black, width: 2),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _heightForItems(int itemCount) {
    return switch (itemCount) {
      <= 1 => 66,
      2 => 94,
      _ => 120,
    };
  }
}

class _ShareFooter extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Text(
            'Saved, summarized, and pinned with ReelPin',
            style: GoogleFonts.spaceMono(
              color: AppTheme.black,
              fontSize: 8.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
              height: 1.15,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFFFD600),
            border: Border.all(color: AppTheme.black, width: 3),
            boxShadow: AppTheme.inkShadowSmall,
          ),
          child: Text(
            'GET REELPIN',
            style: GoogleFonts.spaceMono(
              color: AppTheme.black,
              fontSize: 8.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ),
      ],
    );
  }
}

class _ShareStickyNoteClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    return Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width - 10, size.height - 18)
      ..quadraticBezierTo(
        size.width * 0.55,
        size.height + 8,
        0,
        size.height - 8,
      )
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
