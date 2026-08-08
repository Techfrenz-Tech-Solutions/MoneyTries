import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/network/session_http_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/notification/notification_models.dart';
import '../../core/api/api_config.dart';

const String _kBaseUrl = ApiConfig.baseUrl;
class NotificationRepository {
  final http.Client _client;
  NotificationRepository({http.Client? client})
      : _client = client ?? sessionHttpClient;

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<Map<String, String>> _headers() async {
    final token = await _getToken();
    return {
      'Authorization': 'Bearer ${token ?? ''}',
      'Content-Type': 'application/json',
    };
  }

  // ── Fetch paginated list ─────────────────────────────────────────────────
  /// GET /api/notifications?pageNo=&pageSize=
  Future<NotificationListResponse> fetchNotifications({
    int pageNo = 1,
    int pageSize = 20,
  }) async {
    final uri = Uri.parse('$_kBaseUrl/api/notifications')
        .replace(queryParameters: {
      'pageNo': '$pageNo',
      'pageSize': '$pageSize',
    });
    final response = await _client
        .get(uri, headers: await _headers())
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception(
          'Notification fetch failed (${response.statusCode}): ${response.body}');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    // Backend wraps in { success, message, data: { pageNo, pageSize, total, ... } }
    final payload = body['data'] as Map<String, dynamic>? ?? body;
    return NotificationListResponse.fromJson(payload);
  }

  // ── Mark single notification read ────────────────────────────────────────
  /// POST /api/notifications/mark-read  { notification_id }
  Future<void> markAsRead(String notificationId) async {
    final uri = Uri.parse('$_kBaseUrl/api/notifications/mark-read');
    final response = await _client
        .post(
          uri,
          headers: await _headers(),
          body: jsonEncode({'notification_id': notificationId}),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception(
          'Mark read failed (${response.statusCode}): ${response.body}');
    }
  }

  // ── Mark all read ────────────────────────────────────────────────────────
  /// POST /api/notifications/mark-all-read
  Future<void> markAllRead() async {
    final uri = Uri.parse('$_kBaseUrl/api/notifications/mark-all-read');
    final response = await _client
        .post(uri, headers: await _headers())
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception(
          'Mark all read failed (${response.statusCode}): ${response.body}');
    }
  }

  // ── Delete single notification ───────────────────────────────────────────
  /// DELETE /api/notifications/:id
  Future<void> deleteNotification(String notificationId) async {
    final uri = Uri.parse('$_kBaseUrl/api/notifications/$notificationId');
    final response = await _client
        .delete(uri, headers: await _headers())
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception(
          'Delete notification failed (${response.statusCode}): ${response.body}');
    }
  }
}