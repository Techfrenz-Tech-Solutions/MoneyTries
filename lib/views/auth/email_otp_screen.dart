import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/api_service.dart';
import '../../utils/responsive.dart';

// ── Premium palette (Moneytries brand green) ──────────────────────────────────
const _bgTop = Color(0xFFF7F5F2);
const _bgBottom = Color(0xFFF0EDE7);
const _deepInk = Color(0xFFF7F5F2);
const _titleColor = Color(0xFF111827);
const _bodyColor = Color(0xFF6B7280);
const _emailBold = Color(0xFF111827);
const _cardBorder = Color(0xFFE2CEBA);
const _otpIdleBorder = Color(0xFFD9D5CF);
const _otpFocusBorder = Color(0xFF4CAF7D);
const _otpFill = Color(0xFFFFFFFF);
const _otpText = Color(0xFF111827);
const _primaryGreen = Color(0xFF4CAF7D);
const _emerald = Color(0xFF7DCB9E);
const _timerGrey = Color(0xFF9CA3AF);
const _securityGrey = Color(0xFF6B7280);
const _errorRed = Color(0xFFDC2626);
const _errorBg = Color(0xFFFDF3F3);

class EmailOtpScreen extends StatefulWidget {
  /// Raw email address, used for the backend OTP send/verify calls.
  final String email;
  const EmailOtpScreen({super.key, required this.email});

  @override
  State<EmailOtpScreen> createState() => _EmailOtpScreenState();
}

