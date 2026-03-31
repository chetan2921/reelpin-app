import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/reel.dart';
import '../theme/app_theme.dart';
import '../widgets/category_badge.dart';

class ReelDetailScreen extends StatefulWidget {
  final Reel reel;

  const ReelDetailScreen({super.key, required this.reel});

  @override
  State<ReelDetailScreen> createState() => _ReelDetailScreenState();
}

class _ReelDetailScreenState extends State<ReelDetailScreen> {
  bool _transcriptExpanded = false;

  Reel get reel => widget.reel;

  @override
  Widget build(BuildContext context) {
    final catColor = AppTheme.getCategoryColor(reel.category);

    return Scaffold(
      backgroundColor: AppTheme.midnightPlum,
      body: CustomScrollView(
        slivers: [
          // ── App Bar ──
          SliverAppBar(
            pinned: true,
            backgroundColor: AppTheme.midnightPlum,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppTheme.deepIndigo.withAlpha(200),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.cream.withAlpha(15)),
                ),
                child: Icon(
                  Icons.arrow_back_rounded,
                  color: AppTheme.cream,
                  size: 20,
                ),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                  child: GestureDetector(
                    onTap: () => _openUrl(reel.url),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.deepIndigo.withAlpha(150),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.cream.withAlpha(30)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Open on Instagram App',
                            style: TextStyle(
                              color: AppTheme.cream,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.open_in_new_rounded,
                            color: AppTheme.cream.withAlpha(180),
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // ── Content ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Category + Date ──
                  Row(
                    children: [
                      CategoryBadge(category: reel.category, small: true),
                      const Spacer(),
                      if (reel.displayDate.isNotEmpty)
                        Text(
                          reel.displayDate,
                          style: TextStyle(
                            color: AppTheme.cream.withAlpha(70),
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Title ──
                  Text(
                    reel.title.isNotEmpty ? reel.title : 'Untitled Reel',
                    style: TextStyle(
                      color: AppTheme.cream,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ── AI Summary ──
                  if (reel.summary.isNotEmpty) ...[
                    _buildSection(
                      icon: Icons.auto_awesome_rounded,
                      iconColor: AppTheme.dustyRose,
                      title: 'AI Summary',
                      child: Text(
                        reel.summary,
                        style: TextStyle(
                          color: AppTheme.cream.withAlpha(190),
                          fontSize: 15,
                          height: 1.6,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── Key Facts ──
                  if (reel.keyFacts.isNotEmpty) ...[
                    _buildSection(
                      icon: Icons.lightbulb_outline_rounded,
                      iconColor: AppTheme.cream,
                      title: 'Key Facts',
                      child: Column(
                        children: reel.keyFacts.map((fact) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  margin: const EdgeInsets.only(top: 7),
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        catColor,
                                        catColor.withAlpha(120),
                                      ],
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    fact,
                                    style: TextStyle(
                                      color: AppTheme.cream.withAlpha(170),
                                      fontSize: 14,
                                      height: 1.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── Locations ──
                  if (reel.locations.isNotEmpty) ...[
                    _buildSection(
                      icon: Icons.location_on_outlined,
                      iconColor: AppTheme.mauve,
                      title: 'Locations',
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: reel.locations.map((loc) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 9,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppTheme.mauve.withAlpha(35),
                                  AppTheme.amethyst.withAlpha(20),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppTheme.mauve.withAlpha(50),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.pin_drop,
                                  size: 14,
                                  color: AppTheme.dustyRose,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  loc.name,
                                  style: TextStyle(
                                    color: AppTheme.dustyRose,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── People Mentioned ──
                  if (reel.peopleMentioned.isNotEmpty) ...[
                    _buildSection(
                      icon: Icons.people_outline_rounded,
                      iconColor: AppTheme.dustyRose,
                      title: 'People Mentioned',
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: reel.peopleMentioned.map((person) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppTheme.amethyst.withAlpha(50),
                                  AppTheme.deepIndigo.withAlpha(80),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppTheme.cream.withAlpha(15),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    gradient: AppTheme.accentGradient,
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    person[0].toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.cream,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  person,
                                  style: TextStyle(
                                    color: AppTheme.cream.withAlpha(180),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── Actionable Items ──
                  if (reel.actionableItems.isNotEmpty) ...[
                    _buildSection(
                      icon: Icons.check_circle_outline_rounded,
                      iconColor: AppTheme.amethyst,
                      title: 'Action Items',
                      child: Column(
                        children: reel.actionableItems.map((item) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.arrow_right_rounded,
                                  color: AppTheme.amethyst.withAlpha(200),
                                  size: 20,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    item,
                                    style: TextStyle(
                                      color: AppTheme.cream.withAlpha(170),
                                      fontSize: 14,
                                      height: 1.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── Transcript ──
                  if (reel.transcript.isNotEmpty) ...[
                    _buildSection(
                      icon: Icons.subtitles_outlined,
                      iconColor: AppTheme.cream.withAlpha(120),
                      title: 'Transcript',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AnimatedCrossFade(
                            duration: const Duration(milliseconds: 300),
                            firstChild: Text(
                              reel.transcript,
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppTheme.cream.withAlpha(120),
                                fontSize: 13,
                                height: 1.6,
                              ),
                            ),
                            secondChild: Text(
                              reel.transcript,
                              style: TextStyle(
                                color: AppTheme.cream.withAlpha(120),
                                fontSize: 13,
                                height: 1.6,
                              ),
                            ),
                            crossFadeState: _transcriptExpanded
                                ? CrossFadeState.showSecond
                                : CrossFadeState.showFirst,
                          ),
                          const SizedBox(height: 10),
                          GestureDetector(
                            onTap: () => setState(
                              () => _transcriptExpanded = !_transcriptExpanded,
                            ),
                            child: Text(
                              _transcriptExpanded
                                  ? 'Show less'
                                  : 'Show full transcript',
                              style: TextStyle(
                                color: AppTheme.dustyRose,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required IconData icon,
    required Color iconColor,
    required String title,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.deepIndigo.withAlpha(160),
            AppTheme.amethyst.withAlpha(60),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.cream.withAlpha(12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: iconColor.withAlpha(25),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 16, color: iconColor),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  color: AppTheme.cream.withAlpha(220),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
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
}
