// lib/views/profile/change_login_pin_screen.dart
//
// Security Settings → PIN & Authentication → Change PIN (account Login PIN)
//
// Flow:
//   1. ChangeLoginPinScreen   — user enters their CURRENT 4-digit Login PIN.
//      It's verified against the backend (bcrypt). Wrong attempts are
//      tracked server-side; after 5 wrong attempts the feature locks for
//      5 minutes with a live countdown. All of this is enforced by the
//      backend so it cannot be bypassed by restarting the app or clearing
//      local storage.
//   2. SetNewLoginPinScreen   — pushed only after a successful verification.
//      User enters a New PIN, then confirms it; submitted to the backend
//      which re-hashes it with bcrypt and syncs it to every device on the
//      account.
//
// Premium palette: light green, light brown, white and soft beige.

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/security/security_viewmodel.dart';
import '../../utils/responsive.dart';

// ── Palette (premium light green / light brown / white / soft beige) ───────
const _bgColor = Color(0xFFF7F5F2); // soft beige
const _white = Color(0xFFFFFFFF);
const _titleDark = Color(0xFF2B2620);
const _subtitleGrey = Color(0xFF7A7266);
const _brandGreen = Color(0xFF4CAF7D); // light/premium green
const _brandGreenDark = Color(0xFF357A56);
const _iconBg = Color(0xFFE7F3EC); // pale green tint
const _brownAccentBg = Color(0xFFF3E9DC); // soft light-brown tint
const _brownAccentBorder = Color(0xFFE2CDAE);
const _brownAccentText = Color(0xFF8A6A3F); // light brown
const _dotEmpty = Color(0xFFDCD3C4); // soft beige-brown
const _dotFilled = Color(0xFF4CAF7D);
const _lockBg = Color(0xFFF6EDE3); // warm beige-brown
const _lockAccent = Color(0xFFA9663B); // muted light-brown/terracotta
const _errorRed = Color(0xFFC0533A); // warm, palette-friendly error tone
const _keyBg = Color(0xFFFFFFFF);
const _keyShadow = Color(0x14000000);
const _keyText = Color(0xFF2B2620);

// ══════════════════════════════════════════════════════════════════════════
// ENTRY POINT — Step 1: verify current Login PIN
// ══════════════════════════════════════════════════════════════════════════
class ChangeLoginPinScreen extends StatelessWidget {
  const ChangeLoginPinScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SecurityViewModel()
        ..resetChangeLoginPinFlow()
        ..loadLoginPinChangeStatus(),
      child: const _VerifyCurrentLoginPinBody(),
    );
  }
}

class _VerifyCurrentLoginPinBody extends StatefulWidget {
  const _VerifyCurrentLoginPinBody();

  @override
  State<_VerifyCurrentLoginPinBody> createState() =>
      _VerifyCurrentLoginPinBodyState();
}

