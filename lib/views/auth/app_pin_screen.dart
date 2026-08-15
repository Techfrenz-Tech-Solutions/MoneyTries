import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:moneytries/config/app_fonts.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../routes/app_routes.dart';
import '../../services/biometric_auth_service.dart';
import '../../services/pin_lockout_service.dart';
import '../../services/push_notification_service.dart';
import '../../data/security/security_repository.dart';
import '../../utils/responsive.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _bg = Color(0xFFF7F5F2);
const _brandGreen = Color(0xFF4CAF7D);
const _titleColor = Color(0xFF111827);
const _subtitleColor = Color(0xFF6B7280);
const _dotEmpty = Color(0xFFD9D5CF);
const _dotFilled = Color(0xFF4CAF7D);
const _keyBg = Color(0xFFFFFFFF);
const _keyText = Color(0xFF111827);
const _errorRed = Color(0xFFDC2626);

class AppPinScreen extends StatefulWidget {
  const AppPinScreen({super.key});
  @override
  State<AppPinScreen> createState() => _AppPinScreenState();
}

class _AppPinScreenState extends State<AppPinScreen>
    with SingleTickerProviderStateMixin {
  final List<int> _pin = [];
  static const int _pinLength = 4;
  // Every PIN screen shares one lockout policy (5 wrong attempts → 5 minute
  // cooldown) via PinLockoutService; 'login' keeps this scope's counter
  // separate from the withdrawal PIN's.
  static const String _lockScope = 'login';

  bool _locked = false;
  Duration _lockRemaining = Duration.zero;
  Timer? _countdownTimer;
  String? _error;
  String _accountLabel = '';

  // ── Biometrics ────────────────────────────────────────────────────────────
  bool _biometricsEnabled = false;
  bool _biometricsAvailable = false;
  bool _isAuthenticatingBiometric = false;

  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();
    _loadAccountLabel();
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shakeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: 12), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 12, end: -12), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -12, end: 8), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8, end: -8), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -8, end: 0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.linear));
    // Check for an existing (persisted) lockout before deciding whether to
    // auto-prompt biometrics — a locked-out user shouldn't get a biometric
    // shortcut around the cooldown.
    _checkLockout(andThenInitBiometrics: true);
  }

  // ── Lockout handling ──────────────────────────────────────────────────────

  // Loads any in-progress lockout for this PIN scope from disk (it survives
  // app restarts) and, if one is active, starts the live countdown. If
  // [andThenInitBiometrics] is true and the scope turns out to NOT be
  // locked, kicks off the normal biometric-prompt flow afterwards.
  Future<void> _checkLockout({bool andThenInitBiometrics = false}) async {
    final until = await PinLockoutService.getLockedUntil(_lockScope);
    if (!mounted) return;

    if (until != null) {
      _beginCountdown(until);
    } else if (andThenInitBiometrics) {
      _initBiometrics();
    }
  }

  void _beginCountdown(DateTime until) {
    _countdownTimer?.cancel();
    setState(() {
      _locked = true;
      _lockRemaining = until.difference(DateTime.now());
      _error =
          'Too many attempts. Try again in ${PinLockoutService.formatCountdown(_lockRemaining)}.';
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      final remaining = until.difference(DateTime.now());
      if (!mounted) return;

      if (remaining <= Duration.zero) {
        timer.cancel();
        await PinLockoutService.reset(_lockScope);
        if (!mounted) return;
        setState(() {
          _locked = false;
          _lockRemaining = Duration.zero;
          _error = null;
        });
        return;
      }

      setState(() {
        _lockRemaining = remaining;
        _error =
            'Too many attempts. Try again in ${PinLockoutService.formatCountdown(remaining)}.';
      });
    });
  }

  // Loads a human-readable label (name/email/phone) for the account that is
  // currently locked behind this PIN screen, so it is always obvious *which*
  // account is being unlocked — this is what removes the ambiguity when two
  // different accounts happen to share the same PIN digits: the PIN is only
  // ever checked against this one, clearly-labelled, active session.
  Future<void> _loadAccountLabel() async {
    final prefs = await SharedPreferences.getInstance();
    final label = prefs.getString('logged_in_user_label') ?? '';
    if (mounted) setState(() => _accountLabel = label);
  }

  // Checks whether the device supports biometrics and whether the user has
  // turned the "Biometric Login" switch on in Security Settings. If both are
  // true, automatically prompts Face ID / fingerprint right away so unlocking
  // feels instant — falling back silently to manual PIN entry on any failure
  // or cancellation.
  Future<void> _initBiometrics() async {
    final available = await BiometricAuthService.isDeviceCapable();

    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('logged_in_user_id') ?? '';
    final enabled = await BiometricAuthService.isEnabledFor(userId);

    if (!mounted) return;
    setState(() {
      _biometricsAvailable = available;
      _biometricsEnabled = enabled;
    });

    if (available && enabled) {
      // Slight delay so the screen has finished its entrance transition
      // before the native biometric sheet pops up.
      await Future.delayed(const Duration(milliseconds: 350));
      if (mounted) _authenticateWithBiometrics(auto: true);
    }
  }

  Future<void> _authenticateWithBiometrics({bool auto = false}) async {
    if (!_biometricsAvailable || _locked || _isAuthenticatingBiometric) return;

    setState(() {
      _isAuthenticatingBiometric = true;
      _error = null;
    });

    String? errorMessage;
    final authenticated = await BiometricAuthService.authenticate(
      reason: 'Authenticate to unlock Moneytries',
      onError: (msg) => errorMessage = msg,
    );

    if (!mounted) return;

    if (authenticated) {
      // Refresh the device-remembered session so the full login screen's
      // "Quick Login with Biometrics" option always has this account's
      // latest token available too.
      await _rememberBiometricSession();
      // Also refresh this device's entry in Security Settings →
      // "Manage Devices" so its "last active" time stays current.
      final prefs = await SharedPreferences.getInstance();
      final currentToken = prefs.getString('auth_token') ?? '';
      if (currentToken.isNotEmpty) {
        unawaited(SecurityRepository().registerCurrentSession(currentToken));
        unawaited(PushNotificationService.instance.registerToken());
      }
      _recordUnlockEvent(success: true);
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, AppRoutes.home);
      return;
    }

    // Don't show an error for a silent auto-prompt cancellation — just
    // let the user fall back to the PIN pad without any noise.
    if (!auto) {
      setState(() {
        _error = errorMessage ?? 'Biometric authentication was cancelled.';
      });
    }
    if (mounted) setState(() => _isAuthenticatingBiometric = false);
  }

  // Records this app-unlock (biometric or PIN) as a Login Activity entry
  // so Security Settings → "Login Activity" reflects real, ongoing usage
  // instead of only the one-time full-credential login from install day.
  String get _unlockDeviceName => Platform.isAndroid
      ? 'Android Device'
      : Platform.isIOS
          ? 'iPhone'
          : 'Unknown Device';

  void _recordUnlockEvent({required bool success}) {
    unawaited(
      SecurityRepository().recordLoginEvent(
        deviceName: _unlockDeviceName,
        location: 'India',
        success: success,
      ),
    );
  }

  // Snapshots the current session (token/userId/label) as the device's
  // remembered biometric account, so the credentials screen can offer a
  // real quick-login option for it later without retyping the password.
  Future<void> _rememberBiometricSession() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('logged_in_user_id') ?? '';
    final token = prefs.getString('auth_token') ?? '';
    final label = prefs.getString('logged_in_user_label') ?? '';
    await BiometricAuthService.rememberSession(
      userId: userId,
      token: token,
      label: label,
    );
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _onKey(int digit) {
    if (_locked || _pin.length >= _pinLength) return;
    setState(() {
      _pin.add(digit);
      _error = null;
    });
    // Auto-submit when 4 digits are entered
    if (_pin.length == _pinLength) {
      Future.delayed(const Duration(milliseconds: 120), _verify);
    }
  }

  void _onDelete() {
    if (_pin.isEmpty) return;
    setState(() {
      _pin.removeLast();
      _error = null;
    });
  }

  Future<void> _verify() async {
    // Safety net: the keypad is disabled while _locked is true, but guard
    // here too in case a lockout began in another tab/isolate.
    final activeLockUntil = await PinLockoutService.getLockedUntil(_lockScope);
    if (activeLockUntil != null) {
      if (!mounted) return;
      setState(() => _pin.clear());
      _beginCountdown(activeLockUntil);
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('logged_in_user_id') ?? '';
    final saved = prefs.getString('app_pin_$userId') ?? '';
    final entered = _pin.join();

    bool matches;
    if (saved.isNotEmpty) {
      matches = entered == saved;
    } else {
      // No PIN cached on this device for this account — it may have been
      // set up on a different device. Verify against the account-level
      // PIN on the backend instead of failing outright, and cache it here
      // on success so future unlocks on this device work offline.
      matches = await SecurityRepository().verifyLoginPinRemote(entered);
      if (matches) {
        await prefs.setString('app_pin_$userId', entered);
      }
    }

    if (matches) {
      await PinLockoutService.reset(_lockScope);
      // Keep the device-remembered biometric session fresh whenever this
      // account unlocks successfully, even via the manual PIN pad, so a
      // later biometric quick-login from the credentials screen always has
      // an up-to-date token to validate.
      if (_biometricsAvailable && _biometricsEnabled) {
        await _rememberBiometricSession();
      }
      // Refresh this device's entry in Security Settings →
      // "Manage Devices" so its "last active" time stays current.
      final currentToken = prefs.getString('auth_token') ?? '';
      if (currentToken.isNotEmpty) {
        unawaited(SecurityRepository().registerCurrentSession(currentToken));
        unawaited(PushNotificationService.instance.registerToken());
      }
      _recordUnlockEvent(success: true);
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, AppRoutes.home);
    } else {
      await _shakeCtrl.forward(from: 0);
      if (!mounted) return;

      final lockUntil = await PinLockoutService.registerFailedAttempt(_lockScope);
      if (!mounted) return;

      if (lockUntil != null) {
        // Log the lockout itself as a failed sign-in attempt so Login
        // Activity surfaces suspicious/incorrect unlock attempts too, not
        // just successful ones.
        _recordUnlockEvent(success: false);
        setState(() => _pin.clear());
        _beginCountdown(lockUntil);
      } else {
        final attempts = await PinLockoutService.getAttempts(_lockScope);
        final remaining = PinLockoutService.remainingAttempts(attempts);
        if (!mounted) return;
        setState(() {
          _error =
              'Incorrect PIN. $remaining attempt${remaining == 1 ? '' : 's'} left.';
          _pin.clear();
        });
      }
    }
  }

  void _usePassword() async {
    // Treat "Use Password" as leaving this account's locked session — clear
    // it so the app doesn't keep bouncing back to this account's PIN lock
    // the next time it's opened. The account's saved PIN itself is left
    // intact for next time someone logs back into it.
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('logged_in_user_id');
    await prefs.remove('logged_in_user_label');

    if (!mounted) return;
    Navigator.pushReplacementNamed(context, AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Theme(
        data: ThemeData(brightness: Brightness.light),
        child: Scaffold(
          backgroundColor: _bg,
          body: SafeArea(
            child: Column(
              children: [
                // ── Top bar ────────────────────────────────────────────────
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 20.w,
                    vertical: 16.h,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.shield_rounded,
                        size: 22.sp,
                        color: _brandGreen,
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        'Moneytries',
                        style: TextStyle(fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                          fontSize: 20.sp,
                          fontWeight: FontWeight.w800,
                          color: _brandGreen,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 12.h),
                Container(
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
                    Icons.person_rounded,
                    size: 40.sp,
                    color: _brandGreen,
                  ),
                ),

                SizedBox(height: 16.h),

                // ── Title ─────────────────────────────────────────────────
                Text(
                  'Enter your PIN',
                  style: TextStyle(fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                    fontSize: 22.sp,
                    fontWeight: FontWeight.w800,
                    color: _titleColor,
                    letterSpacing: -0.3,
                    height: 1.2,
                  ),
                ),

                SizedBox(height: 6.h),

                Text(
                  'Use your 4-digit Moneytries PIN',
                  style: TextStyle(fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                    fontSize: 13.5.sp,
                    color: _subtitleColor,
                    height: 1.4,
                  ),
                ),

                if (_accountLabel.isNotEmpty) ...[
                  SizedBox(height: 4.h),
                  Text(
                    _accountLabel,
                    style: TextStyle(fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                      fontSize: 13.5.sp,
                      fontWeight: FontWeight.w700,
                      color: _brandGreen,
                      height: 1.4,
                    ),
                  ),
                ],

                if (_biometricsAvailable && _biometricsEnabled) ...[
                  SizedBox(height: 18.h),
                  GestureDetector(
                    onTap: _isAuthenticatingBiometric
                        ? null
                        : () => _authenticateWithBiometrics(),
                    child: Container(
                      width: 56.w,
                      height: 56.h,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.07),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: _isAuthenticatingBiometric
                          ? Padding(
                              padding: EdgeInsets.all(16.w),
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: _brandGreen,
                              ),
                            )
                          : Icon(
                              Icons.fingerprint_rounded,
                              size: 30.sp,
                              color: _brandGreen,
                            ),
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    'Tap to use biometrics',
                    style: TextStyle(fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                      fontSize: 11.5.sp,
                      fontWeight: FontWeight.w500,
                      color: _subtitleColor,
                    ),
                  ),
                ],

                SizedBox(height: 20.h),

                // ── PIN dots with shake ────────────────────────────────────
                AnimatedBuilder(
                  animation: _shakeAnim,
                  builder: (_, child) => Transform.translate(
                    offset: Offset(_shakeAnim.value, 0),
                    child: child,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_pinLength, (i) {
                      final filled = i < _pin.length;
                      return Container(
                        margin: EdgeInsets.symmetric(horizontal: 12.w),
                        width: 18.w,
                        height: 18.h,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: filled ? _dotFilled : Colors.transparent,
                          border: Border.all(
                            color: _error != null && !filled
                                ? _errorRed
                                : filled
                                ? _dotFilled
                                : _dotEmpty,
                            width: 2.r,
                          ),
                        ),
                      );
                    }),
                  ),
                ),

                SizedBox(height: 16.h),

                // ── Error message ─────────────────────────────────────────
                AnimatedOpacity(
                  opacity: _error != null ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    _error ?? '',
                    style: TextStyle(fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                      fontSize: 12.5.sp,
                      color: _errorRed,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                SizedBox(height: 16.h),

                // ── Keypad ────────────────────────────────────────────────
                Expanded(
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
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
                            // Empty cell keeps 0 aligned under the middle
                            // column and backspace under the right column,
                            // matching the 1-2-3 / 4-5-6 / 7-8-9 grid above.
                            Expanded(child: SizedBox(height: 70.h)),
                            SizedBox(width: 14.w),
                            Expanded(
                              child: _KeyButton(
                                onTap: () => _onKey(0),
                                child: Text(
                                  '0',
                                  style: TextStyle(fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
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

                        // ── Locked state button ──────────────────────────
                        if (_locked)
                          SizedBox(
                            width: double.infinity,
                            height: 52.h,
                            child: ElevatedButton(
                              onPressed: _usePassword,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _errorRed,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14.r),
                                ),
                                elevation: 0,
                              ),
                              child: Text(
                                'Login with Password',
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
                    style: TextStyle(fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
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