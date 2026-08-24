// lib/views/auth/forgot_password_screen.dart

import 'package:flutter/material.dart';
import 'package:moneytries/config/app_fonts.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../viewmodels/auth/forgot_password_viewmodel.dart';
import 'reset_otp_screen.dart';
import '../../utils/responsive.dart';

// ── Palette (matches login_screen.dart) ────────────────────────────────────────
const _titleColor = Color(0xFF1A1A2E);
const _subtitleColor = Color(0xFF6B7280);
const _labelColor = Color(0xFF374151);
const _fieldFill = Color(0xFFF0FAF4);
const _fieldIconColor = Color(0xFF9CA3AF);
const _hintColor = Color(0xFF9CA3AF);
const _borderColorFocus = Color(0xFF4CAF7D);
const _greenPrimary = Color(0xFF4CAF7D);
const _errorRed = Color(0xFFDC2626);

class ForgotPasswordScreen extends StatelessWidget {
  final String prefillIdentifier;
  const ForgotPasswordScreen({super.key, this.prefillIdentifier = ''});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ForgotPasswordViewModel(),
      child: _ForgotPasswordContent(prefillIdentifier: prefillIdentifier),
    );
  }
}

class _ForgotPasswordContent extends StatefulWidget {
  final String prefillIdentifier;
  const _ForgotPasswordContent({required this.prefillIdentifier});

  @override
  State<_ForgotPasswordContent> createState() =>
      _ForgotPasswordContentState();
}

class _ForgotPasswordContentState extends State<_ForgotPasswordContent> {
  late final TextEditingController _identifierCtrl;

  @override
  void initState() {
    super.initState();
    _identifierCtrl = TextEditingController(text: widget.prefillIdentifier);
    if (RegExp(r'^\d{10}$').hasMatch(widget.prefillIdentifier.trim())) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.read<ForgotPasswordViewModel>().selectChannel('PHONE');
      });
    }
  }

  @override
  void dispose() {
    _identifierCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSendOtp() async {
    FocusScope.of(context).unfocus();
    final vm = context.read<ForgotPasswordViewModel>();

    final success = await vm.sendOtp(_identifierCtrl.text);
    if (!mounted || !success) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: vm,
          child: const ResetOtpScreen(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);

    return Theme(
      data: ThemeData(brightness: Brightness.light),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: Scaffold(
          backgroundColor: const Color(0xFFF5FAF7),
          body: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFCDEBDA),
                  Color(0xFFE8F5EE),
                  Color(0xFFF5FAF7),
                ],
                stops: [0.0, 0.40, 1.0],
              ),
            ),
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Back arrow ─────────────────────────────────────────
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Icon badge ─────────────────────────────────
                          Container(
                            width: 64.w,
                            height: 64.h,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16.r),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.06),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Icon(
                                Icons.lock_reset_rounded,
                                size: 34.sp,
                                color: Color(0xFF4CAF7D),
                              ),
                            ),
                          ),

                          SizedBox(height: 22.h),

                          Text(
                            'Forgot Password',
                            style: TextStyle(fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                              fontSize: 26.sp,
                              fontWeight: FontWeight.w800,
                              color: _titleColor,
                              letterSpacing: -0.4,
                              height: 1.15,
                            ),
                          ),
                          SizedBox(height: 8.h),
                          Text(
                            'Enter your registered email or mobile number '
                            'and we\'ll send you a 6-digit OTP to reset your '
                            'password.',
                            style: TextStyle(fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                              fontSize: 13.5.sp,
                              fontWeight: FontWeight.w400,
                              color: _subtitleColor,
                              height: 1.5,
                            ),
                          ),

                          SizedBox(height: mq.size.height * 0.04),

                          // ── White card ─────────────────────────────────
                          Consumer<ForgotPasswordViewModel>(
                            builder: (context, vm, _) {
                              return Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20.r),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.06),
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

                                    SegmentedButton<String>(
                                      segments: const [
                                        ButtonSegment(value: 'EMAIL', icon: Icon(Icons.email_outlined), label: Text('Email')),
                                        ButtonSegment(value: 'PHONE', icon: Icon(Icons.sms_outlined), label: Text('Phone')),
                                      ],
                                      selected: {vm.channel},
                                      onSelectionChanged: (value) {
                                        vm.selectChannel(value.first);
                                        _identifierCtrl.clear();
                                      },
                                    ),
                                    const SizedBox(height: 18),

                                    Text(
                                      vm.channel == 'EMAIL' ? 'Email Address' : 'Mobile Number',
                                      style: TextStyle(fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                                        fontSize: 12.5.sp,
                                        fontWeight: FontWeight.w500,
                                        color: _labelColor,
                                      ),
                                    ),
                                    SizedBox(height: 8.h),
                                    TextField(
                                      controller: _identifierCtrl,
                                      keyboardType:
                                          vm.channel == 'EMAIL' ? TextInputType.emailAddress : TextInputType.phone,
                                      onChanged: (value) {
                                        vm.clearError();
                                        final normalized = value.trim();
                                        final inferred = RegExp(r'^\d{10}$').hasMatch(normalized)
                                            ? 'PHONE'
                                            : RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(normalized)
                                                ? 'EMAIL'
                                                : null;
                                        if (inferred != null && inferred != vm.channel) {
                                          vm.selectChannel(inferred);
                                        }
                                      },
                                      style: TextStyle(fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                                        fontSize: 14.5.sp,
                                        color: const Color(0xFF374151),
                                      ),
                                      decoration: InputDecoration(
                                        hintText: vm.channel == 'EMAIL'
                                            ? 'Enter your registered email'
                                            : 'Enter your 10-digit mobile number',
                                        hintStyle: TextStyle(fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                                          color: _hintColor,
                                          fontSize: 14.5.sp,
                                        ),
                                        prefixIcon: Padding(
                                          padding: EdgeInsets.only(
                                            left: 14.w,
                                            right: 10.w,
                                          ),
                                          child: Icon(
                                            Icons.alternate_email_rounded,
                                            size: 20.sp,
                                            color: _fieldIconColor,
                                          ),
                                        ),
                                        prefixIconConstraints:
                                            const BoxConstraints(
                                          minWidth: 44,
                                          minHeight: 44,
                                        ),
                                        filled: true,
                                        fillColor: _fieldFill,
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(10.r),
                                          borderSide: BorderSide.none,
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(10.r),
                                          borderSide: BorderSide.none,
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(10.r),
                                          borderSide: BorderSide(
                                            color: _borderColorFocus,
                                            width: 1.5.r,
                                          ),
                                        ),
                                        contentPadding:
                                            EdgeInsets.symmetric(
                                          horizontal: 14.w,
                                          vertical: 15.h,
                                        ),
                                      ),
                                    ),

                                    SizedBox(height: 24.h),

                                    SizedBox(
                                      width: double.infinity,
                                      height: 52.h,
                                      child: ElevatedButton(
                                        onPressed: vm.isLoading
                                            ? null
                                            : _handleSendOtp,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: _greenPrimary,
                                          disabledBackgroundColor:
                                              _greenPrimary.withOpacity(0.7),
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                          shadowColor: Colors.transparent,
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
                                                'Send Reset OTP',
                                                style: TextStyle(fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                                                  fontSize: 15.sp,
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors.white,
                                                ),
                                              ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
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
              style: TextStyle(fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
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
