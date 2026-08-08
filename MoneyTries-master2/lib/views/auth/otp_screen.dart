import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../routes/app_routes.dart';
import '../../services/api_service.dart';
import '../../utils/responsive.dart';

// ── Premium palette (Moneytries brand green) ──────────────────────────────────
const _bgTop = Color(0xFFF7F5F2);
const _bgBottom = Color(0xFFF0EDE7);
const _deepInk = Color(0xFFF7F5F2);
const _titleColor = Color(0xFF111827);
const _bodyColor = Color(0xFF6B7280);
const _boldPhone = Color(0xFF111827);
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

class OtpScreen extends StatefulWidget {
  final String phoneNumber;
  const OtpScreen({super.key, required this.phoneNumber});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen>
    with SingleTickerProviderStateMixin {
  final List<TextEditingController> _controllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  int _secondsLeft = 60;
  Timer? _timer;

  String? _otpError;
  bool _isVerifying = false;
  bool _isResending = false;

  late final AnimationController _introController;
  late final Animation<double> _introFade;
  late final Animation<Offset> _introSlide;

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
    setState(() => _secondsLeft = 60);
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
                right: -70,
                child: _blurBlob(220, _primaryGreen.withOpacity(0.14)),
              ),
              Positioned(
                bottom: -60,
                left: -80,
                child: _blurBlob(200, _emerald.withOpacity(0.12)),
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
                        padding: EdgeInsets.fromLTRB(24.w, 8.h, 24.w, 0.h),
                        child: FadeTransition(
                          opacity: _introFade,
                          child: SlideTransition(
                            position: _introSlide,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(height: 12.h),

                                // ── Signature badge: layered glow shield ──────
                                Center(
                                  child: _PremiumBadge(
                                    icon: Icons.phonelink_lock_rounded,
                                  ),
                                ),

                                SizedBox(height: 28.h),

                                Center(
                                  child: Text(
                                    'Verify Your Number',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontFamily: 'Times New Roman',
                                      fontSize: 25.sp,
                                      fontWeight: FontWeight.w800,
                                      color: _titleColor,
                                      letterSpacing: -0.4,
                                      height: 1.15,
                                    ),
                                  ),
                                ),

                                SizedBox(height: 10.h),

                                Center(
                                  child: RichText(
                                    textAlign: TextAlign.center,
                                    text: TextSpan(
                                      style: TextStyle(
                                        fontFamily: 'Times New Roman',
                                        fontSize: 14.sp,
                                        color: _bodyColor,
                                        height: 1.55,
                                      ),
                                      children: [
                                        const TextSpan(
                                          text: 'A 6-digit code was sent to\n',
                                        ),
                                        TextSpan(
                                          text: widget.phoneNumber,
                                          style: TextStyle(
                                            fontFamily: 'Times New Roman',
                                            fontSize: 14.5.sp,
                                            fontWeight: FontWeight.w700,
                                            color: _boldPhone,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                SizedBox(height: 30.h),

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
                                      // ── 6 OTP input boxes ─────────────────
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: List.generate(
                                          6,
                                          (i) => _OtpBox(
                                            controller: _controllers[i],
                                            focusNode: _focusNodes[i],
                                            hasError: _otpError != null,
                                            onChanged: (val) {
                                              if (_otpError != null)
                                                setState(
                                                  () => _otpError = null,
                                                );
                                              if (val.length == 1 && i < 5) {
                                                _focusNodes[i + 1]
                                                    .requestFocus();
                                              } else if (val.isEmpty && i > 0) {
                                                _focusNodes[i - 1]
                                                    .requestFocus();
                                              }
                                            },
                                            onBackspace: () {
                                              if (i > 0 &&
                                                  _controllers[i]
                                                      .text
                                                      .isEmpty) {
                                                _controllers[i - 1].clear();
                                                _focusNodes[i - 1]
                                                    .requestFocus();
                                              }
                                            },
                                          ),
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

                                      // ── Timer chip ─────────────────────────
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 14.w,
                                          vertical: 8.h,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _bgTop,
                                          borderRadius: BorderRadius.circular(
                                            30.r,
                                          ),
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
                                              color: canResend
                                                  ? _primaryGreen
                                                  : _timerGrey,
                                            ),
                                            SizedBox(width: 6.w),
                                            Text(
                                              canResend
                                                  ? 'Code expired'
                                                  : 'Resend in ',
                                              style: TextStyle(
                                                fontFamily: 'Times New Roman',
                                                fontSize: 12.5.sp,
                                                color: _timerGrey,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            if (!canResend)
                                              Text(
                                                _timerText,
                                                style: TextStyle(
                                                  fontFamily: 'Times New Roman',
                                                  fontSize: 12.5.sp,
                                                  fontWeight: FontWeight.w700,
                                                  color: _primaryGreen,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),

                                      SizedBox(height: 14.h),

                                      GestureDetector(
                                        onTap: (canResend && !_isResending)
                                            ? _resend
                                            : null,
                                        child: _isResending
                                            ? SizedBox(
                                                width: 16.w,
                                                height: 16.h,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: _primaryGreen,
                                                    ),
                                              )
                                            : Text(
                                                'Resend via SMS',
                                                style: TextStyle(
                                                  fontFamily: 'Times New Roman',
                                                  fontSize: 13.5.sp,
                                                  fontWeight: FontWeight.w700,
                                                  color: canResend
                                                      ? _primaryGreen
                                                      : _primaryGreen
                                                            .withOpacity(0.35),
                                                ),
                                              ),
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
                        24,
                        8,
                        24,
                        mq.padding.bottom > 0 ? 12 : 22,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _GradientButton(
                            label: 'Verify & Proceed',
                            loading: _isVerifying,
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
                color: _deepInk.withOpacity(0.05),
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
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            fontFamily: 'Times New Roman',
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
      children: [
        Icon(Icons.verified_user_rounded, size: 14.sp, color: _primaryGreen),
        SizedBox(width: 6.w),
        Flexible(
          child: Text(
            text,
            style: TextStyle(
              fontFamily: 'Times New Roman',
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

  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onBackspace,
    this.hasError = false,
  });

  @override
  Widget build(BuildContext context) {
    final boxWidth = (MediaQuery.of(context).size.width - 48 - 40 - 40) / 6;

    return SizedBox(
      width: boxWidth,
      height: boxWidth * 1.2,
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
            controller: controller,
            focusNode: focusNode,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 1,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: TextStyle(
              fontFamily: 'Times New Roman',
              fontSize: 20.sp,
              fontWeight: FontWeight.w700,
              color: _otpText,
            ),
            onChanged: onChanged,
            decoration: InputDecoration(
              counterText: '',
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
      ),
    );
  }
}
