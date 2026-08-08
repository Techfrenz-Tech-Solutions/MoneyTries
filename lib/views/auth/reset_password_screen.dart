// lib/views/auth/reset_password_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../routes/app_routes.dart';
import '../../viewmodels/auth/forgot_password_viewmodel.dart';
import '../../utils/responsive.dart';

// ── Palette (matches login_screen.dart) ────────────────────────────────────────
const _titleColor = Color(0xFF111827);
const _subtitleColor = Color(0xFF6B7280);
const _labelColor = Color(0xFF374151);
const _fieldFill = Color(0xFFF0FAF4);
const _fieldIconColor = Color(0xFF9CA3AF);
const _hintColor = Color(0xFF9CA3AF);
const _borderColorFocus = Color(0xFF4CAF7D);
const _greenPrimary = Color(0xFF4CAF7D);
const _errorRed = Color(0xFFDC2626);
const _bgColor = Color(0xFFF7F5F2);

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _newPasswordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _updated = false;

  @override
  void dispose() {
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleReset() async {
    FocusScope.of(context).unfocus();
    final vm = context.read<ForgotPasswordViewModel>();

    final success = await vm.resetPassword(
      newPassword: _newPasswordCtrl.text,
      confirmPassword: _confirmPasswordCtrl.text,
    );

    if (!mounted || !success) return;
    setState(() => _updated = true);
  }

  void _backToLogin() {
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.login,
      (route) => false,
    );
  }

  // Simple visual strength meter driven by the same rule the backend
  // enforces (min 8 chars, letters + numbers) plus a bonus for length/case
  // mix, purely for user feedback — validation itself happens in the vm.
  int _strengthScore(String value) {
    if (value.isEmpty) return 0;
    int score = 0;
    if (value.length >= 8) score++;
    if (value.length >= 12) score++;
    if (RegExp(r'[A-Z]').hasMatch(value) && RegExp(r'[a-z]').hasMatch(value)) {
      score++;
    }
    if (RegExp(r'\d').hasMatch(value)) score++;
    if (RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-]').hasMatch(value)) score++;
    return score.clamp(0, 4);
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData(brightness: Brightness.light, scaffoldBackgroundColor: _bgColor),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: Scaffold(
          backgroundColor: _bgColor,
          body: SafeArea(
            child: _updated
                ? _SuccessView(onBackToLogin: _backToLogin)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (Navigator.of(context).canPop())
                        Padding(
                          padding: EdgeInsets.fromLTRB(12.w, 8.h, 0.w, 0.h),
                          child: IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: Icon(
                              Icons.arrow_back_rounded,
                              color: _titleColor,
                              size: 22.sp,
                            ),
                            splashRadius: 22,
                          ),
                        ),
                      Expanded(
                        child: SingleChildScrollView(
                          physics: const ClampingScrollPhysics(),
                          padding: EdgeInsets.fromLTRB(24.w, 8.h, 24.w, 24.h),
                          child: Consumer<ForgotPasswordViewModel>(
                            builder: (context, vm, _) {
                              final strength =
                                  _strengthScore(_newPasswordCtrl.text);
                              return Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 64.w,
                                    height: 64.h,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius:
                                          BorderRadius.circular(16.r),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black
                                              .withOpacity(0.06),
                                          blurRadius: 12,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Center(
                                      child: Icon(
                                        Icons.password_rounded,
                                        size: 32.sp,
                                        color: Color(0xFF4CAF7D),
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: 22.h),
                                  Text(
                                    'Create New Password',
                                    style: TextStyle(fontFamily: 'Times New Roman',
                                      fontSize: 24.sp,
                                      fontWeight: FontWeight.w800,
                                      color: _titleColor,
                                      letterSpacing: -0.4,
                                      height: 1.15,
                                    ),
                                  ),
                                  SizedBox(height: 8.h),
                                  Text(
                                    'Your new password must be different '
                                    'from previously used passwords.',
                                    style: TextStyle(fontFamily: 'Times New Roman',
                                      fontSize: 13.5.sp,
                                      color: _subtitleColor,
                                      height: 1.5,
                                    ),
                                  ),
                                  SizedBox(height: 28.h),

                                  Container(
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius:
                                          BorderRadius.circular(20.r),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black
                                              .withOpacity(0.06),
                                          blurRadius: 20,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    padding: EdgeInsets.fromLTRB(20.w, 24.h, 20.w, 24.h),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (vm.errorMessage != null) ...[
                                          _ErrorBanner(
                                            message: vm.errorMessage!,
                                          ),
                                          SizedBox(height: 16.h),
                                        ],

                                        Text(
                                          'New Password',
                                          style: TextStyle(fontFamily: 'Times New Roman',
                                            fontSize: 12.5.sp,
                                            fontWeight: FontWeight.w500,
                                            color: _labelColor,
                                          ),
                                        ),
                                        SizedBox(height: 8.h),
                                        _PasswordField(
                                          controller: _newPasswordCtrl,
                                          hint: 'Enter new password',
                                          obscure: _obscureNew,
                                          onToggle: () => setState(
                                            () => _obscureNew = !_obscureNew,
                                          ),
                                          onChanged: (_) {
                                            vm.clearError();
                                            setState(() {});
                                          },
                                        ),

                                        SizedBox(height: 10.h),
                                        _StrengthMeter(score: strength),

                                        SizedBox(height: 6.h),
                                        Text(
                                          'At least 8 characters, with letters and numbers.',
                                          style: TextStyle(fontFamily: 'Times New Roman',
                                            fontSize: 11.5.sp,
                                            color: _subtitleColor,
                                          ),
                                        ),

                                        SizedBox(height: 18.h),

                                        Text(
                                          'Confirm Password',
                                          style: TextStyle(fontFamily: 'Times New Roman',
                                            fontSize: 12.5.sp,
                                            fontWeight: FontWeight.w500,
                                            color: _labelColor,
                                          ),
                                        ),
                                        SizedBox(height: 8.h),
                                        _PasswordField(
                                          controller: _confirmPasswordCtrl,
                                          hint: 'Re-enter new password',
                                          obscure: _obscureConfirm,
                                          onToggle: () => setState(
                                            () => _obscureConfirm =
                                                !_obscureConfirm,
                                          ),
                                          onChanged: (_) => vm.clearError(),
                                        ),

                                        SizedBox(height: 24.h),

                                        SizedBox(
                                          width: double.infinity,
                                          height: 52.h,
                                          child: ElevatedButton(
                                            onPressed: vm.isLoading
                                                ? null
                                                : _handleReset,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  _greenPrimary,
                                              disabledBackgroundColor:
                                                  _greenPrimary
                                                      .withOpacity(0.7),
                                              foregroundColor: Colors.white,
                                              elevation: 0,
                                              shadowColor:
                                                  Colors.transparent,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12.r),
                                              ),
                                            ),
                                            child: vm.isLoading
                                                ? SizedBox(
                                                    width: 22.w,
                                                    height: 22.h,
                                                    child:
                                                        CircularProgressIndicator(
                                                      color: Colors.white,
                                                      strokeWidth: 2.5,
                                                    ),
                                                  )
                                                : Text(
                                                    'Update Password',
                                                    style:
                                                        TextStyle(fontFamily: 'Times New Roman',
                                                      fontSize: 15.sp,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            },
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

// ─────────────────────────────────────────────────────────────────────────────
// Success view — "Password Updated"
// ─────────────────────────────────────────────────────────────────────────────
class _SuccessView extends StatelessWidget {
  final VoidCallback onBackToLogin;
  const _SuccessView({required this.onBackToLogin});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88.w,
              height: 88.h,
              decoration: const BoxDecoration(
                color: Color(0xFFE8F5EE),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle_rounded,
                size: 52.sp,
                color: _greenPrimary,
              ),
            ),
            SizedBox(height: 24.h),
            Text(
              'Password Updated Successfully',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Times New Roman',
                fontSize: 20.sp,
                fontWeight: FontWeight.w800,
                color: _titleColor,
                height: 1.25,
              ),
            ),
            SizedBox(height: 10.h),
            Text(
              'Your password has been changed. You can now log in '
              'with your new password.',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Times New Roman',
                fontSize: 13.5.sp,
                color: _subtitleColor,
                height: 1.5,
              ),
            ),
            SizedBox(height: 32.h),
            SizedBox(
              width: double.infinity,
              height: 52.h,
              child: ElevatedButton(
                onPressed: onBackToLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _greenPrimary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                child: Text(
                  'Back to Login',
                  style: TextStyle(fontFamily: 'Times New Roman',
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Password strength meter
// ─────────────────────────────────────────────────────────────────────────────
class _StrengthMeter extends StatelessWidget {
  final int score; // 0-4
  const _StrengthMeter({required this.score});

  Color get _color {
    switch (score) {
      case 0:
      case 1:
        return _errorRed;
      case 2:
        return const Color(0xFFF59E0B);
      case 3:
        return const Color(0xFF3B82F6);
      default:
        return _greenPrimary;
    }
  }

  String get _label {
    switch (score) {
      case 0:
        return '';
      case 1:
        return 'Weak';
      case 2:
        return 'Fair';
      case 3:
        return 'Good';
      default:
        return 'Strong';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (score == 0) return SizedBox(height: 4.h);
    return Row(
      children: [
        Expanded(
          child: Row(
            children: List.generate(4, (i) {
              final filled = i < score;
              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: i == 3 ? 0 : 4),
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: filled ? _color : const Color(0xFFE8E4DE),
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              );
            }),
          ),
        ),
        SizedBox(width: 10.w),
        Text(
          _label,
          style: TextStyle(fontFamily: 'Times New Roman',
            fontSize: 11.sp,
            fontWeight: FontWeight.w600,
            color: _color,
          ),
        ),
      ],
    );
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
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5F5),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: _errorRed.withOpacity(0.3), width: 1.r),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, size: 18.sp, color: _errorRed),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontFamily: 'Times New Roman',
                fontSize: 13.sp,
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
// Password Field
// ─────────────────────────────────────────────────────────────────────────────
class _PasswordField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final VoidCallback onToggle;
  final ValueChanged<String>? onChanged;

  const _PasswordField({
    required this.controller,
    required this.hint,
    required this.obscure,
    required this.onToggle,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      obscuringCharacter: '●',
      onChanged: onChanged,
      style: TextStyle(fontFamily: 'Times New Roman',
        fontSize: 14.5.sp,
        color: const Color(0xFF374151),
        letterSpacing: obscure ? 2.5 : 0,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(fontFamily: 'Times New Roman',color: _hintColor, fontSize: 14.5.sp),
        prefixIcon: Padding(
          padding: EdgeInsets.only(left: 14.w, right: 10.w),
          child: Icon(
            Icons.lock_outline_rounded,
            size: 20.sp,
            color: _fieldIconColor,
          ),
        ),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 44,
          minHeight: 44,
        ),
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
        suffixIconConstraints: const BoxConstraints(
          minWidth: 44,
          minHeight: 44,
        ),
        filled: true,
        fillColor: _fieldFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.r),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.r),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.r),
          borderSide: BorderSide(color: _borderColorFocus, width: 1.5.r),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 14.w,
          vertical: 15.h,
        ),
      ),
    );
  }
}