class _VerifyCurrentLoginPinBodyState
    extends State<_VerifyCurrentLoginPinBody>
    with SingleTickerProviderStateMixin {
  bool _navigated = false;

  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeCtrl, curve: Curves.elasticIn),
    );
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    super.dispose();
  }

  Future<void> _onKey(SecurityViewModel vm, int digit) async {
    vm.loginPinKeyPress(digit);
    if (vm.currentLoginPinEntry.length == SecurityViewModel.pinLength) {
      await _submit(vm);
    }
  }

  Future<void> _submit(SecurityViewModel vm) async {
    final success = await vm.verifyCurrentLoginPinStep();
    if (!success) {
      _shakeCtrl.forward(from: 0);
      return;
    }
    if (!mounted || _navigated) return;
    _navigated = true;
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: vm,
          child: const SetNewLoginPinScreen(),
        ),
      ),
    );
    _navigated = false;
    if (result == true && mounted) {
      // PIN was changed successfully — go straight back to Security
      // Settings instead of leaving the user on this "Enter Current PIN"
      // screen.
      Navigator.of(context).pop();
      return;
    }
    // Coming back without success (e.g. user pressed back) — let them
    // re-verify from a clean slate rather than reusing stale entry.
    if (result != true && mounted) {
      vm.resetChangeLoginPinFlow();
      vm.loadLoginPinChangeStatus();
    }
  }

  String _formatCountdown(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SecurityViewModel>();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _bgColor,
        appBar: AppBar(
          backgroundColor: _bgColor,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: _titleDark,
              size: 20.sp,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Change PIN',
            style: TextStyle(
              fontFamily: GoogleFonts.inter().fontFamily,
              fontSize: 17.sp,
              fontWeight: FontWeight.w700,
              color: _titleDark,
            ),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: vm.isLoginPinChangeLocked
              ? SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(20.w, 24.h, 20.w, 24.h),
                  child: _LockedCard(
                    countdown: _formatCountdown(vm.loginPinLockSecondsLeft),
                  ),
                )
              : Column(
                  children: [
                    SizedBox(height: 12.h),
                    Container(
                      width: 64.w,
                      height: 64.h,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: _iconBg,
                      ),
                      child: Icon(
                        Icons.lock_open_rounded,
                        size: 30.sp,
                        color: _brandGreenDark,
                      ),
                    ),
                    SizedBox(height: 20.h),
                    Text(
                      'Enter Current PIN',
                      style: TextStyle(
                        fontFamily: GoogleFonts.inter().fontFamily,
                        fontSize: 21.sp,
                        fontWeight: FontWeight.w800,
                        color: _titleDark,
                        letterSpacing: -0.3,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 32.w),
                      child: Text(
                        'For your security, confirm your current 4-digit '
                        'Login PIN before setting a new one.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: GoogleFonts.inter().fontFamily,
                          fontSize: 13.5.sp,
                          fontWeight: FontWeight.w400,
                          color: _subtitleGrey,
                          height: 1.5,
                        ),
                      ),
                    ),
                    SizedBox(height: 32.h),
                    AnimatedBuilder(
                      animation: _shakeAnim,
                      builder: (context, child) {
                        final double offset = _shakeCtrl.isAnimating
                            ? 8 * (0.5 - _shakeAnim.value).abs() * 2
                            : 0;
                        return Transform.translate(
                          offset: Offset(
                            offset *
                                ((_shakeAnim.value * 10).toInt().isEven
                                    ? 1
                                    : -1),
                            0,
                          ),
                          child: child,
                        );
                      },
                      child: _PinDots(
                        length: SecurityViewModel.pinLength,
                        filled: vm.currentLoginPinEntry.length,
                      ),
                    ),
                    if (vm.loginPinChangeError != null) ...[
                      SizedBox(height: 12.h),
                      Text(
                        vm.loginPinChangeError!,
                        style: TextStyle(
                          fontFamily: GoogleFonts.inter().fontFamily,
                          fontSize: 12.5.sp,
                          fontWeight: FontWeight.w600,
                          color: _errorRed,
                        ),
                      ),
                    ],
                    if (vm.loginPinChangeError == null &&
                        vm.remainingLoginPinAttempts <
                            SecurityViewModel.loginPinChangeMaxAttempts) ...[
                      SizedBox(height: 12.h),
                      _AttemptsNotice(remaining: vm.remainingLoginPinAttempts),
                    ],
                    const Spacer(),
                    _NumPad(
                      onKey: (d) => _onKey(vm, d),
                      onDelete: vm.loginPinDelete,
                      isLoading: vm.isVerifyingLoginPin,
                    ),
                    SizedBox(height: 20.h),
                  ],
                ),
        ),
      ),
    );
  }
}

