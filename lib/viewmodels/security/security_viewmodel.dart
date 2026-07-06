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
    return saved.isNotEmpty;
  }

  static Future<bool> verifyWithdrawalPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('logged_in_user_id') ?? '';
    final saved = prefs.getString('withdrawal_pin_$userId') ?? '';
    return saved.isNotEmpty && saved == pin;
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

  // Change PIN step: 0=current, 1=new, 2=confirm
  int _changePinStep = 0;
  int get changePinStep => _changePinStep;
  List<int> _currentPinEntry = [];
  List<int> _newPinEntry = [];
  List<int> _confirmPinEntry = [];
  static const int pinLength = 4;

  List<int> get activePinEntry {
    if (_changePinStep == 0) return _currentPinEntry;
    if (_changePinStep == 1) return _newPinEntry;
    return _confirmPinEntry;
  }

  String? _pinError;
  String? get pinError => _pinError;

  bool _pinChanged = false;
  bool get pinChanged => _pinChanged;

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

  // ── Change PIN ────────────────────────────────────────────────────────────
  void resetChangePinFlow() {
    _changePinStep = 0;
    _currentPinEntry = [];
    _newPinEntry = [];
    _confirmPinEntry = [];
    _pinError = null;
    _pinChanged = false;
    notifyListeners();
  }

  void pinKeyPress(int digit) {
    final entry = activePinEntry;
    if (entry.length >= pinLength) return;
    entry.add(digit);
    notifyListeners();
  }

  void pinDelete() {
    final entry = activePinEntry;
    if (entry.isEmpty) return;
    entry.removeLast();
    _pinError = null;
    notifyListeners();
  }

  Future<void> pinConfirm() async {
    final entry = activePinEntry;
    if (entry.length < pinLength) {
      _pinError = 'Enter all $pinLength digits';
      notifyListeners();
      return;
    }
    _pinError = null;

    if (_changePinStep == 0) {
      // Validate the current PIN against the locally stored app-lock PIN —
      // the same one checked on the GPay-style PIN-lock screen — instead of
      // the account login password. This is "Change PIN", not
      // "Change Password".
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('logged_in_user_id') ?? '';
      final savedPin = prefs.getString('app_pin_$userId') ?? '';

      if (_currentPinEntry.join() != savedPin) {
        _pinError = 'Incorrect current PIN. Try again.';
        _currentPinEntry.clear();
        notifyListeners();
        return;
      }

      _changePinStep = 1;
      notifyListeners();
    } else if (_changePinStep == 1) {
      _changePinStep = 2;
      notifyListeners();
    } else {
      // Confirm step — check local match first
      if (_newPinEntry.join() != _confirmPinEntry.join()) {
        _pinError = 'PINs do not match. Try again.';
        _confirmPinEntry.clear();
        notifyListeners();
        return;
      }

      _action = SecurityAction.loading;
      notifyListeners();

      // Save the new PIN locally — this is the exact value the PIN-lock
      // screen (and the set-PIN flow) read from, so the change takes effect
      // immediately on the next login/unlock with no extra step needed.
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('logged_in_user_id') ?? '';
      await prefs.setString('app_pin_$userId', _newPinEntry.join());

      _action = SecurityAction.success;
      _pinChanged = true;
      _message = 'PIN changed successfully.';
      notifyListeners();
    }
  }

  String get changePinTitle {
    if (_changePinStep == 0) return 'Enter Current PIN';
    if (_changePinStep == 1) return 'Enter New PIN';
    return 'Confirm New PIN';
  }

  String get changePinSubtitle {
    if (_changePinStep == 0) {
      return 'Enter your existing 4-digit PIN to continue.';
    }
    if (_changePinStep == 1) {
      return 'Choose a strong 4-digit PIN you haven\'t used before.';
    }
    return 'Re-enter the new PIN to confirm the change.';
  }

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
      // Verify the existing withdrawal PIN before allowing it to be changed.
      final savedPin = prefs.getString('withdrawal_pin_$userId') ?? '';
      if (_wCurrentEntry.join() != savedPin) {
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

    await prefs.setString('withdrawal_pin_$userId', _wNewEntry.join());

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
    super.dispose();
  }
}