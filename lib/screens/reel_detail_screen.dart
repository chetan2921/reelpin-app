import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/reel.dart';
import '../theme/app_theme.dart';
import '../viewmodels/home_viewmodel.dart';
import '../viewmodels/map_viewmodel.dart';

class ReelDetailScreen extends StatefulWidget {
  final Reel reel;

  const ReelDetailScreen({super.key, required this.reel});

  @override
  State<ReelDetailScreen> createState() => _ReelDetailScreenState();
}

class _ReelDetailScreenState extends State<ReelDetailScreen> {
  bool _transcriptExpanded = false;

  Reel get reel => widget.reel;
  Color get _detailTextColor => Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFFD0D0D0)
      : AppTheme.textSecondary;

  @override
  Widget build(BuildContext context) {
    final catColor = AppTheme.getCategoryColor(reel.category);
    final layout = AppLayout.of(context);

    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      body: CustomScrollView(
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
              // Open original
              GestureDetector(
                onTap: () => _openUrl(reel.url),
                child: Container(
                  margin: EdgeInsets.only(right: layout.inset(4)),
                  padding: EdgeInsets.symmetric(
                    horizontal: layout.inset(12),
                    vertical: layout.gap(7),
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.yellow,
                    border: Border.all(color: AppTheme.fg(context), width: 2),
                    boxShadow: AppTheme.brutalShadowSmall(context),
                  ),
                  child: Text(
                    'OPEN REEL',
                    style: GoogleFonts.spaceMono(
                      color: AppTheme.fg(context),
                      fontSize: layout.font(11),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              SizedBox(width: layout.inset(8)),
              // Delete
              GestureDetector(
                onTap: () => _confirmDelete(context),
                child: Container(
                  margin: EdgeInsets.only(right: layout.inset(12)),
                  width: layout.inset(36),
                  height: layout.inset(36),
                  decoration: BoxDecoration(
                    color: AppTheme.destructive,
                    border: Border.all(color: AppTheme.fg(context), width: 2),
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
                  // Category + time
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
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
                      if (reel.relativeDate.isNotEmpty) ...[
                        SizedBox(width: layout.inset(12)),
                        Padding(
                          padding: EdgeInsets.only(top: layout.gap(4)),
                          child: Text(
                            reel.relativeDate.toUpperCase(),
                            style: GoogleFonts.spaceMono(
                              color: _detailTextColor,
                              fontSize: layout.font(11),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
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
                    ...reel.locations.map(
                      (loc) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: GestureDetector(
                          onTap: loc.hasCoordinates
                              ? () => _navigateToLocation(loc)
                              : null,
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
                                if (loc.hasCoordinates)
                                  Container(
                                    width: 36,
                                    height: 36,
                                    margin: const EdgeInsets.only(right: 10),
                                    decoration: BoxDecoration(
                                      color: AppTheme.red,
                                      border: Border.all(
                                        color: AppTheme.fg(context),
                                        width: 2,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.navigation,
                                      size: 16,
                                      color: AppTheme.white,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
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
                            boxShadow: AppTheme.brutalShadowSmall(context),
                          ),
                          child: Text(
                            person.toUpperCase(),
                            style: GoogleFonts.spaceMono(
                              color: AppTheme.fg(context),
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
          GestureDetector(
            onTap: () async {
              Navigator.pop(ctx);
              try {
                await context.read<HomeViewModel>().deleteReel(reel.id);
                if (context.mounted) {
                  context.read<MapViewModel>().loadMapReels(forceRefresh: true);
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

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _navigateToLocation(Location loc) async {
    final queryParam = loc.name.isNotEmpty
        ? Uri.encodeComponent(loc.name)
        : '${loc.latitude},${loc.longitude}';
    final url = 'https://www.google.com/maps/search/?api=1&query=$queryParam';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
