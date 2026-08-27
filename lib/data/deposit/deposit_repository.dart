import 'dart:io';
import 'package:http/http.dart' as http;
import '../../core/network/session_http_client.dart';
import 'package:http_parser/http_parser.dart';
import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/deposit/deposit_models.dart';
import '../../core/api/api_config.dart';

const String _kBaseUrl = ApiConfig.baseUrl;
/// Maps common image file extensions to their correct MIME type.
/// Android's image picker sometimes reports application/octet-stream;
/// this ensures the multipart request always carries a proper content-type.
MediaType _mimeForPath(String filePath) {
  final ext = p.extension(filePath).toLowerCase();
  switch (ext) {
    case '.jpg':
    case '.jpeg':
      return MediaType('image', 'jpeg');
    case '.png':
      return MediaType('image', 'png');
    case '.webp':
      return MediaType('image', 'webp');
    case '.heic':
      return MediaType('image', 'heic');
    case '.heif':
      return MediaType('image', 'heif');
    case '.bmp':
      return MediaType('image', 'bmp');
    case '.gif':
      return MediaType('image', 'gif');
    default:
      return MediaType('image', 'jpeg'); // safe fallback
  }
}

class DepositRepository {
  final http.Client _client;
  DepositRepository({http.Client? client}) : _client = client ?? sessionHttpClient;

  /// Reads the JWT token saved by LoginViewModel / RegisterViewModel.
  Future<String> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null || token.isEmpty) {
      throw Exception('Session expired. Please log in again.');
    }
    return token;
  }

  /// Step 1: Upload screenshot → returns a proof_image path.
  Future<String> _uploadScreenshot(File screenshot) async {
    final token = await _getToken();
    final uri   = Uri.parse('$_kBaseUrl/api/deposit/upload');

    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $token'
      ..files.add(await http.MultipartFile.fromPath(
        'file',
        screenshot.path,
        contentType: _mimeForPath(screenshot.path),
      ));

    final streamed = await _client.send(request);
    final body     = await streamed.stream.bytesToString();

    if (streamed.statusCode != 200 && streamed.statusCode != 201) {
      Map<String, dynamic> errJson = {};
      try { errJson = jsonDecode(body) as Map<String, dynamic>; } catch (_) {}
      throw Exception(errJson['message'] ?? 'Screenshot upload failed (${streamed.statusCode}).');
    }

    final json       = jsonDecode(body) as Map<String, dynamic>;
    final uploadResp = UploadResponse.fromJson(json['data'] ?? json);
    if (uploadResp.proofImageUrl.isEmpty) {
      throw Exception('Upload succeeded but no image URL in response.');
    }
    return uploadResp.proofImageUrl;
  }

  /// Step 2: POST /api/deposit/submit with amount, UTR ID, and proof image URL.
  Future<ManualOrderModel> _createOrder({
    required int amount,
    required String utrId,
    required String proofImageUrl,
  }) async {
    final token = await _getToken();
    final uri   = Uri.parse('$_kBaseUrl/api/deposit/submit');

    final response = await _client.post(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type':  'application/json',
      },
      body: jsonEncode({
        'amount':      amount,
        'utr_id':      utrId,
        'proof_image': proofImageUrl,
      }),
    );

    Map<String, dynamic> json = {};
    try { json = jsonDecode(response.body) as Map<String, dynamic>; } catch (_) {}

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(json['message'] ?? 'Deposit submission failed (${response.statusCode}).');
    }

    return ManualOrderModel.fromJson(json['data'] ?? json);
  }

  /// Public method — orchestrates the full 2-step deposit flow.
  Future<ManualOrderModel> createManualDeposit({
    required int amount,
    required String utrId,
    required File screenshot,
  }) async {
    final proofImageUrl = await _uploadScreenshot(screenshot);
    return _createOrder(amount: amount, utrId: utrId, proofImageUrl: proofImageUrl);
  }

  /// Fetch paginated deposit history for the current user.
  Future<DepositListResponse> fetchDepositList({
    int pageNo   = 1,
    int pageSize = 10,
    String? status,
    String? search,
  }) async {
    final token = await _getToken();
    final uri   = Uri.parse('$_kBaseUrl/api/deposit/list');

    final body = <String, dynamic>{'pageNo': pageNo, 'pageSize': pageSize};
    if (status != null && status.isNotEmpty) body['status'] = status;
    if (search != null && search.isNotEmpty) body['search'] = search;

    final response = await _client.post(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type':  'application/json',
      },
      body: jsonEncode(body),
    );

    Map<String, dynamic> json = {};
    try { json = jsonDecode(response.body) as Map<String, dynamic>; } catch (_) {}

    if (response.statusCode != 200) {
      throw Exception(json['message'] ?? 'Could not fetch deposit history (${response.statusCode}).');
    }

    return DepositListResponse.fromJson(json['data'] ?? json);
  }

  /// Checks if the user has any deposit currently under review (pending).
  /// Returns the first pending [DepositRecord] if found, otherwise null.
  Future<DepositRecord?> fetchPendingDeposit() async {
    final result = await fetchDepositList(pageNo: 1, pageSize: 5, status: 'pending');
    if (result.data.isNotEmpty) {
      return result.data.first;
    }
    return null;
  }
}