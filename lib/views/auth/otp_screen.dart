import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:moneytries/config/app_fonts.dart';
import 'package:flutter/services.dart';
import '../../routes/app_routes.dart';
import '../../services/api_service.dart';
import '../../utils/responsive.dart';

// ── Luxury palette (Moneytries brand, elevated with a warm gold accent) ────
const _bgTop = Color(0xFFFAF8F4);
const _bgBottom = Color(0xFFEFEAE1);
const _ink = Color(0xFF0E1712);
const _titleColor = Color(0xFF10201A);
const _bodyColor = Color(0xFF6B7280);
const _boldPhone = Color(0xFF10201A);
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

const int _initialSeconds = 60;

class OtpScreen extends StatefulWidget {
  final String phoneNumber;
  const OtpScreen({super.key, required this.phoneNumber});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen>
    with TickerProviderStateMixin {
  final List<TextEditingController> _controllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  int _secondsLeft = _initialSeconds;
  Timer? _timer;

  String? _otpError;
  bool _isVerifying = false;
  bool _isResending = false;

  late final AnimationController _introController;
  late final Animation<double> _introFade;
  late final Animation<Offset> _introSlide;

  late final AnimationController _bezelController;

  /// Raw 10-digit phone number extracted from the display string
  /// (e.g. "+91 9876543210" -> "9876543210"), for use in API calls.
  String get _rawPhone {
    final digits = widget.phoneNumber.replaceAll(RegExp(r'\D'), '');
    return digits.length > 10 ? digits.substring(digits.length - 10) : digits;
  }

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
        await ApiService.verifyMobOtpRegister(phone: _rawPhone, otp: otp)
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

  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsLeft = _initialSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_secondsLeft <= 0) {
        t.cancel();
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  Future<void> _resend() async {
    if (_isResending) return;

    setState(() => _isResending = true);

    final error = await ApiService.sendMobOtpRegister(phone: _rawPhone)
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

    for (var c in _controllers) c.clear();
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
    for (var c in _controllers) c.dispose();
    for (var f in _focusNodes) f.dispose();
    super.dispose();
  }

  String get _timerText {
    final m = _secondsLeft ~/ 60;
    final s = _secondsLeft % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final canResend = _secondsLeft == 0;

    return PopScope(
      // We intercept every pop attempt (system back gesture / hardware back
      // button included) so an incomplete or abandoned OTP flow can never be
      // mistaken for a verified mobile number by the registration screen.
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
                right: -80,
                child: _blurBlob(240, _primaryGreen.withOpacity(0.14)),
              ),
              Positioned(
                top: -30,
                left: -60,
                child: _blurBlob(150, _gold.withOpacity(0.10)),
              ),
              Positioned(
                bottom: -70,
                left: -90,
                child: _blurBlob(220, _emerald.withOpacity(0.12)),
              ),
              Positioned(
                bottom: 130,
                right: -60,
                child: _blurBlob(140, _gold.withOpacity(0.08)),
              ),

              SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Back arrow ───────────────────────────────────────────
                    Padding(
                      padding: EdgeInsets.fromLTRB(16.w, 12.h, 0.w, 0.h),
                      child: _GlassCircleButton(
                        icon: Icons.arrow_back_rounded,
                        // Explicit false: leaving via the back button must never
                        // be treated as a verified mobile number.
                        onTap: () => Navigator.pop(context, false),
                      ),
                    ),

                    // ── Content area ─────────────────────────────────────────
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(24.w, 4.h, 24.w, 0.h),
                        child: FadeTransition(
                          opacity: _introFade,
                          child: SlideTransition(
                            position: _introSlide,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(height: 6.h),

                                // ── Signature badge: rotating gold bezel ──────
                                Center(
                                  child: AnimatedBuilder(
                                    animation: _bezelController,
                                    builder: (context, _) {
                                      return _PremiumBadge(
                                        icon: Icons.phonelink_lock_rounded,
                                        rotation: _bezelController.value *
                                            2 *
                                            math.pi,
                                      );
                                    },
                                  ),
                                ),

                                SizedBox(height: 22.h),

                                Center(
                                  child: Text(
                                    'PHONE VERIFICATION',
                                    style: TextStyle(
                                      fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                                      fontSize: 11.sp,
                                      fontWeight: FontWeight.w700,
                                      color: _gold,
                                      letterSpacing: 3.2,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),

                                SizedBox(height: 10.h),

                                Center(
                                  child: Text(
                                    'Verify Your Number',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                                      fontSize: 26.sp,
                                      fontWeight: FontWeight.w800,
                                      color: _titleColor,
                                      letterSpacing: -0.4,
                                      height: 1.2,
                                    ),
                                  ),
                                ),

                                SizedBox(height: 10.h),

                                Center(
                                  child: Text(
                                    'A 6-digit code was sent to',
                                    style: TextStyle(
                                      fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.w400,
                                      color: _bodyColor,
                                      height: 1.5,
                                    ),
                                  ),
                                ),

                                SizedBox(height: 10.h),

                                // ── Phone chip ─────────────────────────────────
                                Center(
                                  child: Container(
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
                                          Icons.phone_iphone_rounded,
                                          size: 14.sp,
                                          color: _gold,
                                        ),
                                        SizedBox(width: 6.w),
                                        Text(
                                          widget.phoneNumber,
                                          style: TextStyle(
                                            fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                                            fontSize: 14.5.sp,
                                            fontWeight: FontWeight.w700,
                                            color: _boldPhone,
                                            height: 1.3,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                SizedBox(height: 30.h),

                                // ── Premium card holding the OTP field ────────
                                _OtpCard(
                                  child: Column(
                                    children: [
                                      // ── 6 OTP input boxes ─────────────────
                                      Row(
                                        children: [
                                          for (int i = 0; i < 6; i++) ...[
                                            Expanded(
                                              child: _OtpBox(
                                                controller: _controllers[i],
                                                focusNode: _focusNodes[i],
                                                hasError: _otpError != null,
                                                hasValue: _controllers[i]
                                                    .text
                                                    .isNotEmpty,
                                                onChanged: (val) {
                                                  if (_otpError != null) {
                                                    setState(
                                                      () => _otpError = null,
                                                    );
                                                  } else {
                                                    setState(() {});
                                                  }
                                                  if (val.length == 1 &&
                                                      i < 5) {
                                                    _focusNodes[i + 1]
                                                        .requestFocus();
                                                  } else if (val.isEmpty &&
                                                      i > 0) {
                                                    _focusNodes[i - 1]
                                                        .requestFocus();
                                                  }
                                                },
                                                onBackspace: () {
                                                  if (i > 0 &&
                                                      _controllers[i]
                                                          .text
                                                          .isEmpty) {
                                                    _controllers[i - 1]
                                                        .clear();
                                                    _focusNodes[i - 1]
                                                        .requestFocus();
                                                    setState(() {});
                                                  }
                                                },
                                              ),
                                            ),
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
                                        canResend: canResend,
                                        isResending: _isResending,
                                        timerLabel: _timerText,
                                        onTap: _resend,
                                      ),
                                    ],
                                  ),
                                ),

                                SizedBox(height: 20.h),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // ── Bottom: Verify button + security strip ────────────────
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        24.w,
                        8.h,
                        24.w,
                        mq.padding.bottom > 0 ? 12.h : 22.h,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _GradientButton(
                            label: 'Verify & Proceed',
                            loading: _isVerifying,
                            enabled: true,
                            onTap: _handleVerify,
                          ),
                          SizedBox(height: 16.h),
                          _TrustFooter(
                            text:
                                'Your data is secured by 256-bit AES encryption.',
                          ),
                        ],
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

// ── Frosted circular back button ───────────────────────────────────────────────
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
          width: 42.w,
          height: 42.h,
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
          child: Icon(icon, color: _titleColor, size: 20.sp),
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

// ── Circular countdown ring pairing the resend action ──────────────────────────
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
      onTap: (canResend && !isResending) ? onTap : null,
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
                                Icons.sms_rounded,
                                size: 14.sp,
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
                  isResending ? 'Sending…' : 'Resend via SMS',
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
                                  letterSpacing: 0.2,
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

// ── Trust / security footer chip ───────────────────────────────────────────────
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
          child: Icon(Icons.verified_user_rounded, size: 14.sp, color: _gold),
        ),
        SizedBox(width: 6.w),
        Flexible(
          child: Text(
            text,
            style: TextStyle(
              fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
              fontSize: 11.5.sp,
              color: _securityGrey,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

// ── Single OTP box ────────────────────────────────────────────────────────────
class _OtpBox extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onBackspace;
  final bool hasError;
  final bool hasValue;

  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onBackspace,
    this.hasError = false,
    this.hasValue = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 62.h,
      child: KeyboardListener(
        focusNode: FocusNode(skipTraversal: true),
        onKeyEvent: (event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.backspace &&
              controller.text.isEmpty) {
            onBackspace();
          }
        },
        child: AnimatedBuilder(
          animation: focusNode,
          builder: (context, child) {
            final isFocused = focusNode.hasFocus;
            return AnimatedContainer(
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
            );
          },
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            textAlignVertical: TextAlignVertical.center,
            maxLength: 1,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: TextStyle(
              fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
              fontSize: 22.sp,
              fontWeight: FontWeight.w700,
              color: _otpText,
            ),
            onChanged: onChanged,
            decoration: InputDecoration(
              counterText: '',
              filled: false,
              contentPadding: EdgeInsets.only(bottom: 6.h),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
            ),
          ),
        ),
      ),
    );
  }
}