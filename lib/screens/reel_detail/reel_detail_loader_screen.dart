import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:reelpin/providers.dart';
import 'package:reelpin/constants/app_colors.dart';
import 'package:reelpin/utils/error_message.dart';
import 'package:reelpin/data_models/reels/reel.dart';
import 'package:reelpin/screens/reel_detail/reel_detail_screen.dart';

class ReelDetailLoaderScreen extends ConsumerStatefulWidget {
  const ReelDetailLoaderScreen({
    super.key,
    required this.reelId,
    this.collectionUrl,
  });

  final String reelId;

  /// Passed through to the detail screen so a reel opened from a collection
  /// shares that collection's link too.
  final String? collectionUrl;

  @override
  ConsumerState<ReelDetailLoaderScreen> createState() =>
      _ReelDetailLoaderScreenState();
}

class _ReelDetailLoaderScreenState
    extends ConsumerState<ReelDetailLoaderScreen> {
  late Future<Reel> _reel;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _reel = ref
        .read(reelRepositoryProvider)
        .getReel(widget.reelId, forceRefresh: true);
  }

  void _retry() {
    setState(_load);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Reel>(
      future: _reel,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return ReelDetailScreen(
            reel: snapshot.requireData,
            collectionUrl: widget.collectionUrl,
            // Just fetched above; refreshing again would repeat the call.
            refreshOnOpen: false,
          );
        }

        final error = snapshot.error;
        return Scaffold(
          backgroundColor: AppColors.bg(context),
          appBar: AppBar(
            backgroundColor: AppColors.bg(context),
            foregroundColor: AppColors.fg(context),
          ),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: error == null
                  ? CircularProgressIndicator(color: AppColors.fg(context))
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          userFacingErrorMessage(
                            error,
                            fallbackMessage:
                                'Could not load this reel right now.',
                          ),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.spaceMono(
                            color: AppColors.fg(context),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: _retry,
                          child: const Text('TRY AGAIN'),
                        ),
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }
}
