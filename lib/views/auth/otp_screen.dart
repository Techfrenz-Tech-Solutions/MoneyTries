import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../routes/app_routes.dart';
import '../../services/api_service.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _bgColor        = Color(0xFFECEFF5);
const _titleColor     = Color(0xFF111827);
const _bodyColor      = Color(0xFF374151);
const _boldPhone      = Color(0xFF111827);
const _otpBorder      = Color(0xFFD1D5DB);
const _otpFocusBorder = Color(0xFF22C55E);
const _otpFill        = Color(0xFFFFFFFF);
const _otpText        = Color(0xFF111827);
const _mintSquare     = Color(0xFF4ADE80);
const _greenBtn       = Color(0xFF22C55E);
const _greenLink      = Color(0xFF16A34A);
const _timerGreen     = Color(0xFF22C55E);
const _timerGrey      = Color(0xFF6B7280);
const _securityGrey   = Color(0xFF9CA3AF);
const _securityIcon   = Color(0xFF16A34A);

class OtpScreen extends StatefulWidget {
  final String phoneNumber;
  const OtpScreen({super.key, required this.phoneNumber});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes =
      List.generate(6, (_) => FocusNode());

  int _secondsLeft = 60;
  Timer? _timer;

  String? _otpError;
  bool _isVerifying = false;
  bool _isResending = false;

  /// Raw 10-digit phone number extracted from the display string
  /// (e.g. "+91 9876543210" -> "9876543210"), for use in API calls.
  String get _rawPhone {
    final digits = widget.phoneNumber.replaceAll(RegExp(r'\D'), '');
    return digits.length > 10 ? digits.substring(digits.length - 10) : digits;
  }

  @override
  void initState() {
    super.initState();
    _startTimer();
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

    final error = await ApiService.verifyMobOtpRegister(
      phone: _rawPhone,
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

  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsLeft = 60);
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

  Future<void> _resend() async {
    if (_isResending) return;

    setState(() => _isResending = true);

    final error = await ApiService.sendMobOtpRegister(phone: _rawPhone)
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

    for (var c in _controllers) c.clear();
    setState(() => _otpError = null);
    _startTimer();
    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) _focusNodes[0].requestFocus();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var c in _controllers) c.dispose();
    for (var f in _focusNodes) f.dispose();
    super.dispose();
  }

  String get _timerText {
    final m = _secondsLeft ~/ 60;
    final s = _secondsLeft % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final canResend = _secondsLeft == 0;

    return Theme(
      data: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: _bgColor,
        inputDecorationTheme: InputDecorationTheme(
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
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: Scaffold(
          backgroundColor: _bgColor,
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // ── Back arrow ───────────────────────────────────────────
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

                // ── Content area ─────────────────────────────────────────
                Expanded(
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        // ── Mint icon badge ──────────────────────────────
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: _mintSquare,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Center(
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Icon(
                                  Icons.shield_rounded,
                                  size: 38,
                                  color: Color(0xFF3D9E6A),
                                ),
                                Icon(
                                  Icons.lock_rounded,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        Text(
                          'Verify Mobile',
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
                                  text: 'Enter the 6-digit code sent to '),
                              TextSpan(
                                text: widget.phoneNumber,
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: _boldPhone,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),

                        // ── 6 OTP input boxes ─────────────────────────────
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: List.generate(
                            6,
                            (i) => _OtpBox(
                              controller: _controllers[i],
                              focusNode: _focusNodes[i],
                              onChanged: (val) {
                                if (_otpError != null) setState(() => _otpError = null);
                                if (val.length == 1 && i < 5) {
                                  _focusNodes[i + 1].requestFocus();
                                } else if (val.isEmpty && i > 0) {
                                  _focusNodes[i - 1].requestFocus();
                                }
                              },
                              onBackspace: () {
                                if (i > 0 &&
                                    _controllers[i].text.isEmpty) {
                                  _controllers[i - 1].clear();
                                  _focusNodes[i - 1].requestFocus();
                                }
                              },
                            ),
                          ),
                        ),

                        if (_otpError != null) ...[
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline_rounded,
                                  size: 13, color: Color(0xFFDC2626)),
                              const SizedBox(width: 4),
                              Text(
                                _otpError!,
                                style: GoogleFonts.poppins(
                                  fontSize: 11.5,
                                  color: const Color(0xFFDC2626),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],

                        const SizedBox(height: 28),

                        // ── Resend timer ──────────────────────────────────
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
                                'Resend OTP in ',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: _timerGrey,
                                ),
                              ),
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
                            onTap: (canResend && !_isResending) ? _resend : null,
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
                                    'Resend via SMS',
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

                // ── Bottom: Verify button + security strip ────────────────
                Padding(
                  padding: EdgeInsets.fromLTRB(
                      16, 12, 16, mq.padding.bottom > 0 ? 8 : 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [

                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: _isVerifying ? null : _handleVerify,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _greenBtn,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
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
                              'Your transactions are secured by 256-bit AES encryption.',
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
    final boxWidth =
        (MediaQuery.of(context).size.width - 48 - 40) / 6;

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
              borderSide:
                  const BorderSide(color: _otpFocusBorder, width: 2),
            ),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ),
    );
  }
}