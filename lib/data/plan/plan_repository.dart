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

  // ── Enroll (one-time investment, paid exclusively from wallet balance) ────
  // The old UPI/bank-transfer + payment-screenshot + UTR flow has been
  // removed. The backend deducts/locks `monthlyAmount` from the user's
  // wallet balance (users.balance) at submission time and returns
  // 'Insufficient wallet balance' (422) if the balance is too low.
  Future<ActivePlan> enrollPlan({
    required PlanType planType,
    required int monthlyAmount,
    // Only relevant for PlanType.prePlan (3–80 user-chosen days). Sent as
    // 'duration_days' for a forward-looking backend that adds Pre Plan
    // support; harmless/ignored by the current 3/6/12-month-only backend.
    int? durationDays,
  }) async {
    try {
      final uri = Uri.parse('$_kBaseUrl/api/plans/enroll');
      final response = await _client
          .post(
            uri,
            headers: await _headers(),
            body: jsonEncode({
              // planType.apiKey ('3_month' / '6_month' / '12_month' /
              // 'pre_plan') is accepted by the existing backend's
              // normalisePlanType() just as well as the old numeric-months
              // value, and is required for 'pre_plan' since that has no
              // month count.
              'plan_type': planType.apiKey,
              'monthly_amount': monthlyAmount,
              if (planType == PlanType.prePlan && durationDays != null)
                'duration_days': durationDays,
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

      throw Exception(
        json['message'] ?? 'Plan enrollment failed (${response.statusCode}).',
      );
    } on SocketException {
      throw Exception('No internet connection. Please try again.');
    } on Exception {
      rethrow;
    } catch (e) {
      throw Exception('Plan enrollment failed. Please try again.');
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

  // ── Wallet balance (for pre-submit sufficiency check) ──────────────────────
  // Reuses the existing GET /api/withdrawal/balances endpoint (already used
  // by the Withdrawal screen) instead of adding a new plan-specific route.
  Future<double> fetchWalletBalance() async {
    try {
      final uri = Uri.parse('$_kBaseUrl/api/withdrawal/balances');
      final response = await _client
          .get(uri, headers: await _headers())
          .timeout(const Duration(seconds: 10));

      Map<String, dynamic> json = {};
      try {
        json = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {}

      if (response.statusCode != 200) return 0;

      final data = json['data'] ?? json;
      return double.tryParse(
            (data as Map<String, dynamic>)['wallet_balance']?.toString() ?? '0',
          ) ??
          0.0;
    } catch (_) {
      return 0;
    }
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