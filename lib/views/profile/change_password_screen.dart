// lib/views/profile/change_password_screen.dart
//
// Security Settings → Login Credentials → Change Password
//
// Flow:
//   1. ChangePasswordScreen  — user enters their CURRENT password. It's
//      verified against the backend (bcrypt). Wrong attempts are tracked
//      server-side; after 5 wrong attempts the feature locks for 5 minutes
//      with a live countdown.
//   2. SetNewPasswordScreen  — pushed only after a successful verification.
//      User enters a New Password + Confirm Password, submitted to the
//      backend which re-hashes it with bcrypt.
//
// The existing local "Change PIN" (app-lock PIN) flow is untouched — this
// is a separate feature covering the account's real login password.

import 'package:flutter/material.dart';
import 'package:moneytries/config/app_fonts.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/security/security_viewmodel.dart';
import '../../utils/responsive.dart';

// ── Palette (mirrors security_settings_view.dart) ──────────────────────────────
const _bgColor = Color(0xFFF7F5F2);
const _white = Color(0xFFFFFFFF);
const _titleDark = Color(0xFF111827);
const _subtitleGrey = Color(0xFF6B7280);
const _brandGreen = Color(0xFF4CAF7D);
const _accentGreen = Color(0xFF4CAF7D);
const _iconBg = Color(0xFFD4EDE0);
const _errorRed = Color(0xFFDC2626);
const _errorBg = Color(0xFFFFF5F5);
const _fieldBg = Color(0xFFFFFFFF);
const _fieldBorder = Color(0xFFD9D5CF);
const _fieldIconColor = Color(0xFF374151);
const _hintColor = Color(0xFFADB5BD);
const _inputTextColor = Color(0xFF374151);
const _amberBg = Color(0xFFFFFBEB);
const _amberBorder = Color(0xFFFDE68A);
const _amberText = Color(0xFFB45309);
const _lockRed = Color(0xFFDC2626);
const _lockRedBg = Color(0xFFFEF2F2);

// ══════════════════════════════════════════════════════════════════════════════
// ENTRY POINT — Step 1: verify current password
// ══════════════════════════════════════════════════════════════════════════════
class ChangePasswordScreen extends StatelessWidget {
  const ChangePasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SecurityViewModel()
        ..resetChangePasswordFlow()
        ..loadPasswordChangeStatus(),
      child: const _VerifyCurrentPasswordBody(),
    );
  }
}

class _VerifyCurrentPasswordBody extends StatefulWidget {
  const _VerifyCurrentPasswordBody();

  @override
  State<_VerifyCurrentPasswordBody> createState() =>
      _VerifyCurrentPasswordBodyState();
}

