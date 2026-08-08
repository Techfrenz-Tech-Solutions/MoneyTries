import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../routes/app_routes.dart';
import '../../data/security/security_repository.dart';
import '../../utils/responsive.dart';

// ── Palette (matches Moneytries theme) ───────────────────────────────────────
const _bgColor = Color(0xFFF7F5F2);
const _brandGreen = Color(0xFF4CAF7D);
const _titleColor = Color(0xFF111827);
const _subtitleColor = Color(0xFF6B7280);
const _dotEmpty = Color(0xFFD9D5CF);
const _dotFilled = Color(0xFF4CAF7D);
const _keyBg = Color(0xFFFFFFFF);
const _keyText = Color(0xFF111827);
const _keyShadow = Color(0x14000000);
const _confirmBtnBg = Color(0xFFE8F5EE);
const _confirmBtnText = Color(0xFF6B7280);
const _confirmActive = Color(0xFF4CAF7D);
const _confirmActiveTx = Color(0xFFFFFFFF);
const _iconCircleBg = Color(0xFFFFFFFF);

class SecurityPinScreen extends StatefulWidget {
  const SecurityPinScreen({super.key});

  @override
  State<SecurityPinScreen> createState() => _SecurityPinScreenState();
}

class _SecurityPinScreenState extends State<SecurityPinScreen>
    with SingleTickerProviderStateMixin {
  final List<int> _pin = [];
  static const int _pinLength = 4;

  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnim = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.elasticIn));
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    super.dispose();
  }

  void _onKey(int digit) {
    if (_pin.length >= _pinLength) return;
    setState(() => _pin.add(digit));
  }

  void _onDelete() {
    if (_pin.isEmpty) return;
    setState(() => _pin.removeLast());
  }

  void _onConfirm() async {
    if (_pin.length < _pinLength) {
      _shakeCtrl.forward(from: 0);
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('logged_in_user_id') ?? '';
    final pinStr = _pin.join();
    await prefs.setString('app_pin_$userId', pinStr);
    unawaited(SecurityRepository().setLoginPinRemote(newPin: pinStr));
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    final bool pinComplete = _pin.length == _pinLength;

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
              children: [
                // ── Top bar ──────────────────────────────────────────────
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 20.w,
                    vertical: 14.h,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: GestureDetector(
                          onTap: () => Navigator.maybePop(context),
                          child: Icon(
                            Icons.arrow_back_rounded,
                            size: 22.sp,
                            color: _brandGreen,
                          ),
                        ),
                      ),
                      Text(
                        'Moneytries',
                        style: TextStyle(
                          fontFamily: 'Times New Roman',
                          fontSize: 20.sp,
                          fontWeight: FontWeight.w800,
                          color: _brandGreen,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 28.h),

                // ── Shield / lock icon circle ────────────────────────────
                Container(
                  width: 80.w,
                  height: 80.h,
                  decoration: BoxDecoration(
                    color: _iconCircleBg,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned(
                        left: 22.w,
                        top: 32.h,
                        child: Container(
                          width: 10.w,
                          height: 10.h,
                          decoration: const BoxDecoration(
                            color: _brandGreen,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      Positioned(
                        right: 20.w,
                        top: 28.h,
                        child: Icon(
                          Icons.lock_outline_rounded,
                          size: 22.sp,
                          color: _brandGreen,
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 24.h),

                // ── Title ────────────────────────────────────────────────
                Text(
                  'Set Your App PIN',
                  style: TextStyle(
                    fontFamily: 'Times New Roman',
                    fontSize: 24.sp,
                    fontWeight: FontWeight.w800,
                    color: _titleColor,
                    letterSpacing: -0.4,
                    height: 1.15,
                  ),
                ),

                SizedBox(height: 8.h),

                // ── Subtitle ─────────────────────────────────────────────
                Text(
                  'You\'ll enter this 4-digit PIN\nevery time you open the app',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Times New Roman',
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w400,
                    color: _subtitleColor,
                    height: 1.5,
                  ),
                ),

                SizedBox(height: 28.h),

                // ── 4 PIN dots ───────────────────────────────────────────
                AnimatedBuilder(
                  animation: _shakeAnim,
                  builder: (context, child) {
                    final double offset = _shakeCtrl.isAnimating
                        ? 8 * (0.5 - _shakeAnim.value).abs() * 2
                        : 0;
                    return Transform.translate(
                      offset: Offset(
                        offset *
                            ((_shakeAnim.value * 10).toInt().isEven ? 1 : -1),
                        0,
                      ),
                      child: child,
                    );
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_pinLength, (i) {
                      final filled = i < _pin.length;
                      return Container(
                        margin: EdgeInsets.symmetric(horizontal: 10.w),
                        width: 18.w,
                        height: 18.h,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: filled ? _dotFilled : Colors.transparent,
                          border: Border.all(
                            color: filled ? _dotFilled : _dotEmpty,
                            width: 1.8.r,
                          ),
                        ),
                      );
                    }),
                  ),
                ),

                SizedBox(height: 32.h),

                // ── Number pad ───────────────────────────────────────────
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    child: Column(
                      children: [
                        _KeyRow(keys: const [1, 2, 3], onKey: _onKey),
                        SizedBox(height: 12.h),
                        _KeyRow(keys: const [4, 5, 6], onKey: _onKey),
                        SizedBox(height: 12.h),
                        _KeyRow(keys: const [7, 8, 9], onKey: _onKey),
                        SizedBox(height: 12.h),
                        Row(
                          children: [
                            const Expanded(child: SizedBox()),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: _KeyButton(
                                onTap: () => _onKey(0),
                                child: Text(
                                  '0',
                                  style: TextStyle(
                                    fontFamily: 'Times New Roman',
                                    fontSize: 26.sp,
                                    fontWeight: FontWeight.w600,
                                    color: _keyText,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: _KeyButton(
                                onTap: _onDelete,
                                child: Icon(
                                  Icons.backspace_outlined,
                                  size: 22.sp,
                                  color: _keyText,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 20.h),

                        // ── Confirm PIN button ────────────────────────────
                        SizedBox(
                          width: double.infinity,
                          height: 54.h,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              color: pinComplete
                                  ? _confirmActive
                                  : _confirmBtnBg,
                              borderRadius: BorderRadius.circular(30.r),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(30.r),
                                onTap: _onConfirm,
                                child: Center(
                                  child: Text(
                                    'Confirm PIN',
                                    style: TextStyle(
                                      fontFamily: 'Times New Roman',
                                      fontSize: 16.sp,
                                      fontWeight: FontWeight.w600,
                                      color: pinComplete
                                          ? _confirmActiveTx
                                          : _confirmBtnText,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 16.h),
                      ],
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

// ── A row of 3 digit key buttons ──────────────────────────────────────────────
class _KeyRow extends StatelessWidget {
  final List<int> keys;
  final ValueChanged<int> onKey;

  const _KeyRow({required this.keys, required this.onKey});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: keys
          .expand(
            (k) => [
              Expanded(
                child: _KeyButton(
                  onTap: () => onKey(k),
                  child: Text(
                    '$k',
                    style: TextStyle(
                      fontFamily: 'Times New Roman',
                      fontSize: 26.sp,
                      fontWeight: FontWeight.w600,
                      color: _keyText,
                    ),
                  ),
                ),
              ),
              if (k != keys.last) SizedBox(width: 12.w),
            ],
          )
          .toList(),
    );
  }
}

// ── Single key button ─────────────────────────────────────────────────────────
class _KeyButton extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;

  const _KeyButton({required this.child, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72.h,
      decoration: BoxDecoration(
        color: _keyBg,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: const [
          BoxShadow(color: _keyShadow, blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16.r),
        child: InkWell(
          borderRadius: BorderRadius.circular(16.r),
          splashColor: const Color(0xFFE8F5EE),
          highlightColor: const Color(0xFFF0FAF4),
          onTap: onTap,
          child: Center(child: child),
        ),
      ),
    );
  }
}
