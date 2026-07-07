import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_service.dart';

// ── Premium palette (Moneytries brand green) ──────────────────────────────────
const _bgTop          = Color(0xFFF3FAF6);
const _bgBottom       = Color(0xFFE7F3EC);
const _deepInk        = Color(0xFF0A1A10);
const _titleColor     = Color(0xFF0D2818);
const _bodyColor      = Color(0xFF5B6B62);
const _emailBold      = Color(0xFF0D2818);
const _cardBorder     = Color(0xFFDDEAE1);
const _otpIdleBorder  = Color(0xFFD8E6DD);
const _otpFocusBorder = Color(0xFF16A34A);
const _otpFill        = Color(0xFFFFFFFF);
const _otpText        = Color(0xFF0D2818);
const _primaryGreen   = Color(0xFF16A34A);
const _emerald        = Color(0xFF00C896);
const _timerGrey      = Color(0xFF8A9990);
const _securityGrey   = Color(0xFF6B7A71);
const _errorRed       = Color(0xFFDC2626);
const _errorBg        = Color(0xFFFDF3F3);

class EmailOtpScreen extends StatefulWidget {
  /// Raw email address, used for the backend OTP send/verify calls.
  final String email;
  const EmailOtpScreen({super.key, required this.email});

  @override
  State<EmailOtpScreen> createState() => _EmailOtpScreenState();
}

