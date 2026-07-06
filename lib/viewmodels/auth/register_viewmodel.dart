// lib/viewmodels/auth/register_viewmodel.dart

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';
import '../../data/security/security_repository.dart';

enum RegisterStatus { idle, loading, success, error }

class RegisterViewModel extends ChangeNotifier {
  String firstName = '';
  String lastName = '';
  String email = '';
  String phone = '';
  String password = '';
  String confirm = '';
  String referral = '';
  bool agreed = false;

  bool emailVerified = false;
  bool phoneVerified = false;

  bool obscurePassword = true;
  bool obscureConfirm = true;

  RegisterStatus _status = RegisterStatus.idle;
  String? _errorMessage;

  RegisterStatus get status => _status;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _status == RegisterStatus.loading;

  String? firstNameError;
  String? lastNameError;
  String? emailError;
  String? phoneError;
  String? passwordError;
  String? confirmError;
  String? agreedError;
  String? emailVerifyError;
  String? phoneVerifyError;

  bool isValidEmail(String v) =>
      RegExp(r'^[^\@\s]+@[^\@\s]+\.[^\@\s]+$').hasMatch(v.trim());

  bool isValidPhone(String v) =>
      RegExp(r'^\d{10}$').hasMatch(v.trim());

  String maskEmail(String e) {
    final parts = e.split('@');

    if (parts.length != 2) return e;

    final local = parts[0];
    final domain = parts[1];

    if (local.length <= 2) {
      return '${local[0]}*@$domain';
    }

    return '${local[0]}${'*' * (local.length - 2)}${local[local.length - 1]}@$domain';
  }

  void clearFirstNameError() {
    if (firstNameError != null) {
      firstNameError = null;
      notifyListeners();
    }
  }

  void clearLastNameError() {
    if (lastNameError != null) {
      lastNameError = null;
      notifyListeners();
    }
  }

  void clearPasswordError() {
    if (passwordError != null) {
      passwordError = null;
      notifyListeners();
    }
  }

  void clearConfirmError() {
    if (confirmError != null) {
      confirmError = null;
      notifyListeners();
    }
  }

  void clearEmailError() {
    emailError = null;
    emailVerifyError = null;
    emailVerified = false;
    notifyListeners();
  }

  void clearPhoneError() {
    phoneError = null;
    phoneVerifyError = null;
    phoneVerified = false;
    notifyListeners();
  }

  void toggleAgreed() {
    agreed = !agreed;
    agreedError = null;
    notifyListeners();
  }

  void toggleObscurePassword() {
    obscurePassword = !obscurePassword;
    notifyListeners();
  }

  void toggleObscureConfirm() {
    obscureConfirm = !obscureConfirm;
    notifyListeners();
  }

  String? requestEmailVerify(String rawEmail) {
    email = rawEmail.trim();

    if (email.isEmpty || !isValidEmail(email)) {
      emailError = 'Enter a valid email address before verifying';
      notifyListeners();
      return null;
    }

    emailError = null;
    emailVerifyError = null;
    notifyListeners();

    return maskEmail(email);
  }

  void markEmailVerified() {
    emailVerified = true;
    emailVerifyError = null;
    notifyListeners();
  }

  String? requestPhoneVerify(String rawPhone) {
    phone = rawPhone.trim();

    if (phone.isEmpty || !isValidPhone(phone)) {
      phoneError = 'Enter a valid 10-digit phone number before verifying';
      notifyListeners();
      return null;
    }

    phoneError = null;
    phoneVerifyError = null;
    notifyListeners();

    return '+91 $phone';
  }

  void markPhoneVerified() {
    phoneVerified = true;
    phoneVerifyError = null;
    notifyListeners();
  }

  /// Calls the backend to generate + send an email OTP for [email].
  /// Returns null on success, or an error message on failure.
  /// Also used to power "Resend Code" on the email OTP screen.
  Future<String?> sendEmailOtp(String email) async {
    try {
      final response = await ApiService.sendEmailOtpRegister(email: email);

      if (response['success'] == true) {
        return null;
      }
      return response['message']?.toString() ?? 'Failed to send OTP. Please try again.';
    } catch (e) {
      return 'Something went wrong. Please try again.';
    }
  }

  /// Calls the backend to verify the [otp] entered for [email].
  /// Returns null on success, or an error message on failure.
  Future<String?> verifyEmailOtp(String email, String otp) async {
    try {
      final response = await ApiService.verifyEmailOtpRegister(
        email: email,
        otp: otp,
      );

      if (response['success'] == true) {
        return null;
      }
      return response['message']?.toString() ?? 'Invalid OTP. Please try again.';
    } catch (e) {
      return 'Something went wrong. Please try again.';
    }
  }

  /// Calls the backend to generate + send a mobile OTP for [phone].
  /// Returns null on success, or an error message on failure.
  /// Also used to power "Resend OTP" on the OTP screen.
  Future<String?> sendPhoneOtp(String phone) async {
    try {
      final response = await ApiService.sendMobOtpRegister(phone: phone);

      if (response['success'] == true) {
        return null;
      }
      return response['message']?.toString() ?? 'Failed to send OTP. Please try again.';
    } catch (e) {
      return 'Something went wrong. Please try again.';
    }
  }

