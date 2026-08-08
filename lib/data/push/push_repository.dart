// lib/data/push/push_repository.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/network/session_http_client.dart';
import '../../core/api/api_config.dart';

// ── Base URL ──────────────────────────────────────────────────────────────
//
// The base URL (including the `--dart-define=API_BASE_URL=...` override
// mechanism) now lives centrally in ApiConfig — see
// lib/core/api/api_config.dart for the override docs.
//
// ── What this means for push notifications without a public backend ──────
// This URL is ONLY used to register/refresh this device's FCM token with
// the backend (POST /api/push/register-token) — the actual push message
// is delivered straight from Google's FCM servers to the device, and does
// NOT go through this URL or this backend at delivery time. So:
//   - The phone DOES need to reach this address at least once, at
//     registration time (app launch / login / token refresh) — which in
//     practice means being on the same Wi-Fi as whatever machine is
//     running the backend right then.
//   - Once that registration call has succeeded, the phone can leave that
//     network entirely (mobile data, a different Wi-Fi, anywhere) and
//     will keep receiving pushes fine, because delivery itself doesn't
//     depend on this address being reachable again.
//   - The backend machine itself just needs its own outbound internet
//     access to reach FCM's servers when SENDING (admin approves a
//     deposit, etc.) — that's already covered by config/firebase.js on
//     the server and is unrelated to this address.
//   - If you want a release APK to register successfully from ANY
//     network (not just this Wi-Fi) — e.g. handing it to a tester who
//     isn't on your LAN — you need the backend reachable from the public
//     internet again: redeploy it (Railway, Render, Fly.io, a VPS, etc.)
//     or run a tunnel (ngrok / Cloudflare Tunnel) and pass its URL via
//     --dart-define=API_BASE_URL as documented in ApiConfig.
const String _kBaseUrl = ApiConfig.baseUrl;

class PushRepository {
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Map<String, String> _authHeader(String token) => {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };

  /// Registers (or refreshes) this device's FCM token against the account
  /// currently signed in. Safe to call repeatedly with the same token.
  ///
  /// NOTE ON LOGGING: unlike most other debugPrint calls in this app, the
  /// ones below are NOT gated behind `kDebugMode`. This is deliberate —
  /// this exact call is the one that silently failed on release APKs (see
  /// the ROOT CAUSE note above _kBaseUrl), and `kDebugMode`-gated prints
  /// are compiled OUT of release builds entirely, which is precisely the
  /// build type that needed diagnosing. `debugPrint` itself is safe to
  /// call in release (it's just a print, not a debug-only API) and shows
  /// up in `adb logcat` under the `flutter` tag on a real device even from
  /// an installed release APK — so this stays visible in exactly the
  /// situation where it's needed.
  Future<void> registerToken(String fcmToken) async {
    try {
      final token = await _getToken();
      if (token == null || token.isEmpty) {
        debugPrint(
          '[PushRepository] registerToken skipped — no auth_token in '
          'SharedPreferences (user not logged in yet)',
        );
        return;
      }

      final response = await sessionHttpClient
          .post(
            Uri.parse('$_kBaseUrl/api/push/register-token'),
            headers: _authHeader(token),
            body: jsonEncode({
              'fcm_token': fcmToken,
              'platform': Platform.isIOS ? 'ios' : 'android',
            }),
          )
          .timeout(const Duration(seconds: 10));

      debugPrint(
        '[PushRepository] registerToken -> $_kBaseUrl '
        '(status ${response.statusCode})'
        '${response.statusCode != 200 ? ' body=${response.body}' : ''}',
      );
    } catch (e) {
      // Fire-and-forget; non-critical to the caller — but always log so a
      // silent failure (unreachable host, DNS failure, timeout, etc.) is
      // visible in `adb logcat` / `flutter run` instead of vanishing.
      // This exact log line is what would have shown a
      // "Connection failed"/"No route to host" for the old LAN URL on a
      // real device off the dev network.
      debugPrint('[PushRepository] registerToken FAILED against $_kBaseUrl: $e');
    }
  }

  /// Removes this device's FCM token — called right before a manual
  /// "Logout" clears the local session, using the auth token that is still
  /// valid at that point.
  Future<void> unregisterToken(String fcmToken, {String? authToken}) async {
    try {
      final token = authToken ?? await _getToken();
      if (token == null || token.isEmpty) return;

      final response = await http
          .post(
            Uri.parse('$_kBaseUrl/api/push/unregister-token'),
            headers: _authHeader(token),
            body: jsonEncode({'fcm_token': fcmToken}),
          )
          .timeout(const Duration(seconds: 10));

      debugPrint(
        '[PushRepository] unregisterToken -> $_kBaseUrl '
        '(status ${response.statusCode})',
      );
    } catch (e) {
      // Fire-and-forget; non-critical
      debugPrint('[PushRepository] unregisterToken FAILED against $_kBaseUrl: $e');
    }
  }
}