class _EmailOtpScreenState extends State<EmailOtpScreen>
    with SingleTickerProviderStateMixin {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes =
      List.generate(6, (_) => FocusNode());

  int _secondsLeft = 54;
  Timer? _timer;
  bool _canResend = false;
  String? _otpError;
  bool _isVerifying = false;
  bool _isResending = false;

  late final AnimationController _introController;
  late final Animation<double> _introFade;
  late final Animation<Offset> _introSlide;

  /// Masked email for display only (e.g. "j***n@example.com"); the backend
  /// calls always use the raw widget.email.
  String get _maskedEmail {
    final parts = widget.email.split('@');
    if (parts.length != 2) return widget.email;
    final local = parts[0];
    final domain = parts[1];
    if (local.length <= 2) return '${local[0]}*@$domain';
    return '${local[0]}${'*' * (local.length - 2)}${local[local.length - 1]}@$domain';
  }

  @override
  void initState() {
    super.initState();
    _startTimer();
    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _introFade = CurvedAnimation(parent: _introController, curve: Curves.easeOut);
    _introSlide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _introController, curve: Curves.easeOutCubic));
    _introController.forward();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() {
      _secondsLeft = 54;
      _canResend   = false;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft <= 1) {
        t.cancel();
        setState(() => _canResend = true);
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  String get _timerLabel {
    final m = _secondsLeft ~/ 60;
    final s = _secondsLeft % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _onDigitChanged(int index, String value) {
    if (value.length > 1) {
      final digits = value.replaceAll(RegExp(r'\D'), '').split('');
      for (int i = 0; i < 6 && i < digits.length; i++) {
        _controllers[i].text = digits[i];
      }
      final nextEmpty = _controllers.indexWhere((c) => c.text.isEmpty);
      _focusNodes[nextEmpty == -1 ? 5 : nextEmpty].requestFocus();
      setState(() => _otpError = null);
      return;
    }
    if (value.isNotEmpty) {
      if (index < 5) _focusNodes[index + 1].requestFocus();
    } else {
      if (index > 0) _focusNodes[index - 1].requestFocus();
    }
    if (_otpError != null) setState(() => _otpError = null);
  }

  Future<void> _handleVerify() async {
    final otp = _controllers.map((c) => c.text).join();

    if (otp.length != 6) {
      setState(() {
        _otpError = 'Please enter all 6 digits';
      });
      return;
    }

    setState(() {
      _isVerifying = true;
      _otpError = null;
    });

    final error = await ApiService.verifyEmailOtpRegister(
      email: widget.email,
      otp: otp,
    ).then((response) {
      if (response['success'] == true) return null;
      return response['message']?.toString() ?? 'Invalid OTP. Please try again.';
    }).catchError((_) => 'Something went wrong. Please try again.');

    if (!mounted) return;

    if (error != null) {
      setState(() {
        _isVerifying = false;
        _otpError = error;
      });
      return;
    }

    setState(() => _isVerifying = false);
    // Explicitly signal success so the caller only marks this verified
    // when the backend has actually confirmed the OTP.
    Navigator.pop(context, true);
  }

  Future<void> _resend() async {
    if (_isResending) return;

    setState(() => _isResending = true);

    final error = await ApiService.sendEmailOtpRegister(email: widget.email)
        .then((response) {
      if (response['success'] == true) return null;
      return response['message']?.toString() ?? 'Failed to resend OTP. Please try again.';
    }).catchError((_) => 'Something went wrong. Please try again.');

    if (!mounted) return;

    setState(() => _isResending = false);

    if (error != null) {
      setState(() => _otpError = error);
      return;
    }

    for (final c in _controllers) c.clear();
    setState(() => _otpError = null);
    _startTimer();
    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) _focusNodes[0].requestFocus();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _introController.dispose();
    for (final c in _controllers) c.dispose();
    for (final f in _focusNodes) f.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // We intercept every pop attempt (system back gesture / hardware back
      // button included) so an incomplete or abandoned OTP flow can never be
      // mistaken for a verified email address by the registration screen.
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pop(context, false);
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _bgBottom,
        body: Stack(
          children: [
            // ── Ambient gradient backdrop ─────────────────────────────────
            Positioned.fill(
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [_bgTop, _bgBottom],
                  ),
                ),
              ),
            ),
            Positioned(
              top: -90,
              left: -70,
              child: _blurBlob(220, _primaryGreen.withOpacity(0.14)),
            ),
            Positioned(
              bottom: -60,
              right: -80,
              child: _blurBlob(200, _emerald.withOpacity(0.12)),
            ),

            SafeArea(
              child: Column(
                children: [
                  // ── AppBar ────────────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        _GlassCircleButton(
                          icon: Icons.arrow_back_rounded,
                          // Explicit false: leaving via the back button must
                          // never be treated as a verified email address.
                          onTap: () => Navigator.pop(context, false),
                        ),
                        Expanded(
                          child: Center(
                            child: Text(
                              'Verify Email',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: _titleColor,
                                letterSpacing: -0.1,
                              ),
                            ),
                          ),
                        ),
                        _GlassCircleButton(
                          icon: Icons.help_outline_rounded,
                          onTap: () {},
                        ),
                      ],
                    ),
                  ),

                  // ── Scrollable body ───────────────────────────────────────
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: FadeTransition(
                        opacity: _introFade,
                        child: SlideTransition(
                          position: _introSlide,
                          child: Column(
                            children: [
                              const SizedBox(height: 6),

                              // ── Signature badge: layered glow envelope ────
                              _PremiumBadge(icon: Icons.mark_email_read_rounded),

                              const SizedBox(height: 26),

                              Text(
                                'Verify Your Email',
                                style: GoogleFonts.poppins(
                                  fontSize: 25,
                                  fontWeight: FontWeight.w800,
                                  color: _titleColor,
                                  letterSpacing: -0.4,
                                  height: 1.2,
                                ),
                                textAlign: TextAlign.center,
                              ),

                              const SizedBox(height: 10),

                              Text(
                                "We've sent a 6-digit verification code to",
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                  color: _bodyColor,
                                  height: 1.5,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                _maskedEmail,
                                style: GoogleFonts.poppins(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                  color: _emailBold,
                                  height: 1.5,
                                ),
                                textAlign: TextAlign.center,
                              ),

                              const SizedBox(height: 28),

                              // ── Premium card holding the OTP field ────────
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.fromLTRB(20, 26, 20, 22),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(color: _cardBorder, width: 1),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _deepInk.withOpacity(0.06),
                                      blurRadius: 28,
                                      offset: const Offset(0, 14),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: List.generate(6, _buildOtpBox),
                                    ),

                                    if (_otpError != null) ...[
                                      const SizedBox(height: 14),
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: _errorBg,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            const Icon(
                                              Icons.error_outline_rounded,
                                              size: 14,
                                              color: _errorRed,
                                            ),
                                            const SizedBox(width: 6),
                                            Flexible(
                                              child: Text(
                                                _otpError!,
                                                style: GoogleFonts.poppins(
                                                  fontSize: 12,
                                                  color: _errorRed,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],

                                    const SizedBox(height: 22),

                                    Text(
                                      "Didn't receive the code?",
                                      style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        color: _timerGrey,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 8),
                                    _canResend
                                        ? GestureDetector(
                                            onTap: _isResending ? null : _resend,
                                            child: _isResending
                                                ? const SizedBox(
                                                    width: 16,
                                                    height: 16,
                                                    child: CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: _primaryGreen,
                                                    ),
                                                  )
                                                : Text(
                                                    'Resend Code',
                                                    style: GoogleFonts.poppins(
                                                      fontSize: 13.5,
                                                      fontWeight: FontWeight.w700,
                                                      color: _primaryGreen,
                                                    ),
                                                  ),
                                          )
                                        : Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 14, vertical: 8),
                                            decoration: BoxDecoration(
                                              color: _bgTop,
                                              borderRadius: BorderRadius.circular(30),
                                              border: Border.all(color: _cardBorder),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(
                                                  Icons.access_time_rounded,
                                                  size: 14,
                                                  color: _timerGrey,
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  'Resend in $_timerLabel',
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 12.5,
                                                    fontWeight: FontWeight.w700,
                                                    color: _primaryGreen,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 26),

                              // ── Verify button ─────────────────────────────
                              _GradientButton(
                                label: 'Verify',
                                loading: _isVerifying,
                                onTap: _handleVerify,
                              ),

                              const SizedBox(height: 20),

                              _TrustFooter(
                                text:
                                    'By verifying, your investments and data stay\nsecured within the Moneytries ecosystem.',
                              ),

                              const SizedBox(height: 28),
                            ],
                          ),
                        ),
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
    );
  }

  Widget _buildOtpBox(int index) {
    final hasError = _otpError != null;
    return SizedBox(
      width: 46,
      height: 56,
      child: AnimatedBuilder(
        animation: _focusNodes[index],
        builder: (context, child) {
          final isFocused = _focusNodes[index].hasFocus;
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              boxShadow: isFocused
                  ? [
                      BoxShadow(
                        color: _otpFocusBorder.withOpacity(0.18),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [],
            ),
            child: child,
          );
        },
        child: TextField(
          controller: _controllers[index],
          focusNode: _focusNodes[index],
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          maxLength: 2,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: GoogleFonts.poppins(
            fontSize: 21,
            fontWeight: FontWeight.w700,
            color: _otpText,
          ),
          onChanged: (v) => _onDigitChanged(index, v),
          decoration: InputDecoration(
            counterText: '',
            hintText: '–',
            hintStyle: GoogleFonts.poppins(
              fontSize: 18,
              color: const Color(0xFFB7C6BC),
              fontWeight: FontWeight.w500,
            ),
            filled: true,
            fillColor: _otpFill,
            contentPadding: EdgeInsets.zero,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: hasError ? _errorRed.withOpacity(0.5) : _otpIdleBorder,
                width: 1.4,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: hasError ? _errorRed.withOpacity(0.5) : _otpIdleBorder,
                width: 1.4,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _otpFocusBorder, width: 2),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Blurred ambient blob for background depth ─────────────────────────────────
Widget _blurBlob(double size, Color color) {
  return ClipOval(
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 1, sigmaY: 1),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    ),
  );
}

// ── Frosted circular icon button ───────────────────────────────────────────────
class _GlassCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _GlassCircleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 0,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: _cardBorder),
            boxShadow: [
              BoxShadow(
                color: _deepInk.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(icon, color: _titleColor, size: 18),
        ),
      ),
    );
  }
}

