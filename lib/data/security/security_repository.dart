// lib/data/security/security_repository.dart

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/security/security_model.dart';
import '../../services/biometric_auth_service.dart';

const String _kBaseUrl = 'http://192.168.0.17:3000';

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

      final res = await http
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

      final res = await http
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

      final res = await http
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

      final res = await http
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

      final res = await http
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

      final res = await http
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

      final res = await http
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

      final deviceName = Platform.isAndroid ? 'Android Device' : Platform.isIOS ? 'iPhone' : 'Unknown Device';
      final deviceType = Platform.isAndroid ? 'android' : Platform.isIOS ? 'ios' : 'other';

      await http
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

  // ── Login History ──────────────────────────────────────────────────────────
  Future<List<LoginEvent>> getLoginHistory() async {
    try {
      final token = await _getToken();
      if (token == null) return [];

      final res = await http
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

      await http
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