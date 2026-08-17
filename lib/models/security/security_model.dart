// lib/models/security/security_model.dart

enum SecurityAction { idle, loading, success, error }

class DeviceSession {
  final String id;
  final String deviceName;
  final String deviceType; // 'android' | 'ios' | 'web'
  final String location;
  final String lastActive;
  final bool isCurrent;

  const DeviceSession({
    required this.id,
    required this.deviceName,
    required this.deviceType,
    required this.location,
    required this.lastActive,
    required this.isCurrent,
  });

  factory DeviceSession.fromJson(Map<String, dynamic> json) {
    return DeviceSession(
      id: json['id']?.toString() ?? '',
      deviceName: json['device_name'] ?? 'Unknown Device',
      deviceType: json['device_type'] ?? 'android',
      location: json['location'] ?? 'Unknown',
      lastActive: json['last_active'] ?? 'Unknown',
      isCurrent: json['is_current'] == true || json['is_current'] == 1,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'device_name': deviceName,
        'device_type': deviceType,
        'location': location,
        'last_active': lastActive,
        'is_current': isCurrent,
      };
}

class LoginEvent {
  final String id;
  final String deviceName;
  final String location;
  final String timestamp;
  final bool success;

  const LoginEvent({
    required this.id,
    required this.deviceName,
    required this.location,
    required this.timestamp,
    required this.success,
  });

  factory LoginEvent.fromJson(Map<String, dynamic> json) {
    return LoginEvent(
      id: json['id']?.toString() ?? '',
      deviceName: json['device_name'] ?? 'Unknown Device',
      location: json['location'] ?? 'Unknown',
      timestamp: json['timestamp'] ?? '',
      success: json['success'] == true || json['success'] == 1,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'device_name': deviceName,
        'location': location,
        'timestamp': timestamp,
        'success': success,
      };
}

/// Result of a Login Credentials → Change Password "verify current
/// password" attempt (POST /api/security/password/verify), and also used
/// to represent GET /api/security/password/status.
class PasswordChangeStatus {
  final bool success;
  final bool locked;
  final int remainingSeconds;
  final int remainingAttempts;
  final String message;

  const PasswordChangeStatus({
    required this.success,
    required this.locked,
    required this.remainingSeconds,
    required this.remainingAttempts,
    required this.message,
  });

  factory PasswordChangeStatus.fromJson(
    Map<String, dynamic> json, {
    required bool success,
    required String message,
  }) {
    final data = json['data'] as Map<String, dynamic>? ?? {};
    return PasswordChangeStatus(
      success: success,
      locked: data['locked'] == true,
      remainingSeconds: (data['remaining_seconds'] as num?)?.toInt() ?? 0,
      remainingAttempts:
          (data['remaining_attempts'] as num?)?.toInt() ?? 5,
      message: message,
    );
  }
}

/// Account-level status of the Login PIN and Biometric Login setting -
/// fetched from the backend (GET /api/security/pins/status) so any device
/// can tell what's already configured on the account instead of assuming
/// nothing is set just because this device has no local cache.
class PinSyncStatus {
  final bool loginPinSet;
  final bool biometricEnabled;

  const PinSyncStatus({
    this.loginPinSet = false,
    this.biometricEnabled = false,
  });

  factory PinSyncStatus.fromJson(Map<String, dynamic> json) {
    return PinSyncStatus(
      loginPinSet: json['login_pin_set'] == true,
      biometricEnabled: json['biometric_enabled'] == true,
    );
  }
}

/// Result of a Forgot Login PIN OTP call — covers
/// POST /api/security/pin/login/forgot/send-otp,
/// POST /api/security/pin/login/forgot/verify-otp, and
/// GET  /api/security/pin/login/forgot/status, all of which return the same
/// shape of locked/cooldown/attempts fields.
class ForgotLoginPinOtpResult {
  final bool success;
  final String message;
  final bool locked;
  final int lockedRemainingSeconds;
  final int retryAfterSeconds;
  final int remainingAttempts;
  final int expiresInSeconds;
  final String? email;

  const ForgotLoginPinOtpResult({
    required this.success,
    required this.message,
    this.locked = false,
    this.lockedRemainingSeconds = 0,
    this.retryAfterSeconds = 0,
    this.remainingAttempts = 5,
    this.expiresInSeconds = 300,
    this.email,
  });

  factory ForgotLoginPinOtpResult.fromJson(
    Map<String, dynamic> json, {
    required bool success,
    required String message,
  }) {
    final data = json['data'] as Map<String, dynamic>? ?? {};
    return ForgotLoginPinOtpResult(
      success: success,
      message: message,
      locked: data['locked'] == true,
      lockedRemainingSeconds:
          (data['remaining_seconds'] as num?)?.toInt() ?? 0,
      retryAfterSeconds: (data['retry_after_seconds'] as num?)?.toInt() ?? 0,
      remainingAttempts: (data['remaining_attempts'] as num?)?.toInt() ?? 5,
      expiresInSeconds: (data['expires_in_seconds'] as num?)?.toInt() ?? 300,
      email: data['email']?.toString(),
    );
  }
}

class SecuritySettings {
  final bool biometricsEnabled;
  final bool twoFactorEnabled;

  const SecuritySettings({
    this.biometricsEnabled = false,
    this.twoFactorEnabled = false,
  });

  factory SecuritySettings.fromJson(Map<String, dynamic> json) {
    return SecuritySettings(
      biometricsEnabled: json['biometrics_enabled'] == true,
      twoFactorEnabled: json['two_factor_enabled'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'biometrics_enabled': biometricsEnabled,
        'two_factor_enabled': twoFactorEnabled,
      };
}