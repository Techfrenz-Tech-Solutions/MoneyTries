// lib/views/auth/register_screen.dart

import 'package:flutter/material.dart';
import 'package:moneytries/config/app_fonts.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';

import '../../routes/app_routes.dart';
import '../../viewmodels/auth/register_viewmodel.dart';
import 'otp_screen.dart';
import 'email_otp_screen.dart';
import '../../utils/responsive.dart';
import '../legal/legal_document_screen.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _bgColor        = Color(0xFFF7F5F2);
const _cardBg         = Color(0xFFFFFFFF);
const _titleColor     = Color(0xFF111827);
const _subtitleColor  = Color(0xFF6B7280);
const _labelColor     = Color(0xFF6B7280);
const _fieldBg        = Color(0xFFFFFFFF);
const _fieldBorder    = Color(0xFFD9D5CF);
const _fieldIconColor = Color(0xFF374151);
const _hintColor      = Color(0xFFADB5BD);
const _inputTextColor = Color(0xFF374151);
const _greenPrimary   = Color(0xFF4CAF7D);
const _greenLink      = Color(0xFF4CAF7D);
const _greenVerify    = Color(0xFF4CAF7D);
const _greenVerifyBg  = Color(0xFFE8F5EE);
const _greenVerifyBdr = Color(0xFFB2DFC5);
const _brandGreen     = Color(0xFF4CAF7D);
const _checkboxBorder = Color(0xFFD9D5CF);
const _tosGreen       = Color(0xFF4CAF7D);
const _errorRed       = Color(0xFFDC2626);
const _errorBg        = Color(0xFFFFF5F5);

