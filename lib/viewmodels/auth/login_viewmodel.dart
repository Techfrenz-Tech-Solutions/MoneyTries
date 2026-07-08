import 'dart:async';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';
import '../../services/biometric_auth_service.dart';
import '../../data/security/security_repository.dart';

enum LoginStatus { idle, loading, success, error }

class LoginViewModel extends ChangeNotifier {
  LoginStatus _status = LoginStatus.idle;
  String? _errorMessage;
  bool _rememberMe = false;

  String? _identifierError;
  String? _passwordError;

  // ── Login-time 2FA state ────────────────────────────────────────────────
  // Populated when login() determines the account has 2FA enabled. The
  // pending token is short-lived and only usable against the two
  // /api/auth/2fa/* endpoints below — it can never reach a normal protected
  // route, so this screen genuinely cannot skip straight to the PIN/Home
  // flow without a correct OTP.
  String? _pendingToken;
  String? _phoneHint;
  int _otpExpirySeconds = 300;
  String? _otpErrorMessage;
  bool _isVerifyingOtp = false;
  bool _isResendingOtp = false;

  LoginStatus get status => _status;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _status == LoginStatus.loading;
  bool get rememberMe => _rememberMe;
  String? get identifierError => _identifierError;
  String? get passwordError => _passwordError;

  String? get pendingToken => _pendingToken;
  String? get phoneHint => _phoneHint;
  int get otpExpirySeconds => _otpExpirySeconds;
  String? get otpErrorMessage => _otpErrorMessage;
  bool get isVerifyingOtp => _isVerifyingOtp;
  bool get isResendingOtp => _isResendingOtp;

  String? validateIdentifier(String value) {
    final v = value.trim();
    if (v.isEmpty) return 'Please enter your email or mobile number';
    final isEmail = RegExp(r'^[^\@\s]+@[^\@\s]+\.[^\@\s]+$').hasMatch(v);
    final isMobile = RegExp(r'^\d{10}$').hasMatch(v);
    if (!isEmail && !isMobile) {
      return 'Enter a valid email or 10-digit mobile number';
    }
    return null;
  }

