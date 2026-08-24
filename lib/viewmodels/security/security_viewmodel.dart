// lib/viewmodels/security/security_viewmodel.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/security/security_repository.dart';
import '../../models/security/security_model.dart';
import '../../services/biometric_auth_service.dart';

class SecurityViewModel extends ChangeNotifier {
  final SecurityRepository _repo = SecurityRepository();

  // ── Static helper (used by the withdrawal flow) ──────────────────────────
  // Withdrawals are now confirmed with the account's existing Login PIN
  // instead of a separate Withdrawal PIN. Kept static so the withdrawal
  // screen can verify it without needing a full SecurityViewModel.
  static Future<bool> verifyLoginPinForWithdrawal(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('logged_in_user_id') ?? '';
    final saved = prefs.getString('app_pin_$userId') ?? '';

    if (saved.isNotEmpty) {
      return saved == pin;
    }

    // No local cache for this account on this device — verify against the
    // account's Login PIN on the backend, and cache it locally on success
    // so future checks on this device are instant/offline.
    final valid = await SecurityRepository().verifyLoginPinRemote(pin);
    if (valid) {
      await prefs.setString('app_pin_$userId', pin);
    }
    return valid;
  }

  // ── State ─────────────────────────────────────────────────────────────────
  bool _biometricsEnabled = false;
  bool get biometricsEnabled => _biometricsEnabled;

  bool _twoFactorEnabled = false;
  bool get twoFactorEnabled => _twoFactorEnabled;

  bool _biometricsAvailable = false;
  bool get biometricsAvailable => _biometricsAvailable;

  SecurityAction _action = SecurityAction.idle;
  SecurityAction get action => _action;

  String? _message;
  String? get message => _message;

  bool _isLoadingSessions = false;
  bool get isLoadingSessions => _isLoadingSessions;

  bool _isLoadingHistory = false;
  bool get isLoadingHistory => _isLoadingHistory;

  List<DeviceSession> _sessions = [];
  List<DeviceSession> get sessions => _sessions;

  List<LoginEvent> _loginHistory = [];
  List<LoginEvent> get loginHistory => _loginHistory;

  // 2FA OTP state
  bool _otpSent = false;
  bool get otpSent => _otpSent;

  int _otpCountdown = 0;
  int get otpCountdown => _otpCountdown;
  Timer? _otpTimer;

  static const int pinLength = 4;

  // ── Login Credentials → Change Password ─────────────────────────────────────
  static const int passwordChangeMaxAttempts = 5;
  static const int passwordChangeLockSeconds = 5 * 60;

  bool _isVerifyingPassword = false;
  bool get isVerifyingPassword => _isVerifyingPassword;

  bool _isUpdatingPassword = false;
  bool get isUpdatingPassword => _isUpdatingPassword;

  bool _currentPasswordVerified = false;
  bool get currentPasswordVerified => _currentPasswordVerified;

  String? _changePasswordError;
  String? get changePasswordError => _changePasswordError;

  int _remainingPasswordAttempts = passwordChangeMaxAttempts;
  int get remainingPasswordAttempts => _remainingPasswordAttempts;

  bool _isPasswordChangeLocked = false;
  bool get isPasswordChangeLocked => _isPasswordChangeLocked;

  int _passwordLockSecondsLeft = 0;
  int get passwordLockSecondsLeft => _passwordLockSecondsLeft;
  Timer? _passwordLockTimer;

  bool _passwordChanged = false;
  bool get passwordChanged => _passwordChanged;

  // ── Login PIN → Change Login PIN ─────────────────────────────────────────
  // Server-enforced version of the account's 4-digit Login PIN change flow:
  // current-PIN verification, attempts, and lockout are all tracked on the
  // backend (see SecurityRepository.verifyCurrentLoginPin /
  // getLoginPinChangeStatus / updateLoginPin) so the 5-attempt cap can't be
  // bypassed client-side.
  static const int loginPinChangeMaxAttempts = 5;
  static const int loginPinChangeLockSeconds = 5 * 60;

  final List<int> _currentLoginPinEntry = [];
  List<int> get currentLoginPinEntry => _currentLoginPinEntry;

  final List<int> _newLoginPinEntry = [];
  List<int> get newLoginPinEntry => _newLoginPinEntry;

