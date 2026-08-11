// lib/views/auth/login_two_factor_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../routes/app_routes.dart';
import '../../viewmodels/auth/login_viewmodel.dart';
import '../../utils/responsive.dart';

// ── Palette (matches reset_otp_screen.dart / otp_screen.dart) ─────────────────
const _bgColor = Color(0xFFF7F5F2);
const _titleColor = Color(0xFF111827);
const _bodyColor = Color(0xFF374151);
const _boldIdentifier = Color(0xFF111827);
const _otpBorder = Color(0xFFD9D5CF);
const _otpFocusBorder = Color(0xFF4CAF7D);
const _otpFill = Color(0xFFFFFFFF);
const _otpText = Color(0xFF111827);
const _mintSquare = Color(0xFF4CAF7D);
const _greenBtn = Color(0xFF4CAF7D);
const _greenLink = Color(0xFF4CAF7D);
const _timerGreen = Color(0xFF4CAF7D);
const _timerGrey = Color(0xFF6B7280);
const _securityGrey = Color(0xFF9CA3AF);
const _securityIcon = Color(0xFF4CAF7D);
const _errorRed = Color(0xFFDC2626);

/// Login-time Two-Factor Authentication step: "Enter OTP to Verify Your
/// Login". Shown only when [LoginViewModel.login] determined the account
/// has 2FA enabled — the identifier + password have already been verified
/// by the backend, an OTP has already been sent to the registered mobile
/// number, and this screen's only job is to verify that OTP before the
/// existing PIN → Home flow is allowed to continue.
class LoginTwoFactorScreen extends StatefulWidget {
  const LoginTwoFactorScreen({super.key});

  @override
  State<LoginTwoFactorScreen> createState() => _LoginTwoFactorScreenState();
}

class _LoginTwoFactorScreenState extends State<LoginTwoFactorScreen> {
  final List<TextEditingController> _controllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  int _secondsLeft = 300; // 5 minutes, matches backend OTP expiry
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    final vm = context.read<LoginViewModel>();
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

