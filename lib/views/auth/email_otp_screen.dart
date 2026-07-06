import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_service.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _bgColor        = Color(0xFFEBF0F5);
const _titleColor     = Color(0xFF0D1B2A);
const _bodyColor      = Color(0xFF4B5563);
const _emailBold      = Color(0xFF0D1B2A);
const _otpBg          = Color(0xFFEEF2F7);
const _otpBorder      = Color(0xFFD1D5DB);
const _otpFocusBorder = Color(0xFF166534);
const _otpText        = Color(0xFF0D1B2A);
const _greenPrimary   = Color(0xFF166534);
const _greenLink      = Color(0xFF16A34A);
const _greyText       = Color(0xFF6B7280);
const _footerGrey     = Color(0xFF9CA3AF);
const _verifyBtnBg    = Color(0xFF166534);
const _headerIcon     = Color(0xFF166534);

class EmailOtpScreen extends StatefulWidget {
  /// Raw email address, used for the backend OTP send/verify calls.
  final String email;
  const EmailOtpScreen({super.key, required this.email});

  @override
  State<EmailOtpScreen> createState() => _EmailOtpScreenState();
}

class _EmailOtpScreenState extends State<EmailOtpScreen> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes =
      List.generate(6, (_) => FocusNode());

  int _secondsLeft = 54;
  Timer? _timer;
  bool _canResend = false;
  String? _otpError;
  bool _isVerifying = false;
  bool _isResending = false;

  /// Masked email for display only (e.g. "j***n@example.com"); the backend
  /// calls always use the raw widget.email.
  String get _maskedEmail {
    final parts = widget.email.split('@');
    if (parts.length != 2) return widget.email;
    final local = parts[0];
    final domain = parts[1];
    if (local.length <= 2) return '${local[0]}*@$domain';
    return '${local[0]}${'*' * (local.length - 2)}${local[local.length - 1]}@$domain';
  }

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() {
      _secondsLeft = 54;
      _canResend   = false;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft <= 1) {
        t.cancel();
        setState(() => _canResend = true);
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

  void _onDigitChanged(int index, String value) {
    if (value.length > 1) {
      final digits = value.replaceAll(RegExp(r'\D'), '').split('');
      for (int i = 0; i < 6 && i < digits.length; i++) {
        _controllers[i].text = digits[i];
      }
      final nextEmpty = _controllers.indexWhere((c) => c.text.isEmpty);
      _focusNodes[nextEmpty == -1 ? 5 : nextEmpty].requestFocus();
      setState(() => _otpError = null);
      return;
    }
    if (value.isNotEmpty) {
      if (index < 5) _focusNodes[index + 1].requestFocus();
    } else {
      if (index > 0) _focusNodes[index - 1].requestFocus();
    }
    if (_otpError != null) setState(() => _otpError = null);
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

    final error = await ApiService.verifyEmailOtpRegister(
      email: widget.email,
      otp: otp,
    ).then((response) {
      if (response['success'] == true) return null;
      return response['message']?.toString() ?? 'Invalid OTP. Please try again.';
    }).catchError((_) => 'Something went wrong. Please try again.');

    if (!mounted) return;

    if (error != null) {
      setState(() {
        _isVerifying = false;
        _otpError = error;
      });
      return;
    }

    setState(() => _isVerifying = false);
    Navigator.pop(context);
  }

  Future<void> _resend() async {
    if (_isResending) return;

    setState(() => _isResending = true);

    final error = await ApiService.sendEmailOtpRegister(email: widget.email)
        .then((response) {
      if (response['success'] == true) return null;
      return response['message']?.toString() ?? 'Failed to resend OTP. Please try again.';
    }).catchError((_) => 'Something went wrong. Please try again.');

    if (!mounted) return;

    setState(() => _isResending = false);

    if (error != null) {
      setState(() => _otpError = error);
      return;
    }

    for (final c in _controllers) c.clear();
    setState(() => _otpError = null);
    _startTimer();
    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) _focusNodes[0].requestFocus();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _controllers) c.dispose();
    for (final f in _focusNodes) f.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _bgColor,
        body: SafeArea(
          child: Column(
            children: [
              // ── AppBar ────────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        color: _headerIcon,
                        size: 24,
                      ),
                      splashRadius: 22,
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          'Verify Email',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: _greenPrimary,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {},
                      icon: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: _headerIcon, width: 1.8),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.question_mark_rounded,
                            color: _headerIcon,
                            size: 15,
                          ),
                        ),
                      ),
                      splashRadius: 22,
                    ),
                  ],
                ),
              ),

              // ── Scrollable body ───────────────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      const SizedBox(height: 14),

                      // ── Illustration card ─────────────────────────────────
                      Container(
                        width: double.infinity,
                        height: 240,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FAF5),
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.07),
                              blurRadius: 22,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: Image.asset(
                            'assets/images/email_otp.png',
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: const Color(0xFFF0FAF5),
                                child: const Center(
                                  child: Icon(
                                    Icons.mark_email_read_outlined,
                                    size: 72,
                                    color: Color(0xFF4ADE80),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),

                      const SizedBox(height: 34),

                      // ── Title ─────────────────────────────────────────────
                      Text(
                        'Verify Your Email',
                        style: GoogleFonts.poppins(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: _titleColor,
                          letterSpacing: -0.4,
                          height: 1.2,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 10),

                      // ── Subtitle ──────────────────────────────────────────
                      Text(
                        "We've sent a 6-digit verification code to",
                        style: GoogleFonts.poppins(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w400,
                          color: _bodyColor,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _maskedEmail,
                        style: GoogleFonts.poppins(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: _emailBold,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 30),

                      // ── OTP boxes ─────────────────────────────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(6, _buildOtpBox),
                      ),

                      if (_otpError != null) ...[
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              size: 13,
                              color: Color(0xFFDC2626),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _otpError!,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: const Color(0xFFDC2626),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 26),

                      // ── Resend row ────────────────────────────────────────
                      Text(
                        "Didn't receive the code?",
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: _greyText,
                          fontWeight: FontWeight.w400,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 5),
                      _canResend
                          ? GestureDetector(
                              onTap: _isResending ? null : _resend,
                              child: _isResending
                                  ? SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: _greenLink,
                                      ),
                                    )
                                  : Text(
                                      'Resend Code',
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: _greenLink,
                                      ),
                                    ),
                            )
                          : Text(
                              'Resend in $_timerLabel',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: _greenLink,
                              ),
                            ),

                      const SizedBox(height: 32),

                      // ── Verify button ─────────────────────────────────────
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isVerifying ? null : _handleVerify,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _verifyBtnBg,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          child: _isVerifying
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  'Verify',
                                  style: GoogleFonts.poppins(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(height: 22),

                      // ── Footer note ───────────────────────────────────────
                      Text(
                        'By verifying, you ensure your investments\nand data remain secured within the\nMoneyTries ecosystem.',
                        style: GoogleFonts.poppins(
                          fontSize: 12.5,
                          color: _footerGrey,
                          height: 1.65,
                          fontWeight: FontWeight.w400,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 28),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOtpBox(int index) {
    final hasError = _otpError != null;
    return SizedBox(
      width: 46,
      height: 54,
      child: TextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 2,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: GoogleFonts.poppins(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: _otpText,
        ),
        onChanged: (v) => _onDigitChanged(index, v),
        decoration: InputDecoration(
          counterText: '',
          hintText: '–',
          hintStyle: GoogleFonts.poppins(
            fontSize: 18,
            color: const Color(0xFFB0BAC8),
            fontWeight: FontWeight.w500,
          ),
          filled: true,
          fillColor: hasError ? const Color(0xFFFFF5F5) : _otpBg,
          contentPadding: EdgeInsets.zero,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _otpBorder, width: 1),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: hasError ? const Color(0xFFDC2626) : _otpBorder,
              width: 1,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: hasError ? const Color(0xFFDC2626) : _otpFocusBorder,
              width: 2,
            ),
          ),
        ),
      ),
    );
  }
}