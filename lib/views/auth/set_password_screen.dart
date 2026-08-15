import 'package:flutter/material.dart';
import 'package:moneytries/config/app_fonts.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../routes/app_routes.dart';
import '../../data/security/security_repository.dart';
import '../../utils/responsive.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _bg = Color(0xFFF7F5F2);
const _brandGreen = Color(0xFF4CAF7D);
const _titleColor = Color(0xFF111827);
const _subtitleClr = Color(0xFF6B7280);
const _dotEmpty = Color(0xFFD9D5CF);
const _dotFilled = Color(0xFF4CAF7D);
const _keyBg = Color(0xFFFFFFFF);
const _keyText = Color(0xFF111827);
const _errorRed = Color(0xFFDC2626);

enum _Step { enter, confirm }

class SetPasswordScreen extends StatefulWidget {
  const SetPasswordScreen({super.key});
  @override
  State<SetPasswordScreen> createState() => _SetPasswordScreenState();
}

class _SetPasswordScreenState extends State<SetPasswordScreen>
    with SingleTickerProviderStateMixin {
  static const int _pinLen = 4;

  _Step _step = _Step.enter;
  final List<int> _pin = [];
  final List<int> _confirm = [];
  String? _error;
  bool _saving = false;

  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
    _shakeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 14.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 14.0, end: -14.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -14.0, end: 10.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 10.0, end: -10.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -10.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.linear));
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    super.dispose();
  }

  List<int> get _active => _step == _Step.enter ? _pin : _confirm;

  void _onKey(int digit) {
    if (_active.length >= _pinLen) return;
    setState(() {
      _active.add(digit);
      _error = null;
    });
    if (_active.length == _pinLen) {
      Future.delayed(const Duration(milliseconds: 150), _handleComplete);
    }
  }

  void _onDelete() {
    if (_active.isEmpty) return;
    setState(() {
      _active.removeLast();
      _error = null;
    });
  }

  void _handleComplete() {
    if (_step == _Step.enter) {
      setState(() {
        _step = _Step.confirm;
        _error = null;
      });
    } else {
      if (_listEquals(_pin, _confirm)) {
        _savePinAndContinue();
      } else {
        _shakeCtrl.forward(from: 0).then((_) {
          setState(() {
            _confirm.clear();
            _error = 'PINs do not match. Try again.';
          });
        });
      }
    }
  }

  bool _listEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Future<void> _savePinAndContinue() async {
    setState(() => _saving = true);
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('logged_in_user_id') ?? '';
    final pinStr = _pin.join();
    await prefs.setString('app_pin_$userId', pinStr);
    await prefs.setString('app_password_set_$userId', 'true');
    unawaited(SecurityRepository().setLoginPinRemote(newPin: pinStr));
    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.pushReplacementNamed(context, AppRoutes.home);
  }

  void _goBack() {
    if (_step == _Step.confirm) {
      setState(() {
        _step = _Step.enter;
        _pin.clear();
        _confirm.clear();
        _error = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isConfirm = _step == _Step.confirm;
    final current = _active;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: Column(
            children: [
              // ── Top bar ────────────────────────────────────────────────
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 14.h),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (isConfirm)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: GestureDetector(
                          onTap: _goBack,
                          child: Icon(
                            Icons.arrow_back_rounded,
                            size: 22.sp,
                            color: _brandGreen,
                          ),
                        ),
                      ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.shield_rounded,
                          size: 20.sp,
                          color: _brandGreen,
                        ),
                        SizedBox(width: 6.w),
                        Text(
                          'Moneytries',
                          style: TextStyle(
                            fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                            fontSize: 20.sp,
                            fontWeight: FontWeight.w800,
                            color: _brandGreen,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              SizedBox(height: 28.h),

              // ── Lock icon ──────────────────────────────────────────────
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Container(
                  key: ValueKey(isConfirm),
                  width: 80.w,
                  height: 80.h,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Icon(
                    isConfirm
                        ? Icons.lock_reset_rounded
                        : Icons.lock_outline_rounded,
                    size: 36.sp,
                    color: _brandGreen,
                  ),
                ),
              ),

              SizedBox(height: 22.h),

              // ── Title + subtitle ───────────────────────────────────────
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: Column(
                  key: ValueKey(isConfirm),
                  children: [
                    Text(
                      isConfirm ? 'Confirm Your PIN' : 'Set Your PIN',
                      style: TextStyle(
                        fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                        fontSize: 24.sp,
                        fontWeight: FontWeight.w800,
                        color: _titleColor,
                        letterSpacing: -0.4,
                        height: 1.15,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      isConfirm
                          ? 'Re-enter your 4-digit PIN to confirm'
                          : 'Enter a 4-digit PIN — you\'ll use this\nevery time you open the app',
                      style: TextStyle(
                        fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                        fontSize: 13.5.sp,
                        color: _subtitleClr,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              SizedBox(height: 36.h),

              // ── Step indicator ─────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _StepDot(active: !isConfirm, done: isConfirm),
                  SizedBox(width: 8.w),
                  _StepDot(active: isConfirm, done: false),
                ],
              ),

              SizedBox(height: 28.h),

              // ── PIN dots ───────────────────────────────────────────────
              AnimatedBuilder(
                animation: _shakeAnim,
                builder: (_, child) => Transform.translate(
                  offset: Offset(_shakeAnim.value, 0),
                  child: child,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_pinLen, (i) {
                    final filled = i < current.length;
                    final hasErr = _error != null;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: EdgeInsets.symmetric(horizontal: 12.w),
                      width: 20.w,
                      height: 20.h,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: filled
                            ? (hasErr ? _errorRed : _dotFilled)
                            : Colors.transparent,
                        border: Border.all(
                          color: filled
                              ? (hasErr ? _errorRed : _dotFilled)
                              : _dotEmpty,
                          width: 2.r,
                        ),
                      ),
                    );
                  }),
                ),
              ),

              SizedBox(height: 16.h),

              // ── Error ──────────────────────────────────────────────────
              AnimatedOpacity(
                opacity: _error != null ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 32.w),
                  child: Text(
                    _error ?? '',
                    style: TextStyle(
                      fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                      fontSize: 12.5.sp,
                      color: _errorRed,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),

              const Spacer(),

              // ── Keypad ─────────────────────────────────────────────────
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 32.w),
                child: Column(
                  children: [
                    _KeyRow(keys: const [1, 2, 3], onKey: _onKey),
                    SizedBox(height: 14.h),
                    _KeyRow(keys: const [4, 5, 6], onKey: _onKey),
                    SizedBox(height: 14.h),
                    _KeyRow(keys: const [7, 8, 9], onKey: _onKey),
                    SizedBox(height: 14.h),
                    Row(
                      children: [
                        const Expanded(child: SizedBox()),
                        SizedBox(width: 14.w),
                        Expanded(
                          child: _KeyButton(
                            onTap: () => _onKey(0),
                            child: Text(
                              '0',
                              style: TextStyle(
                                fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                                fontSize: 26.sp,
                                fontWeight: FontWeight.w600,
                                color: _keyText,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 14.w),
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

                    // Saving indicator
                    if (_saving)
                      SizedBox(
                        height: 28.h,
                        width: 28.w,
                        child: CircularProgressIndicator(
                          color: _brandGreen,
                          strokeWidth: 2.5,
                        ),
                      ),

                    SizedBox(height: 16.h),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Step dot indicator ────────────────────────────────────────────────────────
class _StepDot extends StatelessWidget {
  final bool active;
  final bool done;
  const _StepDot({required this.active, required this.done});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: active ? 24.w : 10.w,
      height: 10.h,
      decoration: BoxDecoration(
        color: done || active ? _brandGreen : _dotEmpty,
        borderRadius: BorderRadius.circular(5.r),
      ),
    );
  }
}

// ── Key row ───────────────────────────────────────────────────────────────────
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
                      fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                      fontSize: 26.sp,
                      fontWeight: FontWeight.w600,
                      color: _keyText,
                    ),
                  ),
                ),
              ),
              if (k != keys.last) SizedBox(width: 14.w),
            ],
          )
          .toList(),
    );
  }
}

// ── Key button ────────────────────────────────────────────────────────────────
class _KeyButton extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  const _KeyButton({required this.child, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70.h,
      decoration: BoxDecoration(
        color: _keyBg,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
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
