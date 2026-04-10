import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../theme/app_theme.dart';
import '../viewmodels/session_viewmodel.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isSignUp = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _setMode(bool signUp) {
    FocusScope.of(context).unfocus();
    context.read<SessionViewModel>().clearError();
    context.read<SessionViewModel>().clearStatusMessage();

    setState(() {
      _isSignUp = signUp;
    });
  }

  Future<void> _submit(SessionViewModel sessionVm) async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (_isSignUp) {
      final success = await sessionVm.signUpWithEmail(
        email: email,
        password: password,
        fullName: _nameController.text.trim(),
      );
      if (success && mounted && !sessionVm.isAuthenticated) {
        setState(() {
          _isSignUp = false;
        });
      }
      return;
    }

    await sessionVm.signInWithEmail(
      email: email,
      password: password,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      body: SafeArea(
        child: Consumer<SessionViewModel>(
          builder: (context, sessionVm, _) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'REELPIN',
                          style: GoogleFonts.spaceMono(
                            color: AppTheme.fg(context),
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _isSignUp
                                ? AppTheme.neonGreen
                                : AppTheme.cyan,
                            border: Border.all(
                              color: AppTheme.fg(context),
                              width: 2,
                            ),
                          ),
                          child: Text(
                            _isSignUp ? 'SIGN UP' : 'SIGN IN',
                            style: GoogleFonts.spaceMono(
                              color: AppTheme.fg(context),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      _isSignUp
                          ? 'CREATE YOUR REEL ARCHIVE.'
                          : 'WELCOME BACK TO YOUR REEL ARCHIVE.',
                      style: GoogleFonts.spaceMono(
                        color: AppTheme.fg(context),
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      decoration: AppTheme.brutalCard(context),
                      child: Row(
                        children: [
                          _modeButton(
                            context,
                            label: 'SIGN IN',
                            active: !_isSignUp,
                            onTap: () => _setMode(false),
                          ),
                          Container(
                            width: AppTheme.borderWidth,
                            height: 56,
                            color: AppTheme.fg(context),
                          ),
                          _modeButton(
                            context,
                            label: 'SIGN UP',
                            active: _isSignUp,
                            onTap: () => _setMode(true),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (sessionVm.error != null) ...[
                      _messageBanner(
                        context,
                        text: sessionVm.error!,
                        color: AppTheme.red,
                        textColor: AppTheme.white,
                      ),
                      const SizedBox(height: 14),
                    ],
                    if (sessionVm.statusMessage != null) ...[
                      _messageBanner(
                        context,
                        text: sessionVm.statusMessage!,
                        color: AppTheme.neonGreen,
                        textColor: AppTheme.fg(context),
                      ),
                      const SizedBox(height: 14),
                    ],
                    Container(
                      width: double.infinity,
                      decoration: AppTheme.brutalCard(context),
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_isSignUp) ...[
                              _inputField(
                                context,
                                controller: _nameController,
                                label: 'FULL NAME',
                                hint: 'CHETAN JAIN',
                                validator: (value) {
                                  if (!_isSignUp) return null;
                                  if ((value ?? '').trim().isEmpty) {
                                    return 'ENTER YOUR NAME';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 14),
                            ],
                            _inputField(
                              context,
                              controller: _emailController,
                              label: 'EMAIL',
                              hint: 'you@example.com',
                              keyboardType: TextInputType.emailAddress,
                              validator: (value) {
                                final text = (value ?? '').trim();
                                if (text.isEmpty) return 'ENTER YOUR EMAIL';
                                if (!text.contains('@') || !text.contains('.')) {
                                  return 'ENTER A VALID EMAIL';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            _inputField(
                              context,
                              controller: _passwordController,
                              label: 'PASSWORD',
                              hint: 'MIN 6 CHARACTERS',
                              obscureText: true,
                              validator: (value) {
                                final text = value ?? '';
                                if (text.isEmpty) return 'ENTER YOUR PASSWORD';
                                if (text.length < 6) {
                                  return 'USE AT LEAST 6 CHARACTERS';
                                }
                                return null;
                              },
                            ),
                            if (_isSignUp) ...[
                              const SizedBox(height: 14),
                              _inputField(
                                context,
                                controller: _confirmPasswordController,
                                label: 'CONFIRM PASSWORD',
                                hint: 'REPEAT PASSWORD',
                                obscureText: true,
                                validator: (value) {
                                  final text = value ?? '';
                                  if (text.isEmpty) {
                                    return 'CONFIRM YOUR PASSWORD';
                                  }
                                  if (text != _passwordController.text) {
                                    return 'PASSWORDS DO NOT MATCH';
                                  }
                                  return null;
                                },
                              ),
                            ],
                            const SizedBox(height: 18),
                            GestureDetector(
                              onTap: sessionVm.isBusy
                                  ? null
                                  : () => _submit(sessionVm),
                              child: Opacity(
                                opacity: sessionVm.isBusy ? 0.7 : 1,
                                child: Container(
                                  width: double.infinity,
                                  decoration: AppTheme.brutalCard(
                                    context,
                                    color: AppTheme.fg(context),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    child: Center(
                                      child: sessionVm.isSigningIn
                                          ? SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.5,
                                                color: AppTheme.bg(context),
                                              ),
                                            )
                                          : Text(
                                              _isSignUp
                                                  ? 'CREATE ACCOUNT'
                                                  : 'SIGN IN',
                                              style: GoogleFonts.spaceMono(
                                                color: AppTheme.bg(context),
                                                fontSize: 14,
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: 1,
                                              ),
                                            ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    height: AppTheme.borderWidth,
                                    color: AppTheme.fg(context),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                  ),
                                  child: Text(
                                    'OR',
                                    style: GoogleFonts.spaceMono(
                                      color: AppTheme.textSec(context),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Container(
                                    height: AppTheme.borderWidth,
                                    color: AppTheme.fg(context),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            GestureDetector(
                              onTap: sessionVm.isBusy
                                  ? null
                                  : () {
                                      FocusScope.of(context).unfocus();
                                      sessionVm.signInWithGoogle();
                                    },
                              child: Opacity(
                                opacity: sessionVm.isBusy ? 0.7 : 1,
                                child: Container(
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: AppTheme.white,
                                    border: Border.all(
                                      color: const Color(0xFF1F1F1F),
                                      width: 2,
                                    ),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: AppTheme.black,
                                        offset: Offset(4, 4),
                                        blurRadius: 0,
                                      ),
                                    ],
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 16,
                                    ),
                                    child: Row(
                                      children: [
                                        const _GoogleMark(size: 22),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Text(
                                            _isSignUp
                                                ? 'SIGN UP WITH GOOGLE'
                                                : 'SIGN IN WITH GOOGLE',
                                            style: GoogleFonts.spaceMono(
                                              color: const Color(0xFF1F1F1F),
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 0.7,
                                            ),
                                          ),
                                        ),
                                        Icon(
                                          Icons.arrow_forward,
                                          color: const Color(0xFF1F1F1F),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _modeButton(
    BuildContext context, {
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 56,
          color: active ? AppTheme.yellow : AppTheme.bg(context),
          alignment: Alignment.center,
          child: Text(
            label,
            style: GoogleFonts.spaceMono(
              color: AppTheme.fg(context),
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
        ),
      ),
    );
  }

  Widget _messageBanner(
    BuildContext context, {
    required String text,
    required Color color,
    required Color textColor,
  }) {
    return Container(
      width: double.infinity,
      decoration: AppTheme.brutalBox(
        context,
        color: color,
        shadow: false,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Text(
          text,
          style: GoogleFonts.spaceMono(
            color: textColor,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            height: 1.45,
          ),
        ),
      ),
    );
  }

  Widget _inputField(
    BuildContext context, {
    required TextEditingController controller,
    required String label,
    required String hint,
    required String? Function(String?) validator,
    bool obscureText = false,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.spaceMono(
            color: AppTheme.fg(context),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.7,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          style: GoogleFonts.spaceMono(
            color: AppTheme.fg(context),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.spaceMono(
              color: AppTheme.textSec(context),
              fontSize: 12,
            ),
            filled: true,
            fillColor: AppTheme.bg(context),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(
                color: AppTheme.fg(context),
                width: 2,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(
                color: AppTheme.fg(context),
                width: 3,
              ),
            ),
            errorBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(
                color: AppTheme.red,
                width: 2,
              ),
            ),
            focusedErrorBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(
                color: AppTheme.red,
                width: 3,
              ),
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }
}

class _GoogleMark extends StatelessWidget {
  const _GoogleMark({required this.size});

  @override
  Widget build(BuildContext context) {
    final stroke = size / 5.2;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          _ring(
            color: const Color(0xFF4285F4),
            startAngle: -0.2,
            sweepAngle: 1.35,
            size: size,
            stroke: stroke,
          ),
          _ring(
            color: const Color(0xFFEA4335),
            startAngle: 1.15,
            sweepAngle: 1.1,
            size: size,
            stroke: stroke,
          ),
          _ring(
            color: const Color(0xFFFBBC05),
            startAngle: 2.25,
            sweepAngle: 0.95,
            size: size,
            stroke: stroke,
          ),
          _ring(
            color: const Color(0xFF34A853),
            startAngle: 3.15,
            sweepAngle: 1.1,
            size: size,
            stroke: stroke,
          ),
          Positioned(
            right: 0,
            top: size * 0.42,
            child: Container(
              width: size * 0.42,
              height: stroke,
              color: const Color(0xFF4285F4),
            ),
          ),
        ],
      ),
    );
  }

  final double size;

  Widget _ring({
    required Color color,
    required double startAngle,
    required double sweepAngle,
    required double size,
    required double stroke,
  }) {
    return CustomPaint(
      size: Size.square(size),
      painter: _ArcPainter(
        color: color,
        startAngle: startAngle * math.pi,
        sweepAngle: sweepAngle * math.pi,
        strokeWidth: stroke,
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  const _ArcPainter({
    required this.color,
    required this.startAngle,
    required this.sweepAngle,
    required this.strokeWidth,
  });

  final Color color;
  final double startAngle;
  final double sweepAngle;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawArc(
      rect.deflate(strokeWidth / 2),
      startAngle,
      sweepAngle,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.square,
    );
  }

  @override
  bool shouldRepaint(covariant _ArcPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.startAngle != startAngle ||
        oldDelegate.sweepAngle != sweepAngle ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
