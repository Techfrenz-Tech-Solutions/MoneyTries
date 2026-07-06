// lib/views/auth/reset_password_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../routes/app_routes.dart';
import '../../viewmodels/auth/forgot_password_viewmodel.dart';

// ── Palette (matches login_screen.dart) ────────────────────────────────────────
const _titleColor = Color(0xFF111827);
const _subtitleColor = Color(0xFF6B7280);
const _labelColor = Color(0xFF374151);
const _fieldFill = Color(0xFFEEF2FF);
const _fieldIconColor = Color(0xFF9CA3AF);
const _hintColor = Color(0xFF9CA3AF);
const _borderColorFocus = Color(0xFF4DAA75);
const _greenPrimary = Color(0xFF4DAA75);
const _errorRed = Color(0xFFDC2626);
const _bgColor = Color(0xFFECEFF5);

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
                          padding: const EdgeInsets.fromLTRB(12, 8, 0, 0),
                          child: IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(
                              Icons.arrow_back_rounded,
                              color: _titleColor,
                              size: 22,
                            ),
                            splashRadius: 22,
                          ),
                        ),
                      Expanded(
                        child: SingleChildScrollView(
                          physics: const ClampingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                          child: Consumer<ForgotPasswordViewModel>(
                            builder: (context, vm, _) {
                              final strength =
                                  _strengthScore(_newPasswordCtrl.text);
                              return Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 64,
                                    height: 64,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius:
                                          BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black
                                              .withOpacity(0.06),
                                          blurRadius: 12,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: const Center(
                                      child: Icon(
                                        Icons.password_rounded,
                                        size: 32,
                                        color: Color(0xFF3D9E6A),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 22),
                                  Text(
                                    'Create New Password',
                                    style: GoogleFonts.poppins(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800,
                                      color: _titleColor,
                                      letterSpacing: -0.4,
                                      height: 1.15,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Your new password must be different '
                                    'from previously used passwords.',
                                    style: GoogleFonts.poppins(
                                      fontSize: 13.5,
                                      color: _subtitleColor,
                                      height: 1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 28),

                                  Container(
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius:
                                          BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black
                                              .withOpacity(0.06),
                                          blurRadius: 20,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    padding: const EdgeInsets.fromLTRB(
                                      20,
                                      24,
                                      20,
                                      24,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (vm.errorMessage != null) ...[
                                          _ErrorBanner(
                                            message: vm.errorMessage!,
                                          ),
                                          const SizedBox(height: 16),
                                        ],

                                        Text(
                                          'New Password',
                                          style: GoogleFonts.poppins(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w500,
                                            color: _labelColor,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
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

                                        const SizedBox(height: 10),
                                        _StrengthMeter(score: strength),

                                        const SizedBox(height: 6),
                                        Text(
                                          'At least 8 characters, with letters and numbers.',
                                          style: GoogleFonts.poppins(
                                            fontSize: 11.5,
                                            color: _subtitleColor,
                                          ),
                                        ),

                                        const SizedBox(height: 18),

                                        Text(
                                          'Confirm Password',
                                          style: GoogleFonts.poppins(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w500,
                                            color: _labelColor,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
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

                                        const SizedBox(height: 24),

                                        SizedBox(
                                          width: double.infinity,
                                          height: 52,
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
                                                    BorderRadius.circular(
                                                  12,
                                                ),
                                              ),
                                            ),
                                            child: vm.isLoading
                                                ? const SizedBox(
                                                    width: 22,
                                                    height: 22,
                                                    child:
                                                        CircularProgressIndicator(
                                                      color: Colors.white,
                                                      strokeWidth: 2.5,
                                                    ),
                                                  )
                                                : Text(
                                                    'Update Password',
                                                    style:
                                                        GoogleFonts.poppins(
                                                      fontSize: 15,
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
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: const BoxDecoration(
                color: Color(0xFFE3F3EA),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                size: 52,
                color: _greenPrimary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Password Updated Successfully',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: _titleColor,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Your password has been changed. You can now log in '
              'with your new password.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13.5,
                color: _subtitleColor,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: onBackToLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _greenPrimary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Back to Login',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
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
    if (score == 0) return const SizedBox(height: 4);
    return Row(
      children: [
        Expanded(
          child: Row(
            children: List.generate(4, (i) {
              final filled = i < score;
              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: i == 3 ? 0 : 4),
                  height: 4,
                  decoration: BoxDecoration(
                    color: filled ? _color : const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          _label,
          style: GoogleFonts.poppins(
            fontSize: 11,
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5F5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _errorRed.withOpacity(0.3), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, size: 18, color: _errorRed),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.poppins(
                fontSize: 13,
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
      style: GoogleFonts.poppins(
        fontSize: 14.5,
        color: const Color(0xFF374151),
        letterSpacing: obscure ? 2.5 : 0,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.poppins(color: _hintColor, fontSize: 14.5),
        prefixIcon: const Padding(
          padding: EdgeInsets.only(left: 14, right: 10),
          child: Icon(
            Icons.lock_outline_rounded,
            size: 20,
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
            padding: const EdgeInsets.only(right: 14),
            child: Icon(
              obscure
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              size: 20,
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
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _borderColorFocus, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 15,
        ),
      ),
    );
  }
}