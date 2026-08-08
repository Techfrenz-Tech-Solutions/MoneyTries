// lib/services/biometric_auth_service.dart
//
// Centralized helper for everything biometric-login related, so the
// Security Settings toggle, the GPay-style app-lock screen, and the
// "Quick Login with Biometrics" button on the credentials screen all
// read/write the exact same per-account state instead of drifting apart.
//
// Two separate concerns live here:
//   1. Per-account "is biometric login turned on" flag, namespaced by
//      userId (`security_biometrics_enabled_<userId>`) — mirrors the
//      existing `app_pin_<userId>` / `withdrawal_pin_<userId>` pattern so
//      each account on a shared device has its own independent setting.
//   2. A single device-level "remembered session" (userId + auth token +
//      display label) for whichever account most recently turned biometrics
//      on. This is what lets the full login screen offer a real "Quick
//      Login with Biometrics" option instead of asking for the password
//      again — the cached token is always re-validated against the backend
//      (GET /api/auth/me) before it is trusted.

import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BiometricAuthService {
  BiometricAuthService._();

  static final LocalAuthentication _localAuth = LocalAuthentication();

  static String _enabledKey(String userId) =>
      'security_biometrics_enabled_$userId';

  static const String _kCacheUserId = 'biometric_cache_user_id';
  static const String _kCacheToken = 'biometric_cache_token';
  static const String _kCacheLabel = 'biometric_cache_label';

  // ── Device capability ────────────────────────────────────────────────────
  /// Whether this device has usable biometric hardware (fingerprint/Face ID)
  /// with at least one enrolled credential.
  static Future<bool> isDeviceCapable() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final supported = await _localAuth.isDeviceSupported();
      return canCheck && supported;
    } on PlatformException {
      return false;
    }
  }

  // ── Per-account enabled flag ─────────────────────────────────────────────
  static Future<bool> isEnabledFor(String userId) async {
    if (userId.isEmpty) return false;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey(userId)) ?? false;
  }

  static Future<void> setEnabledFor(String userId, bool value) async {
    if (userId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey(userId), value);
  }

  // ── Native authentication prompt ─────────────────────────────────────────
  /// Shows the native fingerprint/Face ID prompt. Returns true only if the
  /// person actually authenticated. [onError] is invoked with a
  /// human-readable message on hard failures (not on a plain cancel, so
  /// auto-triggered prompts can fail silently and fall back to the PIN pad).
  static Future<bool> authenticate({
    required String reason,
    void Function(String message)? onError,
  }) async {
    try {
      return await _localAuth.authenticate(
        localizedReason: reason,
        authMessages: const [],
        biometricOnly: true,
      );
    } on PlatformException catch (e) {
      onError?.call(e.message ?? 'Biometric authentication failed.');
      return false;
    }
  }

  // ── Device-remembered session (for quick login) ──────────────────────────
  /// Snapshots the given account's active session so it can be restored via
  /// biometrics from the full login screen, without retyping the password.
  /// Called right when the toggle is switched on in Security Settings, and
  /// refreshed on every successful login / app-lock PIN unlock for an
  /// account that already has biometrics turned on.
  static Future<void> rememberSession({
    required String userId,
    required String token,
    required String label,
  }) async {
    if (userId.isEmpty || token.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kCacheUserId, userId);
    await prefs.setString(_kCacheToken, token);
    await prefs.setString(_kCacheLabel, label);
  }

  /// Clears the device-remembered session. Pass [onlyIfUserId] to only clear
  /// it when it currently belongs to that account (used when disabling
  /// biometrics), or leave it null to always clear (used on logout).
  static Future<void> forgetSession([String? onlyIfUserId]) async {
    final prefs = await SharedPreferences.getInstance();
    if (onlyIfUserId != null) {
      final cachedId = prefs.getString(_kCacheUserId) ?? '';
      if (cachedId != onlyIfUserId) return;
    }
    await prefs.remove(_kCacheUserId);
    await prefs.remove(_kCacheToken);
    await prefs.remove(_kCacheLabel);
  }

  /// Returns the remembered session as `{userId, token, label}`, or null if
  /// nothing is cached on this device.
  static Future<Map<String, String>?> getRememberedSession() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString(_kCacheUserId) ?? '';
    final token = prefs.getString(_kCacheToken) ?? '';
    final label = prefs.getString(_kCacheLabel) ?? '';
    if (userId.isEmpty || token.isEmpty) return null;
    return {'userId': userId, 'token': token, 'label': label};
  }
}