class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => RegisterViewModel(),
      child: const _RegisterContent(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Main content — holds all controllers, talks to VM
// ─────────────────────────────────────────────────────────────────────────────
class _RegisterContent extends StatefulWidget {
  const _RegisterContent();

  @override
  State<_RegisterContent> createState() => _RegisterContentState();
}

class _RegisterContentState extends State<_RegisterContent> {
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl  = TextEditingController();
  final _emailCtrl     = TextEditingController();
  final _phoneCtrl     = TextEditingController();
  final _passwordCtrl  = TextEditingController();
  final _confirmCtrl   = TextEditingController();
  final _referralCtrl  = TextEditingController();

  // Separate recognizers so tapping the legal links opens the premium
  // document viewer, while tapping anywhere else in the sentence (or the
  // checkbox itself) simply toggles agreement — the checkbox only records
  // that the user has read & agreed, it never opens anything.
  late final TapGestureRecognizer _agreeToggleRecognizer;
  late final TapGestureRecognizer _tosRecognizer;
  late final TapGestureRecognizer _privacyRecognizer;

  @override
  void initState() {
    super.initState();
    _agreeToggleRecognizer = TapGestureRecognizer()
      ..onTap = () => context.read<RegisterViewModel>().toggleAgreed();
    _tosRecognizer = TapGestureRecognizer()
      ..onTap = () => showLegalDocumentSheet(
          context, LegalDocType.termsOfService);
    _privacyRecognizer = TapGestureRecognizer()
      ..onTap = () => showLegalDocumentSheet(
          context, LegalDocType.privacyPolicy);
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _referralCtrl.dispose();
    _agreeToggleRecognizer.dispose();
    _tosRecognizer.dispose();
    _privacyRecognizer.dispose();
    super.dispose();
  }

  // ── Email verify ──────────────────────────────────────────────────────────
  Future<void> _handleEmailVerify() async {
    final vm     = context.read<RegisterViewModel>();
    final masked = vm.requestEmailVerify(_emailCtrl.text);
    if (masked == null) return;

    final rawEmail = _emailCtrl.text.trim();

    // Ask the backend to generate + send the OTP before opening the OTP
    // screen, so the user always lands on a screen with a live OTP waiting.
    final sendError = await vm.sendEmailOtp(rawEmail);

    if (!mounted) return;

    if (sendError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(sendError), backgroundColor: Colors.red),
      );
      return;
    }

    final verified = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => EmailOtpScreen(email: rawEmail)),
    );

    if (!mounted) return;

    // EmailOtpScreen only pops with `true` when the backend actually
    // confirmed the OTP. Any other outcome — back button, dismissed,
    // expired, failed verification — must leave/reset the field as
    // Not Verified so account creation stays blocked.
    context.read<RegisterViewModel>().setEmailVerified(verified == true);
  }

  // ── Phone verify ──────────────────────────────────────────────────────────
  Future<void> _handlePhoneVerify() async {
    final vm      = context.read<RegisterViewModel>();
    final phoneNo = vm.requestPhoneVerify(_phoneCtrl.text);
    if (phoneNo == null) return;

    final rawPhone = _phoneCtrl.text.trim();

    // Ask the backend to generate + send the OTP before opening the OTP
    // screen, so the user always lands on a screen with a live OTP waiting.
    final sendError = await vm.sendPhoneOtp(rawPhone);

    if (!mounted) return;

    if (sendError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(sendError), backgroundColor: Colors.red),
      );
      return;
    }

    final verified = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => OtpScreen(phoneNumber: phoneNo)),
    );

    if (!mounted) return;

    // OtpScreen only pops with `true` when the backend actually confirmed
    // the OTP. Any other outcome — back button, dismissed, expired, failed
    // verification — must leave/reset the field as Not Verified so account
    // creation stays blocked.
    context.read<RegisterViewModel>().setPhoneVerified(verified == true);
  }

  // ── Sign up ───────────────────────────────────────────────────────────────
  Future<void> _handleSignUp() async {
    FocusScope.of(context).unfocus();
    final vm = context.read<RegisterViewModel>();

    // Push current field values into VM before validating
    vm.firstName = _firstNameCtrl.text.trim();
    vm.lastName  = _lastNameCtrl.text.trim();
    vm.email     = _emailCtrl.text.trim();
    vm.phone     = _phoneCtrl.text.trim();
    vm.password  = _passwordCtrl.text;
    vm.confirm   = _confirmCtrl.text;
    vm.referral  = _referralCtrl.text.trim();

    final success = await vm.signUp();

if (!mounted) return;

if (success) {
  Navigator.pushReplacementNamed(
    context,
    AppRoutes.setPassword,
  );
} else if (vm.errorMessage != null) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(vm.errorMessage!),
      backgroundColor: Colors.red,
    ),
  );
}
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: _bgColor,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: _fieldBg,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.r),
            borderSide: BorderSide(color: _fieldBorder, width: 1.r),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.r),
            borderSide: BorderSide(color: _fieldBorder, width: 1.r),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.r),
            borderSide: BorderSide(color: Color(0xFF4CAF7D), width: 1.5.r),
          ),
          hintStyle: TextStyle(fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
              color: _hintColor, fontSize: 14.5.sp, fontWeight: FontWeight.w400),
          contentPadding:
              EdgeInsets.symmetric(horizontal: 14.w, vertical: 15.h),
        ),
      ),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: Scaffold(
          backgroundColor: _bgColor,
          body: SafeArea(
            child: Column(
              children: [
                // ── Top brand bar ─────────────────────────────────────────
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 18.h),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 34.w,
                        height: 34.h,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8.r),
                          border: Border.all(
                              color: const Color(0xFFB2DFC5), width: 1.2.r),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.06),
                                blurRadius: 6,
                                offset: const Offset(0, 2)),
                          ],
                        ),
                        child: Center(
                          child: Icon(
                              Icons.account_balance_wallet_outlined,
                              size: 18.sp,
                              color: _brandGreen),
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        'Moneytries',
                        style: TextStyle(fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                            fontSize: 20.sp,
                            fontWeight: FontWeight.w800,
                            color: _brandGreen,
                            letterSpacing: -0.3),
                      ),
                    ],
                  ),
                ),

                // ── Scrollable form card ──────────────────────────────────
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(16.w, 0.h, 16.w, 20.h),
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: _cardBg,
                        borderRadius: BorderRadius.circular(20.r),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 16,
                              offset: const Offset(0, 4)),
                        ],
                      ),
                      padding: EdgeInsets.fromLTRB(22.w, 28.h, 22.w, 28.h),
                      child: Consumer<RegisterViewModel>(
                        builder: (context, vm, _) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [

                              // ── Heading ────────────────────────────────
                              Text(
                                'Create Account',
                                style: TextStyle(fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                                    fontSize: 26.sp,
                                    fontWeight: FontWeight.w800,
                                    color: _titleColor,
                                    letterSpacing: -0.4,
                                    height: 1.15),
                              ),
                              SizedBox(height: 6.h),
                              Text(
                                'Start your journey to controlled prosperity.',
                                style: TextStyle(fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w400,
                                    color: _subtitleColor,
                                    height: 1.45),
                              ),

                              SizedBox(height: 28.h),

                              // ── FIRST NAME ──────────────────────────────
                              _FieldLabel('FIRST NAME'),
                              SizedBox(height: 7.h),
                              _PlainField(
                                controller: _firstNameCtrl,
                                hint: 'First name',
                                icon: Icons.person_outline_rounded,
                                keyboardType: TextInputType.name,
                                textCapitalization: TextCapitalization.words,
                                errorText: vm.firstNameError,
                                onChanged: (_) => vm.clearFirstNameError(),
                              ),

                              SizedBox(height: 18.h),

                              // ── LAST NAME ───────────────────────────────
                              _FieldLabel('LAST NAME'),
                              SizedBox(height: 7.h),
                              _PlainField(
                                controller: _lastNameCtrl,
                                hint: 'Last name',
                                icon: Icons.person_outline_rounded,
                                keyboardType: TextInputType.name,
                                textCapitalization: TextCapitalization.words,
                                errorText: vm.lastNameError,
                                onChanged: (_) => vm.clearLastNameError(),
                              ),

                              SizedBox(height: 18.h),

                              // ── EMAIL ADDRESS ────────────────────────────
                              _FieldLabel('EMAIL ADDRESS'),
                              SizedBox(height: 7.h),
                              _VerifyField(
                                controller: _emailCtrl,
                                hint: 'name@example.com',
                                icon: Icons.mail_outline_rounded,
                                keyboardType: TextInputType.emailAddress,
                                onVerify: _handleEmailVerify,
                                errorText: vm.emailError,
                                verifyError: vm.emailVerifyError,
                                isVerified: vm.emailVerified,
                                onChanged: (_) => vm.clearEmailError(),
                              ),

                              SizedBox(height: 18.h),

                              // ── PHONE NUMBER ─────────────────────────────
                              _FieldLabel('PHONE NUMBER'),
                              SizedBox(height: 7.h),
                              _PhoneVerifyField(
                                controller: _phoneCtrl,
                                errorText: vm.phoneError,
                                verifyError: vm.phoneVerifyError,
                                isVerified: vm.phoneVerified,
                                onVerify: _handlePhoneVerify,
                                onChanged: (_) => vm.clearPhoneError(),
                              ),

                              SizedBox(height: 18.h),

                              // ── PASSWORD ─────────────────────────────────
                              _FieldLabel('PASSWORD'),
                              SizedBox(height: 7.h),
                              _PasswordField(
                                controller: _passwordCtrl,
                                hint: 'Min. 8 characters',
                                iconData: Icons.lock_outline_rounded,
                                obscure: vm.obscurePassword,
                                onToggle: vm.toggleObscurePassword,
                                errorText: vm.passwordError,
                                onChanged: (_) => vm.clearPasswordError(),
                              ),

                              // ── Password strength indicator ───────────────
                              if (_passwordCtrl.text.isNotEmpty) ...[
                                SizedBox(height: 8.h),
                                _PasswordStrengthBar(
                                    password: _passwordCtrl.text),
                              ],

                              SizedBox(height: 18.h),

                              // ── CONFIRM PASSWORD ──────────────────────────
                              _FieldLabel('CONFIRM PASSWORD'),
                              SizedBox(height: 7.h),
                              _PasswordField(
                                controller: _confirmCtrl,
                                hint: 'Repeat your password',
                                iconData: Icons.lock_reset_rounded,
                                obscure: vm.obscureConfirm,
                                onToggle: vm.toggleObscureConfirm,
                                errorText: vm.confirmError,
                                onChanged: (_) => vm.clearConfirmError(),
                              ),

                              SizedBox(height: 20.h),

                              // ── Terms checkbox ────────────────────────────
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  GestureDetector(
                                    onTap: vm.toggleAgreed,
                                    child: AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 180),
                                      width: 20.w,
                                      height: 20.h,
                                      margin: EdgeInsets.only(top: 1.5.h),
                                      decoration: BoxDecoration(
                                        color: vm.agreed
                                            ? _greenPrimary
                                            : Colors.white,
                                        border: Border.all(
                                          color: vm.agreedError != null
                                              ? _errorRed
                                              : vm.agreed
                                                  ? _greenPrimary
                                                  : _checkboxBorder,
                                          width: 1.5.r,
                                        ),
                                        borderRadius:
                                            BorderRadius.circular(4.r),
                                      ),
                                      child: vm.agreed
                                          ? Icon(Icons.check,
                                              size: 13.sp, color: Colors.white)
                                          : null,
                                    ),
                                  ),
                                  SizedBox(width: 10.w),
                                  Expanded(
                                    child: RichText(
                                      text: TextSpan(
                                        style: TextStyle(fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                                            fontSize: 13.5.sp,
                                            color: _inputTextColor,
                                            height: 1.5),
                                        children: [
                                          TextSpan(
                                            text: 'I agree to the ',
                                            recognizer: _agreeToggleRecognizer,
                                          ),
                                          TextSpan(
                                            text: 'Terms of Service',
                                            style: TextStyle(fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                                                fontSize: 13.5.sp,
                                                fontWeight: FontWeight.w700,
                                                color: _tosGreen,
                                                decoration:
                                                    TextDecoration.underline,
                                                decorationColor: _tosGreen),
                                            recognizer: _tosRecognizer,
                                          ),
                                          TextSpan(
                                            text: ' and ',
                                            recognizer: _agreeToggleRecognizer,
                                          ),
                                          TextSpan(
                                            text: 'Privacy Policy',
                                            style: TextStyle(fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                                                fontSize: 13.5.sp,
                                                fontWeight: FontWeight.w700,
                                                color: _tosGreen,
                                                decoration:
                                                    TextDecoration.underline,
                                                decorationColor: _tosGreen),
                                            recognizer: _privacyRecognizer,
                                          ),
                                          TextSpan(
                                            text: '.',
                                            recognizer: _agreeToggleRecognizer,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              if (vm.agreedError != null) ...[
                                SizedBox(height: 6.h),
                                _ErrorRow(vm.agreedError!),
                              ],

                              SizedBox(height: 22.h),

                              // ── REFERRAL CODE (OPTIONAL) ──────────────────
                              _FieldLabel('REFERRAL CODE (OPTIONAL)'),
                              SizedBox(height: 7.h),
                              _PlainField(
                                controller: _referralCtrl,
                                hint: 'Enter code if any',
                                icon: Icons.card_giftcard_outlined,
                                textCapitalization:
                                    TextCapitalization.characters,
                              ),

                              SizedBox(height: 26.h),

                              // ── Sign Up button ────────────────────────────
                              SizedBox(
                                width: double.infinity,
                                height: 54.h,
                                child: ElevatedButton(
                                  onPressed: vm.isLoading ? null : _handleSignUp,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _greenPrimary,
                                    disabledBackgroundColor:
                                        _greenPrimary.withOpacity(0.7),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shadowColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12.r)),
                                  ),
                                  child: vm.isLoading
                                      ? SizedBox(
                                          width: 22.w,
                                          height: 22.h,
                                          child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2.5),
                                        )
                                      : Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              'Sign Up',
                                              style: TextStyle(fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                                                  fontSize: 16.sp,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.white,
                                                  letterSpacing: 0.2),
                                            ),
                                            SizedBox(width: 8.w),
                                            Icon(
                                                Icons.arrow_forward_rounded,
                                                size: 18.sp,
                                                color: Colors.white),
                                          ],
                                        ),
                                ),
                              ),

                              SizedBox(height: 20.h),

                              // ── Already have an account? ──────────────────
                              Center(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Already have an account?  ',
                                      style: TextStyle(fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                                          fontSize: 13.5.sp,
                                          color: _subtitleColor),
                                    ),
                                    GestureDetector(
                                      onTap: () =>
                                          Navigator.pushReplacementNamed(
                                              context, AppRoutes.login),
                                      child: Text(
                                        'Login',
                                        style: TextStyle(fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                                            fontSize: 13.5.sp,
                                            fontWeight: FontWeight.w700,
                                            color: _greenLink),
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
// Password Strength Bar
// ─────────────────────────────────────────────────────────────────────────────
class _PasswordStrengthBar extends StatelessWidget {
  final String password;
  const _PasswordStrengthBar({required this.password});

  int _score() {
    int s = 0;
    if (password.length >= 8) s++;
    if (password.length >= 12) s++;
    if (RegExp(r'[A-Z]').hasMatch(password)) s++;
    if (RegExp(r'[0-9]').hasMatch(password)) s++;
    if (RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(password)) s++;
    return s;
  }

  @override
  Widget build(BuildContext context) {
    final score  = _score();
    final label  = score <= 1 ? 'Weak' : score <= 3 ? 'Fair' : 'Strong';
    final color  = score <= 1
        ? _errorRed
        : score <= 3
            ? const Color(0xFFF59E0B)
            : _greenPrimary;
    final filled = (score / 5).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4.r),
          child: LinearProgressIndicator(
            value: filled,
            minHeight: 4,
            backgroundColor: const Color(0xFFE8E4DE),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          'Password strength: $label',
          style: TextStyle(fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
              fontSize: 11.5.sp, fontWeight: FontWeight.w500, color: color),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable widgets
// ─────────────────────────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
          fontSize: 11.sp,
          fontWeight: FontWeight.w600,
          color: _labelColor,
          letterSpacing: 0.9),
    );
  }
}