// ── Signature layered-glow badge ───────────────────────────────────────────────
class _PremiumBadge extends StatelessWidget {
  final IconData icon;
  const _PremiumBadge({required this.icon});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 108,
      height: 108,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 108,
            height: 108,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _primaryGreen.withOpacity(0.08),
            ),
          ),
          Container(
            width: 82,
            height: 82,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _primaryGreen.withOpacity(0.14),
            ),
          ),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_primaryGreen, _emerald],
              ),
              boxShadow: [
                BoxShadow(
                  color: _primaryGreen.withOpacity(0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 30),
          ),
        ],
      ),
    );
  }
}

// ── Gradient CTA button with press feedback ────────────────────────────────────
class _GradientButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback onTap;
  const _GradientButton({
    required this.label,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: Material(
        borderRadius: BorderRadius.circular(16),
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: loading ? null : onTap,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [_primaryGreen, _emerald],
              ),
              boxShadow: [
                BoxShadow(
                  color: _primaryGreen.withOpacity(0.32),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Center(
              child: loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      label,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Trust / security footer note ───────────────────────────────────────────────
class _TrustFooter extends StatelessWidget {
  final String text;
  const _TrustFooter({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 2),
          child: Icon(Icons.verified_user_rounded, size: 14, color: _primaryGreen),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 11.5,
              color: _securityGrey,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}