  String? validatePassword(String value) {
    if (value.isEmpty) return 'Please enter your password';
    if (value.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  void clearIdentifierError() {
    if (_identifierError != null) {
      _identifierError = null;
      notifyListeners();
    }
  }

  void clearPasswordError() {
    if (_passwordError != null) {
      _passwordError = null;
      notifyListeners();
    }
  }

  void clearOtpError() {
    if (_otpErrorMessage != null) {
      _otpErrorMessage = null;
      notifyListeners();
    }
  }

  void toggleRememberMe() {
    _rememberMe = !_rememberMe;
    notifyListeners();
  }

  // Returns: 'home' | 'set_password' | 'app_pin' | 'verify_2fa' | null (failure)
  Future<String?> login({
    required String identifier,
    required String password,
  }) async {
    _identifierError = validateIdentifier(identifier);
    _passwordError = validatePassword(password);

    if (_identifierError != null || _passwordError != null) {
      notifyListeners();
      return null;
    }

    _status = LoginStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await ApiService.login(
        identifier: identifier.trim(),
        password: password,
      );

      if (response['success'] == true) {
        final data = response['data'] as Map<String, dynamic>?;

        // ── 2FA required ───────────────────────────────────────────────
        // Identifier + password were correct, but the account has 2FA
        // enabled. The backend has already sent an OTP to the registered
        // mobile number and returned only a short-lived pending token —
        // no real session has been created yet, so we must NOT skip ahead
        // to the PIN/Home flow here.
        if (data?['requires_2fa'] == true) {
          _pendingToken = data?['pending_token'] as String?;
          _phoneHint = data?['phone_hint'] as String?;
          _otpExpirySeconds = data?['expires_in_seconds'] as int? ?? 300;
          _otpErrorMessage = null;

          _status = LoginStatus.success;
          notifyListeners();
          return 'verify_2fa';
        }

        final token = data?['token'] as String?;
        if (token != null) {
          final route = await _completeAuth(data!);
          _status = LoginStatus.success;
          notifyListeners();
          return route;
        }

        _status = LoginStatus.success;
        notifyListeners();
        return 'home';
      }

      _status = LoginStatus.error;
      _errorMessage = response['message'] ?? 'Login failed';
      notifyListeners();
      return null;
    } catch (e) {
      _status = LoginStatus.error;
      _errorMessage = e.toString();
      notifyListeners();
      return null;
    }
  }

  // ── Step 2 (2FA only): verify the OTP sent during login ────────────────
  // Returns: 'home' | 'set_password' | 'app_pin' | null (failure)
  Future<String?> verifyLoginOtp(String otp) async {
    if (_pendingToken == null) {
      _otpErrorMessage = 'Session expired. Please log in again.';
      notifyListeners();
      return null;
    }

    if (otp.length != 6) {
      _otpErrorMessage = 'Please enter all 6 digits';
      notifyListeners();
      return null;
    }

    _isVerifyingOtp = true;
    _otpErrorMessage = null;
    notifyListeners();

    try {
      final response = await ApiService.verifyLoginOtp(
        pendingToken: _pendingToken!,
        otp: otp,
      );

      if (response['success'] == true) {
        final data = response['data'] as Map<String, dynamic>?;
        final route = await _completeAuth(data ?? {});

        // The pending token and OTP context are single-use — clear them so
        // a stale reference can never be reused after this point.
        _pendingToken = null;
        _phoneHint = null;

        _isVerifyingOtp = false;
        notifyListeners();
        return route;
      }

      _isVerifyingOtp = false;
      _otpErrorMessage =
          response['message']?.toString() ?? 'Invalid OTP. Please try again.';
      notifyListeners();
      return null;
    } catch (e) {
      _isVerifyingOtp = false;
      _otpErrorMessage = 'Something went wrong. Please try again.';
      notifyListeners();
      return null;
    }
  }

  // ── Resend OTP (2FA only) ───────────────────────────────────────────────
  Future<bool> resendLoginOtp() async {
    if (_pendingToken == null) {
      _otpErrorMessage = 'Session expired. Please log in again.';
      notifyListeners();
      return false;
    }

    _isResendingOtp = true;
    _otpErrorMessage = null;
    notifyListeners();

    try {
      final response = await ApiService.resendLoginOtp(
        pendingToken: _pendingToken!,
      );

      if (response['success'] == true) {
        final data = response['data'] as Map<String, dynamic>?;
        _otpExpirySeconds = data?['expires_in_seconds'] as int? ?? 300;
        _phoneHint = data?['phone_hint'] as String? ?? _phoneHint;
        _isResendingOtp = false;
        notifyListeners();
        return true;
      }

      _isResendingOtp = false;
      _otpErrorMessage = response['message']?.toString() ??
          'Failed to resend OTP. Please try again.';
      notifyListeners();
      return false;
    } catch (e) {
      _isResendingOtp = false;
      _otpErrorMessage = 'Something went wrong. Please try again.';
      notifyListeners();
      return false;
    }
  }

  /// Shared by both the direct (non-2FA) login success path and the
  /// post-OTP-verification success path: persists the session, registers
  /// the device/login event, refreshes any remembered biometric session,
  /// and decides which screen to route to next.
  ///
  /// Returns: 'set_password' | 'app_pin' | 'home'
  Future<String> _completeAuth(Map<String, dynamic> data) async {
    final token = data['token'] as String?;
    final userId = data['user']?['id'];
    final userEmail = data['user']?['email'] as String?;
    final userPhone = data['user']?['phone'] as String?;
    final userFirstName = data['user']?['first_name'] as String?;
    // Whether this is a first-time login (no app-pin set yet)
    final isNew = data['is_new_user'] as bool? ?? false;

    if (token == null) return 'home';

    final prefs = await SharedPreferences.getInstance();
    final previousUserId = prefs.getString('logged_in_user_id');
    final newUserId = userId?.toString() ?? '';

    final isAccountSwitch = previousUserId != null &&
        previousUserId.isNotEmpty &&
        previousUserId != newUserId;

    if (isAccountSwitch) {
      await prefs.remove('auth_token');
      await prefs.remove('logged_in_user_id');
      await prefs.remove('logged_in_user_label');
      // NOTE: we intentionally do NOT delete the previous account's
      // saved PIN (app_pin_$previousUserId). Each account's PIN is
      // namespaced by its own userId, so leaving it in place just
      // means that account won't need to re-create a PIN the next
      // time someone logs into it — it never gets mixed up with the
      // new account being logged into below.
    }

    await prefs.setString('auth_token', token);
    await prefs.setString('logged_in_user_id', newUserId);
    // Human-readable label so the PIN-lock screen can clearly show
    // *which* account it is unlocking — this removes any ambiguity
    // when two different accounts happen to share the same PIN digits,
    // since the PIN is always checked against this one active session,
    // never matched/searched across accounts.
    final label = (userFirstName != null && userFirstName.trim().isNotEmpty)
        ? userFirstName.trim()
        : (userEmail ?? userPhone ?? '');
    await prefs.setString('logged_in_user_label', label);

    // Register this login as an active device session and record
    // the login event so Security Settings → "Manage Devices" /
    // "Login Activity" reflect real data instead of staying empty.
    final deviceName = await _getDeviceName();
    unawaited(SecurityRepository().registerCurrentSession(token));
    unawaited(
      SecurityRepository().recordLoginEvent(
        deviceName: deviceName,
        location: 'India',
        success: true,
      ),
    );

    // If this account already has biometrics turned on (from a
    // previous session on this device), refresh the device-remembered
    // session with the freshly issued token so biometric quick-login
    // on the credentials screen keeps working after this login too.
    if (await BiometricAuthService.isEnabledFor(newUserId)) {
      await BiometricAuthService.rememberSession(
        userId: newUserId,
        token: token,
        label: label,
      );
    }

    // Check if this user already has an app PIN set
    final existingPin = prefs.getString('app_pin_$newUserId') ?? '';

    // New user or no pin set → set password flow first
    if (isNew || existingPin.isEmpty) {
      return 'set_password';
    }
    // Returning user with PIN → show GPay-style PIN verify
    return 'app_pin';
  }

  /// Returns the real device model name (e.g. "Samsung Galaxy S24",
  /// "iPhone 15 Pro") using device_info_plus. Falls back gracefully on error.
  static Future<String> _getDeviceName() async {
    try {
      final info = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final android = await info.androidInfo;
        final brand = android.brand.trim();
        final model = android.model.trim();
        // Avoid duplication when brand is already part of the model string
        // (e.g. "samsung SM-S926B" → "Samsung SM-S926B")
        if (model.toLowerCase().startsWith(brand.toLowerCase())) {
          return _capitalize(model);
        }
        return '${_capitalize(brand)} $model';
      } else if (Platform.isIOS) {
        final ios = await info.iosInfo;
        return ios.name.trim().isNotEmpty ? ios.name : ios.utsname.machine;
      }
    } catch (_) {}
    return 'Unknown Device';
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  Future<void> sendForgotPasswordOtp(String identifier) async {
    await Future.delayed(const Duration(milliseconds: 800));
  }

  void resetState() {
    _status = LoginStatus.idle;
    _errorMessage = null;
    _identifierError = null;
    _passwordError = null;
    _pendingToken = null;
    _phoneHint = null;
    _otpErrorMessage = null;
    notifyListeners();
  }
}