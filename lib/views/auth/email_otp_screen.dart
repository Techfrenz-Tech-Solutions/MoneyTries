import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:moneytries/config/app_fonts.dart';
import 'package:flutter/services.dart';
import '../../services/api_service.dart';
import '../../utils/responsive.dart';
import '../../widgets/animations/success_check_animation.dart';

// ── Luxury palette (Moneytries brand, elevated with a warm gold accent) ────
const _bgTop = Color(0xFFFAF8F4);
const _bgBottom = Color(0xFFEFEAE1);
const _ink = Color(0xFF0E1712);
const _titleColor = Color(0xFF10201A);
const _bodyColor = Color(0xFF6B7280);
const _emailBold = Color(0xFF10201A);
const _cardBorder = Color(0xFFE6D8C1);
const _otpIdleBorder = Color(0xFFE4E0D7);
const _otpFocusGold = Color(0xFFB8935A);
const _otpFill = Color(0xFFFFFFFF);
const _otpText = Color(0xFF10231A);
const _primaryGreen = Color(0xFF3FA873);
const _deepEmerald = Color(0xFF1F5C3F);
const _emerald = Color(0xFF7DCB9E);
const _gold = Color(0xFFB8935A);
const _goldLight = Color(0xFFE7CDA0);
const _timerGrey = Color(0xFF9CA3AF);
const _securityGrey = Color(0xFF6B7280);
const _errorRed = Color(0xFFDC2626);
const _errorBg = Color(0xFFFDF3F3);

const int _initialSeconds = 54;

class EmailOtpScreen extends StatefulWidget {
  /// Raw email address, used for the backend OTP send/verify calls.
  final String email;
  const EmailOtpScreen({super.key, required this.email});

  @override
  State<EmailOtpScreen> createState() => _EmailOtpScreenState();
}

