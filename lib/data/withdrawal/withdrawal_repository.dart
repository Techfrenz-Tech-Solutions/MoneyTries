import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/withdrawal/withdrawal_models.dart';

/// Base URL — matches the same value used in DepositRepository / KycViewModel.
/// 10.0.2.2 is the Android emulator's alias for the host machine's localhost.
/// If you're testing on a real device, replace this with your machine's LAN
/// IP (e.g. http://192.168.1.50:3000) or your deployed server URL.
const String _kBaseUrl = 'http://192.168.0.17:3000';

class WithdrawalRepository {
  final http.Client _client;
  WithdrawalRepository({http.Client? client}) : _client = client ?? http.Client();

  /// Reads the JWT token saved by LoginViewModel / RegisterViewModel.
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

  // ── KYC status ─────────────────────────────────────────────────────────────
  /// Fetches KYC verification status and associated bank details.
  Future<KycStatus> fetchKycStatus() async {
    final uri = Uri.parse('$_kBaseUrl/api/withdrawal/kyc-status');
    final response = await _client.get(uri, headers: await _headers());

    Map<String, dynamic> json = {};
    try { json = jsonDecode(response.body) as Map<String, dynamic>; } catch (_) {}

    if (response.statusCode != 200) {
      throw Exception(json['message'] ?? 'KYC fetch failed (${response.statusCode}).');
    }

    return KycStatus.fromJson(json['data'] ?? json);
  }

  // ── Wallet / vault balances ─────────────────────────────────────────────────
  /// Fetches the user's real wallet and vault balances.
  Future<({double wallet, double vault})> fetchBalances() async {
    final uri = Uri.parse('$_kBaseUrl/api/withdrawal/balances');
    final response = await _client.get(uri, headers: await _headers());

    Map<String, dynamic> json = {};
    try { json = jsonDecode(response.body) as Map<String, dynamic>; } catch (_) {}

    if (response.statusCode != 200) {
      throw Exception(json['message'] ?? 'Could not fetch balances (${response.statusCode}).');
    }

    final data = json['data'] ?? json;
    return (
      wallet: double.tryParse(data['wallet_balance']?.toString() ?? '0') ?? 0,
      vault: double.tryParse(data['vault_balance']?.toString() ?? '0') ?? 0,
    );
  }

  // ── Wallet withdrawal ──────────────────────────────────────────────────────
  /// POST /api/withdrawal/wallet
  /// Withdraws from wallet balance to the user's KYC bank account.
  /// Returns a reference_id immediately; admin marks it paid afterwards.
  Future<WalletWithdrawResponse> walletWithdrawRequest({
    required double amount,
  }) async {
    final uri = Uri.parse('$_kBaseUrl/api/withdrawal/wallet');
    final response = await _client.post(
      uri,
      headers: await _headers(),
      body: jsonEncode({'amount': amount}),
    );

    Map<String, dynamic> json = {};
    try { json = jsonDecode(response.body) as Map<String, dynamic>; } catch (_) {}

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(json['message'] ?? 'Wallet withdrawal failed (${response.statusCode}).');
    }

    return WalletWithdrawResponse.fromJson(json['data'] ?? json);
  }

  // ── Vault / capital withdrawal ──────────────────────────────────────────────
  /// POST /api/withdrawal/vault
  /// Moves mining earnings (vault) to main wallet — requires admin approval.
  Future<MoveWalletResponse> requestMoveWalletAmount({
    required double amount,
  }) async {
    final uri = Uri.parse('$_kBaseUrl/api/withdrawal/vault');
    final response = await _client.post(
      uri,
      headers: await _headers(),
      body: jsonEncode({'amount': amount}),
    );

    Map<String, dynamic> json = {};
    try { json = jsonDecode(response.body) as Map<String, dynamic>; } catch (_) {}

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(json['message'] ?? 'Move wallet request failed (${response.statusCode}).');
    }

    return MoveWalletResponse.fromJson(json['data'] ?? json);
  }

  // ── Withdrawal history ─────────────────────────────────────────────────────
  /// POST /api/withdrawal/list with { pageNo, pageSize, status?, search? }
  Future<WithdrawListResponse> fetchWithdrawList({
    int pageNo = 1,
    int pageSize = 10,
    String? status,
    String? search,
  }) async {
    final uri = Uri.parse('$_kBaseUrl/api/withdrawal/list');
    final body = <String, dynamic>{'pageNo': pageNo, 'pageSize': pageSize};
    if (status != null && status.isNotEmpty) body['status'] = status;
    if (search != null && search.isNotEmpty) body['search'] = search;

    final response = await _client.post(
      uri,
      headers: await _headers(),
      body: jsonEncode(body),
    );

    Map<String, dynamic> json = {};
    try { json = jsonDecode(response.body) as Map<String, dynamic>; } catch (_) {}

    if (response.statusCode != 200) {
      throw Exception(json['message'] ?? 'Withdraw list failed (${response.statusCode}).');
    }

    return WithdrawListResponse.fromJson(json['data'] ?? json);
  }

  /// Checks if the user has any withdrawal currently under review (pending).
  /// Returns the first pending [WithdrawRecord] if found, otherwise null.
  Future<WithdrawRecord?> fetchPendingWithdrawal() async {
    final result = await fetchWithdrawList(pageNo: 1, pageSize: 5, status: 'pending');
    if (result.data.isNotEmpty) {
      return result.data.first;
    }
    return null;
  }
}