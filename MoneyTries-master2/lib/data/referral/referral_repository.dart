// lib/data/referral/referral_repository.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/network/session_http_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/referral/referral_model.dart';
import '../../core/api/api_config.dart';

const String _kBaseUrl = ApiConfig.baseUrl;
class ReferralRepository {
  final http.Client _client;
  ReferralRepository({http.Client? client}) : _client = client ?? sessionHttpClient;

  Future<String?> _token() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Map<String, String> _headers(String token) => {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };

  /// Safely decodes a response body as JSON. The backend always replies with
  /// JSON on success, but an unexpected failure (a proxy timeout, a crashed
  /// process, an HTML error page from Express, an empty body, etc.) can
  /// return non-JSON content — `jsonDecode` would otherwise throw a raw
  /// [FormatException] that surfaces as a cryptic "ERROR" in the UI instead
  /// of a readable message.
  Map<String, dynamic> _decode(http.Response res) {
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) return decoded;
      throw const FormatException('Unexpected response shape');
    } catch (_) {
      throw Exception(
          'Unexpected response from server (${res.statusCode}). Please try again.');
    }
  }

  /// GET /api/referral/info
  /// Returns the user's referral code, lifetime referral earnings (display
  /// only — every rupee has already been credited to the Main Wallet),
  /// total referred users, and the invite-5 task progress.
  Future<ReferralInfo> fetchReferralInfo() async {
    final token = await _token();
    if (token == null) throw Exception('Not authenticated');

    final res = await _client.get(
      Uri.parse('$_kBaseUrl/api/referral/info'),
      headers: _headers(token),
    );

    final body = _decode(res);
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(body['message']?.toString() ?? 'Failed to load referral info');
    }

    final data = body['data'];
    if (data is! Map<String, dynamic>) {
      throw Exception('Referral info response was missing data.');
    }
    return ReferralInfo.fromJson(data);
  }

  /// POST /api/referral/claim-reward
  /// Claims the one-time ₹500 "Invite 5 Users" reward. Only succeeds once
  /// the task is complete and hasn't already been claimed — the server is
  /// the source of truth for that check.
  /// Returns the updated (main) wallet balance on success.
  Future<double> claimTaskReward() async {
    final token = await _token();
    if (token == null) throw Exception('Not authenticated');

    final res = await _client.post(
      Uri.parse('$_kBaseUrl/api/referral/claim-reward'),
      headers: _headers(token),
    );

    final body = _decode(res);
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(body['message']?.toString() ?? 'Failed to claim reward');
    }

    final data = body['data'] as Map<String, dynamic>?;
    return double.tryParse(data?['wallet_balance']?.toString() ?? '0') ?? 0;
  }

  /// GET /api/referral/transactions
  /// Returns every referral bonus credit and task-reward claim as separate
  /// transaction rows, newest first — powers the Referral tab in
  /// Transaction History.
  Future<List<ReferralTransaction>> fetchReferralTransactions() async {
    final token = await _token();
    if (token == null) throw Exception('Not authenticated');

    final res = await _client.get(
      Uri.parse('$_kBaseUrl/api/referral/transactions'),
      headers: _headers(token),
    );

    final body = _decode(res);
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(body['message']?.toString() ?? 'Failed to load referral transactions');
    }

    final list = (body['data'] as List<dynamic>? ?? []);
    return list
        .map((e) => ReferralTransaction.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// GET /api/referral/candidates
  /// Returns every referred user who signed up with this user's referral
  /// code AND has completed their first successful plan payment, newest
  /// first — powers the "Referral Candidates" tab on the Referral screen.
  Future<List<ReferralCandidate>> fetchReferralCandidates() async {
    final token = await _token();
    if (token == null) throw Exception('Not authenticated');

    final res = await _client.get(
      Uri.parse('$_kBaseUrl/api/referral/candidates'),
      headers: _headers(token),
    );

    final body = _decode(res);
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(
          body['message']?.toString() ?? 'Failed to load referral candidates');
    }

    final list = (body['data'] as List<dynamic>? ?? []);
    return list
        .map((e) => ReferralCandidate.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}