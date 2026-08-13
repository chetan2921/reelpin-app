import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:reelpin/data_models/reels/reel.dart';
import 'package:reelpin/screens/collections/add_to_collection_sheet.dart';
import 'package:reelpin/providers.dart';
import 'package:reelpin/http/api_exception.dart';
import 'package:reelpin/router.dart';
import 'package:reelpin/utils/error_message.dart';
import 'package:reelpin/services/sharing/reel_share_service.dart';
import 'package:reelpin/constants/app_layout.dart';
import 'package:reelpin/constants/app_colors.dart';
import 'package:reelpin/constants/app_theme.dart';
import 'package:reelpin/constants/source_platforms.dart';
import 'package:reelpin/utils/app_store_links.dart';
import 'package:reelpin/screens/paywall/paywall_screen.dart';
part 'partials/reel_share_card.dart';

const String _appStoreUrl = appStoreUrl;
const String _playStoreUrl = playStoreUrl;

/// Pinterest serves per-country domains from regional subdomains, so anchoring
/// both ends keeps lookalikes out.
final RegExp _pinterestHostRegex = RegExp(
  r'^(?:[a-z0-9-]+\.)*pinterest\.(?:com|net|info|[a-z]{2}|(?:com|co)\.[a-z]{2})$',
);

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
  String get _savedItemNoun =>
      SourcePlatform.byId(_sourcePlatform)?.savedItemNoun ?? 'REEL';
  String get _untitledLabel => 'UNTITLED $_savedItemNoun';
  String get _openSourceLabel => 'OPEN $_openSourceNoun';
  String get _openSourceErrorLabel => 'COULD NOT OPEN $_openSourceNoun';
  String get _openSourceNoun {
    final platform = _sourcePlatform;
    // Instagram and YouTube get a noun per content type; everything else has a
    // single shape of content, so the platform's own noun is accurate.
    if (platform == 'youtube') {
      if (_isShortsSource) return 'SHORTS';
      return 'VIDEO';
    }
    if (platform == 'instagram') {
      if (_isInstagramPostSource) return 'POST';
      return 'REEL';
    }
    return SourcePlatform.byId(platform)?.openSourceNoun ?? 'REEL';
  }

  String? get _sourcePlatform {
    final explicit = reel.sourcePlatform?.trim().toLowerCase();
    if (SourcePlatform.byId(explicit) != null) {
      return explicit;
    }
    // Older saves predate `source_platform`, so fall back to sniffing whichever
    // source URL the reel carries.
    if (_hasSourceUri(_isYoutubeUri)) return 'youtube';
    if (_hasSourceUri(_isInstagramUri)) return 'instagram';
    if (_hasSourceUri(_isXUri)) return 'x';
    if (_hasSourceUri(_isPinterestUri)) return 'pinterest';
    if (_hasSourceUri(_isRedditUri)) return 'reddit';
    if (_hasSourceUri(_isLinkedInUri)) return 'linkedin';
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

  bool _isXUri(Uri uri) {
    var host = uri.host.toLowerCase();
    for (final prefix in const ['www.', 'mobile.', 'm.']) {
      if (host.startsWith(prefix)) {
        host = host.substring(prefix.length);
        break;
      }
    }
    return host == 'x.com' || host == 'twitter.com' || host == 't.co';
  }

  bool _isPinterestUri(Uri uri) {
    final host = uri.host.toLowerCase();
    return host == 'pin.it' || _pinterestHostRegex.hasMatch(host);
  }

  bool _isRedditUri(Uri uri) {
    final host = uri.host.toLowerCase();
    return host == 'redd.it' || _isHostOrSubdomainOf(host, 'reddit.com');
  }

  bool _isLinkedInUri(Uri uri) =>
      _isHostOrSubdomainOf(uri.host.toLowerCase(), 'linkedin.com');

  bool _isHostOrSubdomainOf(String host, String domain) =>
      host == domain || host.endsWith('.$domain');

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
      : AppColors.textSecondary;

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
    final catColor = AppColors.getCategoryColor(reel.category);
    final layout = AppLayout.of(context);
    final hasOpenableReel = _openReelUrl != null;

    return Scaffold(
      backgroundColor: AppColors.bg(context),
      body: Stack(
        clipBehavior: Clip.none,
        children: [
          CustomScrollView(
            slivers: [
              // ── App Bar ──
              SliverAppBar(
                pinned: true,
                backgroundColor: AppColors.bg(context),
                surfaceTintColor: Colors.transparent,
                leading: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: AppColors.fg(context),
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      Icons.arrow_back,
                      color: AppColors.fg(context),
                      size: 20,
                    ),
                  ),
                ),
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(3),
                  child: Container(
                    height: AppTheme.borderWidth,
                    color: AppColors.fg(context),
                  ),
                ),
                actions: [
                  // Add to collection
                  GestureDetector(
                    onTap: () =>
                        showAddToCollectionSheet(context, _activeReel.id),
                    child: Container(
                      margin: EdgeInsets.only(right: layout.inset(8)),
                      width: layout.inset(36),
                      height: layout.inset(36),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevatedColor(context),
                        border: Border.all(
                          color: AppColors.fg(context),
                          width: 2,
                        ),
                        boxShadow: AppTheme.brutalShadowSmall(context),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.playlist_add,
                        size: layout.inset(18),
                        color: AppColors.fg(context),
                      ),
                    ),
                  ),
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
                            ? AppColors.yellow
                            : AppColors.surfaceElevatedColor(context),
                        border: Border.all(
                          color: AppColors.fg(context),
                          width: 2,
                        ),
                        boxShadow: AppTheme.brutalShadowSmall(context),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _openSourceLabel,
                        style: GoogleFonts.spaceMono(
                          color: hasOpenableReel
                              ? AppColors.black
                              : AppColors.textSec(context),
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
                        color: AppColors.destructive,
                        border: Border.all(
                          color: AppColors.fg(context),
                          width: 2,
                        ),
                        boxShadow: AppTheme.brutalShadowSmall(context),
                      ),
                      child: const Icon(
                        Icons.delete,
                        color: AppColors.white,
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
                            color: AppColors.bg(context),
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
                                  color: AppColors.fg(context),
                                ),
                              ),
                              SizedBox(width: layout.inset(8)),
                              Text(
                                'CHECKING ACCESS...',
                                style: GoogleFonts.spaceMono(
                                  color: AppColors.fg(context),
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
                                color: AppColors.black,
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
                                        color: AppColors.fg(context),
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
                                        color: AppColors.bg(context),
                                        border: Border.all(
                                          color: AppColors.fg(context),
                                          width: 2,
                                        ),
                                      ),
                                      child: Text(
                                        reel.subCategory.toUpperCase(),
                                        style: GoogleFonts.spaceMono(
                                          color: AppColors.fg(context),
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
                              : _untitledLabel,
                          style: GoogleFonts.spaceMono(
                            color: AppColors.fg(context),
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
                          color: AppColors.yellow,
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
                                      color: AppColors.red,
                                      border: Border.all(
                                        color: AppColors.fg(context),
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
                                        color: AppColors.neonGreen,
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
                                                  color: AppColors.fg(context),
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
                                              color: AppColors.red,
                                              border: Border.all(
                                                color: AppColors.fg(context),
                                                width: 2,
                                              ),
                                            ),
                                            alignment: Alignment.center,
                                            child: Icon(
                                              Icons.navigation,
                                              size: 22,
                                              color: AppColors.white,
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
                                  color: AppColors.yellow,
                                  border: Border.all(
                                    color: AppColors.fg(context),
                                    width: 2,
                                  ),
                                  boxShadow: AppTheme.brutalShadowSmall(
                                    context,
                                  ),
                                ),
                                child: Text(
                                  person.toUpperCase(),
                                  style: GoogleFonts.spaceMono(
                                    color: AppColors.black,
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
                                      color: AppColors.neonGreen,
                                      border: Border.all(
                                        color: AppColors.fg(context),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.arrow_forward,
                                      size: 12,
                                      color: AppColors.black,
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
                              color: AppColors.surfaceElevated,
                              border: Border.all(
                                color: AppColors.fg(context),
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
                                  color: AppColors.black,
                                  fontSize: 12,
                                  height: 1.6,
                                ),
                              ),
                              secondChild: Text(
                                reel.transcript,
                                style: GoogleFonts.spaceMono(
                                  color: AppColors.black,
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
                                color: AppColors.blue,
                                border: Border.all(
                                  color: AppColors.fg(context),
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
                                      color: AppColors.white,
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
                                      color: AppColors.white,
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
    return bg.computeLuminance() > 0.5 ? AppColors.black : AppColors.white;
  }

  Widget _sectionTitle(String title) {
    final layout = AppLayout.of(context);
    return Row(
      children: [
        Container(
          width: layout.inset(4),
          height: layout.gap(18),
          color: AppColors.fg(context),
        ),
        SizedBox(width: layout.inset(8)),
        Text(
          title,
          style: GoogleFonts.spaceMono(
            color: AppColors.fg(context),
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
                color: AppColors.black,
                fontSize: layout.font(18),
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: layout.gap(10)),
            Text(
              'This saved ${_savedItemNoun.toLowerCase()} is outside the Free history window. Upgrade to Pro to open older saves again.',
              style: GoogleFonts.spaceMono(
                color: AppColors.black,
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
                  color: AppColors.hotPink,
                  shadow: true,
                ),
                child: Text(
                  'VIEW PRO',
                  style: GoogleFonts.spaceMono(
                    color: AppColors.white,
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
            'COULD NOT SHARE $_savedItemNoun',
            style: GoogleFonts.spaceMono(
              color: AppColors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          backgroundColor: AppColors.destructive,
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
    return title.isEmpty
        ? 'ReelPin saved ${_savedItemNoun.toLowerCase()}'
        : title;
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
              ? AppColors.surfaceElevatedColor(context)
              : AppColors.blue,
          border: Border.all(color: AppColors.fg(context), width: 2),
          boxShadow: AppTheme.brutalShadowSmall(context),
        ),
        alignment: Alignment.center,
        child: _isSharingReel
            ? SizedBox(
                width: layout.inset(12),
                height: layout.inset(12),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.fg(context),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.share, color: AppColors.white, size: 16),
                  SizedBox(width: layout.inset(5)),
                  Text(
                    'SHARE',
                    style: GoogleFonts.spaceMono(
                      color: AppColors.white,
                      fontSize: layout.font(10),
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
        backgroundColor: AppColors.bg(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(0),
          side: BorderSide(
            color: AppColors.fg(context),
            width: AppTheme.borderWidth,
          ),
        ),
        title: Text(
          'DELETE THIS $_savedItemNoun?',
          style: GoogleFonts.spaceMono(
            color: AppColors.fg(context),
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
                        '$_savedItemNoun DELETED',
                        style: GoogleFonts.spaceMono(
                          color: AppColors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      backgroundColor: AppColors.black,
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
                          color: AppColors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      backgroundColor: AppColors.destructive,
                    ),
                  );
                }
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.destructive,
                border: Border.all(color: AppColors.fg(context), width: 2),
                boxShadow: AppTheme.brutalShadowSmall(context),
              ),
              child: Text(
                'DELETE',
                style: GoogleFonts.spaceMono(
                  color: AppColors.white,
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
            color: AppColors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: AppColors.destructive,
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
            fallbackMessage:
                'Could not load this ${_savedItemNoun.toLowerCase()} right now.',
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
          fallbackMessage:
              'Could not load this ${_savedItemNoun.toLowerCase()} right now.',
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