// ── Remaining attempts notice (light-brown accent) ──────────────────────────
class _AttemptsNotice extends StatelessWidget {
  final int remaining;
  const _AttemptsNotice({required this.remaining});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24.w),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: _brownAccentBg,
          border: Border.all(color: _brownAccentBorder, width: 1.r),
          borderRadius: BorderRadius.circular(10.r),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline_rounded, size: 16.sp, color: _brownAccentText),
            SizedBox(width: 8.w),
            Expanded(
              child: Text(
                remaining > 0
                    ? '$remaining attempt${remaining == 1 ? '' : 's'} remaining '
                        'before Change PIN is temporarily locked.'
                    : 'Change PIN will lock after the next incorrect attempt.',
                style: TextStyle(
                  fontFamily: GoogleFonts.inter().fontFamily,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: _brownAccentText,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Locked state card with live countdown ───────────────────────────────────
class _LockedCard extends StatelessWidget {
  final String countdown;
  const _LockedCard({required this.countdown});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(height: 24.h),
        Container(
          width: 76.w,
          height: 76.h,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: _lockBg,
          ),
          child: Icon(Icons.lock_clock_rounded, size: 36.sp, color: _lockAccent),
        ),
        SizedBox(height: 22.h),
        Text(
          'Change PIN Locked',
          style: TextStyle(
            fontFamily: GoogleFonts.inter().fontFamily,
            fontSize: 20.sp,
            fontWeight: FontWeight.w800,
            color: _titleDark,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 8.h),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w),
          child: Text(
            'Too many incorrect attempts. For your account\'s security, '
            'please wait before trying again.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: GoogleFonts.inter().fontFamily,
              fontSize: 13.5.sp,
              fontWeight: FontWeight.w400,
              color: _subtitleGrey,
              height: 1.5,
            ),
          ),
        ),
        SizedBox(height: 28.h),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 28.w, vertical: 16.h),
          decoration: BoxDecoration(
            color: _white,
            borderRadius: BorderRadius.circular(18.r),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Text(
                'Try again in',
                style: TextStyle(
                  fontFamily: GoogleFonts.inter().fontFamily,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                  color: _subtitleGrey,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                countdown,
                style: TextStyle(
                  fontFamily: GoogleFonts.inter().fontFamily,
                  fontSize: 34.sp,
                  fontWeight: FontWeight.w800,
                  color: _lockAccent,
                  letterSpacing: 1.5,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// STEP 2 — Set new Login PIN (new → confirm)
// ══════════════════════════════════════════════════════════════════════════
class SetNewLoginPinScreen extends StatefulWidget {
  const SetNewLoginPinScreen({super.key});

  @override
  State<SetNewLoginPinScreen> createState() => _SetNewLoginPinScreenState();
}

class _SetNewLoginPinScreenState extends State<SetNewLoginPinScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeCtrl, curve: Curves.elasticIn),
    );
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    super.dispose();
  }

  Future<void> _onKey(SecurityViewModel vm, int digit) async {
    vm.newLoginPinKeyPress(digit);
    if (vm.activeNewLoginPinEntry.length == SecurityViewModel.pinLength) {
      final success = await vm.newLoginPinConfirm();
      if (!success && vm.loginPinChangeError != null) {
        _shakeCtrl.forward(from: 0);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SecurityViewModel>();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.of(context).pop(vm.loginPinChanged);
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: Scaffold(
          backgroundColor: _bgColor,
          appBar: AppBar(
            backgroundColor: _bgColor,
            elevation: 0,
            automaticallyImplyLeading: false,
            leading: vm.loginPinChanged
                ? null
                : IconButton(
                    icon: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: _titleDark,
                      size: 20.sp,
                    ),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
            title: Text(
              'New PIN',
              style: TextStyle(
                fontFamily: GoogleFonts.inter().fontFamily,
                fontSize: 17.sp,
                fontWeight: FontWeight.w700,
                color: _titleDark,
              ),
            ),
            centerTitle: true,
          ),
          body: SafeArea(
            child: vm.loginPinChanged
                ? _SuccessView(onDone: () => Navigator.of(context).pop(true))
                : Column(
                    children: [
                      SizedBox(height: 12.h),
                      Container(
                        width: 64.w,
                        height: 64.h,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: _iconBg,
                        ),
                        child: Icon(
                          vm.newLoginPinStep == 0
                              ? Icons.lock_outline_rounded
                              : Icons.lock_rounded,
                          size: 30.sp,
                          color: _brandGreenDark,
                        ),
                      ),
                      SizedBox(height: 20.h),
                      Text(
                        vm.newLoginPinTitle,
                        style: TextStyle(
                          fontFamily: GoogleFonts.inter().fontFamily,
                          fontSize: 21.sp,
                          fontWeight: FontWeight.w800,
                          color: _titleDark,
                          letterSpacing: -0.3,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 32.w),
                        child: Text(
                          vm.newLoginPinSubtitle,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: GoogleFonts.inter().fontFamily,
                            fontSize: 13.5.sp,
                            fontWeight: FontWeight.w400,
                            color: _subtitleGrey,
                            height: 1.5,
                          ),
                        ),
                      ),
                      SizedBox(height: 32.h),
                      AnimatedBuilder(
                        animation: _shakeAnim,
                        builder: (context, child) {
                          final double offset = _shakeCtrl.isAnimating
                              ? 8 * (0.5 - _shakeAnim.value).abs() * 2
                              : 0;
                          return Transform.translate(
                            offset: Offset(
                              offset *
                                  ((_shakeAnim.value * 10).toInt().isEven
                                      ? 1
                                      : -1),
                              0,
                            ),
                            child: child,
                          );
                        },
                        child: _PinDots(
                          length: SecurityViewModel.pinLength,
                          filled: vm.activeNewLoginPinEntry.length,
                        ),
                      ),
                      if (vm.loginPinChangeError != null) ...[
                        SizedBox(height: 12.h),
                        Text(
                          vm.loginPinChangeError!,
                          style: TextStyle(
                            fontFamily: GoogleFonts.inter().fontFamily,
                            fontSize: 12.5.sp,
                            fontWeight: FontWeight.w600,
                            color: _errorRed,
                          ),
                        ),
                      ],
                      const Spacer(),
                      _NumPad(
                        onKey: (d) => _onKey(vm, d),
                        onDelete: vm.newLoginPinDelete,
                        isLoading: vm.isUpdatingLoginPin,
                      ),
                      SizedBox(height: 20.h),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

// ── Success view ──────────────────────────────────────────────────────────────
class _SuccessView extends StatelessWidget {
  final VoidCallback onDone;
  const _SuccessView({required this.onDone});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 28.w),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 84.w,
            height: 84.h,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: _iconBg,
            ),
            child: Icon(
              Icons.check_circle_rounded,
              size: 46.sp,
              color: _brandGreenDark,
            ),
          ),
          SizedBox(height: 24.h),
          Text(
            'PIN Changed',
            style: TextStyle(
              fontFamily: GoogleFonts.inter().fontFamily,
              fontSize: 21.sp,
              fontWeight: FontWeight.w800,
              color: _titleDark,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'Your Login PIN was updated successfully. '
            'Use your new PIN the next time you unlock the app.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: GoogleFonts.inter().fontFamily,
              fontSize: 13.5.sp,
              fontWeight: FontWeight.w400,
              color: _subtitleGrey,
              height: 1.5,
            ),
          ),
          SizedBox(height: 32.h),
          SizedBox(
            width: double.infinity,
            height: 54.h,
            child: ElevatedButton(
              onPressed: onDone,
              style: ElevatedButton.styleFrom(
                backgroundColor: _brandGreen,
                foregroundColor: _white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30.r),
                ),
              ),
              child: Text(
                'Done',
                style: TextStyle(
                  fontFamily: GoogleFonts.inter().fontFamily,
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w700,
                  color: _white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// SHARED — PIN dots + number pad (self-contained, premium palette)
// ══════════════════════════════════════════════════════════════════════════
class _PinDots extends StatelessWidget {
  final int length;
  final int filled;
  const _PinDots({required this.length, required this.filled});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(length, (i) {
        final isFilled = i < filled;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: EdgeInsets.symmetric(horizontal: 10.w),
          width: 18.w,
          height: 18.h,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isFilled ? _dotFilled : Colors.transparent,
            border: Border.all(
              color: isFilled ? _dotFilled : _dotEmpty,
              width: 1.8.r,
            ),
          ),
        );
      }),
    );
  }
}

class _NumPad extends StatelessWidget {
  final ValueChanged<int> onKey;
  final VoidCallback onDelete;
  final bool isLoading;

  const _NumPad({
    required this.onKey,
    required this.onDelete,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return AbsorbPointer(
      absorbing: isLoading,
      child: Opacity(
        opacity: isLoading ? 0.5 : 1,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Column(
            children: [
              _KeyRow(keys: const [1, 2, 3], onKey: onKey),
              SizedBox(height: 12.h),
              _KeyRow(keys: const [4, 5, 6], onKey: onKey),
              SizedBox(height: 12.h),
              _KeyRow(keys: const [7, 8, 9], onKey: onKey),
              SizedBox(height: 12.h),
              Row(
                children: [
                  const Expanded(child: SizedBox()),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: _KeyButton(
                      onTap: () => onKey(0),
                      child: Text(
                        '0',
                        style: TextStyle(
                          fontFamily: GoogleFonts.inter().fontFamily,
                          fontSize: 26.sp,
                          fontWeight: FontWeight.w600,
                          color: _keyText,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: isLoading
                        ? Center(
                            child: SizedBox(
                              width: 22.w,
                              height: 22.h,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: _brandGreenDark,
                              ),
                            ),
                          )
                        : _KeyButton(
                            onTap: onDelete,
                            child: Icon(
                              Icons.backspace_outlined,
                              size: 22.sp,
                              color: _keyText,
                            ),
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
                      fontFamily: GoogleFonts.inter().fontFamily,
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

class _KeyButton extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;

  const _KeyButton({required this.child, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 68.h,
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
          splashColor: _iconBg,
          highlightColor: _brownAccentBg,
          onTap: onTap,
          child: Center(child: child),
        ),
      ),
    );
  }
}