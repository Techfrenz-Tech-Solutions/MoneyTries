// lib/views/auth/forgot_password_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../viewmodels/auth/forgot_password_viewmodel.dart';
import 'reset_otp_screen.dart';

// ── Palette (matches login_screen.dart) ────────────────────────────────────────
const _titleColor = Color(0xFF1A1A2E);
const _subtitleColor = Color(0xFF6B7280);
const _labelColor = Color(0xFF374151);
const _fieldFill = Color(0xFFEEF2FF);
const _fieldIconColor = Color(0xFF9CA3AF);
const _hintColor = Color(0xFF9CA3AF);
const _borderColorFocus = Color(0xFF4DAA75);
const _greenPrimary = Color(0xFF4DAA75);
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
                  Color(0xFFE6F4EC),
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Icon badge ─────────────────────────────────
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.06),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.lock_reset_rounded,
                                size: 34,
                                color: Color(0xFF3D9E6A),
                              ),
                            ),
                          ),

                          const SizedBox(height: 22),

                          Text(
                            'Forgot Password',
                            style: GoogleFonts.poppins(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: _titleColor,
                              letterSpacing: -0.4,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Enter your registered email or mobile number '
                            'and we\'ll send you a 6-digit OTP to reset your '
                            'password.',
                            style: GoogleFonts.poppins(
                              fontSize: 13.5,
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
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.06),
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
                                      'Email or Mobile Number',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w500,
                                        color: _labelColor,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    TextField(
                                      controller: _identifierCtrl,
                                      keyboardType:
                                          TextInputType.emailAddress,
                                      onChanged: (_) => vm.clearError(),
                                      style: GoogleFonts.poppins(
                                        fontSize: 14.5,
                                        color: const Color(0xFF374151),
                                      ),
                                      decoration: InputDecoration(
                                        hintText:
                                            'Enter your email or 10-digit mobile',
                                        hintStyle: GoogleFonts.poppins(
                                          color: _hintColor,
                                          fontSize: 14.5,
                                        ),
                                        prefixIcon: const Padding(
                                          padding: EdgeInsets.only(
                                            left: 14,
                                            right: 10,
                                          ),
                                          child: Icon(
                                            Icons.alternate_email_rounded,
                                            size: 20,
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
                                              BorderRadius.circular(10),
                                          borderSide: BorderSide.none,
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          borderSide: BorderSide.none,
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          borderSide: const BorderSide(
                                            color: _borderColorFocus,
                                            width: 1.5,
                                          ),
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 15,
                                        ),
                                      ),
                                    ),

                                    const SizedBox(height: 24),

                                    SizedBox(
                                      width: double.infinity,
                                      height: 52,
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
                                                BorderRadius.circular(12),
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
                                                'Send Reset OTP',
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