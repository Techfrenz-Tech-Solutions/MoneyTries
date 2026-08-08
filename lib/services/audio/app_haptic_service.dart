// lib/services/audio/app_haptic_service.dart
//
// Thin wrapper around Flutter's built-in HapticFeedback so every
// "success" cue in the app uses one consistent, subtle vibration
// pattern instead of each screen picking its own. No extra plugin/
// native code is required — HapticFeedback already ships with Flutter
// and, like sound, is automatically suppressed by the OS when the
// device has haptics/vibration turned off system-wide.
//
// Shares the same on/off toggle as AppSoundService so a single
// "Sound & haptics" switch in Settings controls both.
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppHapticService {
  AppHapticService._();
  static final AppHapticService instance = AppHapticService._();

  static const String _prefsKey = 'haptics_enabled';

  bool _enabled = true;
  bool get isEnabled => _enabled;

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _enabled = prefs.getBool(_prefsKey) ?? true;
    } catch (_) {
      _enabled = true;
    }
  }

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKey, value);
    } catch (_) {
      // Non-fatal — in-memory toggle still applies this session.
    }
  }

  /// Very light tick for ordinary button taps.
  void lightTap() {
    if (!_enabled) return;
    HapticFeedback.lightImpact();
  }

  /// Slightly stronger pulse for a completed action (deposit,
  /// withdrawal, KYC, plan, referral, login, transaction success).
  void success() {
    if (!_enabled) return;
    HapticFeedback.mediumImpact();
  }

  /// Soft double-pulse for non-alarming error/failure feedback.
  void error() {
    if (!_enabled) return;
    HapticFeedback.selectionClick();
  }
}