class _ErrorRow extends StatelessWidget {
  final String message;
  const _ErrorRow(this.message);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.error_outline_rounded, size: 13.sp, color: _errorRed),
        SizedBox(width: 4.w),
        Flexible(
          child: Text(
            message,
            style: TextStyle(fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                fontSize: 11.5.sp,
                color: _errorRed,
                fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}

// ── Plain input field ─────────────────────────────────────────────────────────
class _PlainField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType keyboardType;
  final TextCapitalization textCapitalization;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final List<TextInputFormatter>? inputFormatters;

  const _PlainField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.keyboardType = TextInputType.text,
    this.textCapitalization = TextCapitalization.none,
    this.errorText,
    this.onChanged,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          inputFormatters: inputFormatters,
          onChanged: onChanged,
          style: TextStyle(fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,fontSize: 14.5.sp, color: _inputTextColor),
          decoration: _dec(
            hint: hint,
            prefixIcon: Icon(icon,
                size: 20.sp,
                color: hasError ? _errorRed : _fieldIconColor),
            hasError: hasError,
          ),
        ),
        if (hasError) ...[
          SizedBox(height: 5.h),
          _ErrorRow(errorText!),
        ],
      ],
    );
  }
}

// ── Field with Verify / Verified suffix ───────────────────────────────────────
class _VerifyField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType keyboardType;
  final VoidCallback onVerify;
  final String? errorText;
  final String? verifyError;
  final bool isVerified;
  final ValueChanged<String>? onChanged;

  const _VerifyField({
    required this.controller,
    required this.hint,
    required this.icon,
    required this.onVerify,
    this.keyboardType = TextInputType.text,
    this.errorText,
    this.verifyError,
    this.isVerified = false,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final hasError     = errorText != null || verifyError != null;
    final displayError = errorText ?? verifyError;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          onChanged: onChanged,
          style: TextStyle(fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,fontSize: 14.5.sp, color: _inputTextColor),
          decoration: _dec(
            hint: hint,
            prefixIcon: Icon(icon,
                size: 20.sp,
                color: hasError ? _errorRed : _fieldIconColor),
            suffix: isVerified
                ? const _VerifiedBadge()
                : _VerifyPill(onTap: onVerify, hasError: verifyError != null),
            hasError: hasError,
          ),
        ),
        if (displayError != null) ...[
          SizedBox(height: 5.h),
          _ErrorRow(displayError),
        ],
      ],
    );
  }
}