class _EmailOtpScreenState extends State<EmailOtpScreen>
    with TickerProviderStateMixin {
  final List<TextEditingController> _controllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  final List<bool> _justFilled = List.generate(6, (_) => false);

  int _secondsLeft = _initialSeconds;
  Timer? _timer;
  bool _canResend = false;
  String? _otpError;
  bool _isVerifying = false;
  bool _isResending = false;
  bool _verified = false;

  late final AnimationController _introController;
  late final Animation<double> _introFade;
  late final Animation<Offset> _introSlide;

  late final AnimationController _bezelController;

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

  bool get _isComplete => _controllers.every((c) => c.text.isNotEmpty);

  @override
  void initState() {
    super.initState();
    _startTimer();
    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
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

    _bezelController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    )..repeat();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() {
      _secondsLeft = _initialSeconds;
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

  void _pulseBox(int index) {
    setState(() => _justFilled[index] = true);
    Future.delayed(const Duration(milliseconds: 180), () {
      if (mounted) setState(() => _justFilled[index] = false);
    });
  }

  void _onDigitChanged(int index, String value) {
    if (value.length > 1) {
      final digits = value.replaceAll(RegExp(r'\D'), '').split('');
      for (int i = 0; i < 6 && i < digits.length; i++) {
        _controllers[i].text = digits[i];
        _pulseBox(i);
      }
      final nextEmpty = _controllers.indexWhere((c) => c.text.isEmpty);
      _focusNodes[nextEmpty == -1 ? 5 : nextEmpty].requestFocus();
      setState(() => _otpError = null);
      HapticFeedback.selectionClick();
      _maybeAutoSubmit();
      return;
    }
    if (value.isNotEmpty) {
      HapticFeedback.selectionClick();
      _pulseBox(index);
      if (index < 5) _focusNodes[index + 1].requestFocus();
    } else {
      if (index > 0) _focusNodes[index - 1].requestFocus();
    }
    if (_otpError != null) setState(() => _otpError = null);
    _maybeAutoSubmit();
  }

  void _maybeAutoSubmit() {
    if (_isComplete && !_isVerifying && !_verified) {
      HapticFeedback.mediumImpact();
      FocusManager.instance.primaryFocus?.unfocus();
      Future.delayed(const Duration(milliseconds: 220), () {
        if (mounted && _isComplete && !_isVerifying && !_verified) {
          _handleVerify();
        }
      });
    }
  }

  Future<void> _handleVerify() async {
    final otp = _controllers.map((c) => c.text).join();

    if (otp.length != 6) {
      setState(() {
        _otpError = 'Please enter all 6 digits';
      });
      HapticFeedback.heavyImpact();
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
      HapticFeedback.heavyImpact();
      setState(() {
        _isVerifying = false;
        _otpError = error;
      });
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() {
      _isVerifying = false;
      _verified = true;
    });
  }

  void _onVerifiedAnimationDone() {
    Future.delayed(const Duration(milliseconds: 450), () {
      if (!mounted) return;
      // Explicitly signal success so the caller only marks this verified
      // when the backend has actually confirmed the OTP.
      Navigator.pop(context, true);
    });
  }

  Future<void> _resend() async {
    if (_isResending || !_canResend) return;

    HapticFeedback.selectionClick();
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
    _bezelController.dispose();
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
              // ── Ambient luxury backdrop ───────────────────────────────────
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
                top: -100,
                left: -80,
                child: _blurBlob(240, _primaryGreen.withOpacity(0.14)),
              ),
              Positioned(
                top: -40,
                right: -60,
                child: _blurBlob(160, _gold.withOpacity(0.10)),
              ),
              Positioned(
                bottom: -70,
                right: -90,
                child: _blurBlob(220, _emerald.withOpacity(0.12)),
              ),
              Positioned(
                bottom: 120,
                left: -60,
                child: _blurBlob(140, _gold.withOpacity(0.08)),
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
                                  fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w700,
                                  color: _titleColor,
                                  letterSpacing: -0.1,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 40.w),
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
                                SizedBox(height: 10.h),

                                // ── Signature badge: rotating gold bezel ──────
                                AnimatedBuilder(
                                  animation: _bezelController,
                                  builder: (context, _) {
                                    return _PremiumBadge(
                                      icon: Icons.mark_email_read_rounded,
                                      rotation:
                                          _bezelController.value * 2 * math.pi,
                                    );
                                  },
                                ),

                                SizedBox(height: 22.h),

                                Text(
                                  'SECURE VERIFICATION',
                                  style: TextStyle(
                                    fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.w700,
                                    color: _gold,
                                    letterSpacing: 3.2,
                                  ),
                                  textAlign: TextAlign.center,
                                ),

                                SizedBox(height: 10.h),

                                Text(
                                  'Verify Your Email',
                                  style: TextStyle(
                                    fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                                    fontSize: 26.sp,
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
                                    fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w400,
                                    color: _bodyColor,
                                    height: 1.5,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(height: 10.h),

                                // ── Email chip ─────────────────────────────────
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 14.w,
                                    vertical: 8.h,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(30.r),
                                    border: Border.all(
                                      color: _cardBorder,
                                      width: 1.r,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: _ink.withOpacity(0.04),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.alternate_email_rounded,
                                        size: 14.sp,
                                        color: _gold,
                                      ),
                                      SizedBox(width: 6.w),
                                      Text(
                                        _maskedEmail,
                                        style: TextStyle(
                                          fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                                          fontSize: 14.sp,
                                          fontWeight: FontWeight.w700,
                                          color: _emailBold,
                                          height: 1.3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                SizedBox(height: 30.h),

                                // ── Premium card holding the OTP field ────────
                                _OtpCard(
                                  child: Column(
                                    children: [
                                      Row(
                                        children: [
                                          for (int i = 0; i < 6; i++) ...[
                                            Expanded(child: _buildOtpBox(i)),
                                            if (i != 5) SizedBox(width: 10.w),
                                          ],
                                        ],
                                      ),

                                      AnimatedSize(
                                        duration: const Duration(
                                          milliseconds: 220,
                                        ),
                                        curve: Curves.easeOut,
                                        child: _otpError != null
                                            ? Padding(
                                                padding: EdgeInsets.only(
                                                  top: 14.h,
                                                ),
                                                child: Container(
                                                  width: double.infinity,
                                                  padding: EdgeInsets.symmetric(
                                                    horizontal: 12.w,
                                                    vertical: 8.h,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: _errorBg,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                      10.r,
                                                    ),
                                                  ),
                                                  child: Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: [
                                                      Icon(
                                                        Icons
                                                            .error_outline_rounded,
                                                        size: 14.sp,
                                                        color: _errorRed,
                                                      ),
                                                      SizedBox(width: 6.w),
                                                      Flexible(
                                                        child: Text(
                                                          _otpError!,
                                                          style: TextStyle(
                                                            fontFamily:
                                                                AppFonts
                                                                    .primary,
                                                            fontFamilyFallback:
                                                                AppFonts
                                                                    .fallbacks,
                                                            fontSize: 12.sp,
                                                            color: _errorRed,
                                                            fontWeight:
                                                                FontWeight
                                                                    .w500,
                                                          ),
                                                          textAlign:
                                                              TextAlign.center,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              )
                                            : const SizedBox(
                                                width: double.infinity,
                                              ),
                                      ),

                                      SizedBox(height: 24.h),

                                      Text(
                                        "Didn't receive the code?",
                                        style: TextStyle(
                                          fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                                          fontSize: 13.sp,
                                          color: _timerGrey,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      SizedBox(height: 12.h),

                                      _CountdownRing(
                                        secondsLeft: _secondsLeft,
                                        initialSeconds: _initialSeconds,
                                        canResend: _canResend,
                                        isResending: _isResending,
                                        timerLabel: _timerLabel,
                                        onTap: _resend,
                                      ),
                                    ],
                                  ),
                                ),

                                SizedBox(height: 28.h),

                                // ── Verify button ─────────────────────────────
                                _GradientButton(
                                  label: 'Verify & Continue',
                                  loading: _isVerifying,
                                  enabled: _isComplete,
                                  onTap: _handleVerify,
                                ),

                                SizedBox(height: 22.h),

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

              // ── Success overlay ───────────────────────────────────────────
              IgnorePointer(
                ignoring: !_verified,
                child: AnimatedOpacity(
                  opacity: _verified ? 1 : 0,
                  duration: const Duration(milliseconds: 280),
                  child: Container(
                    color: _bgBottom.withOpacity(0.96),
                    width: double.infinity,
                    height: double.infinity,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_verified)
                            SuccessCheckAnimation(
                              size: 96,
                              color: _primaryGreen,
                              onCompleted: _onVerifiedAnimationDone,
                            ),
                          SizedBox(height: 20.h),
                          if (_verified)
                            Text(
                              'Email Verified',
                              style: TextStyle(
                                fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                                fontSize: 18.sp,
                                fontWeight: FontWeight.w800,
                                color: _titleColor,
                                letterSpacing: -0.2,
                              ),
                            ),
                          SizedBox(height: 6.h),
                          if (_verified)
                            Text(
                              'Your identity has been confirmed',
                              style: TextStyle(
                                fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                                fontSize: 13.sp,
                                color: _bodyColor,
                              ),
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
    );
  }

  Widget _buildOtpBox(int index) {
    final hasError = _otpError != null;
    final hasValue = _controllers[index].text.isNotEmpty;
    return SizedBox(
      height: 62.h,
      child: AnimatedBuilder(
        animation: _focusNodes[index],
        builder: (context, child) {
          final isFocused = _focusNodes[index].hasFocus;
          final Color accent = hasError
              ? _errorRed
              : (isFocused || hasValue)
                  ? _gold
                  : _otpIdleBorder;
          return AnimatedScale(
            scale: _justFilled[index] ? 1.08 : 1.0,
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutBack,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                color: _otpFill,
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(
                  color: hasError
                      ? _errorRed.withOpacity(0.5)
                      : (isFocused ? _otpFocusGold : _otpIdleBorder),
                  width: isFocused ? 1.6.r : 1.2.r,
                ),
                boxShadow: isFocused
                    ? [
                        BoxShadow(
                          color: _otpFocusGold.withOpacity(0.22),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : hasValue
                        ? [
                            BoxShadow(
                              color: _primaryGreen.withOpacity(0.08),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : [],
              ),
              child: Stack(
                children: [
                  child!,
                  // ── Gold accent bar: filled state indicator ─────────────
                  Positioned(
                    left: 10.w,
                    right: 10.w,
                    bottom: 7.h,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 2.6.h,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4.r),
                        gradient: LinearGradient(
                          colors: hasValue
                              ? [_primaryGreen, _gold]
                              : [
                                  _otpIdleBorder.withOpacity(0.6),
                                  _otpIdleBorder.withOpacity(0.6),
                                ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        child: TextField(
          controller: _controllers[index],
          focusNode: _focusNodes[index],
          textAlign: TextAlign.center,
          textAlignVertical: TextAlignVertical.center,
          keyboardType: TextInputType.number,
          maxLength: 2,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: TextStyle(
            fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
            fontSize: 22.sp,
            fontWeight: FontWeight.w700,
            color: _otpText,
          ),
          onChanged: (v) => _onDigitChanged(index, v),
          decoration: InputDecoration(
            counterText: '',
            hintText: '–',
            hintStyle: TextStyle(
              fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
              fontSize: 18.sp,
              color: const Color(0xFFB8BEC7),
              fontWeight: FontWeight.w500,
            ),
            filled: false,
            contentPadding: EdgeInsets.only(bottom: 6.h),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
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
                color: _ink.withOpacity(0.05),
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

// ── OTP card shell with fine gold corner accents ────────────────────────────────
class _OtpCard extends StatelessWidget {
  final Widget child;
  const _OtpCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20.w, 28.h, 20.w, 24.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26.r),
        border: Border.all(color: _cardBorder, width: 1.r),
        boxShadow: [
          BoxShadow(
            color: _ink.withOpacity(0.07),
            blurRadius: 32,
            offset: const Offset(0, 16),
          ),
          BoxShadow(
            color: _gold.withOpacity(0.05),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          child,
          // ── Corner flourish, top-left ─────────────────────────────────
          Positioned(
            top: -1,
            left: -1,
            child: CustomPaint(
              size: Size(26.w, 26.h),
              painter: _CornerFlourishPainter(color: _gold.withOpacity(0.55)),
            ),
          ),
          // ── Corner flourish, bottom-right ─────────────────────────────
          Positioned(
            bottom: -1,
            right: -1,
            child: Transform.rotate(
              angle: math.pi,
              child: CustomPaint(
                size: Size(26.w, 26.h),
                painter:
                    _CornerFlourishPainter(color: _primaryGreen.withOpacity(0.35)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CornerFlourishPainter extends CustomPainter {
  final Color color;
  _CornerFlourishPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(0, size.height * 0.55)
      ..lineTo(0, size.height * 0.12)
      ..quadraticBezierTo(0, 0, size.width * 0.12, 0)
      ..lineTo(size.width * 0.55, 0);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CornerFlourishPainter oldDelegate) =>
      oldDelegate.color != color;
}

// ── Signature layered badge with a slow-rotating gold bezel ───────────────────
class _PremiumBadge extends StatelessWidget {
  final IconData icon;
  final double rotation;
  const _PremiumBadge({required this.icon, required this.rotation});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 128.w,
      height: 128.h,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer static glow halo
          Container(
            width: 128.w,
            height: 128.h,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _primaryGreen.withOpacity(0.06),
            ),
          ),
          // Rotating gold sweep bezel
          Transform.rotate(
            angle: rotation,
            child: CustomPaint(
              size: Size(108.w, 108.h),
              painter: _BezelPainter(colorA: _gold, colorB: _goldLight),
            ),
          ),
          Container(
            width: 88.w,
            height: 88.h,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _primaryGreen.withOpacity(0.12),
            ),
          ),
          Container(
            width: 68.w,
            height: 68.h,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_primaryGreen, _deepEmerald],
              ),
              border: Border.all(color: Colors.white, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: _primaryGreen.withOpacity(0.38),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
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

class _BezelPainter extends CustomPainter {
  final Color colorA;
  final Color colorB;
  _BezelPainter({required this.colorA, required this.colorB});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Faint full track
    final track = Paint()
      ..color = colorA.withOpacity(0.14)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;
    canvas.drawCircle(center, radius, track);

    // Sweeping bright arc segment
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        colors: [
          colorA.withOpacity(0),
          colorB,
          colorA,
          colorA.withOpacity(0),
        ],
        stops: const [0.0, 0.16, 0.28, 0.42],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, sweepPaint);
  }

  @override
  bool shouldRepaint(covariant _BezelPainter oldDelegate) => true;
}

// ── Circular countdown ring replacing the plain resend pill ───────────────────
class _CountdownRing extends StatelessWidget {
  final int secondsLeft;
  final int initialSeconds;
  final bool canResend;
  final bool isResending;
  final String timerLabel;
  final VoidCallback onTap;

  const _CountdownRing({
    required this.secondsLeft,
    required this.initialSeconds,
    required this.canResend,
    required this.isResending,
    required this.timerLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final progress = canResend
        ? 1.0
        : 1.0 - (secondsLeft / initialSeconds).clamp(0.0, 1.0);

    return GestureDetector(
      onTap: canResend ? onTap : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 30.w,
            height: 30.h,
            child: isResending
                ? Padding(
                    padding: EdgeInsets.all(6.w),
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: _primaryGreen,
                    ),
                  )
                : TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: progress),
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOut,
                    builder: (context, value, _) {
                      return CustomPaint(
                        painter: _RingProgressPainter(
                          progress: value,
                          trackColor: _otpIdleBorder,
                          progressColor:
                              canResend ? _primaryGreen : _gold,
                        ),
                        child: canResend
                            ? Icon(
                                Icons.refresh_rounded,
                                size: 15.sp,
                                color: _primaryGreen,
                              )
                            : null,
                      );
                    },
                  ),
          ),
          SizedBox(width: 9.w),
          canResend
              ? Text(
                  isResending ? 'Sending…' : 'Resend Code',
                  style: TextStyle(
                    fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                    fontSize: 13.5.sp,
                    fontWeight: FontWeight.w700,
                    color: _primaryGreen,
                  ),
                )
              : Text(
                  'Resend in $timerLabel',
                  style: TextStyle(
                    fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    color: _titleColor,
                  ),
                ),
        ],
      ),
    );
  }
}

class _RingProgressPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color progressColor;
  _RingProgressPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 2;
    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4;
    canvas.drawCircle(center, radius, track);

    final arc = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(covariant _RingProgressPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.progressColor != progressColor;
}

// ── Gradient CTA button with a slow shimmer sweep + press feedback ────────────
class _GradientButton extends StatefulWidget {
  final String label;
  final bool loading;
  final bool enabled;
  final VoidCallback onTap;
  const _GradientButton({
    required this.label,
    required this.loading,
    required this.enabled,
    required this.onTap,
  });

  @override
  State<_GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<_GradientButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmerController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat();
  bool _pressed = false;

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.enabled && !widget.loading;
    return GestureDetector(
      onTapDown: active ? (_) => setState(() => _pressed = true) : null,
      onTapCancel: active ? () => setState(() => _pressed = false) : null,
      onTapUp: active ? (_) => setState(() => _pressed = false) : null,
      onTap: active ? widget.onTap : null,
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: AnimatedOpacity(
          opacity: active ? 1.0 : 0.55,
          duration: const Duration(milliseconds: 200),
          child: SizedBox(
            width: double.infinity,
            height: 56.h,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16.r),
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [_deepEmerald, _primaryGreen, _emerald],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _primaryGreen.withOpacity(0.32),
                          blurRadius: 22,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                  ),
                  if (active)
                    AnimatedBuilder(
                      animation: _shimmerController,
                      builder: (context, _) {
                        return Positioned.fill(
                          child: Align(
                            alignment: Alignment(
                              -3 + 6 * _shimmerController.value,
                              0,
                            ),
                            child: Transform.rotate(
                              angle: 0.5,
                              child: Container(
                                width: 46.w,
                                color: Colors.transparent,
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.white.withOpacity(0),
                                        Colors.white.withOpacity(0.22),
                                        Colors.white.withOpacity(0),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  Center(
                    child: widget.loading
                        ? SizedBox(
                            width: 22.w,
                            height: 22.h,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: Colors.white,
                            ),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.label,
                                style: TextStyle(
                                  fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              SizedBox(width: 8.w),
                              Icon(
                                Icons.arrow_forward_rounded,
                                size: 18.sp,
                                color: Colors.white,
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
            color: _gold,
          ),
        ),
        SizedBox(width: 6.w),
        Flexible(
          child: Text(
            text,
            style: TextStyle(
              fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
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