  final List<int> _confirmLoginPinEntry = [];
  List<int> get confirmLoginPinEntry => _confirmLoginPinEntry;

  // 0 = entering the new PIN, 1 = confirming it (used by SetNewLoginPinScreen)
  int _newLoginPinStep = 0;
  int get newLoginPinStep => _newLoginPinStep;

  List<int> get activeNewLoginPinEntry =>
      _newLoginPinStep == 0 ? _newLoginPinEntry : _confirmLoginPinEntry;

  bool _isVerifyingLoginPin = false;
  bool get isVerifyingLoginPin => _isVerifyingLoginPin;

  bool _isUpdatingLoginPin = false;
  bool get isUpdatingLoginPin => _isUpdatingLoginPin;

  String? _loginPinChangeError;
  String? get loginPinChangeError => _loginPinChangeError;

  int _remainingLoginPinAttempts = loginPinChangeMaxAttempts;
  int get remainingLoginPinAttempts => _remainingLoginPinAttempts;

  bool _isLoginPinChangeLocked = false;
  bool get isLoginPinChangeLocked => _isLoginPinChangeLocked;

  int _loginPinLockSecondsLeft = 0;
  int get loginPinLockSecondsLeft => _loginPinLockSecondsLeft;
  Timer? _loginPinLockTimer;

  bool _loginPinChanged = false;
  bool get loginPinChanged => _loginPinChanged;

  // ── Login PIN → Forgot Login PIN (email OTP recovery) ───────────────────
  // Lets a user who forgot their Login PIN recover it via an OTP emailed to
  // the account's registered address. A verified OTP opens the very same
  // backend "verified window" that verifyCurrentLoginPinStep() opens above,
  // so newLoginPinConfirm() / SetNewLoginPinScreen is reused unchanged for
  // the final "Set New PIN" / "Confirm New PIN" step.
  static const int forgotPinOtpLength = 6;
  static const int forgotPinResendCooldownSeconds = 30;

  final List<int> _forgotPinOtpEntry = [];
  List<int> get forgotPinOtpEntry => _forgotPinOtpEntry;

  bool _isSendingForgotPinOtp = false;
  bool get isSendingForgotPinOtp => _isSendingForgotPinOtp;

  bool _isVerifyingForgotPinOtp = false;
  bool get isVerifyingForgotPinOtp => _isVerifyingForgotPinOtp;

  String? _forgotPinError;
  String? get forgotPinError => _forgotPinError;

  String? _forgotPinEmailMasked;
  String? get forgotPinEmailMasked => _forgotPinEmailMasked;

  String _forgotPinChannel = 'EMAIL';
  String get forgotPinChannel => _forgotPinChannel;

  String? _forgotPinDestinationMasked;
  String? get forgotPinDestinationMasked => _forgotPinDestinationMasked;

  int _forgotPinOtpExpirySeconds = 300;
  int get forgotPinOtpExpirySeconds => _forgotPinOtpExpirySeconds;

  bool _forgotPinOtpVerified = false;
  bool get forgotPinOtpVerified => _forgotPinOtpVerified;

  bool _isForgotPinLocked = false;
  bool get isForgotPinLocked => _isForgotPinLocked;

  int _forgotPinLockSecondsLeft = 0;
  int get forgotPinLockSecondsLeft => _forgotPinLockSecondsLeft;
  Timer? _forgotPinLockTimer;

  int _forgotPinResendCooldownLeft = 0;
  int get forgotPinResendCooldownLeft => _forgotPinResendCooldownLeft;
  Timer? _forgotPinResendTimer;

  bool get canResendForgotPinOtp =>
      !_isForgotPinLocked && _forgotPinResendCooldownLeft == 0;

  // ── Init ──────────────────────────────────────────────────────────────────
  SecurityViewModel() {
    _init();
  }

  Future<void> _init() async {
    await Future.wait([
      _checkBiometrics(),
      _loadPreferences(),
    ]);
  }

  Future<void> _checkBiometrics() async {
    _biometricsAvailable = await BiometricAuthService.isDeviceCapable();
    notifyListeners();
  }

