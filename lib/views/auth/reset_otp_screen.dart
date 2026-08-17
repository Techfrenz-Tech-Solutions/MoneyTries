// lib/views/auth/reset_otp_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:moneytries/config/app_fonts.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../viewmodels/auth/forgot_password_viewmodel.dart';
import 'reset_password_screen.dart';
import '../../utils/responsive.dart';

// ── Luxury palette (matches otp_screen.dart / Moneytries brand) ────────────
const _bgTop = Color(0xFFFAF8F4);
const _bgBottom = Color(0xFFEFEAE1);
const _ink = Color(0xFF0E1712);
const _titleColor = Color(0xFF10201A);
const _bodyColor = Color(0xFF44504A);
const _boldIdentifier = Color(0xFF10201A);
const _cardBorder = Color(0xFFE6D8C1);
const _otpIdleBorder = Color(0xFFD9CFB8);
const _otpFocusGold = Color(0xFFB8935A);
const _otpFill = Color(0xFFFFFFFF);
const _otpText = Color(0xFF10231A);
const _primaryGreen = Color(0xFF3FA873);
const _deepEmerald = Color(0xFF1F5C3F);
const _gold = Color(0xFFB8935A);
const _goldLight = Color(0xFFE7CDA0);
const _timerText = Color(0xFF3B4A43);
const _timerGreen = Color(0xFF1F5C3F);
const _securityText = Color(0xFF52605A);
const _securityIcon = Color(0xFF3FA873);
const _errorRed = Color(0xFFDC2626);
const _errorBg = Color(0xFFFDF3F3);

class ResetOtpScreen extends StatefulWidget {
  const ResetOtpScreen({super.key});

  @override
  State<ResetOtpScreen> createState() => _ResetOtpScreenState();
}

class _ResetOtpScreenState extends State<ResetOtpScreen> {
  final List<TextEditingController> _controllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  int _secondsLeft = 300; // 5 minutes, matches backend OTP expiry
  Timer? _timer;
  bool _isResending = false;

  @override
  void initState() {
    super.initState();
    // Sync the visible countdown to whatever expiry the backend returned
    // (defaults to 300s == 5 minutes if not provided).
    final vm = context.read<ForgotPasswordViewModel>();
    _startTimer(initialSeconds: vm.otpExpirySeconds);
  }

