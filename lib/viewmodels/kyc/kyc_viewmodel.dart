// lib/viewmodels/kyc/kyc_viewmodel.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/kyc/kyc_model.dart';

class KycViewModel extends ChangeNotifier {
  KycStep _currentStep = KycStep.aadhaar;
  KycStep get currentStep => _currentStep;

  final KycFormData _form = KycFormData();
  KycFormData get form => _form;

  KycStatus _status = KycStatus.idle;
  KycStatus get status => _status;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  bool _ifscLoading = false;
  bool get ifscLoading => _ifscLoading;

  String? _ifscError;
  String? get ifscError => _ifscError;

  bool _completed = false;
  bool get completed => _completed;

  /// True when the API says KYC is already pending or approved.
  /// The screen uses this to skip the upload flow and jump straight
  /// to the success/status screen.
  bool _alreadySubmitted = false;
  bool get alreadySubmitted => _alreadySubmitted;

  /// The status string returned by GET /api/kyc/status
  /// ('not_submitted' | 'pending' | 'approved' | 'rejected')
  String _serverKycStatus = 'not_submitted';
  String get serverKycStatus => _serverKycStatus;

  /// Full submission record (documents + bank details) returned by
  /// GET /api/kyc/status once a submission exists. Null until fetched
  /// or if the user has never submitted KYC.
  KycSubmissionDetails? _submissionDetails;
  KycSubmissionDetails? get submissionDetails => _submissionDetails;

  /// True while the initial status check is in flight.
  bool _checkingStatus = true;
  bool get checkingStatus => _checkingStatus;

  static const String _baseUrl = 'http://192.168.0.17:3000';

  /// Public accessor so views can build absolute URLs (e.g. for images)
  /// from the relative paths stored on [KycSubmissionDetails].
  static String get baseUrl => _baseUrl;

  final ImagePicker _picker = ImagePicker();

  KycViewModel() {
    _checkExistingKycStatus();
  }

  // ── Initial status check ─────────────────────────────────────────────────

  /// Called once on creation. Validates that the stored token belongs to the
  /// currently logged-in user before using it. If no token is found or the
  /// token belongs to a different account, we reset to not_submitted so
  /// a new user never sees a previous user's KYC state.
  Future<void> _checkExistingKycStatus() async {
    _checkingStatus = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final token      = prefs.getString('auth_token');
    final storedUserId = prefs.getString('logged_in_user_id');

    // Guard: no token means no session — start fresh
    if (token == null || token.isEmpty) {
      _resetToNotSubmitted();
      return;
    }

    // Guard: if stored user_id is missing (old install without the fix),
    // we can still proceed but we verify via the server.
    // If user_id IS stored, do a quick JWT sub check to catch account switches
    // that happened without going through login (e.g. token manually replaced).
    if (storedUserId != null && storedUserId.isNotEmpty) {
      final jwtUserId = _extractUserIdFromToken(token);
      if (jwtUserId != null && jwtUserId != storedUserId) {
        // Token user does not match stored user — stale state, reset
        await _clearUserSession(prefs);
        _resetToNotSubmitted();
        return;
      }
    }

    final status = await _fetchAndStoreKycDetails(token);
    if (status != null) {
      _serverKycStatus = status;
      // If pending or approved — skip upload flow, go straight to success screen
      if (status == 'pending' || status == 'approved') {
        _alreadySubmitted = true;
        _completed = true;
      }
      // If rejected/not_submitted — allow re-submission (fall through to upload flow)
    }
    // On network failure (null returned) we leave status as 'not_submitted'
    // so the user can attempt to submit. The server will reject duplicates with 409.

    _checkingStatus = false;
    notifyListeners();
  }

  /// Resets KYC state to a clean "not submitted" baseline.
  void _resetToNotSubmitted() {
    _serverKycStatus  = 'not_submitted';
    _submissionDetails = null;
    _alreadySubmitted = false;
    _completed        = false;
    _checkingStatus   = false;
    notifyListeners();
  }

  /// Removes token and user_id from prefs (called on account switch detection).
  Future<void> _clearUserSession(SharedPreferences prefs) async {
    await prefs.remove('auth_token');
    await prefs.remove('logged_in_user_id');
  }