  /// Calls the backend to verify the [otp] entered for [phone].
  /// Returns null on success, or an error message on failure.
  Future<String?> verifyPhoneOtp(String phone, String otp) async {
    try {
      final response = await ApiService.verifyMobOtpRegister(
        phone: phone,
        otp: otp,
      );

      if (response['success'] == true) {
        return null;
      }
      return response['message']?.toString() ?? 'Invalid OTP. Please try again.';
    } catch (e) {
      return 'Something went wrong. Please try again.';
    }
  }

  bool validate() {
    firstNameError =
        firstName.isEmpty ? 'First name is required' : null;

    lastNameError =
        lastName.isEmpty ? 'Last name is required' : null;

    if (email.isEmpty) {
      emailError = 'Email address is required';
    } else if (!isValidEmail(email)) {
      emailError = 'Enter a valid email address';
    } else {
      emailError = null;
    }

    if (phone.isEmpty) {
      phoneError = 'Phone number is required';
    } else if (!isValidPhone(phone)) {
      phoneError = 'Enter a valid 10-digit phone number';
    } else {
      phoneError = null;
    }

    if (password.isEmpty) {
      passwordError = 'Password is required';
    } else if (password.length < 8) {
      passwordError =
          'Password must be at least 8 characters';
    } else if (!RegExp(r'(?=.*[A-Za-z])(?=.*\d)')
        .hasMatch(password)) {
      passwordError =
          'Password must contain letters and numbers';
    } else {
      passwordError = null;
    }

    if (confirm.isEmpty) {
      confirmError = 'Please confirm your password';
    } else if (confirm != password) {
      confirmError = 'Passwords do not match';
    } else {
      confirmError = null;
    }

    agreedError = !agreed
        ? 'You must agree to the Terms of Service'
        : null;

    emailVerifyError =
        (emailError == null && !emailVerified)
            ? 'Please verify your email address'
            : null;

    phoneVerifyError =
        (phoneError == null && !phoneVerified)
            ? 'Please verify your phone number'
            : null;

    notifyListeners();

    return firstNameError == null &&
        lastNameError == null &&
        emailError == null &&
        phoneError == null &&
        passwordError == null &&
        confirmError == null &&
        agreedError == null &&
        emailVerifyError == null &&
        phoneVerifyError == null;
  }

  Future<bool> signUp() async {
    if (!validate()) return false;

    _status = RegisterStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await ApiService.register(
        firstName: firstName,
        lastName: lastName,
        email: email,
        phone: phone,
        password: password,
        confirmPassword: confirm,
        emailVerified: emailVerified,
        phoneVerified: phoneVerified,
        referralCode: referral,
      );

      if (response['success'] == true) {
        // ── Save token + user_id so KycViewModel works immediately ───
        // Without this, after registration the old user's token remains
        // in SharedPreferences and KYC loads the wrong account's status.
        final token  = response['data']?['token'] as String?;
        final userId = response['data']?['user']?['id'];

        if (token != null) {
          final prefs = await SharedPreferences.getInstance();

          // Detect account switch and wipe stale per-user state
          final previousUserId = prefs.getString('logged_in_user_id');
          final newUserId      = userId?.toString() ?? '';

          if (previousUserId != null && previousUserId != newUserId) {
            await prefs.remove('auth_token');
            await prefs.remove('logged_in_user_id');
            await prefs.remove('logged_in_user_label');
          }

          await prefs.setString('auth_token', token);
          await prefs.setString('logged_in_user_id', newUserId);
          // Label shown on the PIN-lock screen so it's always clear which
          // account is being unlocked, regardless of PIN digit collisions
          // between accounts.
          final label = firstName.trim().isNotEmpty
              ? firstName.trim()
              : (email.isNotEmpty ? email : phone);
          await prefs.setString('logged_in_user_label', label);

          // Register this signup as an active device session and record
          // the login event so Security Settings → "Manage Devices" /
          // "Login Activity" reflect real data instead of staying empty.
          final deviceName = Platform.isAndroid
              ? 'Android Device'
              : Platform.isIOS
                  ? 'iPhone'
                  : 'Unknown Device';
          unawaited(SecurityRepository().registerCurrentSession(token));
          unawaited(
            SecurityRepository().recordLoginEvent(
              deviceName: deviceName,
              location: 'India',
              success: true,
            ),
          );
        }
        // ─────────────────────────────────────────────────────────────

        _status = RegisterStatus.success;
        notifyListeners();
        return true;
      }

      _status = RegisterStatus.error;
      _errorMessage =
          response['message'] ?? 'Registration failed';
      notifyListeners();
      return false;
    } catch (e) {
      _status = RegisterStatus.error;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  void resetStatus() {
    _status = RegisterStatus.idle;
    _errorMessage = null;
    notifyListeners();
  }
}