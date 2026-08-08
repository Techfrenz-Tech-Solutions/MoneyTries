import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/network/session_http_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/date_time_utils.dart';
import '../../core/api/api_config.dart';

const String _kBaseUrl = ApiConfig.baseUrl;
class HomeBalances {
  final double walletBalance;
  final double vaultBalance;
  const HomeBalances({required this.walletBalance, required this.vaultBalance});
}

class RecentTransaction {
  final String id;
  final String type;
  final String title;
  final String subtitle;
  final double amount;
  final bool isCredit;
  final String status;
  final DateTime date;

  const RecentTransaction({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.isCredit,
    required this.status,
    required this.date,
  });

  factory RecentTransaction.fromJson(Map<String, dynamic> j) {
    return RecentTransaction(
      id:       j['id']?.toString() ?? '',
      type:     j['type']?.toString() ?? '',
      title:    j['title']?.toString() ?? 'Transaction',
      subtitle: j['subtitle']?.toString() ?? '',
      amount:   double.tryParse(j['amount']?.toString() ?? '0') ?? 0,
      isCredit: j['is_credit'] == true,
      status:   j['status']?.toString() ?? 'pending',
      date:     parseServerDateTime(j['date']) ?? DateTime.now(),
    );
  }
}

class HomeRepository {
  final http.Client _client;
  HomeRepository({http.Client? client}) : _client = client ?? sessionHttpClient;

  Future<String> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null || token.isEmpty) {
      throw Exception('Session expired. Please log in again.');
    }
    return token;
  }

  /// Fetches the user's real wallet (main) and vault (mining earnings) balances.
  /// Backed by the same endpoint the Withdrawal screen uses, so both screens
  /// always agree on the figures.
  Future<HomeBalances> fetchBalances() async {
    final token = await _getToken();
    final uri = Uri.parse('$_kBaseUrl/api/withdrawal/balances');

    final response = await _client.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );

    Map<String, dynamic> json = {};
    try { json = jsonDecode(response.body) as Map<String, dynamic>; } catch (_) {}

    if (response.statusCode != 200) {
      throw Exception(json['message'] ?? 'Could not fetch balances (${response.statusCode}).');
    }

    final data = json['data'] ?? json;
    return HomeBalances(
      walletBalance: double.tryParse(data['wallet_balance']?.toString() ?? '0') ?? 0,
      vaultBalance: double.tryParse(data['vault_balance']?.toString() ?? '0') ?? 0,
    );
  }

  /// Fetches the 5 most recent transactions from /api/history.
  Future<List<RecentTransaction>> fetchRecentTransactions() async {
    final token = await _getToken();
    final uri = Uri.parse('$_kBaseUrl/api/history?pageSize=5&page=1');

    final response = await _client.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );

    Map<String, dynamic> json = {};
    try { json = jsonDecode(response.body) as Map<String, dynamic>; } catch (_) {}

    if (response.statusCode != 200) {
      throw Exception(json['message'] ?? 'Could not fetch transactions.');
    }

    final outer = json['data'] ?? json;
    final List<dynamic> items = outer['data'] ?? [];
    return items.map((e) => RecentTransaction.fromJson(e as Map<String, dynamic>)).toList();
  }
}