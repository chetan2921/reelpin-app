import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:reelpin/app/providers.dart';
import 'package:reelpin/core/design/app_theme.dart';
import 'package:reelpin/core/network/error_message.dart';
import 'package:reelpin/features/reels/domain/reel.dart';
import 'package:reelpin/features/reels/presentation/detail/reel_detail_screen.dart';

class ReelDetailLoaderScreen extends ConsumerStatefulWidget {
  const ReelDetailLoaderScreen({super.key, required this.reelId});

  final String reelId;

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
          return ReelDetailScreen(reel: snapshot.requireData);
        }

        final error = snapshot.error;
        return Scaffold(
          backgroundColor: AppTheme.bg(context),
          appBar: AppBar(
            backgroundColor: AppTheme.bg(context),
            foregroundColor: AppTheme.fg(context),
          ),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: error == null
                  ? CircularProgressIndicator(color: AppTheme.fg(context))
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
                            color: AppTheme.fg(context),
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
