// lib/views/auth/forgot_login_pin_screen.dart
//
// Login PIN → Forgot PIN? (email or SMS OTP recovery)
//
// Reached from AppPinScreen ("Enter your PIN") when the user taps
// "Forgot PIN?". Flow:
//   0. ForgotLoginPinScreen opens on a method-choice step: "Send OTP to
//      Email" / "Send OTP via SMS". No OTP is sent until the user picks
//      one (skipped straight to step 1 if a lock/cooldown is resumed from
//      a previous attempt, so the countdown keeps behaving correctly).
//   1. Picking a method sends a fresh OTP on that channel and shows the
//      OTP verification step. Underneath "Resend OTP" there's a link to
//      switch to the *other* channel — "Send OTP via SMS" while on email,
//      "Send OTP to Email" while on SMS — which generates and sends a new
//      OTP on that channel. Either way the user enters the 6-digit code;
//      it's verified against the backend, with expiry, resend cooldown,
//      and a 5-attempt lockout all enforced server-side and shared across
//      both channels and both directions of switching (see
//      SecurityViewModel.sendForgotLoginPinOtp / verifyForgotLoginPinOtp).
//   2. On success, this pushes the existing SetNewLoginPinScreen (from
//      change_login_pin_screen.dart) unchanged — a verified Forgot-PIN OTP
//      opens the very same backend "verified window" that the regular
//      Change Login PIN flow opens, so "Set New PIN" / "Confirm New PIN"
//      and the update call are reused as-is.
//   3. Once the new PIN is saved, both screens pop back to AppPinScreen,
//      which the user must now unlock with the newly created PIN.
//
// Palette matches the sibling PIN screens in this folder
// (app_pin_screen.dart / security_pin_screen.dart).

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:moneytries/config/app_fonts.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/security/security_viewmodel.dart';
import '../profile/change_login_pin_screen.dart' show SetNewLoginPinScreen;
import '../../utils/responsive.dart';

// ── Palette (matches app_pin_screen.dart / security_pin_screen.dart) ───────
const _bg = Color(0xFFF7F5F2);
const _brandGreen = Color(0xFF4CAF7D);
const _deepEmerald = Color(0xFF1F5C3F);
const _titleColor = Color(0xFF111827);
const _subtitleColor = Color(0xFF6B7280);
const _cardBorder = Color(0xFFE9E4DA);
const _otpIdleBorder = Color(0xFFD9D5CF);
const _otpFocusBorder = Color(0xFF4CAF7D);
const _otpFill = Color(0xFFFFFFFF);
const _otpText = Color(0xFF111827);
const _boldIdentifier = Color(0xFF111827);
const _timerGrey = Color(0xFF6B7280);
const _errorRed = Color(0xFFDC2626);
const _errorBg = Color(0xFFFDF3F3);
const _disabledBg = Color(0xFFF3F1EC);
const _disabledText = Color(0xFF9CA3AF);

/// Which step of the Forgot PIN flow is on screen.
enum _ForgotPinStep {
  /// "How would you like to receive your OTP?" — shown first, before any
  /// OTP has been sent.
  choice,

  /// The 6-digit OTP entry screen for whichever channel was chosen.
  otp,
}

class ForgotLoginPinScreen extends StatelessWidget {
  const ForgotLoginPinScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SecurityViewModel()..resetForgotLoginPinFlow(),
      child: const _ForgotLoginPinBody(),
    );
  }
}

class _ForgotLoginPinBody extends StatefulWidget {
  const _ForgotLoginPinBody();

  @override
  State<_ForgotLoginPinBody> createState() => _ForgotLoginPinBodyState();
}

