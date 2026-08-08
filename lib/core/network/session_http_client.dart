// lib/core/network/session_http_client.dart
//
// Single Device Login — the one place every outgoing API call is watched.
//
// http.BaseClient funnels get/post/put/delete/patch through a single
// send(BaseRequest) method, so overriding it here is enough to intercept
// every request made through this client — no matter which repository or
// service issues it.
//
// Usage: replace `http.Client()` (or the top-level `http.get`/`http.post`
// functions) with the shared `sessionHttpClient` singleton below. On every
// response, if the backend says this device's session was invalidated by a
// login on another device (middleware/auth.js → 401 with
// code:'SESSION_INVALIDATED'), we forward straight to
// SessionManager.forceLogout(), which clears local state and redirects to
// the Login screen with that message.
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../session/session_manager.dart';

class SessionAwareHttpClient extends http.BaseClient {
  final http.Client _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final streamedResponse = await _inner.send(request);

    // We need to read the body to inspect it, which consumes the stream —
    // so we buffer it and hand back a fresh StreamedResponse built from the
    // same bytes, keeping this client a transparent drop-in for callers
    // that expect a normal http.Client.
    final bytes = await streamedResponse.stream.toBytes();

    if (streamedResponse.statusCode == 401) {
      _checkForSessionInvalidation(bytes);
    }

    return http.StreamedResponse(
      Stream.value(bytes),
      streamedResponse.statusCode,
      contentLength: bytes.length,
      request: streamedResponse.request,
      headers: streamedResponse.headers,
      isRedirect: streamedResponse.isRedirect,
      persistentConnection: streamedResponse.persistentConnection,
      reasonPhrase: streamedResponse.reasonPhrase,
    );
  }

  void _checkForSessionInvalidation(List<int> bytes) {
    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is Map && decoded['code'] == 'SESSION_INVALIDATED') {
        final message = decoded['message']?.toString() ??
            'Your account has been logged in on another device. Please log in again.';
        unawaited(SessionManager.instance.forceLogout(message));
      }
    } catch (_) {
      // Not JSON, or not the shape we expect — nothing to do.
    }
  }
}

/// Shared singleton — reuse this everywhere instead of constructing new
/// http.Client()/calling the top-level http.get/http.post functions, so
/// every request in the app is covered by the Single Device Login check.
final http.Client sessionHttpClient = SessionAwareHttpClient();