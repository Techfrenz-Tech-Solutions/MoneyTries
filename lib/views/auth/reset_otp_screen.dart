// lib/views/auth/reset_otp_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../viewmodels/auth/forgot_password_viewmodel.dart';
import 'reset_password_screen.dart';

// ── Palette (matches otp_screen.dart) ──────────────────────────────────────────
const _bgColor = Color(0xFFECEFF5);
const _titleColor = Color(0xFF111827);
const _bodyColor = Color(0xFF374151);
const _boldIdentifier = Color(0xFF111827);
const _otpBorder = Color(0xFFD1D5DB);
const _otpFocusBorder = Color(0xFF22C55E);
const _otpFill = Color(0xFFFFFFFF);
const _otpText = Color(0xFF111827);
const _mintSquare = Color(0xFF4ADE80);
const _greenBtn = Color(0xFF22C55E);
const _greenLink = Color(0xFF16A34A);
const _timerGreen = Color(0xFF22C55E);
const _timerGrey = Color(0xFF6B7280);
const _securityGrey = Color(0xFF9CA3AF);
const _securityIcon = Color(0xFF16A34A);
const _errorRed = Color(0xFFDC2626);

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

  String get _timerText {
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
                  padding: const EdgeInsets.fromLTRB(12, 12, 0, 0),
                  child: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: _titleColor,
                      size: 22,
                    ),
                    splashRadius: 22,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Mint icon badge ─────────────────────────────
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: _mintSquare,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.mark_email_read_rounded,
                              size: 32,
                              color: Color(0xFF3D9E6A),
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        Text(
                          'Verify OTP',
                          style: GoogleFonts.poppins(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: _titleColor,
                            letterSpacing: -0.4,
                            height: 1.15,
                          ),
                        ),

                        const SizedBox(height: 8),

                        RichText(
                          text: TextSpan(
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: _bodyColor,
                              height: 1.55,
                            ),
                            children: [
                              const TextSpan(
                                text: 'Enter the 6-digit code sent to ',
                              ),
                              TextSpan(
                                text: identifier,
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: _boldIdentifier,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),

                        // ── 6 OTP input boxes ───────────────────────────
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: List.generate(
                            6,
                            (i) => _OtpBox(
                              controller: _controllers[i],
                              focusNode: _focusNodes[i],
                              onChanged: (val) {
                                if (vm.errorMessage != null) vm.clearError();
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

                        if (vm.errorMessage != null) ...[
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.error_outline_rounded,
                                size: 13,
                                color: _errorRed,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  vm.errorMessage!,
                                  style: GoogleFonts.poppins(
                                    fontSize: 11.5,
                                    color: _errorRed,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],

                        const SizedBox(height: 28),

                        // ── Resend timer ─────────────────────────────────
                        Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.access_time_rounded,
                                size: 14,
                                color: _timerGrey,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                canResend
                                    ? 'OTP expired. '
                                    : 'OTP expires in ',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: _timerGrey,
                                ),
                              ),
                              if (!canResend)
                                Text(
                                  _timerText,
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: _timerGreen,
                                  ),
                                ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 10),

                        Center(
                          child: GestureDetector(
                            onTap: (canResend && !_isResending)
                                ? _resend
                                : null,
                            child: _isResending
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: _greenLink,
                                    ),
                                  )
                                : Text(
                                    'Resend OTP',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
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
                        height: 54,
                        child: ElevatedButton(
                          onPressed: vm.isLoading ? null : _handleVerify,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _greenBtn,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: vm.isLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                    color: Colors.white,
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Verify & Proceed',
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(
                                      Icons.arrow_forward_rounded,
                                      size: 18,
                                      color: Colors.white,
                                    ),
                                  ],
                                ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.shield_outlined,
                            size: 15,
                            color: _securityIcon,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'This OTP is valid for 5 minutes and can be used only once.',
                              style: GoogleFonts.poppins(
                                fontSize: 11.5,
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
    );
  }
}

// ── Single OTP box ────────────────────────────────────────────────────────────
class _OtpBox extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onBackspace;

  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onBackspace,
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
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: _otpText,
          ),
          onChanged: onChanged,
          decoration: InputDecoration(
            counterText: '',
            filled: true,
            fillColor: _otpFill,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _otpBorder, width: 1.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _otpBorder, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _otpFocusBorder, width: 2),
            ),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ),
    );
  }
}