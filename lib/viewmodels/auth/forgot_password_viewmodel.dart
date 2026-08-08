import 'package:flutter/material.dart';
import '../../services/api_service.dart';

enum ForgotPasswordStatus { idle, loading, success, error }

/// Shared state for the whole "Forgot Password" flow:
/// Enter Email/Mobile → Send OTP → Verify OTP → Reset Password.
///
/// A single instance is created in [ForgotPasswordScreen] and threaded
/// through the subsequent screens (via ChangeNotifierProvider.value) so the
/// verified identifier and reset token survive screen navigation without
/// being re-entered or re-verified.
class ForgotPasswordViewModel extends ChangeNotifier {
  ForgotPasswordStatus _status = ForgotPasswordStatus.idle;
  String? _errorMessage;

  /// The email or 10-digit mobile number this flow is operating on, as
  /// returned/normalized by the backend after a successful OTP send.
  String? _identifier;

  /// Short-lived token issued after successful OTP verification. Required by
  /// the reset-password endpoint — without it the server rejects the reset,
  /// so a client can never skip straight from "enter identifier" to
  /// "set new password" without actually verifying an OTP.
  String? _resetToken;

  /// Seconds remaining before the currently-issued OTP expires (server sends
  /// this; defaults to 5 minutes == 300 seconds).
  int _otpExpirySeconds = 300;

  ForgotPasswordStatus get status => _status;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _status == ForgotPasswordStatus.loading;
  String? get identifier => _identifier;
  String? get resetToken => _resetToken;
  int get otpExpirySeconds => _otpExpirySeconds;

  // ── Validation ───────────────────────────────────────────────────────────

  String? validateIdentifier(String value) {
    final v = value.trim();
    if (v.isEmpty) return 'Please enter your email or mobile number';
    final isEmail = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v);
    final isMobile = RegExp(r'^\d{10}$').hasMatch(v);
    if (!isEmail && !isMobile) {
      return 'Enter a valid email or 10-digit mobile number';
    }
    return null;
  }

  /// Mirrors the backend rule: minimum 8 characters, containing both
  /// letters and numbers.
  String? validatePasswordStrength(String value) {
    if (value.isEmpty) return 'Please enter a new password';
    if (value.length < 8) return 'Password must be at least 8 characters';
    final hasLetter = RegExp(r'[A-Za-z]').hasMatch(value);
    final hasDigit = RegExp(r'\d').hasMatch(value);
    if (!hasLetter || !hasDigit) {
      return 'Password must contain letters and numbers';
    }
    return null;
  }

  String? validateConfirmPassword(String password, String confirmPassword) {
    if (confirmPassword.isEmpty) return 'Please confirm your new password';
    if (confirmPassword != password) return 'Passwords do not match';
    return null;
  }

  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  // ── Step 1: Send OTP ────────────────────────────────────────────────────

  Future<bool> sendOtp(String identifier) async {
    final validationError = validateIdentifier(identifier);
    if (validationError != null) {
      _errorMessage = validationError;
      notifyListeners();
      return false;
    }

    _status = ForgotPasswordStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await ApiService.sendForgotPasswordOtp(
        identifier: identifier.trim(),
      );

      if (response['success'] == true) {
        _identifier = response['data']?['identifier'] as String? ??
            identifier.trim();
        _otpExpirySeconds =
            response['data']?['expires_in_seconds'] as int? ?? 300;
        _status = ForgotPasswordStatus.success;
        notifyListeners();
        return true;
      }

      _status = ForgotPasswordStatus.error;
      _errorMessage = response['message']?.toString() ??
          'Failed to send OTP. Please try again.';
      notifyListeners();
      return false;
    } catch (e) {
      _status = ForgotPasswordStatus.error;
      _errorMessage = 'Something went wrong. Please try again.';
      notifyListeners();
      return false;
    }
  }

  /// Re-sends the OTP to the already-established [identifier] — used by the
  /// "Resend OTP" action on the verification screen.
  Future<bool> resendOtp() async {
    if (_identifier == null) return false;
    return sendOtp(_identifier!);
  }

  // ── Step 2: Verify OTP ──────────────────────────────────────────────────

  Future<bool> verifyOtp(String otp) async {
    if (_identifier == null) {
      _errorMessage = 'Session expired. Please start again.';
      notifyListeners();
      return false;
    }

    if (otp.length != 6) {
      _errorMessage = 'Please enter all 6 digits';
      notifyListeners();
      return false;
    }

    _status = ForgotPasswordStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await ApiService.verifyForgotPasswordOtp(
        identifier: _identifier!,
        otp: otp,
      );

      if (response['success'] == true) {
        _resetToken = response['data']?['reset_token'] as String?;
        _status = ForgotPasswordStatus.success;
        notifyListeners();
        return true;
      }

      _status = ForgotPasswordStatus.error;
      _errorMessage = response['message']?.toString() ??
          'Invalid OTP. Please try again.';
      notifyListeners();
      return false;
    } catch (e) {
      _status = ForgotPasswordStatus.error;
      _errorMessage = 'Something went wrong. Please try again.';
      notifyListeners();
      return false;
    }
  }

  // ── Step 3: Reset password ─────────────────────────────────────────────

  Future<bool> resetPassword({
    required String newPassword,
    required String confirmPassword,
  }) async {
    if (_identifier == null || _resetToken == null) {
      _errorMessage = 'Session expired. Please start again.';
      notifyListeners();
      return false;
    }

    final strengthError = validatePasswordStrength(newPassword);
    if (strengthError != null) {
      _errorMessage = strengthError;
      notifyListeners();
      return false;
    }

    final matchError =
        validateConfirmPassword(newPassword, confirmPassword);
    if (matchError != null) {
      _errorMessage = matchError;
      notifyListeners();
      return false;
    }

    _status = ForgotPasswordStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await ApiService.resetPassword(
        identifier: _identifier!,
        resetToken: _resetToken!,
        newPassword: newPassword,
        confirmPassword: confirmPassword,
      );

      if (response['success'] == true) {
        _status = ForgotPasswordStatus.success;
        notifyListeners();
        return true;
      }

      _status = ForgotPasswordStatus.error;
      _errorMessage = response['message']?.toString() ??
          'Failed to reset password. Please try again.';
      notifyListeners();
      return false;
    } catch (e) {
      _status = ForgotPasswordStatus.error;
      _errorMessage = 'Something went wrong. Please try again.';
      notifyListeners();
      return false;
    }
  }

  void resetState() {
    _status = ForgotPasswordStatus.idle;
    _errorMessage = null;
    notifyListeners();
  }
}