class _EmailOtpScreenState extends State<EmailOtpScreen>
    with SingleTickerProviderStateMixin {
  final List<TextEditingController> _controllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

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
    _introFade = CurvedAnimation(
      parent: _introController,
      curve: Curves.easeOut,
    );
    _introSlide = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _introController, curve: Curves.easeOutCubic),
        );
    _introController.forward();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() {
      _secondsLeft = 54;
      _canResend = false;
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

    final error =
        await ApiService.verifyEmailOtpRegister(email: widget.email, otp: otp)
            .then((response) {
              if (response['success'] == true) return null;
              return response['message']?.toString() ??
                  'Invalid OTP. Please try again.';
            })
            .catchError((_) => 'Something went wrong. Please try again.');

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
          return response['message']?.toString() ??
              'Failed to resend OTP. Please try again.';
        })
        .catchError((_) => 'Something went wrong. Please try again.');

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
                      padding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 10.h,
                      ),
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
                                style: TextStyle(
                                  fontFamily: 'Times New Roman',
                                  fontSize: 16.sp,
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
                        padding: EdgeInsets.symmetric(horizontal: 24.w),
                        child: FadeTransition(
                          opacity: _introFade,
                          child: SlideTransition(
                            position: _introSlide,
                            child: Column(
                              children: [
                                SizedBox(height: 6.h),

                                // ── Signature badge: layered glow envelope ────
                                _PremiumBadge(
                                  icon: Icons.mark_email_read_rounded,
                                ),

                                SizedBox(height: 26.h),

                                Text(
                                  'Verify Your Email',
                                  style: TextStyle(
                                    fontFamily: 'Times New Roman',
                                    fontSize: 25.sp,
                                    fontWeight: FontWeight.w800,
                                    color: _titleColor,
                                    letterSpacing: -0.4,
                                    height: 1.2,
                                  ),
                                  textAlign: TextAlign.center,
                                ),

                                SizedBox(height: 10.h),

                                Text(
                                  "We've sent a 6-digit verification code to",
                                  style: TextStyle(
                                    fontFamily: 'Times New Roman',
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w400,
                                    color: _bodyColor,
                                    height: 1.5,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(height: 3.h),
                                Text(
                                  _maskedEmail,
                                  style: TextStyle(
                                    fontFamily: 'Times New Roman',
                                    fontSize: 14.5.sp,
                                    fontWeight: FontWeight.w700,
                                    color: _emailBold,
                                    height: 1.5,
                                  ),
                                  textAlign: TextAlign.center,
                                ),

                                SizedBox(height: 28.h),

                                // ── Premium card holding the OTP field ────────
                                Container(
                                  width: double.infinity,
                                  padding: EdgeInsets.fromLTRB(
                                    20.w,
                                    26.h,
                                    20.w,
                                    22.h,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(24.r),
                                    border: Border.all(
                                      color: _cardBorder,
                                      width: 1.r,
                                    ),
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
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: List.generate(
                                          6,
                                          _buildOtpBox,
                                        ),
                                      ),

                                      if (_otpError != null) ...[
                                        SizedBox(height: 14.h),
                                        Container(
                                          width: double.infinity,
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 12.w,
                                            vertical: 8.h,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _errorBg,
                                            borderRadius: BorderRadius.circular(
                                              10.r,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.error_outline_rounded,
                                                size: 14.sp,
                                                color: _errorRed,
                                              ),
                                              SizedBox(width: 6.w),
                                              Flexible(
                                                child: Text(
                                                  _otpError!,
                                                  style: TextStyle(
                                                    fontFamily:
                                                        'Times New Roman',
                                                    fontSize: 12.sp,
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

                                      SizedBox(height: 22.h),

                                      Text(
                                        "Didn't receive the code?",
                                        style: TextStyle(
                                          fontFamily: 'Times New Roman',
                                          fontSize: 13.sp,
                                          color: _timerGrey,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      SizedBox(height: 8.h),
                                      _canResend
                                          ? GestureDetector(
                                              onTap: _isResending
                                                  ? null
                                                  : _resend,
                                              child: _isResending
                                                  ? SizedBox(
                                                      width: 16.w,
                                                      height: 16.h,
                                                      child:
                                                          CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                            color:
                                                                _primaryGreen,
                                                          ),
                                                    )
                                                  : Text(
                                                      'Resend Code',
                                                      style: TextStyle(
                                                        fontFamily:
                                                            'Times New Roman',
                                                        fontSize: 13.5.sp,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: _primaryGreen,
                                                      ),
                                                    ),
                                            )
                                          : Container(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: 14.w,
                                                vertical: 8.h,
                                              ),
                                              decoration: BoxDecoration(
                                                color: _bgTop,
                                                borderRadius:
                                                    BorderRadius.circular(30.r),
                                                border: Border.all(
                                                  color: _cardBorder,
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.access_time_rounded,
                                                    size: 14.sp,
                                                    color: _timerGrey,
                                                  ),
                                                  SizedBox(width: 6.w),
                                                  Text(
                                                    'Resend in $_timerLabel',
                                                    style: TextStyle(
                                                      fontFamily:
                                                          'Times New Roman',
                                                      fontSize: 12.5.sp,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: _primaryGreen,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                    ],
                                  ),
                                ),

                                SizedBox(height: 26.h),

                                // ── Verify button ─────────────────────────────
                                _GradientButton(
                                  label: 'Verify',
                                  loading: _isVerifying,
                                  onTap: _handleVerify,
                                ),

                                SizedBox(height: 20.h),

                                _TrustFooter(
                                  text:
                                      'By verifying, your investments and data stay\nsecured within the Moneytries ecosystem.',
                                ),

                                SizedBox(height: 28.h),
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
      width: 46.w,
      height: 56.h,
      child: AnimatedBuilder(
        animation: _focusNodes[index],
        builder: (context, child) {
          final isFocused = _focusNodes[index].hasFocus;
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14.r),
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
          style: TextStyle(
            fontFamily: 'Times New Roman',
            fontSize: 21.sp,
            fontWeight: FontWeight.w700,
            color: _otpText,
          ),
          onChanged: (v) => _onDigitChanged(index, v),
          decoration: InputDecoration(
            counterText: '',
            hintText: '–',
            hintStyle: TextStyle(
              fontFamily: 'Times New Roman',
              fontSize: 18.sp,
              color: const Color(0xFF9CA3AF),
              fontWeight: FontWeight.w500,
            ),
            filled: true,
            fillColor: _otpFill,
            contentPadding: EdgeInsets.zero,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14.r),
              borderSide: BorderSide(
                color: hasError ? _errorRed.withOpacity(0.5) : _otpIdleBorder,
                width: 1.4.r,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14.r),
              borderSide: BorderSide(
                color: hasError ? _errorRed.withOpacity(0.5) : _otpIdleBorder,
                width: 1.4.r,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14.r),
              borderSide: BorderSide(color: _otpFocusBorder, width: 2.r),
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
          width: 40.w,
          height: 40.h,
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
          child: Icon(icon, color: _titleColor, size: 18.sp),
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
      width: 108.w,
      height: 108.h,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 108.w,
            height: 108.h,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _primaryGreen.withOpacity(0.08),
            ),
          ),
          Container(
            width: 82.w,
            height: 82.h,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _primaryGreen.withOpacity(0.14),
            ),
          ),
          Container(
            width: 64.w,
            height: 64.h,
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
            child: Icon(icon, color: Colors.white, size: 30.sp),
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
      height: 56.h,
      child: Material(
        borderRadius: BorderRadius.circular(16.r),
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16.r),
          onTap: loading ? null : onTap,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16.r),
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
                  ? SizedBox(
                      width: 22.w,
                      height: 22.h,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      label,
                      style: TextStyle(
                        fontFamily: 'Times New Roman',
                        fontSize: 16.sp,
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
        Padding(
          padding: EdgeInsets.only(top: 2.h),
          child: Icon(
            Icons.verified_user_rounded,
            size: 14.sp,
            color: _primaryGreen,
          ),
        ),
        SizedBox(width: 6.w),
        Flexible(
          child: Text(
            text,
            style: TextStyle(
              fontFamily: 'Times New Roman',
              fontSize: 11.5.sp,
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