  void _startTimer({required int initialSeconds}) {
    _timer?.cancel();
    setState(() => _secondsLeft = initialSeconds);
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

  String get _timerLabel {
    final m = _secondsLeft ~/ 60;
    final s = _secondsLeft % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _handleVerify() async {
    FocusScope.of(context).unfocus();
    final otp = _controllers.map((c) => c.text).join();
    final vm = context.read<ForgotPasswordViewModel>();

    final success = await vm.verifyOtp(otp);
    if (!mounted || !success) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: vm,
          child: const ResetPasswordScreen(),
        ),
      ),
    );
  }

  Future<void> _resend() async {
    if (_isResending) return;
    setState(() => _isResending = true);

    final vm = context.read<ForgotPasswordViewModel>();
    final success = await vm.resendOtp();

    if (!mounted) return;
    setState(() => _isResending = false);

    if (!success) return;

    for (var c in _controllers) {
      c.clear();
    }
    _startTimer(initialSeconds: vm.otpExpirySeconds);
    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) _focusNodes[0].requestFocus();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var c in _controllers) {
      c.dispose();
    }
    for (var f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final vm = context.watch<ForgotPasswordViewModel>();
    final canResend = _secondsLeft == 0;
    final identifier = vm.identifier ?? '';

    return Theme(
      data: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: _bgTop,
      ),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [_bgTop, _bgBottom],
              ),
            ),
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Back arrow ─────────────────────────────────────────
                  Padding(
                    padding: EdgeInsets.fromLTRB(12.w, 12.h, 0.w, 0.h),
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.arrow_back_rounded,
                        color: _titleColor,
                        size: 22.sp,
                      ),
                      splashRadius: 22,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ),

                  Expanded(
                    child: SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(24.w, 12.h, 24.w, 0.h),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Gold-ringed icon badge ────────────────────
                          Container(
                            width: 68.w,
                            height: 68.h,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [_primaryGreen, _deepEmerald],
                              ),
                              borderRadius: BorderRadius.circular(18.r),
                              boxShadow: [
                                BoxShadow(
                                  color: _deepEmerald.withOpacity(0.28),
                                  blurRadius: 18,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Icon(
                                Icons.mark_email_read_rounded,
                                size: 32.sp,
                                color: Colors.white,
                              ),
                            ),
                          ),

                          SizedBox(height: 24.h),

                          Text(
                            'Verify OTP',
                            style: TextStyle(
                              fontFamily: AppFonts.primary,
                              fontFamilyFallback: AppFonts.fallbacks,
                              fontSize: 26.sp,
                              fontWeight: FontWeight.w800,
                              color: _titleColor,
                              letterSpacing: -0.4,
                              height: 1.15,
                            ),
                          ),

                          SizedBox(height: 8.h),

                          Text(
                            'Enter the 6-digit code sent to',
                            style: TextStyle(
                              fontFamily: AppFonts.primary,
                              fontFamilyFallback: AppFonts.fallbacks,
                              fontSize: 14.sp,
                              color: _bodyColor,
                              height: 1.4,
                            ),
                          ),

                          SizedBox(height: 10.h),

                          // ── Identifier chip ──────────────────────────
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 14.w,
                              vertical: 8.h,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(30.r),
                              border: Border.all(color: _cardBorder, width: 1.r),
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
                                  Icons.mail_outline_rounded,
                                  size: 14.sp,
                                  color: _gold,
                                ),
                                SizedBox(width: 6.w),
                                Flexible(
                                  child: Text(
                                    identifier,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontFamily: AppFonts.primary,
                                      fontFamilyFallback: AppFonts.fallbacks,
                                      fontSize: 14.5.sp,
                                      fontWeight: FontWeight.w700,
                                      color: _boldIdentifier,
                                      height: 1.3,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          SizedBox(height: 30.h),

                          // ── Premium card holding the OTP field ───────
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.fromLTRB(18.w, 22.h, 18.w, 22.h),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20.r),
                              border: Border.all(color: _cardBorder, width: 1.r),
                              boxShadow: [
                                BoxShadow(
                                  color: _ink.withOpacity(0.05),
                                  blurRadius: 24,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                // ── 6 OTP input boxes ──────────────────
                                Row(
                                  children: [
                                    for (int i = 0; i < 6; i++) ...[
                                      Expanded(
                                        child: _OtpBox(
                                          controller: _controllers[i],
                                          focusNode: _focusNodes[i],
                                          hasError: vm.errorMessage != null,
                                          onChanged: (val) {
                                            if (vm.errorMessage != null) {
                                              vm.clearError();
                                            }
                                            setState(() {});
                                            if (val.length == 1 && i < 5) {
                                              _focusNodes[i + 1].requestFocus();
                                            } else if (val.isEmpty && i > 0) {
                                              _focusNodes[i - 1].requestFocus();
                                            }
                                          },
                                          onBackspace: () {
                                            if (i > 0 &&
                                                _controllers[i].text.isEmpty) {
                                              _controllers[i - 1].clear();
                                              _focusNodes[i - 1].requestFocus();
                                              setState(() {});
                                            }
                                          },
                                        ),
                                      ),
                                      if (i != 5) SizedBox(width: 8.w),
                                    ],
                                  ],
                                ),

                                if (vm.errorMessage != null) ...[
                                  SizedBox(height: 14.h),
                                  Container(
                                    width: double.infinity,
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 12.w,
                                      vertical: 8.h,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _errorBg,
                                      borderRadius: BorderRadius.circular(10.r),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.error_outline_rounded,
                                          size: 13.sp,
                                          color: _errorRed,
                                        ),
                                        SizedBox(width: 4.w),
                                        Flexible(
                                          child: Text(
                                            vm.errorMessage!,
                                            style: TextStyle(
                                              fontFamily: AppFonts.primary,
                                              fontFamilyFallback:
                                                  AppFonts.fallbacks,
                                              fontSize: 11.5.sp,
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

                                // ── Resend timer ─────────────────────
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.access_time_rounded,
                                      size: 14.sp,
                                      color: canResend
                                          ? _errorRed
                                          : _timerText,
                                    ),
                                    SizedBox(width: 5.w),
                                    Text(
                                      canResend
                                          ? 'OTP expired.'
                                          : 'OTP expires in ',
                                      style: TextStyle(
                                        fontFamily: AppFonts.primary,
                                        fontFamilyFallback:
                                            AppFonts.fallbacks,
                                        fontSize: 13.sp,
                                        fontWeight: FontWeight.w500,
                                        color: canResend
                                            ? _errorRed
                                            : _timerText,
                                      ),
                                    ),
                                    if (!canResend)
                                      Text(
                                        _timerLabel,
                                        style: TextStyle(
                                          fontFamily: AppFonts.primary,
                                          fontFamilyFallback:
                                              AppFonts.fallbacks,
                                          fontSize: 13.sp,
                                          fontWeight: FontWeight.w800,
                                          color: _timerGreen,
                                        ),
                                      ),
                                  ],
                                ),

                                SizedBox(height: 12.h),

                                GestureDetector(
                                  onTap: (canResend && !_isResending)
                                      ? _resend
                                      : null,
                                  child: _isResending
                                      ? SizedBox(
                                          width: 16.w,
                                          height: 16.h,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: _deepEmerald,
                                          ),
                                        )
                                      : Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 14.w,
                                            vertical: 6.h,
                                          ),
                                          decoration: BoxDecoration(
                                            color: canResend
                                                ? _primaryGreen
                                                    .withOpacity(0.10)
                                                : Colors.transparent,
                                            borderRadius:
                                                BorderRadius.circular(20.r),
                                          ),
                                          child: Text(
                                            'Resend OTP',
                                            style: TextStyle(
                                              fontFamily: AppFonts.primary,
                                              fontFamilyFallback:
                                                  AppFonts.fallbacks,
                                              fontSize: 14.sp,
                                              fontWeight: FontWeight.w700,
                                              color: canResend
                                                  ? _deepEmerald
                                                  : _bodyColor
                                                      .withOpacity(0.55),
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

                  // ── Bottom: Verify button + security strip ──────────
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      12,
                      16,
                      mq.padding.bottom > 0 ? 8 : 20,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: double.infinity,
                          height: 56.h,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14.r),
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [_primaryGreen, _deepEmerald],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: _deepEmerald.withOpacity(0.30),
                                  blurRadius: 18,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14.r),
                                onTap: vm.isLoading ? null : _handleVerify,
                                child: Center(
                                  child: vm.isLoading
                                      ? SizedBox(
                                          width: 22.w,
                                          height: 22.h,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.4,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              'Verify & Proceed',
                                              style: TextStyle(
                                                fontFamily: AppFonts.primary,
                                                fontFamilyFallback:
                                                    AppFonts.fallbacks,
                                                fontSize: 16.sp,
                                                fontWeight: FontWeight.w700,
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
                        ),

                        SizedBox(height: 16.h),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.shield_outlined,
                              size: 15.sp,
                              color: _securityIcon,
                            ),
                            SizedBox(width: 6.w),
                            Flexible(
                              child: Text(
                                'This OTP is valid for 5 minutes and can be used only once.',
                                style: TextStyle(
                                  fontFamily: AppFonts.primary,
                                  fontFamilyFallback: AppFonts.fallbacks,
                                  fontSize: 11.5.sp,
                                  fontWeight: FontWeight.w500,
                                  color: _securityText,
                                  height: 1.4,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
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

// ── Single OTP box ───────────────────────────────────────────────────────
class _OtpBox extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool hasError;
  final ValueChanged<String> onChanged;
  final VoidCallback onBackspace;

  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.hasError,
    required this.onChanged,
    required this.onBackspace,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 0.82,
      child: KeyboardListener(
        focusNode: FocusNode(skipTraversal: true),
        onKeyEvent: (event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.backspace &&
              controller.text.isEmpty) {
            onBackspace();
          }
        },
        child: ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) {
            final hasValue = value.text.isNotEmpty;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              decoration: BoxDecoration(
                color: hasError ? _errorBg : const Color(0xFFF7F5EF),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(
                  color: hasError
                      ? _errorRed
                      : (focusNode.hasFocus || hasValue)
                          ? _otpFocusGold
                          : _otpIdleBorder,
                  width: (focusNode.hasFocus || hasValue) ? 2.r : 1.4.r,
                ),
                boxShadow: (focusNode.hasFocus)
                    ? [
                        BoxShadow(
                          color: _otpFocusGold.withOpacity(0.18),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : [],
              ),
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 1,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: TextStyle(
                  fontFamily: AppFonts.primary,
                  fontFamilyFallback: AppFonts.fallbacks,
                  fontSize: 21.sp,
                  fontWeight: FontWeight.w800,
                  color: _otpText,
                ),
                onChanged: onChanged,
                decoration: const InputDecoration(
                  counterText: '',
                  filled: true,
                  fillColor: Colors.transparent,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}