  Future<void> _loadPreferences() async {
    _biometricsEnabled = await _repo.getBiometricsEnabled();
    _twoFactorEnabled = await _repo.getTwoFactorEnabled();

    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('logged_in_user_id') ?? '';

    // Reconcile with the account-level backend so a Login PIN or Biometric
    // Login preference set on a *different* device shows up correctly here
    // too, instead of this device assuming nothing is configured just
    // because it has no local cache.
    final pinStatus = await _repo.getPinsStatus();

    if (!_biometricsEnabled && pinStatus.biometricEnabled && _biometricsAvailable) {
      // The account has biometric login turned on from another device.
      // Mirror the toggle state locally so Security Settings reflects it —
      // actually unlocking with biometrics on this device still requires
      // this device's own enrolled fingerprint/Face ID, enforced by the
      // OS/local_auth, so this is safe to reflect automatically.
      _biometricsEnabled = true;
      await BiometricAuthService.setEnabledFor(userId, true);
    }

    notifyListeners();
  }

  // ── Biometrics toggle ─────────────────────────────────────────────────────
  Future<bool> toggleBiometrics(bool enable) async {
    if (!_biometricsAvailable) {
      _message = 'Biometric authentication is not available on this device.';
      notifyListeners();
      return false;
    }

    if (enable) {
      String? errorMessage;
      final authenticated = await BiometricAuthService.authenticate(
        reason: 'Authenticate to enable biometric login',
        onError: (msg) => errorMessage = msg,
      );

      if (authenticated) {
        _biometricsEnabled = true;
        await _repo.setBiometricsEnabled(true);
        _message = 'Biometric login enabled successfully.';
        notifyListeners();
        return true;
      } else {
        _message = errorMessage ?? 'Biometric authentication was cancelled.';
        notifyListeners();
        return false;
      }
    } else {
      _biometricsEnabled = false;
      await _repo.setBiometricsEnabled(false);
      _message = 'Biometric login disabled.';
      notifyListeners();
      return true;
    }
  }

  // ── 2FA ───────────────────────────────────────────────────────────────────
  Future<void> send2faOtp() async {
    _action = SecurityAction.loading;
    notifyListeners();

    final error = await _repo.send2faOtp();

    if (error == null) {
      _otpSent = true;
      _action = SecurityAction.idle;
      _startOtpCountdown();
    } else {
      _action = SecurityAction.error;
      _message = error;
    }
    notifyListeners();
  }

