// lib/core/session/session_manager.dart
//
// Single Device Login — client-side enforcement.
//
// The backend invalidates a device's token the instant the same account
// logs in anywhere else (see middleware/auth.js: it compares each request's
// JWT `sid` against users.active_session_id and returns
// { success:false, code:'SESSION_INVALIDATED' } on a mismatch).
//
// SessionAwareHttpClient (core/network/session_http_client.dart) is the
// single choke point that inspects every API response for that code. When
// it sees one, it calls SessionManager.instance.forceLogout(), which:
//   1. Clears the locally-stored session (auth token, user id/label, and
//      the device-remembered biometric quick-login session — mirroring
//      exactly what the manual "Logout" button in ProfileScreen already
//      clears, see profile_screen.dart _handleLogout).
//   2. Uses a global navigatorKey (wired into MaterialApp in main.dart) to
//      push the Login screen and clear the whole navigation stack, passing
//      the "logged in on another device" message as the route argument so
//      LoginScreen can surface it to the person.
//
// A single global instance is used (rather than something threaded through
// widget context) because the trigger can originate from *any* repository,
// at any point in the widget tree, including from background calls that
// have no BuildContext of their own.
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../routes/app_routes.dart';
import '../../services/biometric_auth_service.dart';

class SessionManager {
  SessionManager._();
  static final SessionManager instance = SessionManager._();

  /// Attach this to MaterialApp(navigatorKey: ...) in main.dart so we can
  /// navigate from outside the widget tree (e.g. from an HTTP client).
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  bool _isHandlingForcedLogout = false;

  /// Clears the local session and redirects to the Login screen with
  /// [message]. Safe to call multiple times concurrently — only the first
  /// call in a burst actually runs; the rest are no-ops so a flurry of
  /// requests failing at once doesn't fire multiple navigations.
  Future<void> forceLogout([
    String message =
        'Your account has been logged in on another device. Please log in again.',
  ]) async {
    if (_isHandlingForcedLogout) return;
    _isHandlingForcedLogout = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('logged_in_user_id') ?? '';

      await prefs.remove('auth_token');
      await prefs.remove('logged_in_user_id');
      await prefs.remove('logged_in_user_label');

      // This device was logged out by another login, not by a deliberate
      // "sign out of this device" action — but the cached biometric
      // session is now backed by a dead token, so it must go too, or the
      // fingerprint quick-login button would just fail silently next time.
      await BiometricAuthService.forgetSession(userId.isEmpty ? null : userId);

      final nav = navigatorKey.currentState;
      if (nav != null) {
        nav.pushNamedAndRemoveUntil(
          AppRoutes.login,
          (route) => false,
          arguments: {'forcedLogoutMessage': message},
        );
      }
    } finally {
      // Reset shortly after navigating so a genuinely new forced-logout
      // event (after logging back in on this device) can be handled again.
      _isHandlingForcedLogout = false;
    }
  }
}