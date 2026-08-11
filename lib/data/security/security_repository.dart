// lib/data/security/security_repository.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;
import '../../core/network/session_http_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/security/security_model.dart';
import '../../services/biometric_auth_service.dart';
import '../../core/api/api_config.dart';

const String _kBaseUrl = ApiConfig.baseUrl;
class SecurityRepository {
  // ── Token ──────────────────────────────────────────────────────────────────
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Map<String, String> _authHeader(String token) => {
    'Authorization': 'Bearer $token',
    'Content-Type': 'application/json',
  };

  // ── Change PIN (password) ──────────────────────────────────────────────────
  /// Returns null on success, error message on failure.
  Future<String?> changePin({
    required String currentPin,
    required String newPin,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return 'Session expired. Please log in again.';

      final res = await sessionHttpClient
          .post(
            Uri.parse('$_kBaseUrl/api/security/change-password'),
            headers: _authHeader(token),
            body: jsonEncode({
              'current_password': currentPin,
              'new_password': newPin,
              'confirm_password': newPin,
            }),
          )
          .timeout(const Duration(seconds: 15));

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200 && body['success'] == true) {
        return null;
      }
      return body['message']?.toString() ?? 'Failed to change PIN.';
    } on SocketException {
      return 'No internet connection.';
    } catch (_) {
      return 'Something went wrong. Please try again.';
    }
  }

  // ── Login Credentials → Change Password ──────────────────────────────────────
  // Step 1: verify the account's current login password. Attempts and any
  // resulting lockout are tracked server-side so they can't be bypassed by
  // restarting the app.
  Future<PasswordChangeStatus> verifyCurrentPassword(String currentPassword) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return const PasswordChangeStatus(
          success: false,
          locked: false,
          remainingSeconds: 0,
          remainingAttempts: 5,
          message: 'Session expired. Please log in again.',
        );
      }

      final res = await sessionHttpClient
          .post(
            Uri.parse('$_kBaseUrl/api/security/password/verify'),
            headers: _authHeader(token),
            body: jsonEncode({'current_password': currentPassword}),
          )
          .timeout(const Duration(seconds: 15));

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final success = res.statusCode == 200 && body['success'] == true;
      final message = body['message']?.toString() ??
          (success ? 'Password verified' : 'Current password is incorrect.');

      return PasswordChangeStatus.fromJson(body, success: success, message: message);
    } on SocketException {
      return const PasswordChangeStatus(
        success: false,
        locked: false,
        remainingSeconds: 0,
        remainingAttempts: 5,
        message: 'No internet connection.',
      );
    } catch (_) {
      return const PasswordChangeStatus(
        success: false,
        locked: false,
        remainingSeconds: 0,
        remainingAttempts: 5,
        message: 'Something went wrong. Please try again.',
      );
    }
  }

  // Resumes lock/attempt state if the user re-opens Change Password after
  // the app was backgrounded or killed mid-lockout.
  Future<PasswordChangeStatus> getPasswordChangeStatus() async {
    try {
      final token = await _getToken();
      if (token == null) {
        return const PasswordChangeStatus(
          success: false,
          locked: false,
          remainingSeconds: 0,
          remainingAttempts: 5,
          message: 'Session expired. Please log in again.',
        );
      }

      final res = await sessionHttpClient
          .get(
            Uri.parse('$_kBaseUrl/api/security/password/status'),
            headers: _authHeader(token),
          )
          .timeout(const Duration(seconds: 15));

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final success = res.statusCode == 200 && body['success'] == true;
      return PasswordChangeStatus.fromJson(
        body,
        success: success,
        message: body['message']?.toString() ?? '',
      );
    } catch (_) {
      return const PasswordChangeStatus(
        success: true,
        locked: false,
        remainingSeconds: 0,
        remainingAttempts: 5,
        message: '',
      );
    }
  }

  // Step 2: set the new login password. Only succeeds within the short
  // window opened by a successful verifyCurrentPassword call.
  /// Returns null on success, error message on failure.
  Future<String?> updatePassword({
    required String newPassword,
    required String confirmPassword,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return 'Session expired. Please log in again.';

      final res = await sessionHttpClient
          .post(
            Uri.parse('$_kBaseUrl/api/security/password/update'),
            headers: _authHeader(token),
            body: jsonEncode({
              'new_password': newPassword,
              'confirm_password': confirmPassword,
            }),
          )
          .timeout(const Duration(seconds: 15));

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200 && body['success'] == true) {
        return null;
      }
      return body['message']?.toString() ?? 'Failed to change password.';
    } on SocketException {
      return 'No internet connection.';
    } catch (_) {
      return 'Something went wrong. Please try again.';
    }
  }

  // ── Account-level Login PIN / Withdrawal PIN / Biometric sync ───────────────
  // These make Login PIN, Withdrawal PIN, and the Biometric Login preference
  // properties of the account (backend), instead of purely per-device
  // SharedPreferences. Any device can fetch what's already configured and
  // any change made on one device is picked up by the others.

  Future<PinSyncStatus> getPinsStatus() async {
    try {
      final token = await _getToken();
      if (token == null) return const PinSyncStatus();

      final res = await sessionHttpClient
          .get(
            Uri.parse('$_kBaseUrl/api/security/pins/status'),
            headers: _authHeader(token),
          )
          .timeout(const Duration(seconds: 10));

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200 && body['success'] == true) {
        return PinSyncStatus.fromJson(
          body['data'] as Map<String, dynamic>? ?? {},
        );
      }
      return const PinSyncStatus();
    } catch (_) {
      return const PinSyncStatus();
    }
  }

  Future<String?> setLoginPinRemote({
    required String newPin,
    String? currentPin,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return 'Session expired. Please log in again.';

      final res = await sessionHttpClient
          .post(
            Uri.parse('$_kBaseUrl/api/security/pin/login'),
            headers: _authHeader(token),
            body: jsonEncode({
              'new_pin': newPin,
              if (currentPin != null) 'current_pin': currentPin,
            }),
          )
          .timeout(const Duration(seconds: 15));

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200 && body['success'] == true) {
        return null;
      }
      return body['message']?.toString() ?? 'Failed to save Login PIN.';
    } on SocketException {
      return 'No internet connection.';
    } catch (_) {
      return 'Something went wrong. Please try again.';
    }
  }

  Future<bool> verifyLoginPinRemote(String pin) async {
    try {
      final token = await _getToken();
      if (token == null) return false;

      final res = await sessionHttpClient
          .post(
            Uri.parse('$_kBaseUrl/api/security/pin/login/verify'),
            headers: _authHeader(token),
            body: jsonEncode({'pin': pin}),
          )
          .timeout(const Duration(seconds: 15));

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200 && body['success'] == true) {
        return body['data']?['valid'] == true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  // ── Login PIN → Change Login PIN ─────────────────────────────────────────
  // Server-enforced version of the Login PIN change flow: current-PIN
  // verification, attempts, and any resulting lockout are all tracked and
  // checked on the backend so the 5-attempt limit can't be bypassed by
  // restarting the app or clearing local storage.

  // Step 1: verify the account's current Login PIN.
  Future<PasswordChangeStatus> verifyCurrentLoginPin(String currentPin) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return const PasswordChangeStatus(
          success: false,
          locked: false,
          remainingSeconds: 0,
          remainingAttempts: 5,
          message: 'Session expired. Please log in again.',
        );
      }

      final res = await sessionHttpClient
          .post(
            Uri.parse('$_kBaseUrl/api/security/pin/login/change/verify'),
            headers: _authHeader(token),
            body: jsonEncode({'current_pin': currentPin}),
          )
          .timeout(const Duration(seconds: 15));

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final success = res.statusCode == 200 && body['success'] == true;
      final message = body['message']?.toString() ??
          (success ? 'PIN verified' : 'Incorrect PIN');

      return PasswordChangeStatus.fromJson(body, success: success, message: message);
    } on SocketException {
      return const PasswordChangeStatus(
        success: false,
        locked: false,
        remainingSeconds: 0,
        remainingAttempts: 5,
        message: 'No internet connection.',
      );
    } catch (_) {
      return const PasswordChangeStatus(
        success: false,
        locked: false,
        remainingSeconds: 0,
        remainingAttempts: 5,
        message: 'Something went wrong. Please try again.',
      );
    }
  }

  // Resumes lock/attempt state if the user re-opens Change Login PIN after
  // the app was backgrounded or killed mid-lockout.
  Future<PasswordChangeStatus> getLoginPinChangeStatus() async {
    try {
      final token = await _getToken();
      if (token == null) {
        return const PasswordChangeStatus(
          success: false,
          locked: false,
          remainingSeconds: 0,
          remainingAttempts: 5,
          message: 'Session expired. Please log in again.',
        );
      }

      final res = await sessionHttpClient
          .get(
            Uri.parse('$_kBaseUrl/api/security/pin/login/change/status'),
            headers: _authHeader(token),
          )
          .timeout(const Duration(seconds: 15));

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final success = res.statusCode == 200 && body['success'] == true;
      return PasswordChangeStatus.fromJson(
        body,
        success: success,
        message: body['message']?.toString() ?? '',
      );
    } catch (_) {
      return const PasswordChangeStatus(
        success: true,
        locked: false,
        remainingSeconds: 0,
        remainingAttempts: 5,
        message: '',
      );
    }
  }

  // Step 2: set the new Login PIN. Only succeeds within the short window
  // opened by a successful verifyCurrentLoginPin call.
  /// Returns null on success, error message on failure.
  Future<String?> updateLoginPin({
    required String newPin,
    required String confirmPin,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return 'Session expired. Please log in again.';

      final res = await sessionHttpClient
          .post(
            Uri.parse('$_kBaseUrl/api/security/pin/login/change/update'),
            headers: _authHeader(token),
            body: jsonEncode({
              'new_pin': newPin,
              'confirm_pin': confirmPin,
            }),
          )
          .timeout(const Duration(seconds: 15));

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200 && body['success'] == true) {
        return null;
      }
      return body['message']?.toString() ?? 'Failed to save Login PIN.';
    } on SocketException {
      return 'No internet connection.';
    } catch (_) {
      return 'Something went wrong. Please try again.';
    }
  }

  Future<String?> setWithdrawalPinRemote({
    required String newPin,
    String? currentPin,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return 'Session expired. Please log in again.';

      final res = await sessionHttpClient
          .post(
            Uri.parse('$_kBaseUrl/api/security/pin/withdrawal'),
            headers: _authHeader(token),
            body: jsonEncode({
              'new_pin': newPin,
              if (currentPin != null) 'current_pin': currentPin,
            }),
          )
          .timeout(const Duration(seconds: 15));

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200 && body['success'] == true) {
        return null;
      }
      return body['message']?.toString() ?? 'Failed to save withdrawal PIN.';
    } on SocketException {
      return 'No internet connection.';
    } catch (_) {
      return 'Something went wrong. Please try again.';
    }
  }

  Future<bool> verifyWithdrawalPinRemote(String pin) async {
    try {
      final token = await _getToken();
      if (token == null) return false;

      final res = await sessionHttpClient
          .post(
            Uri.parse('$_kBaseUrl/api/security/pin/withdrawal/verify'),
            headers: _authHeader(token),
            body: jsonEncode({'pin': pin}),
          )
          .timeout(const Duration(seconds: 15));

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200 && body['success'] == true) {
        return body['data']?['valid'] == true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  // Step 1: verify the current Withdrawal PIN (server-side attempt counter,
  // 5-attempt cap, 5-minute lockout — mirrors verifyCurrentLoginPin).
  Future<PasswordChangeStatus> verifyCurrentWithdrawalPin(String currentPin) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return const PasswordChangeStatus(
          success: false,
          locked: false,
          remainingSeconds: 0,
          remainingAttempts: 5,
          message: 'Session expired. Please log in again.',
        );
      }

      final res = await sessionHttpClient
          .post(
            Uri.parse('$_kBaseUrl/api/security/pin/withdrawal/change/verify'),
            headers: _authHeader(token),
            body: jsonEncode({'current_pin': currentPin}),
          )
          .timeout(const Duration(seconds: 15));

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final success = res.statusCode == 200 && body['success'] == true;
      final message = body['message']?.toString() ??
          (success ? 'PIN verified' : 'Incorrect PIN');

      return PasswordChangeStatus.fromJson(body, success: success, message: message);
    } on SocketException {
      return const PasswordChangeStatus(
        success: false,
        locked: false,
        remainingSeconds: 0,
        remainingAttempts: 5,
        message: 'No internet connection.',
      );
    } catch (_) {
      return const PasswordChangeStatus(
        success: false,
        locked: false,
        remainingSeconds: 0,
        remainingAttempts: 5,
        message: 'Something went wrong. Please try again.',
      );
    }
  }

  // Resumes lock/attempt state if the user re-opens Change Withdrawal PIN
  // after the app was backgrounded or killed mid-lockout.
  Future<PasswordChangeStatus> getWithdrawalPinChangeStatus() async {
    try {
      final token = await _getToken();
      if (token == null) {
        return const PasswordChangeStatus(
          success: false,
          locked: false,
          remainingSeconds: 0,
          remainingAttempts: 5,
          message: 'Session expired. Please log in again.',
        );
      }

      final res = await sessionHttpClient
          .get(
            Uri.parse('$_kBaseUrl/api/security/pin/withdrawal/change/status'),
            headers: _authHeader(token),
          )
          .timeout(const Duration(seconds: 15));

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final success = res.statusCode == 200 && body['success'] == true;
      return PasswordChangeStatus.fromJson(
        body,
        success: success,
        message: body['message']?.toString() ?? '',
      );
    } catch (_) {
      return const PasswordChangeStatus(
        success: true,
        locked: false,
        remainingSeconds: 0,
        remainingAttempts: 5,
        message: '',
      );
    }
  }

  // Step 2: set the new Withdrawal PIN. Only succeeds within the short
  // window opened by a successful verifyCurrentWithdrawalPin call.
  /// Returns null on success, error message on failure.
  Future<String?> updateWithdrawalPin({
    required String newPin,
    required String confirmPin,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return 'Session expired. Please log in again.';

      final res = await sessionHttpClient
          .post(
            Uri.parse('$_kBaseUrl/api/security/pin/withdrawal/change/update'),
            headers: _authHeader(token),
            body: jsonEncode({
              'new_pin': newPin,
              'confirm_pin': confirmPin,
            }),
          )
          .timeout(const Duration(seconds: 15));

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200 && body['success'] == true) {
        return null;
      }
      return body['message']?.toString() ?? 'Failed to save Withdrawal PIN.';
    } on SocketException {
      return 'No internet connection.';
    } catch (_) {
      return 'Something went wrong. Please try again.';
    }
  }

  Future<String?> setBiometricEnabledRemote(bool enabled) async {
    try {
      final token = await _getToken();
      if (token == null) return 'Session expired. Please log in again.';

      final res = await sessionHttpClient
          .post(
            Uri.parse('$_kBaseUrl/api/security/biometric'),
            headers: _authHeader(token),
            body: jsonEncode({'enabled': enabled}),
          )
          .timeout(const Duration(seconds: 15));

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200 && body['success'] == true) {
        return null;
      }
      return body['message']?.toString() ?? 'Failed to update biometric setting.';
    } on SocketException {
      return 'No internet connection.';
    } catch (_) {
      return 'Something went wrong. Please try again.';
    }
  }

  // ── Biometric preference (local only, namespaced per account) ───────────────
  // Delegates to BiometricAuthService so this flag, the device-remembered
  // quick-login session, and the app-lock PIN screen stay in sync using the
  // exact same per-account state.
  Future<bool> getBiometricsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('logged_in_user_id') ?? '';
    return BiometricAuthService.isEnabledFor(userId);
  }

  Future<void> setBiometricsEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('logged_in_user_id') ?? '';
    await BiometricAuthService.setEnabledFor(userId, value);

    // Sync the on/off preference to the account so other devices know
    // biometric login is (or isn't) turned on for this account too.
    // Fire-and-forget: the local flag above is the source of truth for
    // this device's own UI, and _loadPreferences() reconciles from the
    // backend on next load if this call fails offline.
    unawaited(setBiometricEnabledRemote(value));

    if (value) {
      // Snapshot the active session so the login screen can offer a real
      // "Quick Login with Biometrics" option for this account going forward.
      final token = prefs.getString('auth_token') ?? '';
      final label = prefs.getString('logged_in_user_label') ?? '';
      await BiometricAuthService.rememberSession(
        userId: userId,
        token: token,
        label: label,
      );
    } else {
      await BiometricAuthService.forgetSession(userId);
    }
  }

  // ── 2FA status ─────────────────────────────────────────────────────────────
  Future<bool> getTwoFactorEnabled() async {
    try {
      final token = await _getToken();
      if (token == null) return false;

      final res = await sessionHttpClient
          .get(
            Uri.parse('$_kBaseUrl/api/security/2fa/status'),
            headers: _authHeader(token),
          )
          .timeout(const Duration(seconds: 10));

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200 && body['success'] == true) {
        return body['data']?['two_factor_enabled'] == true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  // ── 2FA: send OTP ──────────────────────────────────────────────────────────
  Future<String?> send2faOtp() async {
    try {
      final token = await _getToken();
      if (token == null) return 'Session expired. Please log in again.';

      final res = await sessionHttpClient
          .post(
            Uri.parse('$_kBaseUrl/api/security/2fa/send-otp'),
            headers: _authHeader(token),
          )
          .timeout(const Duration(seconds: 15));

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200 && body['success'] == true) {
        return null;
      }
      return body['message']?.toString() ?? 'Failed to send OTP.';
    } on SocketException {
      return 'No internet connection.';
    } catch (_) {
      return 'Something went wrong. Please try again.';
    }
  }

  // ── 2FA: verify OTP ────────────────────────────────────────────────────────
  Future<String?> verify2faOtp(String otp) async {
    try {
      final token = await _getToken();
      if (token == null) return 'Session expired. Please log in again.';

      final res = await sessionHttpClient
          .post(
            Uri.parse('$_kBaseUrl/api/security/2fa/verify-otp'),
            headers: _authHeader(token),
            body: jsonEncode({'otp': otp}),
          )
          .timeout(const Duration(seconds: 15));

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200 && body['success'] == true) {
        return null;
      }
      return body['message']?.toString() ?? 'Invalid OTP.';
    } on SocketException {
      return 'No internet connection.';
    } catch (_) {
      return 'Something went wrong. Please try again.';
    }
  }

  // ── 2FA: disable ───────────────────────────────────────────────────────────
  Future<String?> disable2fa() async {
    try {
      final token = await _getToken();
      if (token == null) return 'Session expired. Please log in again.';

      final res = await sessionHttpClient
          .post(
            Uri.parse('$_kBaseUrl/api/security/2fa/disable'),
            headers: _authHeader(token),
          )
          .timeout(const Duration(seconds: 15));

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200 && body['success'] == true) {
        return null;
      }
      return body['message']?.toString() ?? 'Failed to disable 2FA.';
    } on SocketException {
      return 'No internet connection.';
    } catch (_) {
      return 'Something went wrong. Please try again.';
    }
  }

  // ── Sessions ───────────────────────────────────────────────────────────────
  Future<List<DeviceSession>> getSessions() async {
    try {
      final token = await _getToken();
      if (token == null) return [];

      final res = await sessionHttpClient
          .get(
            Uri.parse('$_kBaseUrl/api/security/sessions'),
            headers: _authHeader(token),
          )
          .timeout(const Duration(seconds: 15));

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200 && body['success'] == true) {
        final list = (body['data']?['sessions'] as List<dynamic>?) ?? [];
        return list
            .map((e) => DeviceSession.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<String?> revokeSession(String sessionId) async {
    try {
      final token = await _getToken();
      if (token == null) return 'Session expired. Please log in again.';

      final res = await sessionHttpClient
          .delete(
            Uri.parse('$_kBaseUrl/api/security/sessions/$sessionId'),
            headers: _authHeader(token),
          )
          .timeout(const Duration(seconds: 15));

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200 && body['success'] == true) {
        return null;
      }
      return body['message']?.toString() ?? 'Failed to revoke session.';
    } on SocketException {
      return 'No internet connection.';
    } catch (_) {
      return 'Something went wrong. Please try again.';
    }
  }

  /// Register current device session with the backend after login.
  Future<void> registerCurrentSession(String sessionToken) async {
    try {
      final token = await _getToken();
      if (token == null) return;

      final deviceName = await _resolveDeviceName();
      final deviceType = Platform.isAndroid
          ? 'android'
          : Platform.isIOS
          ? 'ios'
          : 'other';

      await sessionHttpClient
          .post(
            Uri.parse('$_kBaseUrl/api/security/sessions/register'),
            headers: _authHeader(token),
            body: jsonEncode({
              'session_token': sessionToken,
              'device_name': deviceName,
              'device_type': deviceType,
              'location': 'India',
            }),
          )
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      // Fire-and-forget; non-critical
    }
  }

  /// Resolves the real device model name via device_info_plus.
  static Future<String> _resolveDeviceName() async {
    try {
      final info = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final android = await info.androidInfo;
        final brand = android.brand.trim();
        final model = android.model.trim();
        // Avoid duplication when brand prefix is already in model string
        // e.g. "samsung SM-S926B" → "Samsung SM-S926B"
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

  // ── Login History ──────────────────────────────────────────────────────────
  Future<List<LoginEvent>> getLoginHistory() async {
    try {
      final token = await _getToken();
      if (token == null) return [];

      final res = await sessionHttpClient
          .get(
            Uri.parse('$_kBaseUrl/api/security/login-history'),
            headers: _authHeader(token),
          )
          .timeout(const Duration(seconds: 15));

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200 && body['success'] == true) {
        final list = (body['data']?['history'] as List<dynamic>?) ?? [];
        return list
            .map((e) => LoginEvent.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Called after a successful login to record the event.
  Future<void> recordLoginEvent({
    required String deviceName,
    required String location,
    required bool success,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return;

      await sessionHttpClient
          .post(
            Uri.parse('$_kBaseUrl/api/security/login-history/record'),
            headers: _authHeader(token),
            body: jsonEncode({
              'device_name': deviceName,
              'location': location,
              'success': success,
            }),
          )
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      // Fire-and-forget; non-critical
    }
  }
}