// ── Phone + verify ────────────────────────────────────────────────────────────
class _PhoneVerifyField extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onVerify;
  final String? errorText;
  final String? verifyError;
  final bool isVerified;
  final ValueChanged<String>? onChanged;

  const _PhoneVerifyField({
    required this.controller,
    required this.onVerify,
    this.errorText,
    this.verifyError,
    this.isVerified = false,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final hasError     = errorText != null || verifyError != null;
    final displayError = errorText ?? verifyError;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          keyboardType: TextInputType.phone,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10),
          ],
          onChanged: onChanged,
          style: TextStyle(fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,fontSize: 14.5.sp, color: _inputTextColor),
          decoration: _dec(
            hint: '10-digit mobile number',
            prefixIcon: Icon(Icons.phone_outlined,
                size: 20.sp,
                color: hasError ? _errorRed : _fieldIconColor),
            suffix: isVerified
                ? const _VerifiedBadge()
                : _VerifyPill(onTap: onVerify, hasError: verifyError != null),
            hasError: hasError,
          ),
        ),
        if (displayError != null) ...[
          SizedBox(height: 5.h),
          _ErrorRow(displayError),
        ],
      ],
    );
  }
}

// ── Password field ────────────────────────────────────────────────────────────
class _PasswordField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData iconData;
  final bool obscure;
  final VoidCallback onToggle;
  final String? errorText;
  final ValueChanged<String>? onChanged;

  const _PasswordField({
    required this.controller,
    required this.hint,
    required this.iconData,
    required this.obscure,
    required this.onToggle,
    this.errorText,
    this.onChanged,
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
          style: TextStyle(fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
            fontSize: 14.5.sp,
            color: _inputTextColor,
            letterSpacing: obscure ? 2.0 : 0,
          ),
          decoration: _dec(
            hint: hint,
            prefixIcon: Icon(iconData,
                size: 20.sp,
                color: hasError ? _errorRed : _fieldIconColor),
            suffix: GestureDetector(
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
            hasError: hasError,
          ),
        ),
        if (hasError) ...[
          SizedBox(height: 5.h),
          _ErrorRow(errorText!),
        ],
      ],
    );
  }
}

