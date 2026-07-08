import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
    //static const String baseUrl = 'http://10.0.2.2:3000';
    static const String baseUrl = 'http://192.168.0.17:3000';
  static Future<Map<String, dynamic>> login({
    required String identifier,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/auth/login'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'identifier': identifier,
        'password': password,
      }),
    );

    return jsonDecode(response.body);
  }

  /// Validates a previously-issued token against the backend by calling the
  /// protected `GET /api/auth/me` route. Used by the "Quick Login with
  /// Biometrics" flow on the login screen to confirm a device-remembered
  /// session is still valid (not expired / not revoked) before letting the
  /// person straight into the app without re-entering their password.
  static Future<Map<String, dynamic>> validateSession({
    required String token,
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/auth/me'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> register({
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    required String password,
    required String confirmPassword,
    required bool emailVerified,
    required bool phoneVerified,
    String? referralCode,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/auth/register'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'phone': phone,
        'password': password,
        'confirmPassword': confirmPassword,
        'emailVerified': emailVerified,
        'phoneVerified': phoneVerified,
        'referralCode': referralCode ?? '',
      }),
    );

    return jsonDecode(response.body);
  }

  /// Sends a fresh 6-digit OTP to [phone] for registration.
  /// Also used to power "Resend OTP" — the backend invalidates any
  /// previously issued OTP for the same number before generating a new one.
  static Future<Map<String, dynamic>> sendMobOtpRegister({
    required String phone,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/users/send_mob_otp_register'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'phone': phone,
      }),
    );

    return jsonDecode(response.body);
  }

  /// Verifies the [otp] entered by the user for [phone] during registration.
  static Future<Map<String, dynamic>> verifyMobOtpRegister({
    required String phone,
    required String otp,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/users/verify_mob_otp_register'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'phone': phone,
        'otp': otp,
      }),
    );

    return jsonDecode(response.body);
  }

  /// Sends a fresh 6-digit OTP to [email] for registration.
  /// Also used to power "Resend Code" — the backend invalidates any
  /// previously issued OTP for the same email before generating a new one.
  static Future<Map<String, dynamic>> sendEmailOtpRegister({
    required String email,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/users/send_email_otp_register'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'email': email,
      }),
    );

    return jsonDecode(response.body);
  }

  /// Verifies the [otp] entered by the user for [email] during registration.
  static Future<Map<String, dynamic>> verifyEmailOtpRegister({
    required String email,
    required String otp,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/users/verify_email_otp_register'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'email': email,
        'otp': otp,
      }),
    );

    return jsonDecode(response.body);
  }

  // ── Forgot password flow ────────────────────────────────────────────────────

  /// Sends a 6-digit OTP to the account matching [identifier] (email or
  /// 10-digit mobile number), valid for 5 minutes. Also powers "Resend OTP" —
  /// the backend invalidates any previously issued reset OTP for the same
  /// identifier before generating a new one.
  static Future<Map<String, dynamic>> sendForgotPasswordOtp({
    required String identifier,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/auth/forgot-password/send-otp'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'identifier': identifier,
      }),
    );

    return jsonDecode(response.body);
  }

  /// Verifies the [otp] entered by the user for [identifier] during the
  /// forgot-password flow. On success, the response contains a short-lived
  /// `reset_token` (under `data.reset_token`) that must be passed to
  /// [resetPassword] to actually change the password.
  static Future<Map<String, dynamic>> verifyForgotPasswordOtp({
    required String identifier,
    required String otp,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/auth/forgot-password/verify-otp'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'identifier': identifier,
        'otp': otp,
      }),
    );

    return jsonDecode(response.body);
  }

  /// Sets a new password for the account matching [identifier]. Requires the
  /// [resetToken] issued by a successful [verifyForgotPasswordOtp] call.
  /// The backend hashes the password before saving and invalidates all
  /// previous reset OTPs for this identifier once the reset succeeds.
  static Future<Map<String, dynamic>> resetPassword({
    required String identifier,
    required String resetToken,
    required String newPassword,
    required String confirmPassword,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/auth/forgot-password/reset-password'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'identifier': identifier,
        'resetToken': resetToken,
        'newPassword': newPassword,
        'confirmPassword': confirmPassword,
      }),
    );

    return jsonDecode(response.body);
  }

  // ── Login-time Two-Factor Authentication ────────────────────────────────
  // These are only reachable with the short-lived `pending_token` returned
  // by [login] when the account has 2FA enabled. They complete the second
  // factor of the login itself and are distinct from the Security Settings
  // 2FA enable/disable endpoints (which run on a full session token).

  /// Verifies the [otp] entered on the "Enter OTP to Verify Your Login"
  /// screen. On success the response has the exact same shape as a normal
  /// [login] success — `data.token` + `data.user` — so the caller can reuse
  /// the same post-login handling (save session, decide PIN/home route).
  static Future<Map<String, dynamic>> verifyLoginOtp({
    required String pendingToken,
    required String otp,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/auth/2fa/verify-otp'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $pendingToken',
      },
      body: jsonEncode({
        'otp': otp,
      }),
    );

    return jsonDecode(response.body);
  }

  /// Re-sends the login OTP for the account tied to [pendingToken],
  /// invalidating whatever OTP was issued previously.
  static Future<Map<String, dynamic>> resendLoginOtp({
    required String pendingToken,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/auth/2fa/resend-otp'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $pendingToken',
      },
    );

    return jsonDecode(response.body);
  }
}