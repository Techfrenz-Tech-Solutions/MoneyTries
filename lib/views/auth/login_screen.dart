// lib/views/auth/login_screen.dart

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/security/security_repository.dart';
import '../../routes/app_routes.dart';
import '../../services/api_service.dart';
import '../../services/biometric_auth_service.dart';
import '../../viewmodels/auth/login_viewmodel.dart';
import 'forgot_password_screen.dart';
import 'login_two_factor_screen.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _titleColor = Color(0xFF1A1A2E);
const _subtitleColor = Color(0xFF6B7280);
const _labelColor = Color(0xFF374151);
const _fieldFill = Color(0xFFEEF2FF);
const _fieldIconColor = Color(0xFF9CA3AF);
const _hintColor = Color(0xFF9CA3AF);
const _borderColorFocus = Color(0xFF4DAA75);
const _greenPrimary = Color(0xFF4DAA75);
const _greenLink = Color(0xFF3D9E6A);
const _forgotColor = Color(0xFF3D9E6A);
const _biometricCircle = Color(0xFFE3F3EA);
const _biometricIcon = Color(0xFF4DAA75);
const _errorRed = Color(0xFFDC2626);

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => LoginViewModel(),
      child: const _LoginContent(),
    );
  }
}

class _LoginContent extends StatefulWidget {
  const _LoginContent();

  @override
  State<_LoginContent> createState() => _LoginContentState();
}

class _LoginContentState extends State<_LoginContent> {
  final _identifierCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;

  // ── Biometrics ────────────────────────────────────────────────────────────
  bool _biometricAvailable = false;
  String? _biometricLabel; // remembered account's display name, if any
  bool _isBiometricBusy = false;

  bool get _hasBiometricSession => _biometricLabel != null;

  @override
  void initState() {
    super.initState();
    _refreshBiometricState();
  }

  Future<void> _refreshBiometricState() async {
    final available = await BiometricAuthService.isDeviceCapable();
    final remembered = await BiometricAuthService.getRememberedSession();
    if (!mounted) return;
    setState(() {
      _biometricAvailable = available;
      _biometricLabel = remembered?['label'];
    });
  }