// ── Verify pill ───────────────────────────────────────────────────────────────
class _VerifyPill extends StatelessWidget {
  final VoidCallback onTap;
  final bool hasError;
  const _VerifyPill({required this.onTap, this.hasError = false});

  @override
  Widget build(BuildContext context) {
    return UnconstrainedBox(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: EdgeInsets.only(right: 10.w),
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 5.h),
          decoration: BoxDecoration(
            color: hasError ? _errorBg : _greenVerifyBg,
            border: Border.all(
              color: hasError ? _errorRed : _greenVerifyBdr,
              width: 1.r,
            ),
            borderRadius: BorderRadius.circular(20.r),
          ),
          child: Text(
            'Verify',
            style: TextStyle(fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: hasError ? _errorRed : _greenVerify),
          ),
        ),
      ),
    );
  }
}

// ── Verified badge ────────────────────────────────────────────────────────────
class _VerifiedBadge extends StatelessWidget {
  const _VerifiedBadge();

  @override
  Widget build(BuildContext context) {
    return UnconstrainedBox(
      child: Container(
        margin: EdgeInsets.only(right: 10.w),
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
        decoration: BoxDecoration(
          color: _greenVerifyBg,
          border: Border.all(color: _greenVerifyBdr, width: 1.r),
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_rounded,
                size: 13.sp, color: _greenVerify),
            SizedBox(width: 4.w),
            Text(
              'Verified',
              style: TextStyle(fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: _greenVerify),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared InputDecoration factory ────────────────────────────────────────────
InputDecoration _dec({
  required String hint,
  Widget? prefixIcon,
  Widget? suffix,
  bool hasError = false,
}) {
  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
        color: _hintColor, fontSize: 14.5.sp, fontWeight: FontWeight.w400),
    prefixIcon: prefixIcon != null
        ? Padding(
            padding: EdgeInsets.only(left: 14.w, right: 10.w),
            child: prefixIcon,
          )
        : null,
    prefixIconConstraints: const BoxConstraints(minWidth: 46, minHeight: 46),
    suffixIcon: suffix,
    suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
    filled: true,
    fillColor: hasError ? _errorBg : _fieldBg,
    border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.r),
        borderSide: BorderSide(color: _fieldBorder, width: 1.r)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10.r),
      borderSide: hasError
          ? BorderSide(color: _errorRed, width: 1.5.r)
          : BorderSide(color: _fieldBorder, width: 1.r),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10.r),
      borderSide: BorderSide(
          color: hasError ? _errorRed : const Color(0xFF4CAF7D), width: 1.5.r),
    ),
    contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 15.h),
  );
}