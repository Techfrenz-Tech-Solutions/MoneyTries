import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../../core/network/session_http_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/plan/plan_models.dart';
import '../../core/api/api_config.dart';

const String _kBaseUrl = ApiConfig.baseUrl;
class PlanRepository {
  final http.Client _client;
  PlanRepository({http.Client? client}) : _client = client ?? sessionHttpClient;

  // ── Auth ──────────────────────────────────────────────────────────────────
  Future<String> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null || token.isEmpty) {
      throw Exception('Session expired. Please log in again.');
    }
    return token;
  }

  Future<Map<String, String>> _headers() async {
    final token = await _getToken();
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  // ── Fetch all plans ───────────────────────────────────────────────────────
  Future<List<ActivePlan>> fetchMyPlans() async {
    try {
      final uri = Uri.parse('$_kBaseUrl/api/plans/my');
      final response = await _client
          .get(uri, headers: await _headers())
          .timeout(const Duration(seconds: 10));

      Map<String, dynamic> json = {};
      try {
        json = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {}

      if (response.statusCode == 200) {
        final raw = (json['data'] as List<dynamic>?) ?? [];
        return raw
            .map((e) => ActivePlan.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } on SocketException {
      return [];
    } catch (_) {
      return [];
    }
  }

  // ── Enroll (first month payment + plan creation) via UPI ──────────────────
  Future<ActivePlan> enrollPlan({
    required PlanType planType,
    required int monthlyAmount,
    required String utrId,
    required String proofImageUrl,
  }) async {
    try {
      final uri = Uri.parse('$_kBaseUrl/api/plans/enroll');
      final response = await _client
          .post(
            uri,
            headers: await _headers(),
            body: jsonEncode({
              'plan_type': planType.months,
              'monthly_amount': monthlyAmount,
              'utr_id': utrId,
              'proof_image': proofImageUrl,
            }),
          )
          .timeout(const Duration(seconds: 15));

      Map<String, dynamic> json = {};
      try {
        json = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {}

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json['data'] ?? json;
        return ActivePlan.fromJson(data as Map<String, dynamic>);
      }

      throw Exception(json['message'] ?? 'Plan enrollment failed (${response.statusCode}).');
    } on SocketException {
      throw Exception('No internet connection. Please try again.');
    } on Exception {
      rethrow;
    } catch (e) {
      throw Exception('Plan enrollment failed. Please try again.');
    }
  }

  // ── Pay monthly instalment via UPI ────────────────────────────────────────
  Future<PlanPaymentResponse> payMonthlyInstalment({
    required String planId,
    required String utrId,
    required String proofImageUrl,
  }) async {
    try {
      final uri = Uri.parse('$_kBaseUrl/api/plans/$planId/pay');
      final response = await _client
          .post(
            uri,
            headers: await _headers(),
            body: jsonEncode({'utr_id': utrId, 'proof_image': proofImageUrl}),
          )
          .timeout(const Duration(seconds: 15));

      Map<String, dynamic> json = {};
      try {
        json = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {}

      if (response.statusCode == 200 || response.statusCode == 201) {
        return PlanPaymentResponse.fromJson(json);
      }

      throw Exception(json['message'] ?? 'Payment submission failed (${response.statusCode}).');
    } on SocketException {
      throw Exception('No internet connection. Please try again.');
    } on Exception {
      rethrow;
    } catch (e) {
      throw Exception('Payment submission failed. Please try again.');
    }
  }

  // ── ROI withdrawal ────────────────────────────────────────────────────────
  Future<RoiWithdrawalResponse> withdrawRoi({
    required String planId,
    required double amount,
  }) async {
    final uri = Uri.parse('$_kBaseUrl/api/plans/$planId/withdraw-roi');
    final response = await _client
        .post(
          uri,
          headers: await _headers(),
          body: jsonEncode({'amount': amount}),
        )
        .timeout(const Duration(seconds: 15));

    Map<String, dynamic> json = {};
    try {
      json = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {}

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(
        json['message'] ?? 'ROI withdrawal failed (${response.statusCode})',
      );
    }

    return RoiWithdrawalResponse.fromJson(json);
  }

  // ── Principal withdrawal ──────────────────────────────────────────────────
  Future<PrincipalWithdrawalResponse> withdrawPrincipal({
    required String planId,
  }) async {
    final uri = Uri.parse('$_kBaseUrl/api/plans/$planId/withdraw-principal');
    final response = await _client
        .post(uri, headers: await _headers())
        .timeout(const Duration(seconds: 15));

    Map<String, dynamic> json = {};
    try {
      json = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {}

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(
        json['message'] ??
            'Principal withdrawal failed (${response.statusCode})',
      );
    }

    return PrincipalWithdrawalResponse.fromJson(json);
  }

  // ── Upload proof image ────────────────────────────────────────────────────
  Future<String> uploadProof(List<int> fileBytes, String filename) async {
    final token = await _getToken();
    final uri = Uri.parse('$_kBaseUrl/api/deposit/upload');

    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $token'
      ..files.add(
        http.MultipartFile.fromBytes('file', fileBytes, filename: filename),
      );

    final streamed = await _client.send(request);
    final body = await streamed.stream.bytesToString();

    if (streamed.statusCode != 200 && streamed.statusCode != 201) {
      Map<String, dynamic> errJson = {};
      try {
        errJson = jsonDecode(body) as Map<String, dynamic>;
      } catch (_) {}
      throw Exception(
        errJson['message'] ?? 'Image upload failed (${streamed.statusCode})',
      );
    }

    final json = jsonDecode(body) as Map<String, dynamic>;
    final data = json['data'] ?? json;
    return (data as Map<String, dynamic>)['proof_image']?.toString() ??
        data['url']?.toString() ??
        data['image_url']?.toString() ??
        '';
  }

  // ── Profile: plan amount ──────────────────────────────────────────────────
  Future<double> fetchPlanAmount() async {
    try {
      final uri = Uri.parse('$_kBaseUrl/api/plans/plan-amount');
      final response = await _client
          .get(uri, headers: await _headers())
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return 0;

      Map<String, dynamic> json = {};
      try {
        json = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {}

      final data = json['data'] ?? json;
      return double.tryParse(
            (data as Map<String, dynamic>)['plan_amount']?.toString() ?? '0',
          ) ??
          0.0;
    } catch (_) {
      return 0;
    }
  }
}