  String get _timerText {
    final m = _secondsLeft ~/ 60;
    final s = _secondsLeft % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _handleVerify() async {
    FocusScope.of(context).unfocus();
    final otp = _controllers.map((c) => c.text).join();
    final vm = context.read<LoginViewModel>();

    final destination = await vm.verifyLoginOtp(otp);
    if (!mounted || destination == null) return;

    if (destination == 'set_password') {
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.setPassword,
        (route) => false,
      );
    } else if (destination == 'app_pin') {
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.appPin,
        (route) => false,
      );
    } else {
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.home,
        (route) => false,
      );
    }
  }

  Future<void> _resend() async {
    final vm = context.read<LoginViewModel>();
    if (vm.isResendingOtp) return;

    final success = await vm.resendLoginOtp();
    if (!mounted || !success) return;

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
    final vm = context.watch<LoginViewModel>();
    final canResend = _secondsLeft == 0;
    final phoneHint = vm.phoneHint ?? 'your registered mobile number';

    return PopScope(
      // Stepping back to the password screen must never leave a stale
      // pending-token session half-verified — force a fresh login attempt.
      canPop: true,
      child: Theme(
        data: ThemeData(
          brightness: Brightness.light,
          scaffoldBackgroundColor: _bgColor,
        ),
        child: AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.dark,
          child: Scaffold(
            backgroundColor: _bgColor,
            body: SafeArea(
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
                      padding: EdgeInsets.fromLTRB(24.w, 20.h, 24.w, 0.h),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Mint icon badge ─────────────────────────────
                          Container(
                            width: 64.w,
                            height: 64.h,
                            decoration: BoxDecoration(
                              color: _mintSquare,
                              borderRadius: BorderRadius.circular(16.r),
                            ),
                            child: Center(
                              child: Icon(
                                Icons.verified_user_rounded,
                                size: 32.sp,
                                color: Color(0xFF4CAF7D),
                              ),
                            ),
                          ),

                          SizedBox(height: 24.h),

                          Text(
                            'Enter OTP to Verify Your Login',
                            style: TextStyle(fontFamily: GoogleFonts.inter().fontFamily,
                              fontSize: 24.sp,
                              fontWeight: FontWeight.w800,
                              color: _titleColor,
                              letterSpacing: -0.4,
                              height: 1.2,
                            ),
                          ),

                          SizedBox(height: 8.h),

                          RichText(
                            text: TextSpan(
                              style: TextStyle(fontFamily: GoogleFonts.inter().fontFamily,
                                fontSize: 14.sp,
                                color: _bodyColor,
                                height: 1.55,
                              ),
                              children: [
                                const TextSpan(
                                  text: 'Two-Factor Authentication is on '
                                      'for this account. Enter the 6-digit '
                                      'code sent to ',
                                ),
                                TextSpan(
                                  text: phoneHint,
                                  style: TextStyle(fontFamily: GoogleFonts.inter().fontFamily,
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w700,
                                    color: _boldIdentifier,
                                  ),
                                ),
                                const TextSpan(text: ' to continue.'),
                              ],
                            ),
                          ),

                          SizedBox(height: 32.h),

                          // ── 6 OTP input boxes ───────────────────────────
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: List.generate(
                              6,
                              (i) => _OtpBox(
                                controller: _controllers[i],
                                focusNode: _focusNodes[i],
                                hasError: vm.otpErrorMessage != null,
                                onChanged: (val) {
                                  if (vm.otpErrorMessage != null) {
                                    vm.clearOtpError();
                                  }
                                  if (val.length == 1 && i < 5) {
                                    _focusNodes[i + 1].requestFocus();
                                  } else if (val.isEmpty && i > 0) {
                                    _focusNodes[i - 1].requestFocus();
                                  }
                                },
                                onBackspace: () {
                                  if (i > 0 && _controllers[i].text.isEmpty) {
                                    _controllers[i - 1].clear();
                                    _focusNodes[i - 1].requestFocus();
                                  }
                                },
                              ),
                            ),
                          ),

                          if (vm.otpErrorMessage != null) ...[
                            SizedBox(height: 10.h),
                            Row(
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
                                    vm.otpErrorMessage!,
                                    style: TextStyle(fontFamily: GoogleFonts.inter().fontFamily,
                                      fontSize: 11.5.sp,
                                      color: _errorRed,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],

                          SizedBox(height: 28.h),

                          // ── Resend timer ─────────────────────────────────
                          Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.access_time_rounded,
                                  size: 14.sp,
                                  color: _timerGrey,
                                ),
                                SizedBox(width: 5.w),
                                Text(
                                  canResend
                                      ? 'OTP expired. '
                                      : 'OTP expires in ',
                                  style: TextStyle(fontFamily: GoogleFonts.inter().fontFamily,
                                    fontSize: 13.sp,
                                    color: _timerGrey,
                                  ),
                                ),
                                if (!canResend)
                                  Text(
                                    _timerText,
                                    style: TextStyle(fontFamily: GoogleFonts.inter().fontFamily,
                                      fontSize: 13.sp,
                                      fontWeight: FontWeight.w700,
                                      color: _timerGreen,
                                    ),
                                  ),
                              ],
                            ),
                          ),

                          SizedBox(height: 10.h),

                          Center(
                            child: GestureDetector(
                              onTap: (canResend && !vm.isResendingOtp)
                                  ? _resend
                                  : null,
                              child: vm.isResendingOtp
                                  ? SizedBox(
                                      width: 16.w,
                                      height: 16.h,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: _greenLink,
                                      ),
                                    )
                                  : Text(
                                      'Resend OTP',
                                      style: TextStyle(fontFamily: GoogleFonts.inter().fontFamily,
                                        fontSize: 14.sp,
                                        fontWeight: FontWeight.w600,
                                        color: canResend
                                            ? _greenLink
                                            : _greenLink.withOpacity(0.4),
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Bottom: Verify button + security strip ──────────────
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
                          height: 54.h,
                          child: ElevatedButton(
                            onPressed:
                                vm.isVerifyingOtp ? null : _handleVerify,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _greenBtn,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                            ),
                            child: vm.isVerifyingOtp
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
                                        'Verify & Continue',
                                        style: TextStyle(fontFamily: GoogleFonts.inter().fontFamily,
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

                        SizedBox(height: 14.h),

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
                                'This OTP is valid for 5 minutes and can be '
                                'used only once.',
                                style: TextStyle(fontFamily: GoogleFonts.inter().fontFamily,
                                  fontSize: 11.5.sp,
                                  color: _securityGrey,
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
    final boxWidth = (MediaQuery.of(context).size.width - 48 - 40) / 6;

    return SizedBox(
      width: boxWidth,
      height: boxWidth * 1.15,
      child: KeyboardListener(
        focusNode: FocusNode(skipTraversal: true),
        onKeyEvent: (event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.backspace &&
              controller.text.isEmpty) {
            onBackspace();
          }
        },
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 1,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: TextStyle(fontFamily: GoogleFonts.inter().fontFamily,
            fontSize: 20.sp,
            fontWeight: FontWeight.w700,
            color: _otpText,
          ),
          onChanged: onChanged,
          decoration: InputDecoration(
            counterText: '',
            filled: true,
            fillColor: _otpFill,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10.r),
              borderSide: BorderSide(
                color: hasError ? _errorRed.withOpacity(0.5) : _otpBorder,
                width: 1.5.r,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10.r),
              borderSide: BorderSide(
                color: hasError ? _errorRed.withOpacity(0.5) : _otpBorder,
                width: 1.5.r,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10.r),
              borderSide: BorderSide(color: _otpFocusBorder, width: 2.r),
            ),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ),
    );
  }
}