  void _startOtpCountdown() {
    _otpCountdown = 60;
    _otpTimer?.cancel();
    _otpTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_otpCountdown <= 0) {
        t.cancel();
      } else {
        _otpCountdown--;
        notifyListeners();
      }
    });
  }

  Future<bool> verify2faOtp(String otp) async {
    if (otp.length < 6) {
      _message = 'Please enter the full 6-digit OTP.';
      notifyListeners();
      return false;
    }

    _action = SecurityAction.loading;
    notifyListeners();

    final error = await _repo.verify2faOtp(otp);

    if (error == null) {
      _twoFactorEnabled = true;
      _otpSent = false;
      _action = SecurityAction.success;
      _message = '2FA enabled successfully.';
      notifyListeners();
      return true;
    } else {
      _action = SecurityAction.error;
      _message = error;
      notifyListeners();
      return false;
    }
  }

  Future<void> disable2fa() async {
    _action = SecurityAction.loading;
    notifyListeners();

    final error = await _repo.disable2fa();

    if (error == null) {
      _twoFactorEnabled = false;
      _otpSent = false;
      _otpTimer?.cancel();
      _action = SecurityAction.idle;
      _message = '2FA has been disabled.';
    } else {
      _action = SecurityAction.error;
      _message = error;
    }
    notifyListeners();
  }

  void reset2faState() {
    _otpSent = false;
    _action = SecurityAction.idle;
    _otpTimer?.cancel();
    notifyListeners();
  }

  // ── Login PIN → Change Login PIN (server-enforced) ───────────────────────

  /// Resets all Change Login PIN flow state. Call when opening the screen.
  void resetChangeLoginPinFlow() {
    _isVerifyingLoginPin = false;
    _isUpdatingLoginPin = false;
    _loginPinChangeError = null;
    _remainingLoginPinAttempts = loginPinChangeMaxAttempts;
    _isLoginPinChangeLocked = false;
    _loginPinLockSecondsLeft = 0;
    _loginPinLockTimer?.cancel();
    _loginPinChanged = false;
    _currentLoginPinEntry.clear();
    _newLoginPinEntry.clear();
    _confirmLoginPinEntry.clear();
    _newLoginPinStep = 0;
    notifyListeners();
  }

  /// Resumes lock/attempt state from the backend — call on screen open so a
  /// lockout survives the app being backgrounded or killed mid-countdown.
  Future<void> loadLoginPinChangeStatus() async {
    final status = await _repo.getLoginPinChangeStatus();
    _remainingLoginPinAttempts = status.remainingAttempts;
    if (status.locked && status.remainingSeconds > 0) {
      _startLoginPinLockCountdown(status.remainingSeconds);
    }
    notifyListeners();
  }

  void _startLoginPinLockCountdown(int seconds) {
    _isLoginPinChangeLocked = true;
    _loginPinLockSecondsLeft = seconds;
    _loginPinLockTimer?.cancel();
    _loginPinLockTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_loginPinLockSecondsLeft <= 1) {
        t.cancel();
        _isLoginPinChangeLocked = false;
        _loginPinLockSecondsLeft = 0;
        _remainingLoginPinAttempts = loginPinChangeMaxAttempts;
      } else {
        _loginPinLockSecondsLeft--;
      }
      notifyListeners();
    });
  }

  void loginPinKeyPress(int digit) {
    if (_currentLoginPinEntry.length >= pinLength) return;
    _currentLoginPinEntry.add(digit);
    notifyListeners();
  }

  void loginPinDelete() {
    if (_currentLoginPinEntry.isEmpty) return;
    _currentLoginPinEntry.removeLast();
    _loginPinChangeError = null;
    notifyListeners();
  }

  /// Step 1: verify the current Login PIN. Every attempt — correct or not —
  /// is checked and counted on the backend, so this can't be bypassed by
  /// restarting the app or clearing local storage. Returns true on success.
  Future<bool> verifyCurrentLoginPinStep() async {
    if (_isLoginPinChangeLocked) return false;

    if (_currentLoginPinEntry.length < pinLength) {
      _loginPinChangeError = 'Enter all $pinLength digits';
      notifyListeners();
      return false;
    }

    _isVerifyingLoginPin = true;
    _loginPinChangeError = null;
    notifyListeners();

    final pin = _currentLoginPinEntry.join();
    final status = await _repo.verifyCurrentLoginPin(pin);
    _isVerifyingLoginPin = false;

    if (status.success) {
      _loginPinChangeError = null;
      _remainingLoginPinAttempts = loginPinChangeMaxAttempts;
      notifyListeners();
      return true;
    }

    if (status.locked) {
      _startLoginPinLockCountdown(
        status.remainingSeconds > 0
            ? status.remainingSeconds
            : loginPinChangeLockSeconds,
      );
      _loginPinChangeError = status.message;
    } else {
      _remainingLoginPinAttempts = status.remainingAttempts;
      _loginPinChangeError = status.message;
      _currentLoginPinEntry.clear();
    }
    notifyListeners();
    return false;
  }

  void newLoginPinKeyPress(int digit) {
    final entry = activeNewLoginPinEntry;
    if (entry.length >= pinLength) return;
    entry.add(digit);
    notifyListeners();
  }

  void newLoginPinDelete() {
    final entry = activeNewLoginPinEntry;
    if (entry.isEmpty) return;
    entry.removeLast();
    _loginPinChangeError = null;
    notifyListeners();
  }

  /// Advances the "Set New PIN" screen through its own two steps
  /// (new → confirm), then submits to the backend on the confirm step.
  /// Only succeeds within the short window opened by a successful
  /// verifyCurrentLoginPinStep() call. Returns true once the PIN has
  /// actually been changed.
  Future<bool> newLoginPinConfirm() async {
    final entry = activeNewLoginPinEntry;
    if (entry.length < pinLength) {
      _loginPinChangeError = 'Enter all $pinLength digits';
      notifyListeners();
      return false;
    }
    _loginPinChangeError = null;

    if (_newLoginPinStep == 0) {
      _newLoginPinStep = 1;
      notifyListeners();
      return false;
    }

    if (_newLoginPinEntry.join() != _confirmLoginPinEntry.join()) {
      _loginPinChangeError = 'PINs do not match. Try again.';
      _confirmLoginPinEntry.clear();
      notifyListeners();
      return false;
    }

    _isUpdatingLoginPin = true;
    _loginPinChangeError = null;
    notifyListeners();

    final newPin = _newLoginPinEntry.join();
    final error = await _repo.updateLoginPin(
      newPin: newPin,
      confirmPin: _confirmLoginPinEntry.join(),
    );

    _isUpdatingLoginPin = false;

    if (error != null) {
      _loginPinChangeError = error;
      notifyListeners();
      return false;
    }

    // Save the new PIN locally too — this is the exact value the PIN-lock
    // screen (and the set-PIN flow) read from, so the change takes effect
    // immediately on this device with no extra step needed.
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('logged_in_user_id') ?? '';
    await prefs.setString('app_pin_$userId', newPin);

    _loginPinChanged = true;
    _action = SecurityAction.success;
    _message = 'Login PIN changed successfully.';
    notifyListeners();
    return true;
  }

  void clearLoginPinChangeError() {
    _loginPinChangeError = null;
    notifyListeners();
  }

  /// Resets all Forgot Login PIN flow state. Call when opening the screen.
  void resetForgotLoginPinFlow() {
    _forgotPinOtpEntry.clear();
    _isSendingForgotPinOtp = false;
    _isVerifyingForgotPinOtp = false;
    _forgotPinError = null;
    _forgotPinEmailMasked = null;
    _forgotPinChannel = 'EMAIL';
    _forgotPinDestinationMasked = null;
    _forgotPinOtpExpirySeconds = 300;
    _forgotPinOtpVerified = false;
    _isForgotPinLocked = false;
    _forgotPinLockSecondsLeft = 0;
    _forgotPinLockTimer?.cancel();
    _forgotPinResendCooldownLeft = 0;
    _forgotPinResendTimer?.cancel();
    notifyListeners();
  }

  /// Resumes lock/cooldown state from the backend — call on screen open so
  /// it survives the app being backgrounded or killed mid-lockout.
  Future<void> loadForgotLoginPinStatus() async {
    final status = await _repo.getForgotLoginPinStatus();
    _forgotPinEmailMasked = status.email ?? _forgotPinEmailMasked;
    _forgotPinChannel = status.channel ?? _forgotPinChannel;
    _forgotPinDestinationMasked = status.destination ??
        (_forgotPinChannel == 'PHONE' ? status.phone : status.email) ??
        _forgotPinDestinationMasked;
    if (status.locked && status.lockedRemainingSeconds > 0) {
      _startForgotPinLockCountdown(status.lockedRemainingSeconds);
    } else if (status.retryAfterSeconds > 0) {
      _startForgotPinResendCountdown(status.retryAfterSeconds);
    }
    notifyListeners();
  }

  void _startForgotPinLockCountdown(int seconds) {
    _isForgotPinLocked = true;
    _forgotPinLockSecondsLeft = seconds;
    _forgotPinLockTimer?.cancel();
    _forgotPinLockTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_forgotPinLockSecondsLeft <= 1) {
        t.cancel();
        _isForgotPinLocked = false;
        _forgotPinLockSecondsLeft = 0;
      } else {
        _forgotPinLockSecondsLeft--;
      }
      notifyListeners();
    });
  }

  void _startForgotPinResendCountdown(int seconds) {
    _forgotPinResendCooldownLeft = seconds;
    _forgotPinResendTimer?.cancel();
    _forgotPinResendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_forgotPinResendCooldownLeft <= 1) {
        t.cancel();
        _forgotPinResendCooldownLeft = 0;
      } else {
        _forgotPinResendCooldownLeft--;
      }
      notifyListeners();
    });
  }

  /// Sends a 6-digit OTP over the selected channel. Switching channels is
  /// allowed during the resend cooldown because the backend invalidates the
  /// previous code and explicitly permits that transition.
  Future<bool> sendForgotLoginPinOtp({String? channel}) async {
    final requestedChannel = channel ?? _forgotPinChannel;
    final switchingChannel = requestedChannel != _forgotPinChannel;
    if (_isForgotPinLocked ||
        (!switchingChannel && !canResendForgotPinOtp) ||
        _isSendingForgotPinOtp) {
      return false;
    }

    _isSendingForgotPinOtp = true;
    _forgotPinError = null;
    notifyListeners();

    final result = await _repo.sendForgotLoginPinOtp(requestedChannel);
    _isSendingForgotPinOtp = false;

    if (result.success) {
      _forgotPinEmailMasked = result.email ?? _forgotPinEmailMasked;
      _forgotPinChannel = result.channel ?? requestedChannel;
      _forgotPinDestinationMasked = result.destination ??
          (_forgotPinChannel == 'PHONE' ? result.phone : result.email) ??
          _forgotPinDestinationMasked;
      _forgotPinOtpExpirySeconds = result.expiresInSeconds;
      _forgotPinOtpEntry.clear();
      _forgotPinError = null;
      _startForgotPinResendCountdown(forgotPinResendCooldownSeconds);
      notifyListeners();
      return true;
    }

    if (result.locked) {
      _startForgotPinLockCountdown(
        result.lockedRemainingSeconds > 0 ? result.lockedRemainingSeconds : 300,
      );
    } else if (result.retryAfterSeconds > 0) {
      _startForgotPinResendCountdown(result.retryAfterSeconds);
    }
    _forgotPinError = result.message;
    notifyListeners();
    return false;
  }

  void forgotPinOtpKeyPress(int digit) {
    if (_forgotPinOtpEntry.length >= forgotPinOtpLength) return;
    _forgotPinOtpEntry.add(digit);
    _forgotPinError = null;
    notifyListeners();
  }

  void forgotPinOtpDelete() {
    if (_forgotPinOtpEntry.isEmpty) return;
    _forgotPinOtpEntry.removeLast();
    _forgotPinError = null;
    notifyListeners();
  }

  void forgotPinOtpChanged(String otp) {
    _forgotPinOtpEntry
      ..clear()
      ..addAll(otp.split('').map(int.parse));
    _forgotPinError = null;
    notifyListeners();
  }

  /// Verifies the OTP. On success, the backend has already opened the same
  /// verified window used by the existing Change Login PIN flow, so the
  /// caller should push SetNewLoginPinScreen next — newLoginPinConfirm()
  /// there calls the existing updateLoginPin() endpoint unchanged.
  Future<bool> verifyForgotLoginPinOtp() async {
    if (_isForgotPinLocked) return false;
    if (_forgotPinOtpEntry.length < forgotPinOtpLength) {
      _forgotPinError = 'Enter all $forgotPinOtpLength digits';
      notifyListeners();
      return false;
    }

    _isVerifyingForgotPinOtp = true;
    _forgotPinError = null;
    notifyListeners();

    final otp = _forgotPinOtpEntry.join();
    final result = await _repo.verifyForgotLoginPinOtp(otp);
    _isVerifyingForgotPinOtp = false;

    if (result.success) {
      _forgotPinOtpVerified = true;
      _forgotPinError = null;
      notifyListeners();
      return true;
    }

    if (result.locked) {
      _startForgotPinLockCountdown(
        result.lockedRemainingSeconds > 0 ? result.lockedRemainingSeconds : 300,
      );
    }
    _forgotPinOtpEntry.clear();
    _forgotPinError = result.message;
    notifyListeners();
    return false;
  }

  String get newLoginPinTitle =>
      _newLoginPinStep == 0 ? 'Enter New PIN' : 'Confirm New PIN';

  String get newLoginPinSubtitle => _newLoginPinStep == 0
      ? 'Choose a strong 4-digit PIN you haven\'t used before.'
      : 'Re-enter the new PIN to confirm the change.';

  /// Resets all Change Password flow state. Call when opening the screen.
  void resetChangePasswordFlow() {
    _isVerifyingPassword = false;
    _isUpdatingPassword = false;
    _currentPasswordVerified = false;
    _changePasswordError = null;
    _remainingPasswordAttempts = passwordChangeMaxAttempts;
    _isPasswordChangeLocked = false;
    _passwordLockSecondsLeft = 0;
    _passwordLockTimer?.cancel();
    _passwordChanged = false;
    notifyListeners();
  }

  /// Resumes lock/attempt state from the backend — call on screen open so a
  /// lockout survives the app being backgrounded or killed mid-countdown.
  Future<void> loadPasswordChangeStatus() async {
    final status = await _repo.getPasswordChangeStatus();
    _remainingPasswordAttempts = status.remainingAttempts;
    if (status.locked && status.remainingSeconds > 0) {
      _startPasswordLockCountdown(status.remainingSeconds);
    }
    notifyListeners();
  }

  void _startPasswordLockCountdown(int seconds) {
    _isPasswordChangeLocked = true;
    _passwordLockSecondsLeft = seconds;
    _passwordLockTimer?.cancel();
    _passwordLockTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_passwordLockSecondsLeft <= 1) {
        t.cancel();
        _isPasswordChangeLocked = false;
        _passwordLockSecondsLeft = 0;
        _remainingPasswordAttempts = passwordChangeMaxAttempts;
      } else {
        _passwordLockSecondsLeft--;
      }
      notifyListeners();
    });
  }

  /// Step 1: verify the current login password. Returns true on success.
  Future<bool> verifyCurrentPassword(String currentPassword) async {
    if (_isPasswordChangeLocked) return false;

    if (currentPassword.isEmpty) {
      _changePasswordError = 'Please enter your current password.';
      notifyListeners();
      return false;
    }

    _isVerifyingPassword = true;
    _changePasswordError = null;
    notifyListeners();

    final status = await _repo.verifyCurrentPassword(currentPassword);
    _isVerifyingPassword = false;

    if (status.success) {
      _currentPasswordVerified = true;
      _changePasswordError = null;
      _remainingPasswordAttempts = passwordChangeMaxAttempts;
      notifyListeners();
      return true;
    }

    if (status.locked) {
      _startPasswordLockCountdown(
        status.remainingSeconds > 0
            ? status.remainingSeconds
            : passwordChangeLockSeconds,
      );
      _changePasswordError = status.message;
    } else {
      _remainingPasswordAttempts = status.remainingAttempts;
      _changePasswordError = status.message;
    }
    notifyListeners();
    return false;
  }

  /// Step 2: submit the new password. Returns true on success.
  Future<bool> submitNewPassword({
    required String newPassword,
    required String confirmPassword,
  }) async {
    if (newPassword.length < 8 ||
        !RegExp(r'(?=.*[A-Za-z])(?=.*\d)').hasMatch(newPassword)) {
      _changePasswordError =
          'Password must be at least 8 characters and contain letters and numbers.';
      notifyListeners();
      return false;
    }
    if (newPassword != confirmPassword) {
      _changePasswordError = 'Passwords do not match.';
      notifyListeners();
      return false;
    }

    _isUpdatingPassword = true;
    _changePasswordError = null;
    notifyListeners();

    final error = await _repo.updatePassword(
      newPassword: newPassword,
      confirmPassword: confirmPassword,
    );

    _isUpdatingPassword = false;

    if (error == null) {
      _passwordChanged = true;
      _action = SecurityAction.success;
      _message = 'Password changed successfully.';
      notifyListeners();
      return true;
    }

    _changePasswordError = error;
    notifyListeners();
    return false;
  }

  void clearChangePasswordError() {
    _changePasswordError = null;
    notifyListeners();
  }

  // ── Sessions ──────────────────────────────────────────────────────────────
  Future<void> loadSessions() async {
    _isLoadingSessions = true;
    notifyListeners();

    _sessions = await _repo.getSessions();

    _isLoadingSessions = false;
    notifyListeners();
  }

  Future<void> revokeSession(String sessionId) async {
    _action = SecurityAction.loading;
    notifyListeners();

    final error = await _repo.revokeSession(sessionId);

    if (error == null) {
      _sessions = await _repo.getSessions();
      _action = SecurityAction.idle;
      _message = 'Device signed out successfully.';
    } else {
      _action = SecurityAction.error;
      _message = error;
    }
    notifyListeners();
  }

  // ── Login History ─────────────────────────────────────────────────────────
  Future<void> loadLoginHistory() async {
    _isLoadingHistory = true;
    notifyListeners();

    _loginHistory = await _repo.getLoginHistory();

    _isLoadingHistory = false;
    notifyListeners();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  void clearMessage() {
    _message = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _otpTimer?.cancel();
    _passwordLockTimer?.cancel();
    _loginPinLockTimer?.cancel();
    _forgotPinLockTimer?.cancel();
    _forgotPinResendTimer?.cancel();
    super.dispose();
  }
}
