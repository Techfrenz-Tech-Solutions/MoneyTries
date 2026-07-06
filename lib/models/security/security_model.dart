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