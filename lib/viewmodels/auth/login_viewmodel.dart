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

  LoginStatus get status => _status;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _status == LoginStatus.loading;
  bool get rememberMe => _rememberMe;
  String? get identifierError => _identifierError;
  String? get passwordError => _passwordError;

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

  void toggleRememberMe() {
    _rememberMe = !_rememberMe;
    notifyListeners();
  }

  // Returns: 'home' | 'set_password' | 'app_pin' | null (failure)
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
        final token = response['data']?['token'] as String?;
        final userId = response['data']?['user']?['id'];
        final userEmail = response['data']?['user']?['email'] as String?;
        final userPhone = response['data']?['user']?['phone'] as String?;
        final userFirstName =
            response['data']?['user']?['first_name'] as String?;
        // Whether this is a first-time login (no app-pin set yet)
        final isNew = response['data']?['is_new_user'] as bool? ?? false;

        if (token != null) {
          final prefs = await SharedPreferences.getInstance();
          final previousUserId = prefs.getString('logged_in_user_id');
          final newUserId = userId?.toString() ?? '';

          final isAccountSwitch =
              previousUserId != null &&
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
          final label =
              (userFirstName != null && userFirstName.trim().isNotEmpty)
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

          _status = LoginStatus.success;
          notifyListeners();

          // New user or no pin set → set password flow first
          if (isNew || existingPin.isEmpty) {
            return 'set_password';
          }
          // Returning user with PIN → show GPay-style PIN verify
          return 'app_pin';
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
    notifyListeners();
  }
}
