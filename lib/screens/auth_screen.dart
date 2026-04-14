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
  bool _showPassword = false;
  bool _showConfirmPassword = false;

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

    await sessionVm.signInWithEmail(email: email, password: password);
  }

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);

    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      body: SafeArea(
        child: Consumer<SessionViewModel>(
          builder: (context, sessionVm, _) {
            return SingleChildScrollView(
              padding: layout.pagePadding(horizontal: 20, top: 20, bottom: 24),
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
                            fontSize: layout.font(
                              28,
                              minFactor: 0.9,
                              maxFactor: 1.08,
                            ),
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2,
                          ),
                        ),
                        SizedBox(width: layout.inset(8)),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: layout.inset(8),
                            vertical: layout.gap(4),
                          ),
                          decoration: BoxDecoration(
                            color: _isSignUp
                                ? AppTheme.lime
                                : AppTheme.darkTeal,
                            border: Border.all(
                              color: AppTheme.fg(context),
                              width: 2,
                            ),
                          ),
                          child: Text(
                            _isSignUp ? 'SIGN UP' : 'SIGN IN',
                            style: GoogleFonts.spaceMono(
                              color: AppTheme.black,
                              fontSize: layout.font(10),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: layout.gap(18)),
                    Text(
                      _isSignUp
                          ? 'JOIN THE COMMUNITY OF REEL SAVERS'
                          : 'WELCOME BACK TO YOUR REEL ARCHIVE.',
                      style: GoogleFonts.spaceMono(
                        color: AppTheme.fg(context),
                        fontSize: layout.font(
                          24,
                          minFactor: 0.9,
                          maxFactor: 1.12,
                        ),
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                      ),
                    ),
                    SizedBox(height: layout.gap(22)),
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
                            height: layout.gap(54),
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
                    SizedBox(height: layout.gap(22)),
                    if (sessionVm.error != null) ...[
                      _messageBanner(
                        context,
                        text: sessionVm.error!,
                        color: AppTheme.red,
                        textColor: AppTheme.white,
                      ),
                      SizedBox(height: layout.gap(14)),
                    ],
                    if (sessionVm.statusMessage != null) ...[
                      _messageBanner(
                        context,
                        text: sessionVm.statusMessage!,
                        color: AppTheme.neonGreen,
                        textColor: AppTheme.fg(context),
                      ),
                      SizedBox(height: layout.gap(14)),
                    ],
                    Container(
                      width: double.infinity,
                      decoration: AppTheme.brutalCard(context),
                      child: Padding(
                        padding: EdgeInsets.all(layout.inset(18)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_isSignUp) ...[
                              _inputField(
                                context,
                                controller: _nameController,
                                label: 'FULL NAME',
                                hint: 'Your Name',
                                validator: (value) {
                                  if (!_isSignUp) return null;
                                  if ((value ?? '').trim().isEmpty) {
                                    return 'ENTER YOUR NAME';
                                  }
                                  return null;
                                },
                              ),
                              SizedBox(height: layout.gap(14)),
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
                                if (!text.contains('@') ||
                                    !text.contains('.')) {
                                  return 'ENTER A VALID EMAIL';
                                }
                                return null;
                              },
                            ),
                            SizedBox(height: layout.gap(14)),
                            _inputField(
                              context,
                              controller: _passwordController,
                              label: 'PASSWORD',
                              hint: 'MIN 6 CHARACTERS',
                              obscureText: !_showPassword,
                              suffixIcon: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _showPassword = !_showPassword;
                                  });
                                },
                                child: Icon(
                                  _showPassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: AppTheme.fg(context),
                                  size: layout.inset(18),
                                ),
                              ),
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
                              SizedBox(height: layout.gap(14)),
                              _inputField(
                                context,
                                controller: _confirmPasswordController,
                                label: 'CONFIRM PASSWORD',
                                hint: 'REPEAT PASSWORD',
                                obscureText: !_showConfirmPassword,
                                suffixIcon: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _showConfirmPassword =
                                          !_showConfirmPassword;
                                    });
                                  },
                                  child: Icon(
                                    _showConfirmPassword
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                    color: AppTheme.fg(context),
                                    size: layout.inset(18),
                                  ),
                                ),
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
                            SizedBox(height: layout.gap(18)),
                            GestureDetector(
                              onTap: sessionVm.isBusy
                                  ? null
                                  : () => _submit(sessionVm),
                              child: Opacity(
                                opacity: sessionVm.isBusy ? 0.7 : 1,
                                child: Container(
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: AppTheme.white,
                                    border: Border.all(
                                      color: AppTheme.black,
                                      width: 3,
                                    ),
                                    boxShadow: AppTheme.inkShadow,
                                  ),
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(
                                      vertical: layout.gap(16),
                                    ),
                                    child: Center(
                                      child: sessionVm.isSigningIn
                                          ? SizedBox(
                                              width: layout.inset(20),
                                              height: layout.inset(20),
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
                                                color: AppTheme.black,
                                                fontSize: layout.font(14),
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: 1,
                                              ),
                                            ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: layout.gap(14)),
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    height: AppTheme.borderWidth,
                                    color: AppTheme.fg(context),
                                  ),
                                ),
                                Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: layout.inset(10),
                                  ),
                                  child: Text(
                                    'OR',
                                    style: GoogleFonts.spaceMono(
                                      color: AppTheme.textSec(context),
                                      fontSize: layout.font(11),
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
                            SizedBox(height: layout.gap(14)),
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
                                      color: AppTheme.black,
                                      width: 3,
                                    ),
                                    boxShadow: AppTheme.inkShadow,
                                  ),
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: layout.inset(16),
                                      vertical: layout.gap(16),
                                    ),
                                    child: Row(
                                      children: [
                                        Image.asset(
                                          'assets/images/google_logo.png',
                                          width: layout.inset(22),
                                          height: layout.inset(22),
                                        ),
                                        SizedBox(width: layout.inset(14)),
                                        Expanded(
                                          child: Text(
                                            _isSignUp
                                                ? 'SIGN UP WITH GOOGLE'
                                                : 'SIGN IN WITH GOOGLE',
                                            style: GoogleFonts.spaceMono(
                                              color: AppTheme.black,
                                              fontSize: layout.font(13),
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 0.7,
                                            ),
                                          ),
                                        ),
                                        Icon(
                                          Icons.arrow_forward,
                                          color: AppTheme.black,
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
    final layout = AppLayout.of(context);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: layout.gap(54),
          color: active ? AppTheme.yellow : AppTheme.bg(context),
          alignment: Alignment.center,
          child: Text(
            label,
            style: GoogleFonts.spaceMono(
              color: active ? AppTheme.black : AppTheme.fg(context),
              fontSize: layout.font(13),
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
    final layout = AppLayout.of(context);
    return Container(
      width: double.infinity,
      decoration: AppTheme.brutalBox(context, color: color, shadow: false),
      child: Padding(
        padding: EdgeInsets.all(layout.inset(14)),
        child: Text(
          text,
          style: GoogleFonts.spaceMono(
            color: textColor,
            fontSize: layout.font(11),
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
    Widget? suffixIcon,
  }) {
    final layout = AppLayout.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.spaceMono(
            color: AppTheme.fg(context),
            fontSize: layout.font(11),
            fontWeight: FontWeight.w700,
            letterSpacing: 0.7,
          ),
        ),
        SizedBox(height: layout.gap(8)),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          style: GoogleFonts.spaceMono(
            color: AppTheme.fg(context),
            fontSize: layout.font(13),
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.spaceMono(
              color: AppTheme.textSec(context),
              fontSize: layout.font(12),
            ),
            filled: true,
            fillColor: AppTheme.bg(context),
            suffixIcon: suffixIcon == null
                ? null
                : Padding(
                    padding: EdgeInsets.only(right: layout.inset(8)),
                    child: suffixIcon,
                  ),
            suffixIconConstraints: BoxConstraints(
              minWidth: layout.inset(36),
              minHeight: layout.inset(36),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: layout.inset(14),
              vertical: layout.gap(14),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(color: AppTheme.fg(context), width: 2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(color: AppTheme.fg(context), width: 3),
            ),
            errorBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(color: AppTheme.red, width: 2),
            ),
            focusedErrorBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(color: AppTheme.red, width: 3),
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }
}
