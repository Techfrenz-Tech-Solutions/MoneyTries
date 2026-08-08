// lib/utils/date_time_utils.dart
//
// ── Single source of truth for server-timestamp handling ─────────────────────
//
// ROOT CAUSE OF THE "wrong date/time" BUG:
//
// The backend now always stores and emits `created_at` / `reviewed_at` /
// `paid_at` / `credited_at` timestamps as real, unambiguous UTC instants
// (see config/db.js — the MySQL session timezone is pinned to +00:00 so it
// can never again drift from what the Node driver assumes). A well-formed
// value therefore comes back from the API as e.g.
// "2026-07-07T10:15:00.000Z" — and `DateTime.parse` already recognises the
// trailing "Z" and correctly marks the result as UTC.
//
// However, several screens in this app were previously parsing that value
// with a bare `DateTime.tryParse(...)` and then either:
//   1. hard-coding a "+5:30 IST" shift on top of it (notifications_view.dart), or
//   2. deliberately *not* calling `.toLocal()` because someone observed the
//      time was already "off" and assumed `.toLocal()` was double-applying
//      an offset (home_screen.dart, referral_model.dart) — when the real
//      problem was the backend/DB timezone mismatch, not `.toLocal()`.
//
// Both are wrong: (1) breaks for any user outside IST, and (2) means a
// correctly-tagged UTC instant is displayed as if it were already local,
// which is off by the device's UTC offset in the other direction.
//
// The fix: parse every server timestamp through [parseServerDateTime] below
// (which also safely re-tags any legacy/naive "no timezone marker" string as
// UTC instead of local), then always call `.toLocal()` — never a
// hard-coded offset — when displaying it. `.toLocal()` is a safe no-op on
// values that are already local (e.g. plain calendar-only DATE fields like
// `credit_date` / `start_date` / `last_payment_date`, which intentionally
// are NOT run through [parseServerDateTime] since they represent a calendar
// day rather than a moment in time, and must never be shifted across a day
// boundary by a timezone conversion).

import 'package:intl/intl.dart';

/// Parses a server-supplied timestamp value (String, DateTime, or anything
/// with a sane `toString()`) into a correctly UTC-tagged [DateTime].
///
/// Use this for genuine "moment in time" fields — `created_at`,
/// `reviewed_at`, `paid_at`, `credited_at`, `registered_at`, notification
/// timestamps, etc. Do NOT use this for pure calendar-date fields (e.g. a
/// `credit_date` or `start_date` that only ever means "this calendar day"),
/// since re-tagging those as UTC and later converting `.toLocal()` can shift
/// them into the previous or next day depending on the device's offset.
DateTime? parseServerDateTime(dynamic raw) {
  if (raw == null) return null;

  if (raw is DateTime) {
    return raw.isUtc ? raw : raw.toUtc();
  }

  final str = raw.toString().trim();
  if (str.isEmpty) return null;

  final parsed = DateTime.tryParse(str);
  if (parsed == null) return null;

  if (parsed.isUtc) return parsed;

  // No 'Z' / offset was present in the string. The value is still a UTC
  // wall-clock reading from the server — re-tag it as UTC instead of
  // silently treating it as if it were already expressed in the device's
  // local timezone (which is what caused the multi-hour drift bugs).
  return DateTime.utc(
    parsed.year,
    parsed.month,
    parsed.day,
    parsed.hour,
    parsed.minute,
    parsed.second,
    parsed.millisecond,
    parsed.microsecond,
  );
}

/// Converts [dt] to the device's real local timezone. Safe to call on any
/// [DateTime] — if it's already local (e.g. a pure calendar-date field),
/// this is a no-op.
DateTime toDeviceLocal(DateTime dt) => dt.isUtc ? dt.toLocal() : dt;

/// Device-local midnight for [dt] — used for "Today" / "Yesterday" /
/// day-grouping comparisons so they're always based on the device's actual
/// calendar day, not the server's.
DateTime localDateOnly(DateTime dt) {
  final local = toDeviceLocal(dt);
  return DateTime(local.year, local.month, local.day);
}

/// Formats [dt] (a UTC instant from [parseServerDateTime], or already-local)
/// in the device's local timezone using an [intl] `pattern`. Returns '' for
/// null input.
String formatLocal(DateTime? dt, String pattern) {
  if (dt == null) return '';
  return DateFormat(pattern).format(toDeviceLocal(dt));
}