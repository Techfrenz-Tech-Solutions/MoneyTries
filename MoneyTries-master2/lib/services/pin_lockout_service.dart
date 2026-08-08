// lib/services/pin_lockout_service.dart
//
// Shared brute-force protection for every PIN entry point in the app
// (app-lock/login PIN, withdrawal PIN, and any future PIN screens).
//
// Rule: 5 wrong attempts in a row locks that PIN scope for 5 minutes.
// The attempt count and lockout expiry are persisted in SharedPreferences
// (not just in-memory State), so a user can't bypass the cooldown by
// closing and reopening the app — the lock survives app restarts and is
// only lifted once the real wall-clock 5 minutes has elapsed.
//
// Each PIN screen uses its own `scope` string (e.g. 'login', 'withdrawal')
// so a lockout on one PIN never blocks the other.

import 'package:shared_preferences/shared_preferences.dart';

class PinLockoutService {
  PinLockoutService._();

  static const int maxAttempts = 5;
  static const Duration lockoutDuration = Duration(minutes: 5);

  static String _attemptsKey(String scope) => 'pin_lockout_attempts_$scope';
  static String _untilKey(String scope) => 'pin_lockout_until_$scope';

  /// Current failed-attempt count for [scope] (0 if none / after a reset).
  static Future<int> getAttempts(String scope) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_attemptsKey(scope)) ?? 0;
  }

  /// Returns the [DateTime] the lockout ends, or `null` if [scope] is not
  /// currently locked. Automatically clears an expired lockout it finds.
  static Future<DateTime?> getLockedUntil(String scope) async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(_untilKey(scope));
    if (ms == null) return null;

    final until = DateTime.fromMillisecondsSinceEpoch(ms);
    if (!DateTime.now().isBefore(until)) {
      // Lockout window has already passed — clear it so the caller sees
      // a fresh, unlocked state.
      await _clear(scope);
      return null;
    }
    return until;
  }

  /// Call once for every incorrect PIN entry. Increments the persisted
  /// attempt counter for [scope] and, once it reaches [maxAttempts],
  /// starts a [lockoutDuration] cooldown and returns the lockout end time.
  /// Returns `null` if the limit hasn't been reached yet.
  static Future<DateTime?> registerFailedAttempt(String scope) async {
    final prefs = await SharedPreferences.getInstance();
    final attempts = (prefs.getInt(_attemptsKey(scope)) ?? 0) + 1;
    await prefs.setInt(_attemptsKey(scope), attempts);

    if (attempts >= maxAttempts) {
      final until = DateTime.now().add(lockoutDuration);
      await prefs.setInt(_untilKey(scope), until.millisecondsSinceEpoch);
      return until;
    }
    return null;
  }

  /// Call once the correct PIN is entered — clears attempts and any lockout
  /// for [scope].
  static Future<void> reset(String scope) => _clear(scope);

  static Future<void> _clear(String scope) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_attemptsKey(scope));
    await prefs.remove(_untilKey(scope));
  }

  /// Attempts left before [scope] gets locked, given [attempts] already used.
  static int remainingAttempts(int attempts) =>
      (maxAttempts - attempts).clamp(0, maxAttempts);

  /// Formats a remaining duration as `m:ss` (e.g. "4:59", "0:07").
  static String formatCountdown(Duration d) {
    final total = d.inSeconds < 0 ? 0 : d.inSeconds;
    final minutes = total ~/ 60;
    final seconds = total % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}