class _VerifyCurrentPasswordBodyState
    extends State<_VerifyCurrentPasswordBody> {
  final _currentCtrl = TextEditingController();
  bool _obscure = true;
  bool _navigated = false;

  @override
  void dispose() {
    _currentCtrl.dispose();
    super.dispose();
  }

  Future<void> _onContinue(SecurityViewModel vm) async {
    FocusScope.of(context).unfocus();
    final success = await vm.verifyCurrentPassword(_currentCtrl.text);
    if (success && mounted && !_navigated) {
      _navigated = true;
      final result = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => ChangeNotifierProvider.value(
            value: vm,
            child: const SetNewPasswordScreen(),
          ),
        ),
      );
      _navigated = false;
      if (result == true && mounted) {
        // Password was changed successfully — go straight back to Security
        // Settings instead of leaving the user on this "Enter Current
        // Password" screen (which would otherwise look like the flow
        // closed abruptly on Security Settings only after a second, extra
        // back tap).
        Navigator.of(context).pop();
        return;
      }
      // Coming back without success (e.g. user pressed back) — let them
      // re-verify from a clean slate rather than reusing a stale/expired
      // verification window.
      if (result != true && mounted) {
        vm.resetChangePasswordFlow();
        _currentCtrl.clear();
      }
    }
  }

  String _formatCountdown(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SecurityViewModel>();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _bgColor,
        appBar: AppBar(
          backgroundColor: _bgColor,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: _titleDark,
              size: 20.sp,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Change Password',
            style: TextStyle(fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
              fontSize: 17.sp,
              fontWeight: FontWeight.w700,
              color: _titleDark,
            ),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(20.w, 24.h, 20.w, 24.h),
            child: vm.isPasswordChangeLocked
                ? _LockedCard(
                    countdown: _formatCountdown(vm.passwordLockSecondsLeft),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 64.w,
                        height: 64.h,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: _iconBg,
                        ),
                        child: Icon(
                          Icons.password_rounded,
                          size: 30.sp,
                          color: _brandGreen,
                        ),
                      ),
                      SizedBox(height: 20.h),
                      Text(
                        'Enter Current Password',
                        style: TextStyle(fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                          fontSize: 21.sp,
                          fontWeight: FontWeight.w800,
                          color: _titleDark,
                          letterSpacing: -0.3,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        'For your security, confirm your current login '
                        'password before setting a new one.',
                        style: TextStyle(fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                          fontSize: 13.5.sp,
                          fontWeight: FontWeight.w400,
                          color: _subtitleGrey,
                          height: 1.5,
                        ),
                      ),
                      SizedBox(height: 28.h),
                      _PasswordField(
                        controller: _currentCtrl,
                        hint: 'Current password',
                        obscure: _obscure,
                        onToggle: () => setState(() => _obscure = !_obscure),
                        errorText: vm.changePasswordError,
                        onChanged: (_) {
                          if (vm.changePasswordError != null) {
                            vm.clearChangePasswordError();
                          }
                        },
                        onSubmitted: (_) => _onContinue(vm),
                      ),
                      if (!vm.isPasswordChangeLocked &&
                          vm.remainingPasswordAttempts <
                              SecurityViewModel.passwordChangeMaxAttempts) ...[
                        SizedBox(height: 10.h),
                        _AttemptsNotice(
                          remaining: vm.remainingPasswordAttempts,
                        ),
                      ],
                      SizedBox(height: 28.h),
                      SizedBox(
                        width: double.infinity,
                        height: 54.h,
                        child: ElevatedButton(
                          onPressed: vm.isVerifyingPassword
                              ? null
                              : () => _onContinue(vm),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _brandGreen,
                            disabledBackgroundColor:
                                _brandGreen.withOpacity(0.5),
                            foregroundColor: _white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30.r),
                            ),
                          ),
                          child: vm.isVerifyingPassword
                              ? SizedBox(
                                  width: 22.w,
                                  height: 22.h,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: _white,
                                  ),
                                )
                              : Text(
                                  'Continue',
                                  style: TextStyle(fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                                    fontSize: 15.sp,
                                    fontWeight: FontWeight.w700,
                                    color: _white,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

// ── Remaining attempts notice ───────────────────────────────────────────────
class _AttemptsNotice extends StatelessWidget {
  final int remaining;
  const _AttemptsNotice({required this.remaining});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: _amberBg,
        border: Border.all(color: _amberBorder, width: 1.r),
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, size: 16.sp, color: _amberText),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              remaining > 0
                  ? '$remaining attempt${remaining == 1 ? '' : 's'} remaining '
                        'before Change Password is temporarily locked.'
                  : 'Change Password will lock after the next incorrect attempt.',
              style: TextStyle(fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: _amberText,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Locked state card with live countdown ───────────────────────────────────
class _LockedCard extends StatelessWidget {
  final String countdown;
  const _LockedCard({required this.countdown});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(height: 24.h),
        Container(
          width: 76.w,
          height: 76.h,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: _lockRedBg,
          ),
          child: Icon(
            Icons.lock_clock_rounded,
            size: 36.sp,
            color: _lockRed,
          ),
        ),
        SizedBox(height: 22.h),
        Text(
          'Change Password Locked',
          style: TextStyle(fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
            fontSize: 20.sp,
            fontWeight: FontWeight.w800,
            color: _titleDark,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 8.h),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w),
          child: Text(
            'Too many incorrect attempts. For your account\'s security, '
            'please wait before trying again.',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
              fontSize: 13.5.sp,
              fontWeight: FontWeight.w400,
              color: _subtitleGrey,
              height: 1.5,
            ),
          ),
        ),
        SizedBox(height: 28.h),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 28.w, vertical: 16.h),
          decoration: BoxDecoration(
            color: _white,
            borderRadius: BorderRadius.circular(18.r),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Text(
                'Try again in',
                style: TextStyle(fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                  color: _subtitleGrey,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                countdown,
                style: TextStyle(fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                  fontSize: 34.sp,
                  fontWeight: FontWeight.w800,
                  color: _lockRed,
                  letterSpacing: 1.5,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// STEP 2 — Set new password
// ══════════════════════════════════════════════════════════════════════════════
class SetNewPasswordScreen extends StatefulWidget {
  const SetNewPasswordScreen({super.key});

  @override
  State<SetNewPasswordScreen> createState() => _SetNewPasswordScreenState();
}

class _SetNewPasswordScreenState extends State<SetNewPasswordScreen> {
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  bool get _hasMinLength => _newCtrl.text.length >= 8;
  bool get _hasLetterAndNumber =>
      RegExp(r'(?=.*[A-Za-z])(?=.*\d)').hasMatch(_newCtrl.text);

  Future<void> _onSubmit(SecurityViewModel vm) async {
    FocusScope.of(context).unfocus();
    await vm.submitNewPassword(
      newPassword: _newCtrl.text,
      confirmPassword: _confirmCtrl.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SecurityViewModel>();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.of(context).pop(vm.passwordChanged);
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: Scaffold(
          backgroundColor: _bgColor,
          appBar: AppBar(
            backgroundColor: _bgColor,
            elevation: 0,
            automaticallyImplyLeading: false,
            leading: vm.passwordChanged
                ? null
                : IconButton(
                    icon: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: _titleDark,
                      size: 20.sp,
                    ),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
            title: Text(
              'New Password',
              style: TextStyle(fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                fontSize: 17.sp,
                fontWeight: FontWeight.w700,
                color: _titleDark,
              ),
            ),
            centerTitle: true,
          ),
          body: SafeArea(
            child: vm.passwordChanged
                ? _SuccessView(
                    onDone: () => Navigator.of(context).pop(true),
                  )
                : SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(20.w, 24.h, 20.w, 24.h),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 64.w,
                          height: 64.h,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: _iconBg,
                          ),
                          child: Icon(
                            Icons.lock_reset_rounded,
                            size: 30.sp,
                            color: _brandGreen,
                          ),
                        ),
                        SizedBox(height: 20.h),
                        Text(
                          'Set a New Password',
                          style: TextStyle(fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                            fontSize: 21.sp,
                            fontWeight: FontWeight.w800,
                            color: _titleDark,
                            letterSpacing: -0.3,
                          ),
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          'Choose a strong password you haven\'t used before.',
                          style: TextStyle(fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                            fontSize: 13.5.sp,
                            fontWeight: FontWeight.w400,
                            color: _subtitleGrey,
                            height: 1.5,
                          ),
                        ),
                        SizedBox(height: 28.h),
                        _PasswordField(
                          controller: _newCtrl,
                          hint: 'New password',
                          obscure: _obscureNew,
                          onToggle: () =>
                              setState(() => _obscureNew = !_obscureNew),
                          onChanged: (_) {
                            if (vm.changePasswordError != null) {
                              vm.clearChangePasswordError();
                            }
                            setState(() {});
                          },
                        ),
                        SizedBox(height: 12.h),
                        _PasswordRequirement(
                          met: _hasMinLength,
                          label: 'At least 8 characters',
                        ),
                        SizedBox(height: 6.h),
                        _PasswordRequirement(
                          met: _hasLetterAndNumber,
                          label: 'Contains letters and numbers',
                        ),
                        SizedBox(height: 20.h),
                        _PasswordField(
                          controller: _confirmCtrl,
                          hint: 'Confirm new password',
                          obscure: _obscureConfirm,
                          onToggle: () => setState(
                            () => _obscureConfirm = !_obscureConfirm,
                          ),
                          errorText: vm.changePasswordError,
                          onChanged: (_) {
                            if (vm.changePasswordError != null) {
                              vm.clearChangePasswordError();
                            }
                          },
                          onSubmitted: (_) => _onSubmit(vm),
                        ),
                        SizedBox(height: 28.h),
                        SizedBox(
                          width: double.infinity,
                          height: 54.h,
                          child: ElevatedButton(
                            onPressed: vm.isUpdatingPassword
                                ? null
                                : () => _onSubmit(vm),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _brandGreen,
                              disabledBackgroundColor:
                                  _brandGreen.withOpacity(0.5),
                              foregroundColor: _white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30.r),
                              ),
                            ),
                            child: vm.isUpdatingPassword
                                ? SizedBox(
                                    width: 22.w,
                                    height: 22.h,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: _white,
                                    ),
                                  )
                                : Text(
                                    'Update Password',
                                    style: TextStyle(fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                                      fontSize: 15.sp,
                                      fontWeight: FontWeight.w700,
                                      color: _white,
                                    ),
                                  ),
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

// ── Password requirement checklist row ───────────────────────────────────────
class _PasswordRequirement extends StatelessWidget {
  final bool met;
  final String label;
  const _PasswordRequirement({required this.met, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          met ? Icons.check_circle_rounded : Icons.circle_outlined,
          size: 15.sp,
          color: met ? _accentGreen : _subtitleGrey.withOpacity(0.6),
        ),
        SizedBox(width: 8.w),
        Text(
          label,
          style: TextStyle(fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
            fontSize: 12.3.sp,
            fontWeight: FontWeight.w500,
            color: met ? _accentGreen : _subtitleGrey,
          ),
        ),
      ],
    );
  }
}

// ── Success view ──────────────────────────────────────────────────────────────
class _SuccessView extends StatelessWidget {
  final VoidCallback onDone;
  const _SuccessView({required this.onDone});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 28.w),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 84.w,
            height: 84.h,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: _iconBg,
            ),
            child: Icon(
              Icons.check_circle_rounded,
              size: 46.sp,
              color: _brandGreen,
            ),
          ),
          SizedBox(height: 24.h),
          Text(
            'Password Changed',
            style: TextStyle(fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
              fontSize: 21.sp,
              fontWeight: FontWeight.w800,
              color: _titleDark,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'Your login password was updated successfully. '
            'Use your new password the next time you sign in.',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
              fontSize: 13.5.sp,
              fontWeight: FontWeight.w400,
              color: _subtitleGrey,
              height: 1.5,
            ),
          ),
          SizedBox(height: 32.h),
          SizedBox(
            width: double.infinity,
            height: 54.h,
            child: ElevatedButton(
              onPressed: onDone,
              style: ElevatedButton.styleFrom(
                backgroundColor: _brandGreen,
                foregroundColor: _white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30.r),
                ),
              ),
              child: Text(
                'Done',
                style: TextStyle(fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w700,
                  color: _white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SHARED — premium password text field
// ══════════════════════════════════════════════════════════════════════════════
class _PasswordField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final VoidCallback onToggle;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  const _PasswordField({
    required this.controller,
    required this.hint,
    required this.obscure,
    required this.onToggle,
    this.errorText,
    this.onChanged,
    this.onSubmitted,
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
          onSubmitted: onSubmitted,
          textInputAction: TextInputAction.next,
          style: TextStyle(fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
            fontSize: 14.5.sp,
            color: _inputTextColor,
            letterSpacing: obscure ? 2.0 : 0,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
              color: _hintColor,
              fontSize: 14.5.sp,
              fontWeight: FontWeight.w400,
            ),
            prefixIcon: Padding(
              padding: EdgeInsets.only(left: 14.w, right: 10.w),
              child: Icon(
                Icons.lock_outline_rounded,
                size: 20.sp,
                color: hasError ? _errorRed : _fieldIconColor,
              ),
            ),
            prefixIconConstraints:
                const BoxConstraints(minWidth: 46, minHeight: 46),
            suffixIcon: GestureDetector(
              onTap: onToggle,
              child: Padding(
                padding: EdgeInsets.only(right: 14.w),
                child: Icon(
                  obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 20.sp,
                  color: _fieldIconColor,
                ),
              ),
            ),
            suffixIconConstraints:
                const BoxConstraints(minWidth: 0, minHeight: 0),
            filled: true,
            fillColor: hasError ? _errorBg : _fieldBg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide(color: _fieldBorder, width: 1.r),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: hasError
                  ? BorderSide(color: _errorRed, width: 1.5.r)
                  : BorderSide(color: _fieldBorder, width: 1.r),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide(
                color: hasError ? _errorRed : _accentGreen,
                width: 1.5.r,
              ),
            ),
            contentPadding:
                EdgeInsets.symmetric(horizontal: 14.w, vertical: 15.h),
          ),
        ),
        if (hasError) ...[
          SizedBox(height: 6.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.error_outline_rounded,
                  size: 13.sp, color: _errorRed),
              SizedBox(width: 5.w),
              Expanded(
                child: Text(
                  errorText!,
                  style: TextStyle(fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                    color: _errorRed,
                    height: 1.4,
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