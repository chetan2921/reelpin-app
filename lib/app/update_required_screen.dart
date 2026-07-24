import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:reelpin/core/design/app_theme.dart';
import 'package:reelpin/core/platform/app_update_service.dart';

class UpdateRequiredScreen extends StatefulWidget {
  const UpdateRequiredScreen({
    required this.update,
    required this.onUpdate,
    super.key,
  });

  final RequiredAppUpdate update;
  final Future<AppUpdateStartResult> Function() onUpdate;

  @override
  State<UpdateRequiredScreen> createState() => _UpdateRequiredScreenState();
}

class _UpdateRequiredScreenState extends State<UpdateRequiredScreen> {
  bool _isOpeningStore = false;
  AppUpdateStartResult? _lastResult;

  Future<void> _startUpdate() async {
    if (_isOpeningStore) return;
    setState(() {
      _isOpeningStore = true;
      _lastResult = null;
    });

    final result = await widget.onUpdate();
    if (!mounted) return;
    setState(() {
      _isOpeningStore = false;
      _lastResult = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppTheme.bg(context),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 124,
                      height: 124,
                      decoration: AppTheme.brutalCard(
                        context,
                        color: AppTheme.yellow,
                      ),
                      child: Icon(
                        Icons.system_update_alt,
                        size: 58,
                        color: AppTheme.black,
                      ),
                    ),
                    const SizedBox(height: 34),
                    Text(
                      'UPDATE REQUIRED',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.spaceMono(
                        color: AppTheme.fg(context),
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'A NEW REELPIN VERSION IS READY. UPDATE TO KEEP USING THE APP.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.spaceMono(
                        color: AppTheme.textSec(context),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        height: 1.5,
                      ),
                    ),
                    if (widget.update.installedVersion != null &&
                        widget.update.latestVersion != null) ...[
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: AppTheme.brutalBox(context, shadow: false),
                        child: Text(
                          '${widget.update.installedVersion}  ->  ${widget.update.latestVersion}',
                          style: GoogleFonts.spaceMono(
                            color: AppTheme.fg(context),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: FilledButton.icon(
                        onPressed: _isOpeningStore ? null : _startUpdate,
                        icon: _isOpeningStore
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: AppTheme.black,
                                ),
                              )
                            : const Icon(Icons.open_in_new),
                        label: const Text('UPDATE NOW'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.yellow,
                          foregroundColor: AppTheme.black,
                          disabledBackgroundColor: AppTheme.yellow,
                          disabledForegroundColor: AppTheme.black,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.zero,
                            side: BorderSide(color: AppTheme.black),
                          ),
                          textStyle: GoogleFonts.spaceMono(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    if (_lastResult == AppUpdateStartResult.declined) ...[
                      const SizedBox(height: 14),
                      Text(
                        'THE UPDATE WAS NOT COMPLETED. TAP UPDATE NOW TO TRY AGAIN.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.spaceMono(
                          color: AppTheme.red,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          height: 1.4,
                        ),
                      ),
                    ],
                    if (_lastResult == AppUpdateStartResult.failed) ...[
                      const SizedBox(height: 14),
                      Text(
                        'THE UPDATE COULD NOT START. CHECK YOUR CONNECTION AND TRY AGAIN.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.spaceMono(
                          color: AppTheme.red,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
