// lib/viewmodels/security/security_viewmodel.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/security/security_repository.dart';
import '../../models/security/security_model.dart';
import '../../services/biometric_auth_service.dart';

class SecurityViewModel extends ChangeNotifier {
  final SecurityRepository _repo = SecurityRepository();

  // ── Static helpers (used by the withdrawal flow) ────────────────────────
  // Kept static so other features (e.g. the withdrawal screen) can check or
  // verify the withdrawal PIN without needing a full SecurityViewModel.
  static Future<bool> isWithdrawalPinSet() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('logged_in_user_id') ?? '';
    final saved = prefs.getString('withdrawal_pin_$userId') ?? '';
    if (saved.isNotEmpty) return true;

    // Not cached on this device — this could be a different device than
    // the one the withdrawal PIN was set on, so ask the account directly
    // instead of assuming no PIN exists.
    final status = await SecurityRepository().getPinsStatus();
    return status.withdrawalPinSet;
  }

  static Future<bool> verifyWithdrawalPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('logged_in_user_id') ?? '';
    final saved = prefs.getString('withdrawal_pin_$userId') ?? '';

    if (saved.isNotEmpty) {
      return saved == pin;
    }

    // No local cache for this account on this device — verify against the
    // account's PIN on the backend, and cache it locally on success so
    // future checks on this device are instant/offline.
    final valid = await SecurityRepository().verifyWithdrawalPinRemote(pin);
    if (valid) {
      await prefs.setString('withdrawal_pin_$userId', pin);
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

  // ── Withdrawal PIN ────────────────────────────────────────────────────────
  // A separate 4-digit PIN required to confirm withdrawal requests. Stored
  // locally per-account as `withdrawal_pin_<userId>`, independent of the
  // app-lock PIN (`app_pin_<userId>`).
  bool _hasWithdrawalPin = false;
  bool get hasWithdrawalPin => _hasWithdrawalPin;

  // Step index. When no withdrawal PIN exists yet: 0=new, 1=confirm.
  // When one already exists (changing it): 0=current, 1=new, 2=confirm.
  int _wPinStep = 0;
  int get withdrawalPinStep => _wPinStep;
  List<int> _wCurrentEntry = [];
  List<int> _wNewEntry = [];
  List<int> _wConfirmEntry = [];

  bool get _isChangingWithdrawalPin => _hasWithdrawalPin;
  int get _wConfirmStepIndex => _isChangingWithdrawalPin ? 2 : 1;
  int get _wNewStepIndex => _isChangingWithdrawalPin ? 1 : 0;

  List<int> get activeWithdrawalPinEntry {
    if (_isChangingWithdrawalPin) {
      if (_wPinStep == 0) return _wCurrentEntry;
      if (_wPinStep == 1) return _wNewEntry;
      return _wConfirmEntry;
    }
    if (_wPinStep == 0) return _wNewEntry;
    return _wConfirmEntry;
  }

  String? _wPinError;
  String? get withdrawalPinError => _wPinError;

  bool _withdrawalPinChanged = false;
  bool get withdrawalPinChanged => _withdrawalPinChanged;

  // ── Withdrawal PIN → Change Withdrawal PIN (server-enforced) ────────────
  // Server-enforced version of the account's 4-digit Withdrawal PIN change
  // flow: current-PIN verification, attempts, and lockout are all tracked
  // on the backend (see SecurityRepository.verifyCurrentWithdrawalPin /
  // getWithdrawalPinChangeStatus / updateWithdrawalPin) so the 5-attempt
  // cap can't be bypassed client-side. Used by ChangeWithdrawalPinScreen
  // when the account already has a Withdrawal PIN set.
  static const int withdrawalPinChangeMaxAttempts = 5;
  static const int withdrawalPinChangeLockSeconds = 5 * 60;

  final List<int> _currentWithdrawalPinEntry = [];
  List<int> get currentWithdrawalPinEntry => _currentWithdrawalPinEntry;

  final List<int> _newWithdrawalPinEntry = [];
  List<int> get newWithdrawalPinEntry => _newWithdrawalPinEntry;

  final List<int> _confirmWithdrawalPinEntry = [];
  List<int> get confirmWithdrawalPinEntry => _confirmWithdrawalPinEntry;

  // 0 = entering the new PIN, 1 = confirming it (used by SetNewWithdrawalPinScreen)
  int _newWithdrawalPinStep = 0;
  int get newWithdrawalPinStep => _newWithdrawalPinStep;

  List<int> get activeNewWithdrawalPinEntry => _newWithdrawalPinStep == 0
      ? _newWithdrawalPinEntry
      : _confirmWithdrawalPinEntry;

  bool _isVerifyingWithdrawalPin = false;
  bool get isVerifyingWithdrawalPin => _isVerifyingWithdrawalPin;

  bool _isUpdatingWithdrawalPin = false;
  bool get isUpdatingWithdrawalPin => _isUpdatingWithdrawalPin;

  String? _withdrawalPinChangeError;
  String? get withdrawalPinChangeError => _withdrawalPinChangeError;

  int _remainingWithdrawalPinAttempts = withdrawalPinChangeMaxAttempts;
  int get remainingWithdrawalPinAttempts => _remainingWithdrawalPinAttempts;

  bool _isWithdrawalPinChangeLocked = false;
  bool get isWithdrawalPinChangeLocked => _isWithdrawalPinChangeLocked;

  int _withdrawalPinLockSecondsLeft = 0;
  int get withdrawalPinLockSecondsLeft => _withdrawalPinLockSecondsLeft;
  Timer? _withdrawalPinLockTimer;

  bool _withdrawalPinChangedServer = false;
  bool get withdrawalPinChangedServer => _withdrawalPinChangedServer;

  void resetChangeWithdrawalPinFlow() {
    _isVerifyingWithdrawalPin = false;
    _isUpdatingWithdrawalPin = false;
    _withdrawalPinChangeError = null;
    _remainingWithdrawalPinAttempts = withdrawalPinChangeMaxAttempts;
    _isWithdrawalPinChangeLocked = false;
    _withdrawalPinLockSecondsLeft = 0;
    _withdrawalPinLockTimer?.cancel();
    _withdrawalPinChangedServer = false;
    _currentWithdrawalPinEntry.clear();
    _newWithdrawalPinEntry.clear();
    _confirmWithdrawalPinEntry.clear();
    _newWithdrawalPinStep = 0;
    notifyListeners();
  }

  /// Resumes lock/attempt state from the backend — call on screen open so a
  /// lockout survives the app being backgrounded or killed mid-countdown.
  Future<void> loadWithdrawalPinChangeStatus() async {
    final status = await _repo.getWithdrawalPinChangeStatus();
    _remainingWithdrawalPinAttempts = status.remainingAttempts;
    if (status.locked && status.remainingSeconds > 0) {
      _startWithdrawalPinLockCountdown(status.remainingSeconds);
    }
    notifyListeners();
  }

  void _startWithdrawalPinLockCountdown(int seconds) {
    _isWithdrawalPinChangeLocked = true;
    _withdrawalPinLockSecondsLeft = seconds;
    _withdrawalPinLockTimer?.cancel();
    _withdrawalPinLockTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_withdrawalPinLockSecondsLeft <= 1) {
        t.cancel();
        _isWithdrawalPinChangeLocked = false;
        _withdrawalPinLockSecondsLeft = 0;
        _remainingWithdrawalPinAttempts = withdrawalPinChangeMaxAttempts;
      } else {
        _withdrawalPinLockSecondsLeft--;
      }
      notifyListeners();
    });
  }

  void currentWithdrawalPinKeyPress(int digit) {
    if (_currentWithdrawalPinEntry.length >= pinLength) return;
    _currentWithdrawalPinEntry.add(digit);
    notifyListeners();
  }

  void currentWithdrawalPinDelete() {
    if (_currentWithdrawalPinEntry.isEmpty) return;
    _currentWithdrawalPinEntry.removeLast();
    _withdrawalPinChangeError = null;
    notifyListeners();
  }

  /// Step 1: verify the current Withdrawal PIN. Every attempt — correct or
  /// not — is checked and counted on the backend, so this can't be
  /// bypassed by restarting the app or clearing local storage. Returns
  /// true on success.
  Future<bool> verifyCurrentWithdrawalPinStep() async {
    if (_isWithdrawalPinChangeLocked) return false;

    if (_currentWithdrawalPinEntry.length < pinLength) {
      _withdrawalPinChangeError = 'Enter all $pinLength digits';
      notifyListeners();
      return false;
    }

    _isVerifyingWithdrawalPin = true;
    _withdrawalPinChangeError = null;
    notifyListeners();

    final pin = _currentWithdrawalPinEntry.join();
    final status = await _repo.verifyCurrentWithdrawalPin(pin);
    _isVerifyingWithdrawalPin = false;

    if (status.success) {
      _withdrawalPinChangeError = null;
      _remainingWithdrawalPinAttempts = withdrawalPinChangeMaxAttempts;
      notifyListeners();
      return true;
    }

    if (status.locked) {
      _startWithdrawalPinLockCountdown(
        status.remainingSeconds > 0
            ? status.remainingSeconds
            : withdrawalPinChangeLockSeconds,
      );
      _withdrawalPinChangeError = status.message;
    } else {
      _remainingWithdrawalPinAttempts = status.remainingAttempts;
      _withdrawalPinChangeError = status.message;
      _currentWithdrawalPinEntry.clear();
    }
    notifyListeners();
    return false;
  }

  void newWithdrawalPinKeyPress(int digit) {
    final entry = activeNewWithdrawalPinEntry;
    if (entry.length >= pinLength) return;
    entry.add(digit);
    notifyListeners();
  }

  void newWithdrawalPinDelete() {
    final entry = activeNewWithdrawalPinEntry;
    if (entry.isEmpty) return;
    entry.removeLast();
    _withdrawalPinChangeError = null;
    notifyListeners();
  }

  /// Advances the "Set New PIN" screen through its own two steps
  /// (new → confirm), then submits to the backend on the confirm step.
  /// Only succeeds within the short window opened by a successful
  /// verifyCurrentWithdrawalPinStep() call. Returns true once the PIN has
  /// actually been changed.
  Future<bool> newWithdrawalPinConfirm() async {
    final entry = activeNewWithdrawalPinEntry;
    if (entry.length < pinLength) {
      _withdrawalPinChangeError = 'Enter all $pinLength digits';
      notifyListeners();
      return false;
    }
    _withdrawalPinChangeError = null;

    if (_newWithdrawalPinStep == 0) {
      _newWithdrawalPinStep = 1;
      notifyListeners();
      return false;
    }

    if (_newWithdrawalPinEntry.join() != _confirmWithdrawalPinEntry.join()) {
      _withdrawalPinChangeError = 'PINs do not match. Try again.';
      _confirmWithdrawalPinEntry.clear();
      notifyListeners();
      return false;
    }

    _isUpdatingWithdrawalPin = true;
    _withdrawalPinChangeError = null;
    notifyListeners();

    final newPin = _newWithdrawalPinEntry.join();
    final error = await _repo.updateWithdrawalPin(
      newPin: newPin,
      confirmPin: _confirmWithdrawalPinEntry.join(),
    );

    _isUpdatingWithdrawalPin = false;

    if (error != null) {
      _withdrawalPinChangeError = error;
      notifyListeners();
      return false;
    }

    // Save the new PIN locally too — this is the exact value the
    // withdrawal flow reads from, so the change takes effect immediately
    // on this device with no extra step needed.
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('logged_in_user_id') ?? '';
    await prefs.setString('withdrawal_pin_$userId', newPin);

    _hasWithdrawalPin = true;
    _withdrawalPinChangedServer = true;
    _action = SecurityAction.success;
    _message = 'Withdrawal PIN changed successfully.';
    notifyListeners();
    return true;
  }

  void clearWithdrawalPinChangeError() {
    _withdrawalPinChangeError = null;
    notifyListeners();
  }

  String get newWithdrawalPinTitle =>
      _newWithdrawalPinStep == 0 ? 'Enter New PIN' : 'Confirm New PIN';

  String get newWithdrawalPinSubtitle => _newWithdrawalPinStep == 0
      ? 'Choose a strong 4-digit PIN you haven\'t used before.'
      : 'Re-enter the new PIN to confirm the change.';

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
    final savedWithdrawalPin = prefs.getString('withdrawal_pin_$userId') ?? '';
    _hasWithdrawalPin = savedWithdrawalPin.isNotEmpty;
    notifyListeners();

    // Reconcile with the account-level backend so a Login PIN, Withdrawal
    // PIN, or Biometric Login preference set on a *different* device shows
    // up correctly here too, instead of this device assuming nothing is
    // configured just because it has no local cache.
    final pinStatus = await _repo.getPinsStatus();

    if (!_hasWithdrawalPin && pinStatus.withdrawalPinSet) {
      // The account already has a withdrawal PIN (set on another device);
      // this device just hasn't verified/cached it yet. Mark it as set so
      // the UI offers "change PIN" (which will verify the current PIN via
      // the backend) instead of "create PIN" and overwriting it.
      _hasWithdrawalPin = true;
    }

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

  String get newLoginPinTitle =>
      _newLoginPinStep == 0 ? 'Enter New PIN' : 'Confirm New PIN';

  String get newLoginPinSubtitle => _newLoginPinStep == 0
      ? 'Choose a strong 4-digit PIN you haven\'t used before.'
      : 'Re-enter the new PIN to confirm the change.';

  // ── Withdrawal PIN ────────────────────────────────────────────────────────
  void resetWithdrawalPinFlow() {
    _wPinStep = 0;
    _wCurrentEntry = [];
    _wNewEntry = [];
    _wConfirmEntry = [];
    _wPinError = null;
    _withdrawalPinChanged = false;
    notifyListeners();
  }

  void withdrawalPinKeyPress(int digit) {
    final entry = activeWithdrawalPinEntry;
    if (entry.length >= pinLength) return;
    entry.add(digit);
    notifyListeners();
  }

  void withdrawalPinDelete() {
    final entry = activeWithdrawalPinEntry;
    if (entry.isEmpty) return;
    entry.removeLast();
    _wPinError = null;
    notifyListeners();
  }

  Future<void> withdrawalPinConfirm() async {
    final entry = activeWithdrawalPinEntry;
    if (entry.length < pinLength) {
      _wPinError = 'Enter all $pinLength digits';
      notifyListeners();
      return;
    }
    _wPinError = null;

    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('logged_in_user_id') ?? '';

    if (_isChangingWithdrawalPin && _wPinStep == 0) {
      // Verify the existing withdrawal PIN before allowing it to be
      // changed. Falls back to the backend when this device has no local
      // cache for it (e.g. it was set up on a different device), caching
      // it locally on success.
      final savedPin = prefs.getString('withdrawal_pin_$userId') ?? '';
      final entered = _wCurrentEntry.join();

      bool matches;
      if (savedPin.isNotEmpty) {
        matches = entered == savedPin;
      } else {
        matches = await _repo.verifyWithdrawalPinRemote(entered);
        if (matches) {
          await prefs.setString('withdrawal_pin_$userId', entered);
        }
      }

      if (!matches) {
        _wPinError = 'Incorrect current withdrawal PIN. Try again.';
        _wCurrentEntry.clear();
        notifyListeners();
        return;
      }
      _wPinStep = 1;
      notifyListeners();
      return;
    }

    if (_wPinStep == _wNewStepIndex) {
      _wPinStep = _wConfirmStepIndex;
      notifyListeners();
      return;
    }

    // Confirm step — new and confirm entries must match.
    if (_wNewEntry.join() != _wConfirmEntry.join()) {
      _wPinError = 'PINs do not match. Try again.';
      _wConfirmEntry.clear();
      notifyListeners();
      return;
    }

    _action = SecurityAction.loading;
    notifyListeners();

    final newPin = _wNewEntry.join();

    // Push the new withdrawal PIN to the account (backend) first, so every
    // other device on this account picks it up too.
    final error = await _repo.setWithdrawalPinRemote(
      newPin: newPin,
      currentPin: _isChangingWithdrawalPin && _wCurrentEntry.isNotEmpty
          ? _wCurrentEntry.join()
          : null,
    );

    if (error != null) {
      _action = SecurityAction.error;
      _message = error;
      notifyListeners();
      return;
    }

    await prefs.setString('withdrawal_pin_$userId', newPin);

    _hasWithdrawalPin = true;
    _action = SecurityAction.success;
    _withdrawalPinChanged = true;
    _message = _isChangingWithdrawalPin
        ? 'Withdrawal PIN changed successfully.'
        : 'Withdrawal PIN set successfully.';
    notifyListeners();
  }

  String get withdrawalPinTitle {
    if (_isChangingWithdrawalPin) {
      if (_wPinStep == 0) return 'Enter Current Withdrawal PIN';
      if (_wPinStep == 1) return 'Enter New Withdrawal PIN';
      return 'Confirm New Withdrawal PIN';
    }
    if (_wPinStep == 0) return 'Set Withdrawal PIN';
    return 'Confirm Withdrawal PIN';
  }

  String get withdrawalPinSubtitle {
    if (_isChangingWithdrawalPin) {
      if (_wPinStep == 0) {
        return 'Enter your existing 4-digit withdrawal PIN to continue.';
      }
      if (_wPinStep == 1) {
        return 'Choose a new 4-digit PIN for withdrawal requests.';
      }
      return 'Re-enter the new PIN to confirm the change.';
    }
    if (_wPinStep == 0) {
      return 'Create a 4-digit PIN you\'ll enter every time you '
          'submit a withdrawal request.';
    }
    return 'Re-enter the PIN to confirm.';
  }

  // Total number of steps in the current withdrawal-PIN flow (used to size
  // the step indicator dots on the sheet).
  int get withdrawalPinTotalSteps => _isChangingWithdrawalPin ? 3 : 2;

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
    _withdrawalPinLockTimer?.cancel();
    super.dispose();
  }
}