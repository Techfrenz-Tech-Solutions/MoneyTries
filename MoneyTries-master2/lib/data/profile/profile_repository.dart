import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/network/session_http_client.dart';
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/user_profile_model.dart';
import '../../core/api/api_config.dart';

const String _kBaseUrl = ApiConfig.baseUrl;
class ProfileRepository {
  final http.Client _client;
  ProfileRepository({http.Client? client}) : _client = client ?? sessionHttpClient;

  Future<String> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null || token.isEmpty) {
      throw Exception('Session expired. Please log in again.');
    }
    return token;
  }

  Map<String, String> _authHeaders(String token) => {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };

  /// GET /api/profile — fetch current user's profile.
  /// Falls back to GET /api/auth/me if the profile endpoint returns non-200.
  Future<UserProfileModel> fetchProfile() async {
    final token = await _getToken();

    // ── Primary endpoint ─────────────────────────────────────────────────────
    try {
      final res = await _client
          .get(
            Uri.parse('$_kBaseUrl/api/profile'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        if (body['success'] == true) {
          final data = body['data'] as Map<String, dynamic>? ?? body;
          return UserProfileModel.fromJson(data);
        }
      }
    } catch (_) {
      // Network error on primary — fall through to fallback
    }

    // ── Fallback: /api/auth/me ────────────────────────────────────────────────
    final res = await _client
        .get(
          Uri.parse('$_kBaseUrl/api/auth/me'),
          headers: {'Authorization': 'Bearer $token'},
        )
        .timeout(const Duration(seconds: 15));

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200 || body['success'] == false) {
      throw Exception(body['message'] ?? 'Failed to fetch profile');
    }

    final data = body['data'] as Map<String, dynamic>? ?? body;
    return UserProfileModel.fromJson(data);
  }

  /// PUT /api/profile/update — update name, dob, gender, address.
  Future<UserProfileModel> updateProfile({
    required String firstName,
    required String lastName,
    String? dateOfBirth,
    String? gender,
    String? address,
  }) async {
    final token = await _getToken();
    final res = await _client
        .put(
          Uri.parse('$_kBaseUrl/api/profile/update'),
          headers: _authHeaders(token),
          body: jsonEncode({
            'first_name': firstName.trim(),
            'last_name': lastName.trim(),
            'date_of_birth':
                (dateOfBirth == null || dateOfBirth.isEmpty) ? null : dateOfBirth,
            'gender': (gender == null || gender.isEmpty) ? null : gender,
            'address': (address == null || address.trim().isEmpty)
                ? null
                : address.trim(),
          }),
        )
        .timeout(const Duration(seconds: 15));

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200 || body['success'] == false) {
      throw Exception(body['message'] ?? 'Failed to update profile');
    }

    final data = body['data'] as Map<String, dynamic>? ?? body;
    return UserProfileModel.fromJson(data);
  }

  /// POST /api/profile/avatar — upload or replace profile picture.
  Future<String> uploadAvatar(String localPath) async {
    final token = await _getToken();
    final ext  = p.extension(localPath).toLowerCase();
    final mime = ext == '.png' ? 'png' : 'jpeg';

    final req = http.MultipartRequest(
      'POST',
      Uri.parse('$_kBaseUrl/api/profile/avatar'),
    )
      ..headers['Authorization'] = 'Bearer $token'
      ..files.add(
        await http.MultipartFile.fromPath(
          'avatar',
          localPath,
          contentType: MediaType('image', mime),
        ),
      );

    final streamed = await req.send().timeout(const Duration(seconds: 30));
    final resBody = jsonDecode(await streamed.stream.bytesToString())
        as Map<String, dynamic>;

    if (streamed.statusCode != 200 || resBody['success'] == false) {
      throw Exception(resBody['message'] ?? 'Failed to upload avatar');
    }

    return resBody['data']?['profile_image']?.toString() ?? '';
  }

  /// DELETE /api/profile/avatar — remove profile picture.
  Future<void> deleteAvatar() async {
    final token = await _getToken();
    final res = await _client
        .delete(
          Uri.parse('$_kBaseUrl/api/profile/avatar'),
          headers: {'Authorization': 'Bearer $token'},
        )
        .timeout(const Duration(seconds: 15));

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200 || body['success'] == false) {
      throw Exception(body['message'] ?? 'Failed to remove avatar');
    }
  }

  /// Builds the full URL for a relative avatar path returned by the server.
  String buildAvatarUrl(String relPath) {
    if (relPath.startsWith('http')) return relPath;
    return '$_kBaseUrl/uploads/$relPath';
  }
}