  /// Decodes the JWT payload (base64) and extracts the `sub` field as a
  /// string without verifying the signature (verification happens server-side).
  /// Returns null if the token is malformed.
  String? _extractUserIdFromToken(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      // JWT segments use base64Url encoding without padding
      String payload = parts[1];
      // Add padding so base64 decoding works
      while (payload.length % 4 != 0) {
        payload += '=';
      }
      final decoded = utf8.decode(base64Url.decode(payload));
      final map     = jsonDecode(decoded) as Map<String, dynamic>;
      return map['sub']?.toString();
    } catch (_) {
      return null;
    }
  }

  /// Fetches the full KYC status response (status + uploaded document URLs
  /// + bank details) from GET /api/kyc/status, storing it in
  /// [_submissionDetails] so the success/status screen can render the
  /// submitted Aadhaar, PAN, selfie images and bank details once available.
  /// Returns the status string, or null on network/parse failure.
  Future<String?> _fetchAndStoreKycDetails(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/kyc/status'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final data = body['data'] as Map<String, dynamic>?;
        final status = (data?['status'] as String?) ?? 'not_submitted';

        // Only build submission details when a real submission exists
        // (the "no submission" response only contains {status: 'not_submitted'}).
        if (data != null && status != 'not_submitted') {
          _submissionDetails = KycSubmissionDetails.fromJson(
            data,
            baseUrl: _baseUrl,
          );
        } else {
          _submissionDetails = null;
        }
        return status;
      }

      if (response.statusCode == 401 || response.statusCode == 403) {
        _submissionDetails = null;
        return 'not_submitted';
      }
    } catch (_) {
      // Network error — caller decides how to handle a null result.
    }
    return null;
  }

  // ── Token helper ─────────────────────────────────────────────────────────

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  // ── Step helpers ─────────────────────────────────────────────────────────
  int get currentStepIndex => KycStep.values.indexOf(_currentStep);

  bool get canContinue {
    switch (_currentStep) {
      case KycStep.aadhaar: return _form.aadhaarComplete;
      case KycStep.pan:     return _form.panComplete;
      case KycStep.selfie:  return _form.selfieComplete;
      case KycStep.bank:    return _form.bankComplete;
    }
  }

  String get nextLabel {
    switch (_currentStep) {
      case KycStep.aadhaar: return 'Continue to PAN';
      case KycStep.pan:     return 'Continue to Selfie';
      case KycStep.selfie:  return 'Continue to Bank';
      case KycStep.bank:    return 'Complete Verification';
    }
  }

  String get stepTitle {
    switch (_currentStep) {
      case KycStep.aadhaar: return 'Moneytries Verification';
      case KycStep.pan:     return 'PAN Verification';
      case KycStep.selfie:  return 'Verify Identity';
      case KycStep.bank:    return 'Link Bank Account';
    }
  }

  void goBack() {
    final idx = currentStepIndex;
    if (idx > 0) {
      _currentStep = KycStep.values[idx - 1];
      _errorMessage = null;
      notifyListeners();
    }
  }

  void goNext() {
    if (!canContinue) {
      _errorMessage = _validationMessage();
      notifyListeners();
      return;
    }

    final idx = currentStepIndex;
    if (idx < KycStep.values.length - 1) {
      _currentStep = KycStep.values[idx + 1];
      _errorMessage = null;
      notifyListeners();
    } else {
      _submitKyc();
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // ── Image picking ─────────────────────────────────────────────────────────
  Future<void> pickAadhaarFront() async {
    final path = await _pickAndConvertImage(source: ImageSource.gallery);
    if (path != null) { _form.aadhaarFrontPath = path; _errorMessage = null; notifyListeners(); }
  }

  Future<void> pickAadhaarBack() async {
    final path = await _pickAndConvertImage(source: ImageSource.gallery);
    if (path != null) { _form.aadhaarBackPath = path; _errorMessage = null; notifyListeners(); }
  }

  Future<void> pickPanFront() async {
    final path = await _pickAndConvertImage(source: ImageSource.gallery);
    if (path != null) { _form.panFrontPath = path; _errorMessage = null; notifyListeners(); }
  }

  /// Opens the device camera to capture a live selfie and returns the local
  /// file path of the captured photo (or `null` if the user cancelled).
  /// This does NOT commit the photo as the KYC selfie — the UI must show a
  /// Retake / Use Photo preview and call [confirmSelfie] only once the user
  /// accepts the shot. Gallery/image-picker selection is intentionally not
  /// available for this step — only a live camera capture is accepted.
  Future<String?> captureSelfiePhoto() async {
    return _pickAndConvertImage(source: ImageSource.camera);
  }

  /// Commits a photo previously captured via [captureSelfiePhoto] (and
  /// accepted by the user in the Retake / Use Photo preview) as the final
  /// selfie to submit with the KYC application.
  void confirmSelfie(String path) {
    _form.selfiePath = path;
    _errorMessage = null;
    notifyListeners();
  }

  /// Picks an image from gallery or camera, then converts it to JPEG if the
  /// format is not natively accepted by the server (HEIC, WEBP, BMP, etc.).
  /// JPEG and PNG files are passed through unchanged (no re-encode).
  Future<String?> _pickAndConvertImage({required ImageSource source}) async {
    try {
      XFile? file;

      if (source == ImageSource.gallery) {
        file = await _picker.pickMedia();
      } else {
        file = await _picker.pickImage(
          source: source,
          maxWidth: 1920,
          maxHeight: 1920,
          imageQuality: 85,
        );
      }

      if (file == null) return null;

      // Determine if the picked file needs conversion
      final ext = p.extension(file.path).toLowerCase();
      const nativeFormats = {'.jpg', '.jpeg', '.png'};

      if (nativeFormats.contains(ext)) {
        // Already a server-accepted format — no conversion needed
        return file.path;
      }

      // Convert to JPEG using flutter_image_compress
      final tempDir = await getTemporaryDirectory();
      final targetPath =
          p.join(tempDir.path, '${p.basenameWithoutExtension(file.path)}_converted.jpg');

      final XFile? compressed = await FlutterImageCompress.compressAndGetFile(
        file.path,
        targetPath,
        format: CompressFormat.jpeg,
        quality: 88,
        minWidth: 800,
        minHeight: 800,
        keepExif: false,
      );

      if (compressed == null) {
        // Fallback: return original path (server-side accept list now also
        // covers webp/heic/heif so it may still work)
        return file.path;
      }

      return compressed.path;
    } catch (e) {
      _errorMessage = 'Unable to access camera/gallery. Please check permissions.';
      notifyListeners();
      return null;
    }
  }

  // ── Bank field updaters ───────────────────────────────────────────────────
  void updateAccountHolder(String v) { _form.accountHolderName = v; notifyListeners(); }
  void updateAccountNumber(String v) { _form.accountNumber = v; notifyListeners(); }
  void updateIfsc(String v) {
    _form.ifscCode = v.toUpperCase();
    _form.bankInfo = null;
    _ifscError = null;
    notifyListeners();
  }

  // ── IFSC lookup ───────────────────────────────────────────────────────────
  Future<void> lookupIfsc() async {
    final code = _form.ifscCode.trim().toUpperCase();
    if (code.length != 11) {
      _ifscError = 'IFSC must be exactly 11 characters';
      notifyListeners();
      return;
    }

    _ifscLoading = true;
    _ifscError = null;
    notifyListeners();

    try {
      final uri = Uri.parse('https://ifsc.razorpay.com/$code');
      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        _form.bankInfo = IfscBankInfo.fromJson(json);
        _ifscError = null;
      } else if (response.statusCode == 404) {
        _ifscError = 'Invalid IFSC code. Please check and try again.';
        _form.bankInfo = null;
      } else {
        _ifscError = 'Could not verify IFSC. Please try again.';
        _form.bankInfo = null;
      }
    } on SocketException {
      _ifscError = 'No internet connection. Please check your network.';
      _form.bankInfo = null;
    } catch (_) {
      _ifscError = 'IFSC lookup failed. Please try again.';
      _form.bankInfo = null;
    } finally {
      _ifscLoading = false;
      notifyListeners();
    }
  }

  // ── Final submission ──────────────────────────────────────────────────────
  Future<void> _submitKyc() async {
    _status = KycStatus.loading;
    notifyListeners();

    try {
      final token = await _getToken();
      if (token == null) {
        _status = KycStatus.error;
        _errorMessage = 'Session expired. Please log in again.';
        notifyListeners();
        return;
      }

      final uri = Uri.parse('$_baseUrl/api/kyc/submit');
      final request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer $token';

      // All files are guaranteed to be JPEG or PNG after _pickAndConvertImage.
      // We still call _imageMediaType() for correctness in case a path slips
      // through unchanged.
      request.files.add(await http.MultipartFile.fromPath(
          'aadhaar_front', _form.aadhaarFrontPath!,
          contentType: _imageMediaType(_form.aadhaarFrontPath!)));
      request.files.add(await http.MultipartFile.fromPath(
          'aadhaar_back', _form.aadhaarBackPath!,
          contentType: _imageMediaType(_form.aadhaarBackPath!)));
      request.files.add(await http.MultipartFile.fromPath(
          'pan_front', _form.panFrontPath!,
          contentType: _imageMediaType(_form.panFrontPath!)));
      request.files.add(await http.MultipartFile.fromPath(
          'selfie', _form.selfiePath!,
          contentType: _imageMediaType(_form.selfiePath!)));

      // Attach bank text fields
      request.fields['accountHolderName'] = _form.accountHolderName.trim();
      request.fields['accountNumber']     = _form.accountNumber.trim();
      request.fields['ifscCode']          = _form.ifscCode.trim().toUpperCase();
      request.fields['bankName']          = _form.bankInfo?.bankName ?? '';
      request.fields['bankBranch']        = _form.bankInfo?.branch ?? '';
      request.fields['bankCity']          = _form.bankInfo?.city ?? '';
      request.fields['bankState']         = _form.bankInfo?.state ?? '';

      final streamed = await request.send().timeout(const Duration(seconds: 30));
      final responseBody = await streamed.stream.bytesToString();

      // Safely parse JSON — server may return an HTML error page on crash
      Map<String, dynamic> body = {};
      try {
        body = jsonDecode(responseBody) as Map<String, dynamic>;
      } catch (_) {
        // Non-JSON response (HTML error page, gateway error, etc.)
        body = {'message': 'Server error. Please try again later.'};
      }

      if (streamed.statusCode == 200 || streamed.statusCode == 201) {
        _status = KycStatus.success;
        _serverKycStatus = 'pending';
        _alreadySubmitted = true;
        _completed = true;
        // Best-effort: pull the freshly stored submission (with document
        // URLs) so the success screen can render it immediately. Failure
        // here is non-fatal — the screen still works without it.
        await _fetchAndStoreKycDetails(token);
      } else if (streamed.statusCode == 409) {
        // Conflict — don't blindly assume success. Re-check the authoritative
        // status from the server so the UI always reflects what's actually
        // stored, instead of masking a real failure as "submitted".
        final realStatus = await _fetchAndStoreKycDetails(token);

        if (realStatus == 'pending' || realStatus == 'approved') {
          _status = KycStatus.success;
          _serverKycStatus = realStatus!;
          _alreadySubmitted = true;
          _completed = true;
        } else {
          _status = KycStatus.error;
          _errorMessage = (body['message'] as String?) ??
              'A submission is already in progress. Please try again shortly.';
        }
      } else {
        _status = KycStatus.error;
        _errorMessage = (body['message'] as String?) ?? 'Submission failed. Please try again.';
      }
    } on SocketException {
      _status = KycStatus.error;
      _errorMessage = 'No internet connection. Please check your network.';
    } on TimeoutException {
      _status = KycStatus.error;
      _errorMessage = 'Request timed out. Please check your connection and try again.';
    } catch (e) {
      _status = KycStatus.error;
      // Show the actual error in debug mode so it's easier to diagnose
      assert(() {
        _errorMessage = 'Submission error: $e';
        return true;
      }());
      _errorMessage ??= 'Submission failed. Please try again.';
    } finally {
      notifyListeners();
    }
  }

  // ── Image MIME helper ────────────────────────────────────────────────────

  /// Returns a [MediaType] for [filePath] based on its extension.
  /// After conversion, almost all files will be JPEG; this covers edge cases.
  MediaType _imageMediaType(String filePath) {
    final ext = filePath.split('.').last.toLowerCase();
    const map = <String, String>{
      'jpg': 'jpeg', 'jpeg': 'jpeg',
      'png': 'png',  'webp': 'webp',
      'heic': 'heic', 'heif': 'heif',
      'bmp': 'bmp',  'tiff': 'tiff', 'tif': 'tiff',
      'gif': 'gif',
    };
    return MediaType('image', map[ext] ?? 'jpeg');
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  String _validationMessage() {
    switch (_currentStep) {
      case KycStep.aadhaar:
        if (_form.aadhaarFrontPath == null && _form.aadhaarBackPath == null) {
          return 'Please upload both front and back of your Aadhaar card.';
        }
        if (_form.aadhaarFrontPath == null) return 'Please upload Aadhaar front side.';
        return 'Please upload Aadhaar back side.';
      case KycStep.pan:
        return 'Please upload your PAN card.';
      case KycStep.selfie:
        return 'Please capture or upload your selfie.';
      case KycStep.bank:
        if (_form.accountHolderName.trim().isEmpty) return 'Please enter account holder name.';
        if (_form.accountNumber.trim().length < 9)  return 'Please enter a valid account number (min 9 digits).';
        if (_form.ifscCode.trim().length != 11)     return 'IFSC code must be 11 characters.';
        if (_form.bankInfo == null) return 'Please verify your IFSC code first using the FIND button.';
        return 'Please fill all bank details correctly.';
    }
  }
}