  @override
  void dispose() {
    _identifierCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  // ── Login handler ─────────────────────────────────────────────────────────
  Future<void> _handleLogin() async {
    FocusScope.of(context).unfocus();
    final vm = context.read<LoginViewModel>();

    final destination = await vm.login(
      identifier: _identifierCtrl.text,
      password: _passwordCtrl.text,
    );

    if (!mounted) return;

    if (destination == 'set_password') {
      Navigator.pushReplacementNamed(context, AppRoutes.setPassword);
    } else if (destination == 'app_pin') {
      Navigator.pushReplacementNamed(context, AppRoutes.appPin);
    } else if (destination == 'home') {
      Navigator.pushReplacementNamed(context, AppRoutes.home);
    } else if (destination == 'verify_2fa') {
      // Password was correct, but this account has 2FA enabled — hand off
      // to the OTP verification screen using the SAME LoginViewModel
      // instance so it can complete the login once the OTP is verified.
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChangeNotifierProvider.value(
            value: vm,
            child: const LoginTwoFactorScreen(),
          ),
        ),
      );
    }
  }

  // ── Forgot password handler ───────────────────────────────────────────────
  void _handleForgotPassword() {
    final id = _identifierCtrl.text.trim();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ForgotPasswordScreen(prefillIdentifier: id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);

    return Theme(
      data: ThemeData(
        brightness: Brightness.light,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: _fieldFill,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _borderColorFocus, width: 1.5),
          ),
          hintStyle: GoogleFonts.poppins(
            color: _hintColor,
            fontSize: 14.5,
            fontWeight: FontWeight.w400,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 15,
          ),
        ),
      ),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: Scaffold(
          backgroundColor: const Color(0xFFF5FAF7),
          body: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFCDEBDA),
                  Color(0xFFE6F4EC),
                  Color(0xFFF5FAF7),
                ],
                stops: [0.0, 0.40, 1.0],
              ),
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight:
                        mq.size.height - mq.padding.top - mq.padding.bottom,
                  ),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(height: mq.size.height * 0.115),

                        // ── Icon badge ──────────────────────────────────
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.06),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Icon(
                                  Icons.shield_rounded,
                                  size: 36,
                                  color: Color(0xFF3D9E6A),
                                ),
                                Icon(
                                  Icons.favorite,
                                  size: 14,
                                  color: Colors.white,
                                ),
                              ],
                            ),
                          ),
                        ),

                        SizedBox(height: mq.size.height * 0.03),

                        // ── Title ────────────────────────────────────────
                        Text(
                          'Welcome Back',
                          style: GoogleFonts.poppins(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: _titleColor,
                            letterSpacing: -0.4,
                            height: 1.15,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Secure access to your Moneytries portfolio',
                          style: GoogleFonts.poppins(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w400,
                            color: _subtitleColor,
                            height: 1.4,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        SizedBox(height: mq.size.height * 0.035),

                        // ── White card ───────────────────────────────────
                        Consumer<LoginViewModel>(
                          builder: (context, vm, _) {
                            return Container(
                              width: double.infinity,
                              margin: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.06),
                                    blurRadius: 20,
                                    offset: const Offset(0, 4),
                                  ),
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.03),
                                    blurRadius: 6,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                24,
                                20,
                                28,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // ── Global error banner ──────────────
                                  if (vm.errorMessage != null) ...[
                                    _ErrorBanner(message: vm.errorMessage!),
                                    const SizedBox(height: 16),
                                  ],

                                  // ── Identifier label + field ──────────
                                  Text(
                                    'Mobile Number or Email',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w500,
                                      color: _labelColor,
                                      letterSpacing: 0.1,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  _InputField(
                                    controller: _identifierCtrl,
                                    hint: 'Enter your email or 10-digit mobile',
                                    icon: Icons.person_outline_rounded,
                                    keyboardType: TextInputType.emailAddress,
                                    errorText: vm.identifierError,
                                    onChanged: (_) => vm.clearIdentifierError(),
                                  ),

                                  const SizedBox(height: 18),

                                  // ── Password label row ─────────────────
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Password',
                                        style: GoogleFonts.poppins(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w500,
                                          color: _labelColor,
                                          letterSpacing: 0.1,
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: _handleForgotPassword,
                                        child: Text(
                                          'Forgot Password?',
                                          style: GoogleFonts.poppins(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w600,
                                            color: _forgotColor,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),

                                  // ── Password field ────────────────────
                                  _PasswordField(
                                    controller: _passwordCtrl,
                                    obscure: _obscurePassword,
                                    onToggle: () => setState(
                                      () =>
                                          _obscurePassword = !_obscurePassword,
                                    ),
                                    errorText: vm.passwordError,
                                    onChanged: (_) => vm.clearPasswordError(),
                                  ),

                                  const SizedBox(height: 16),

                                  // ── Remember me ───────────────────────
                                  GestureDetector(
                                    onTap: vm.toggleRememberMe,
                                    child: Row(
                                      children: [
                                        AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 180,
                                          ),
                                          width: 20,
                                          height: 20,
                                          decoration: BoxDecoration(
                                            color: vm.rememberMe
                                                ? _greenPrimary
                                                : Colors.transparent,
                                            borderRadius: BorderRadius.circular(
                                              5,
                                            ),
                                            border: Border.all(
                                              color: vm.rememberMe
                                                  ? _greenPrimary
                                                  : const Color(0xFFD1D5DB),
                                              width: 1.5,
                                            ),
                                          ),
                                          child: vm.rememberMe
                                              ? const Icon(
                                                  Icons.check_rounded,
                                                  size: 13,
                                                  color: Colors.white,
                                                )
                                              : null,
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          'Remember me',
                                          style: GoogleFonts.poppins(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color: _labelColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(height: 22),

                                  // ── Login button ──────────────────────
                                  SizedBox(
                                    width: double.infinity,
                                    height: 52,
                                    child: ElevatedButton(
                                      onPressed: vm.isLoading
                                          ? null
                                          : _handleLogin,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _greenPrimary,
                                        disabledBackgroundColor: _greenPrimary
                                            .withOpacity(0.7),
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        shadowColor: Colors.transparent,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                      child: vm.isLoading
                                          ? const SizedBox(
                                              width: 22,
                                              height: 22,
                                              child: CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 2.5,
                                              ),
                                            )
                                          : Text(
                                              'Login',
                                              style: GoogleFonts.poppins(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.white,
                                                letterSpacing: 0.3,
                                              ),
                                            ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),

                        const Spacer(),

                        // ── Register link ────────────────────────────────
                        Padding(
                          padding: const EdgeInsets.only(bottom: 28, top: 20),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Don't have an account?  ",
                                style: GoogleFonts.poppins(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w400,
                                  color: _subtitleColor,
                                ),
                              ),
                              GestureDetector(
                                onTap: () => Navigator.pushNamed(
                                  context,
                                  AppRoutes.register,
                                ),
                                child: Text(
                                  'Register',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                    color: _greenLink,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showSnack(BuildContext context, String message, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: GoogleFonts.poppins(fontSize: 13.5, color: Colors.white),
          ),
          backgroundColor: isError ? _errorRed : _greenPrimary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 3),
        ),
      );
  }

  // ── Biometric quick login ─────────────────────────────────────────────────
  // Uses the account most recently remembered on this device (the one that
  // last had "Biometric Login" turned on in Security Settings). A native
  // fingerprint/Face ID prompt confirms it's really that person, then the
  // cached token is re-validated against the backend (GET /api/auth/me)
  // before restoring the session — so an expired or revoked token can never
  // quietly let someone in.
  Future<void> _handleBiometricLogin(BuildContext context) async {
    if (_isBiometricBusy) return;

    if (!_biometricAvailable) {
      _showSnack(
        context,
        "Biometric authentication isn't available on this device.",
        isError: true,
      );
      return;
    }

    if (!_hasBiometricSession) {
      _showSnack(
        context,
        'Log in with your password once and turn on Biometric Login in '
        'Security Settings to use quick login.',
        isError: true,
      );
      return;
    }

    setState(() => _isBiometricBusy = true);

    String? authError;
    final authenticated = await BiometricAuthService.authenticate(
      reason: 'Authenticate to log in',
      onError: (msg) => authError = msg,
    );

    if (!mounted) return;

    if (!authenticated) {
      setState(() => _isBiometricBusy = false);
      if (authError != null) {
        _showSnack(context, authError!, isError: true);
      }
      return;
    }

    final session = await BiometricAuthService.getRememberedSession();
    if (session == null) {
      if (!mounted) return;
      setState(() => _isBiometricBusy = false);
      _showSnack(
        context,
        'No account is set up for biometric login on this device.',
        isError: true,
      );
      return;
    }

    try {
      final response = await ApiService.validateSession(token: session['token']!);

      if (!mounted) return;

      if (response['success'] == true) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', session['token']!);
        await prefs.setString('logged_in_user_id', session['userId']!);
        await prefs.setString(
          'logged_in_user_label',
          session['label'] ?? '',
        );

        // Best-effort bookkeeping — same endpoints already used for the
        // Security Settings "Manage Devices" / "Login Activity" sections.
        final deviceName = Platform.isAndroid
            ? 'Android Device'
            : Platform.isIOS
                ? 'iPhone'
                : 'Unknown Device';
        unawaited(
          SecurityRepository().registerCurrentSession(session['token']!),
        );
        unawaited(
          SecurityRepository().recordLoginEvent(
            deviceName: deviceName,
            location: 'India',
            success: true,
          ),
        );

        if (!mounted) return;
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.home,
          (route) => false,
        );
        return;
      }

      // Token rejected by the backend (expired/revoked) — don't keep
      // offering a quick login that will only ever fail from here on.
      await BiometricAuthService.forgetSession();
      if (!mounted) return;
      setState(() {
        _isBiometricBusy = false;
        _biometricLabel = null;
      });
      _showSnack(
        context,
        'Your session has expired. Please log in with your password.',
        isError: true,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isBiometricBusy = false);
      _showSnack(context, 'No internet connection. Please try again.', isError: true);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Error Banner
// ─────────────────────────────────────────────────────────────────────────────
class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5F5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _errorRed.withOpacity(0.3), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, size: 18, color: _errorRed),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: _errorRed,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Input Field
// ─────────────────────────────────────────────────────────────────────────────
class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType keyboardType;
  final String? errorText;
  final ValueChanged<String>? onChanged;

  const _InputField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.keyboardType = TextInputType.text,
    this.errorText,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          onChanged: onChanged,
          style: GoogleFonts.poppins(
            fontSize: 14.5,
            color: const Color(0xFF374151),
            fontWeight: FontWeight.w400,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.poppins(
              color: _hintColor,
              fontSize: 14.5,
              fontWeight: FontWeight.w400,
            ),
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 14, right: 10),
              child: Icon(
                icon,
                size: 20,
                color: hasError ? _errorRed : _fieldIconColor,
              ),
            ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 44,
              minHeight: 44,
            ),
            filled: true,
            fillColor: hasError ? const Color(0xFFFFF5F5) : _fieldFill,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: hasError
                  ? const BorderSide(color: _errorRed, width: 1.5)
                  : BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: hasError ? _errorRed : _borderColorFocus,
                width: 1.5,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 15,
            ),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 5),
          Row(
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 13,
                color: _errorRed,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  errorText!,
                  style: GoogleFonts.poppins(
                    fontSize: 11.5,
                    color: _errorRed,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Password Field
// ─────────────────────────────────────────────────────────────────────────────
class _PasswordField extends StatelessWidget {
  final TextEditingController controller;
  final bool obscure;
  final VoidCallback onToggle;
  final String? errorText;
  final ValueChanged<String>? onChanged;

  const _PasswordField({
    required this.controller,
    required this.obscure,
    required this.onToggle,
    this.errorText,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          obscureText: obscure,
          obscuringCharacter: '●',
          onChanged: onChanged,
          style: GoogleFonts.poppins(
            fontSize: 14.5,
            color: const Color(0xFF374151),
            fontWeight: FontWeight.w400,
            letterSpacing: obscure ? 2.5 : 0,
          ),
          decoration: InputDecoration(
            hintText: 'Enter password',
            hintStyle: GoogleFonts.poppins(
              color: _hintColor,
              fontSize: 14.5,
              fontWeight: FontWeight.w400,
            ),
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 14, right: 10),
              child: Icon(
                Icons.lock_outline_rounded,
                size: 20,
                color: hasError ? _errorRed : _fieldIconColor,
              ),
            ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 44,
              minHeight: 44,
            ),
            suffixIcon: GestureDetector(
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.only(right: 14),
                child: Icon(
                  obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 20,
                  color: _fieldIconColor,
                ),
              ),
            ),
            suffixIconConstraints: const BoxConstraints(
              minWidth: 44,
              minHeight: 44,
            ),
            filled: true,
            fillColor: hasError ? const Color(0xFFFFF5F5) : _fieldFill,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: hasError
                  ? const BorderSide(color: _errorRed, width: 1.5)
                  : BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: hasError ? _errorRed : _borderColorFocus,
                width: 1.5,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 15,
            ),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 5),
          Row(
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 13,
                color: _errorRed,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  errorText!,
                  style: GoogleFonts.poppins(
                    fontSize: 11.5,
                    color: _errorRed,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}