class _ForgotLoginPinBodyState extends State<_ForgotLoginPinBody> {
  final List<TextEditingController> _controllers = List.generate(
    SecurityViewModel.forgotPinOtpLength,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(
    SecurityViewModel.forgotPinOtpLength,
    (_) => FocusNode(),
  );

  bool _navigated = false;
  _ForgotPinStep _step = _ForgotPinStep.choice;
  bool _statusLoaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    final vm = context.read<SecurityViewModel>();
    await vm.loadForgotLoginPinStatus();
    if (!mounted) return;
    setState(() {
      _statusLoaded = true;
      // If a lock or an in-flight resend cooldown was resumed from a
      // previous attempt (e.g. the app was backgrounded mid-flow), skip
      // straight to the OTP step for the channel that's already active
      // instead of asking the user to choose again.
      _step = (vm.isForgotPinLocked || !vm.canResendForgotPinOtp)
          ? _ForgotPinStep.otp
          : _ForgotPinStep.choice;
    });
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _clearBoxes() {
    for (final c in _controllers) {
      c.clear();
    }
    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) _focusNodes[0].requestFocus();
    });
  }

  /// Called when the user picks a delivery method on the choice step.
  /// Sends the first OTP for that channel and, on success (or if the
  /// account turns out to be locked), advances to the OTP step.
  Future<void> _selectChannel(SecurityViewModel vm, String channel) async {
    final success = channel == 'sms'
        ? await vm.sendForgotLoginPinOtpViaSms()
        : await vm.sendForgotLoginPinOtpViaEmail();
    if (!mounted) return;
    if (success || vm.isForgotPinLocked) {
      _clearBoxes();
      setState(() => _step = _ForgotPinStep.otp);
    }
    // On any other failure (e.g. no phone/email on file), stay on the
    // choice step — vm.forgotPinError is surfaced there.
  }

  /// Switches the OTP step to the other channel, generating and sending a
  /// fresh OTP on it (same expiry/cooldown/attempt rules apply).
  Future<void> _switchChannel(SecurityViewModel vm, String channel) async {
    final success = channel == 'sms'
        ? await vm.sendForgotLoginPinOtpViaSms()
        : await vm.sendForgotLoginPinOtpViaEmail();
    if (!mounted) return;
    if (success) _clearBoxes();
  }

  /// Back arrow on the OTP step: returns to the method-choice step (unless
  /// the account is currently locked, in which case there's nothing to
  /// choose, so it exits the flow entirely).
  void _handleOtpBack(SecurityViewModel vm) {
    if (vm.isForgotPinLocked) {
      Navigator.of(context).maybePop();
      return;
    }
    vm.clearForgotPinOtpInput();
    _clearBoxes();
    setState(() => _step = _ForgotPinStep.choice);
  }

  Future<void> _handleVerify(SecurityViewModel vm) async {
    FocusScope.of(context).unfocus();
    final success = await vm.verifyForgotLoginPinOtp();
    if (!mounted) return;

    if (!success) {
      _clearBoxes();
      return;
    }
    if (_navigated) return;
    _navigated = true;

    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: vm,
          child: const SetNewLoginPinScreen(),
        ),
      ),
    );
    _navigated = false;
    if (!mounted) return;

    if (result == true) {
      // New PIN saved — pop back to AppPinScreen; the user re-enters the
      // new PIN there to continue into the app.
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SecurityViewModel>();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Theme(
        data: ThemeData(brightness: Brightness.light, scaffoldBackgroundColor: _bg),
        child: Scaffold(
          backgroundColor: _bg,
          body: SafeArea(
            child: !_statusLoaded
                ? const Center(child: CircularProgressIndicator(color: _brandGreen))
                : (_step == _ForgotPinStep.choice
                    ? _buildChoiceStep(context, vm)
                    : _buildOtpStep(context, vm)),
          ),
        ),
      ),
    );
  }

  // ── Step 0: method choice ─────────────────────────────────────────────
  Widget _buildChoiceStep(BuildContext context, SecurityViewModel vm) {
    final sending = vm.isSendingForgotPinOtp;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(12.w, 12.h, 0.w, 0.h),
          child: IconButton(
            onPressed: sending ? null : () => Navigator.of(context).maybePop(),
            icon: Icon(Icons.arrow_back_rounded, color: _titleColor, size: 22.sp),
            splashRadius: 22,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(24.w, 12.h, 24.w, 24.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 64.w,
                  height: 64.h,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [_brandGreen, _deepEmerald],
                    ),
                    borderRadius: BorderRadius.circular(16.r),
                    boxShadow: [
                      BoxShadow(
                        color: _deepEmerald.withOpacity(0.25),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(Icons.lock_reset_rounded, size: 30.sp, color: Colors.white),
                  ),
                ),
                SizedBox(height: 22.h),
                Text(
                  'Forgot PIN?',
                  style: TextStyle(
                    fontFamily: AppFonts.primary,
                    fontFamilyFallback: AppFonts.fallbacks,
                    fontSize: 25.sp,
                    fontWeight: FontWeight.w800,
                    color: _titleColor,
                    letterSpacing: -0.4,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  'Choose how you\u2019d like to receive your verification code',
                  style: TextStyle(
                    fontFamily: AppFonts.primary,
                    fontFamilyFallback: AppFonts.fallbacks,
                    fontSize: 14.sp,
                    color: _subtitleColor,
                    height: 1.45,
                  ),
                ),
                SizedBox(height: 28.h),

                _ChoiceOption(
                  icon: Icons.mail_outline_rounded,
                  title: 'Send OTP to Email',
                  subtitle: vm.forgotPinEmailMasked ?? 'No email on file',
                  enabled: !sending && vm.forgotPinEmailMasked != null,
                  loading: sending && !vm.isSendingForgotPinSmsOtp,
                  onTap: () => _selectChannel(vm, 'email'),
                ),
                SizedBox(height: 14.h),
                _ChoiceOption(
                  icon: Icons.sms_outlined,
                  title: 'Send OTP via SMS',
                  subtitle: vm.forgotPinPhoneMasked ?? 'No mobile number on file',
                  enabled: !sending && vm.forgotPinSmsAvailable,
                  loading: vm.isSendingForgotPinSmsOtp,
                  onTap: () => _selectChannel(vm, 'sms'),
                ),

                if (vm.forgotPinError != null) ...[
                  SizedBox(height: 18.h),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                    decoration: BoxDecoration(
                      color: _errorBg,
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline_rounded, size: 14.sp, color: _errorRed),
                        SizedBox(width: 6.w),
                        Expanded(
                          child: Text(
                            vm.forgotPinError!,
                            style: TextStyle(
                              fontFamily: AppFonts.primary,
                              fontFamilyFallback: AppFonts.fallbacks,
                              fontSize: 12.sp,
                              color: _errorRed,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Step 1: OTP entry ────────────────────────────────────────────────
  Widget _buildOtpStep(BuildContext context, SecurityViewModel vm) {
    final canResend = vm.canResendForgotPinOtp && !vm.isForgotPinLocked;
    final otherChannelIsSms = !vm.isForgotPinChannelSms && vm.forgotPinSmsAvailable;
    final otherChannelIsEmail = vm.isForgotPinChannelSms && vm.forgotPinEmailMasked != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(12.w, 12.h, 0.w, 0.h),
          child: IconButton(
            onPressed: () => _handleOtpBack(vm),
            icon: Icon(Icons.arrow_back_rounded, color: _titleColor, size: 22.sp),
            splashRadius: 22,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ),

        Expanded(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(24.w, 12.h, 24.w, 24.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 64.w,
                  height: 64.h,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [_brandGreen, _deepEmerald],
                    ),
                    borderRadius: BorderRadius.circular(16.r),
                    boxShadow: [
                      BoxShadow(
                        color: _deepEmerald.withOpacity(0.25),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      vm.isForgotPinChannelSms
                          ? Icons.sms_outlined
                          : Icons.mark_email_read_rounded,
                      size: 30.sp,
                      color: Colors.white,
                    ),
                  ),
                ),

                SizedBox(height: 22.h),

                Text(
                  'Forgot PIN?',
                  style: TextStyle(
                    fontFamily: AppFonts.primary,
                    fontFamilyFallback: AppFonts.fallbacks,
                    fontSize: 25.sp,
                    fontWeight: FontWeight.w800,
                    color: _titleColor,
                    letterSpacing: -0.4,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  vm.isForgotPinChannelSms
                      ? 'Enter the 6-digit code sent to your registered mobile number'
                      : 'Enter the 6-digit code sent to your registered email',
                  style: TextStyle(
                    fontFamily: AppFonts.primary,
                    fontFamilyFallback: AppFonts.fallbacks,
                    fontSize: 14.sp,
                    color: _subtitleColor,
                    height: 1.45,
                  ),
                ),

                if ((vm.isForgotPinChannelSms
                        ? vm.forgotPinPhoneMasked
                        : vm.forgotPinEmailMasked) !=
                    null) ...[
                  SizedBox(height: 10.h),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30.r),
                      border: Border.all(color: _cardBorder, width: 1.r),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          vm.isForgotPinChannelSms
                              ? Icons.sms_outlined
                              : Icons.mail_outline_rounded,
                          size: 14.sp,
                          color: _brandGreen,
                        ),
                        SizedBox(width: 6.w),
                        Text(
                          (vm.isForgotPinChannelSms
                              ? vm.forgotPinPhoneMasked
                              : vm.forgotPinEmailMasked)!,
                          style: TextStyle(
                            fontFamily: AppFonts.primary,
                            fontFamilyFallback: AppFonts.fallbacks,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w700,
                            color: _boldIdentifier,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                SizedBox(height: 30.h),

                if (vm.isForgotPinLocked)
                  _LockedNotice(secondsLeft: vm.forgotPinLockSecondsLeft)
                else ...[
                  Row(
                    children: [
                      for (int i = 0; i < SecurityViewModel.forgotPinOtpLength; i++) ...[
                        Expanded(
                          child: _OtpBox(
                            controller: _controllers[i],
                            focusNode: _focusNodes[i],
                            hasError: vm.forgotPinError != null,
                            onChanged: (val) {
                              if (val.length == 1 && i < SecurityViewModel.forgotPinOtpLength - 1) {
                                _focusNodes[i + 1].requestFocus();
                              } else if (val.isEmpty && i > 0) {
                                _focusNodes[i - 1].requestFocus();
                              }
                              final joined = _controllers.map((c) => c.text).join();
                              vm.forgotPinOtpChanged(joined);
                              if (joined.length == SecurityViewModel.forgotPinOtpLength) {
                                _handleVerify(vm);
                              }
                            },
                            onBackspace: () {
                              if (i > 0 && _controllers[i].text.isEmpty) {
                                _controllers[i - 1].clear();
                                _focusNodes[i - 1].requestFocus();
                                final joined = _controllers.map((c) => c.text).join();
                                vm.forgotPinOtpChanged(joined);
                              }
                            },
                          ),
                        ),
                        if (i != SecurityViewModel.forgotPinOtpLength - 1) SizedBox(width: 8.w),
                      ],
                    ],
                  ),

                  if (vm.forgotPinError != null) ...[
                    SizedBox(height: 12.h),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                      decoration: BoxDecoration(
                        color: _errorBg,
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline_rounded, size: 13.sp, color: _errorRed),
                          SizedBox(width: 4.w),
                          Flexible(
                            child: Text(
                              vm.forgotPinError!,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: AppFonts.primary,
                                fontFamilyFallback: AppFonts.fallbacks,
                                fontSize: 11.5.sp,
                                color: _errorRed,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  SizedBox(height: 24.h),

                  Center(
                    child: (vm.isSendingForgotPinOtp && !vm.isSendingForgotPinSmsOtp)
                        ? SizedBox(
                            width: 18.w,
                            height: 18.h,
                            child: CircularProgressIndicator(strokeWidth: 2, color: _brandGreen),
                          )
                        : GestureDetector(
                            onTap: canResend ? () => vm.sendForgotLoginPinOtp() : null,
                            child: Text(
                              canResend
                                  ? 'Resend OTP'
                                  : 'Resend OTP in ${vm.forgotPinResendCooldownLeft}s',
                              style: TextStyle(
                                fontFamily: AppFonts.primary,
                                fontFamilyFallback: AppFonts.fallbacks,
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w700,
                                color: canResend ? _deepEmerald : _timerGrey,
                              ),
                            ),
                          ),
                  ),

                  // Switch-channel link under "Resend OTP":
                  //   • on the email OTP screen → "Send OTP via SMS"
                  //   • on the SMS OTP screen   → "Send OTP to Email"
                  // Sends a brand-new OTP on the other channel, sharing the
                  // same expiry/cooldown/attempt-limit/lockout rules
                  // (enforced server-side), so it's gated by the same
                  // canResend / isForgotPinLocked state.
                  if (otherChannelIsSms || otherChannelIsEmail) ...[
                    SizedBox(height: 14.h),
                    Center(
                      child: vm.isSendingForgotPinOtp
                          ? SizedBox(
                              width: 18.w,
                              height: 18.h,
                              child: CircularProgressIndicator(strokeWidth: 2, color: _brandGreen),
                            )
                          : GestureDetector(
                              onTap: canResend
                                  ? () => _switchChannel(
                                      vm, otherChannelIsSms ? 'sms' : 'email')
                                  : null,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    otherChannelIsSms
                                        ? Icons.sms_outlined
                                        : Icons.mail_outline_rounded,
                                    size: 15.sp,
                                    color: canResend ? _deepEmerald : _timerGrey,
                                  ),
                                  SizedBox(width: 6.w),
                                  Text(
                                    otherChannelIsSms
                                        ? 'Send OTP via SMS'
                                        : 'Send OTP to Email',
                                    style: TextStyle(
                                      fontFamily: AppFonts.primary,
                                      fontFamilyFallback: AppFonts.fallbacks,
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.w700,
                                      color: canResend ? _deepEmerald : _timerGrey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),

        if (!vm.isForgotPinLocked)
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 20.h),
            child: SizedBox(
              width: double.infinity,
              height: 54.h,
              child: ElevatedButton(
                onPressed: vm.isVerifyingForgotPinOtp ? null : () => _handleVerify(vm),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _brandGreen,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                ),
                child: vm.isVerifyingForgotPinOtp
                    ? SizedBox(
                        width: 22.w,
                        height: 22.h,
                        child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Verify & Continue',
                            style: TextStyle(
                              fontFamily: AppFonts.primary,
                              fontFamilyFallback: AppFonts.fallbacks,
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              letterSpacing: 0.2,
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Icon(Icons.arrow_forward_rounded, size: 18.sp, color: Colors.white),
                        ],
                      ),
              ),
            ),
          ),
      ],
    );
  }
}

/// One tappable delivery-method card on the method-choice step.
class _ChoiceOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool enabled;
  final bool loading;
  final VoidCallback onTap;

  const _ChoiceOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(16.r),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
          decoration: BoxDecoration(
            color: enabled ? Colors.white : _disabledBg,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: _cardBorder, width: 1.r),
          ),
          child: Row(
            children: [
              Container(
                width: 42.w,
                height: 42.h,
                decoration: BoxDecoration(
                  color: enabled ? _brandGreen.withOpacity(0.12) : _disabledText.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Icon(
                  icon,
                  size: 20.sp,
                  color: enabled ? _deepEmerald : _disabledText,
                ),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: AppFonts.primary,
                        fontFamilyFallback: AppFonts.fallbacks,
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w700,
                        color: enabled ? _titleColor : _disabledText,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontFamily: AppFonts.primary,
                        fontFamilyFallback: AppFonts.fallbacks,
                        fontSize: 12.5.sp,
                        color: enabled ? _subtitleColor : _disabledText,
                      ),
                    ),
                  ],
                ),
              ),
              if (loading)
                SizedBox(
                  width: 18.w,
                  height: 18.h,
                  child: CircularProgressIndicator(strokeWidth: 2, color: _brandGreen),
                )
              else
                Icon(
                  Icons.chevron_right_rounded,
                  size: 22.sp,
                  color: enabled ? _subtitleColor : _disabledText,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LockedNotice extends StatelessWidget {
  final int secondsLeft;
  const _LockedNotice({required this.secondsLeft});

  @override
  Widget build(BuildContext context) {
    final m = (secondsLeft ~/ 60).toString().padLeft(2, '0');
    final s = (secondsLeft % 60).toString().padLeft(2, '0');
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 20.h),
      decoration: BoxDecoration(
        color: _errorBg,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFF3D2D2), width: 1.r),
      ),
      child: Column(
        children: [
          Icon(Icons.lock_clock_rounded, size: 26.sp, color: _errorRed),
          SizedBox(height: 10.h),
          Text(
            'Too many incorrect attempts',
            style: TextStyle(
              fontFamily: AppFonts.primary,
              fontFamilyFallback: AppFonts.fallbacks,
              fontSize: 14.5.sp,
              fontWeight: FontWeight.w700,
              color: _errorRed,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            'Try again in $m:$s',
            style: TextStyle(
              fontFamily: AppFonts.primary,
              fontFamilyFallback: AppFonts.fallbacks,
              fontSize: 13.sp,
              color: _subtitleColor,
            ),
          ),
        ],
      ),
    );
  }
}

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
            fontSize: 20.sp,
            fontWeight: FontWeight.w700,
            color: _otpText,
          ),
          onChanged: onChanged,
          decoration: InputDecoration(
            counterText: '',
            filled: true,
            fillColor: hasError ? _errorBg : _otpFill,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10.r),
              borderSide: BorderSide(color: hasError ? _errorRed : _otpIdleBorder, width: 1.5.r),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10.r),
              borderSide: BorderSide(color: hasError ? _errorRed : _otpIdleBorder, width: 1.5.r),
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