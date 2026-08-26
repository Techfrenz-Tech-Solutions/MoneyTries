// ── Investment Plan Models ────────────────────────────────────────────────────

import '../../utils/date_time_utils.dart';

/// Adds [months] calendar months to [start], clamping the day to the last
/// valid day of the target month (e.g. 31 Jan + 1 month → 28/29 Feb).
/// This is the canonical maturity-date formula used on both client and server.
/// Start Date = Admin Approval Date (permanent, never changes).
/// Maturity Date = Start Date + plan duration in calendar months.
///   3 months  → +3 calendar months
///   6 months  → +6 calendar months
///   12 months → +12 calendar months
/// Example: 23 Jun 2026 + 3 months → 23 Sep 2026.
DateTime addCalendarMonths(DateTime start, int months) {
  final totalMonths = (start.month - 1) + months;
  final newYear = start.year + (totalMonths ~/ 12);
  final newMonth = (totalMonths % 12) + 1;
  final lastDayOfNewMonth = DateTime(newYear, newMonth + 1, 0).day;
  final newDay = start.day > lastDayOfNewMonth ? lastDayOfNewMonth : start.day;
  return DateTime(newYear, newMonth, newDay);
}

// ─────────────────────────────────────────────────────────────────────────────

enum PlanType { prePlan, threeMonth, sixMonth, twelveMonth }

extension PlanTypeExt on PlanType {
  /// Fixed-tenure plans are month-based; Pre Plan is day-based (user picks
  /// 3–80 days at enrollment), so this returns 0 for it. Use [durationDays]
  /// (and, for a real enrolled Pre Plan, [ActivePlan.totalPlanDays]) instead.
  int get months {
    switch (this) {
      case PlanType.prePlan:
        return 0;
      case PlanType.threeMonth:
        return 3;
      case PlanType.sixMonth:
        return 6;
      case PlanType.twelveMonth:
        return 12;
    }
  }

  // Daily ROI rates. Must always match the backend's ROI_RATES
  // (controllers/planController.js, historyController.js) and
  // PLAN_ROI_LABEL (controllers/dashboardController.js).
  double get dailyRoiPercent {
    switch (this) {
      case PlanType.prePlan:
        return 0.20;
      case PlanType.threeMonth:
        return 0.30;
      case PlanType.sixMonth:
        return 0.40;
      case PlanType.twelveMonth:
        return 0.50;
    }
  }

  String get displayName {
    switch (this) {
      case PlanType.prePlan:
        return 'Pre Plan';
      case PlanType.threeMonth:
        return '3 Month Plan';
      case PlanType.sixMonth:
        return '6 Month Plan';
      case PlanType.twelveMonth:
        return '12 Month Plan';
    }
  }

  String get rateLabel => '${dailyRoiPercent.toStringAsFixed(2)}%';

  /// Fixed plan duration in days: 3M=90, 6M=180, 12M=360.
  /// These are FIXED day counts, not calendar-month arithmetic — used for
  /// all "days left" / progress calculations so a 3-month plan is always
  /// exactly 90 days, regardless of which calendar months it spans.
  ///
  /// Pre Plan has NO fixed duration — the user chooses 3–80 days at
  /// enrollment time. This getter returns a fallback (used only if no
  /// instance-specific duration is available); the real, user-chosen value
  /// always flows separately through the comparison/enrollment args and
  /// [ActivePlan.customDurationDays] / [ActivePlan.totalPlanDays].
  int get durationDays {
    switch (this) {
      case PlanType.prePlan:
        return 30;
      case PlanType.threeMonth:
        return 90;
      case PlanType.sixMonth:
        return 180;
      case PlanType.twelveMonth:
        return 360;
    }
  }

  String get apiKey {
    switch (this) {
      case PlanType.prePlan:
        return 'pre_plan';
      case PlanType.threeMonth:
        return '3_month';
      case PlanType.sixMonth:
        return '6_month';
      case PlanType.twelveMonth:
        return '12_month';
    }
  }

  static PlanType fromMonths(int months) {
    switch (months) {
      case 3:
        return PlanType.threeMonth;
      case 6:
        return PlanType.sixMonth;
      case 12:
        return PlanType.twelveMonth;
      default:
        return PlanType.sixMonth;
    }
  }

  /// Robust reverse mapping from whatever the backend / route args send —
  /// handles the existing numeric-month values ('3','6','12', 3, 6, 12) as
  /// well as the forward-looking 'pre_plan' / 'pre' plan-type key so a real
  /// active Pre Plan (once the backend supports it) still resolves
  /// correctly instead of silently falling back to the 6-month plan.
  static PlanType fromApiValue(dynamic raw) {
    final s = raw?.toString().toLowerCase().trim() ?? '';
    if (s == 'pre_plan' || s == 'pre' || s == 'preplan') return PlanType.prePlan;
    final asInt = int.tryParse(s);
    if (asInt != null) return fromMonths(asInt);
    if (s.contains('3')) return PlanType.threeMonth;
    if (s.contains('12')) return PlanType.twelveMonth;
    if (s.contains('6')) return PlanType.sixMonth;
    return PlanType.sixMonth;
  }
}

// ── Plan Status ───────────────────────────────────────────────────────────────

enum PlanStatus { underReview, approved, active, completed, rejected }

extension PlanStatusExt on PlanStatus {
  static PlanStatus fromString(String s) {
    switch (s.toLowerCase()) {
      case 'under_review':
      case 'underreview':
      case 'pending':
        return PlanStatus.underReview;
      case 'approved':
        return PlanStatus.approved;
      case 'active':
        return PlanStatus.active;
      case 'completed':
        return PlanStatus.completed;
      case 'rejected':
        return PlanStatus.rejected;
      default:
        return PlanStatus.underReview;
    }
  }

  String get displayLabel {
    switch (this) {
      case PlanStatus.underReview:
        return 'Under Review';
      case PlanStatus.approved:
        return 'Approved';
      case PlanStatus.active:
        return 'Active';
      case PlanStatus.completed:
        return 'Completed';
      case PlanStatus.rejected:
        return 'Rejected';
    }
  }

  bool get isRunning =>
      this == PlanStatus.active || this == PlanStatus.approved;
}

// ── Instalment Row ────────────────────────────────────────────────────────────

class PlanInstalment {
  final int monthNumber;
  final int amount;
  final DateTime? paidAt;
  final bool isPaid;

  const PlanInstalment({
    required this.monthNumber,
    required this.amount,
    this.paidAt,
    required this.isPaid,
  });

  factory PlanInstalment.fromJson(Map<String, dynamic> json) {
    return PlanInstalment(
      monthNumber: int.tryParse(json['month']?.toString() ?? '0') ?? 0,
      amount: int.tryParse(json['amount']?.toString() ?? '0') ?? 0,
      paidAt: parseServerDateTime(json['paid_at']),
      isPaid:
          json['is_paid'] as bool? ??
          (json['status']?.toString().toLowerCase() == 'paid'),
    );
  }
}

// ── ROI Withdrawal Record ─────────────────────────────────────────────────────
// One "withdraw ROI to wallet" action taken by the user. Instant, no admin
// review — so it's always considered settled/approved once it exists.

class RoiWithdrawal {
  final String id;
  final double amount;
  final DateTime? createdAt;
  final bool isLegacy;

  const RoiWithdrawal({
    required this.id,
    required this.amount,
    this.createdAt,
    this.isLegacy = false,
  });

  factory RoiWithdrawal.fromJson(Map<String, dynamic> json) {
    return RoiWithdrawal(
      id: json['id']?.toString() ?? '',
      amount: double.tryParse(json['amount']?.toString() ?? '0') ?? 0.0,
      createdAt: parseServerDateTime(json['created_at']),
      isLegacy: json['is_legacy'] == true,
    );
  }
}

// ── Daily ROI Credit Transaction ──────────────────────────────────────────────
// One permanent transaction record per calendar day this plan's ROI was
// credited. Sourced from the server's roi_daily_credits table, which
// guarantees exactly one row per (plan, date) — so this list can never
// contain two entries for the same date, even after an offline catch-up
// backfills several missed days at once.

class DailyRoiCredit {
  final String id;
  final String planName;
  final double amount;
  final DateTime? creditDate;
  final DateTime? creditedAt;
  final String status; // always "Success"

  const DailyRoiCredit({
    required this.id,
    required this.planName,
    required this.amount,
    this.creditDate,
    this.creditedAt,
    this.status = 'Success',
  });

  factory DailyRoiCredit.fromJson(Map<String, dynamic> json) {
    return DailyRoiCredit(
      id: json['id']?.toString() ?? '',
      planName: json['plan_name']?.toString() ?? 'Investment Plan',
      amount: double.tryParse(json['amount']?.toString() ?? '0') ?? 0.0,
      creditDate: json['credit_date'] != null
          ? DateTime.tryParse(json['credit_date'].toString())
          : null,
      creditedAt: parseServerDateTime(json['credited_at']),
      status: json['status']?.toString() ?? 'Success',
    );
  }
}

// ── ROI Day Entry (for ROI history display) ───────────────────────────────────

class RoiDayEntry {
  final DateTime date;
  final double amount;
  final double principal; // principal on that day

  const RoiDayEntry({
    required this.date,
    required this.amount,
    required this.principal,
  });
}

// ── Active Plan ───────────────────────────────────────────────────────────────

class ActivePlan {
  final String id;
  final PlanType planType;
  final int monthlyAmount;
  final int monthsPaid;

  /// Plan Start Date = Admin Approval Date. PERMANENT — never changes.
  final DateTime startDate;

  /// Maturity Date = startDate + plan months (calendar months).
  /// Always computed client-side from startDate to ensure correctness.
  final DateTime maturityDate;

  final DateTime? lastPaymentDate;
  final double accruedRoi;
  final double withdrawnRoi;
  final PlanStatus status;
  final String? rejectionReason;
  final List<PlanInstalment> instalments;
  final List<RoiWithdrawal> roiWithdrawals;
  final List<DailyRoiCredit> dailyRoiCredits;

  /// One-time investment model: the invested principal is locked until
  /// maturity, then auto-credited to the wallet and the plan is marked
  /// completed (see maturePlanIfDue() on the server). Null until that
  /// happens — non-null exactly once the credit has actually occurred.
  final double? principalCreditedAmount;
  final DateTime? principalCreditedAt;

  /// One-time investment model: any ROI that accrued but was never manually
  /// withdrawn is auto-settled to the wallet alongside the principal at
  /// maturity (see maturePlanIfDue() on the server). Null until the plan
  /// matures, and null forever if the user had already withdrawn every
  /// last paisa of ROI before maturity — there was nothing left to settle.
  final double? roiSettledAmount;
  final DateTime? roiSettledAt;

  /// Only set (and only meaningful) for [PlanType.prePlan], where duration
  /// is chosen by the user (3–80 days) at enrollment rather than fixed by
  /// the plan type. Null for every other plan type — use [planType]'s own
  /// [PlanTypeExt.durationDays] for those.
  final int? customDurationDays;

  const ActivePlan({
    required this.id,
    required this.planType,
    required this.monthlyAmount,
    required this.monthsPaid,
    required this.startDate,
    required this.maturityDate,
    this.lastPaymentDate,
    required this.accruedRoi,
    required this.withdrawnRoi,
    required this.status,
    this.rejectionReason,
    this.instalments = const [],
    this.roiWithdrawals = const [],
    this.dailyRoiCredits = const [],
    this.principalCreditedAmount,
    this.principalCreditedAt,
    this.roiSettledAmount,
    this.roiSettledAt,
    this.customDurationDays,
  });

  /// True once the locked principal has actually been credited back to the
  /// wallet at maturity (the one-time investment model's terminal event).
  bool get isPrincipalCredited => principalCreditedAt != null;

  /// True once the remaining unpaid ROI has actually been settled to the
  /// wallet at maturity. Stays false forever if the user had already
  /// withdrawn all ROI before maturity (nothing was left to settle).
  bool get isRoiSettled => roiSettledAt != null;

  // ── Basic computed ─────────────────────────────────────────────────────────
  int get totalMonths => planType.months;
  double get dailyRoiRate => planType.dailyRoiPercent / 100;
  int get totalPrincipal => monthlyAmount * monthsPaid;
  // One-time investment model: the plan is funded by a single payment, so
  // the "total committed" amount IS the invested amount — never multiplied
  // by the plan's duration in months.
  int get totalCommitment => monthlyAmount;
  int get paidAmount => monthlyAmount * monthsPaid;
  // Nothing is ever "remaining" to pay — the one-time payment is submitted
  // in full at enrollment.
  int get remainingAmount => 0;
  double get pendingRoi =>
      (accruedRoi - withdrawnRoi).clamp(0.0, double.infinity);

  // ── Maturity / progress ────────────────────────────────────────────────────
  bool get isMatured =>
      status == PlanStatus.completed ||
      ((status == PlanStatus.active || status == PlanStatus.approved) &&
          DateTime.now().isAfter(maturityDate));

  /// "Days Left" shown across Plan Dashboard, Plan Details, and Investment
  /// Plans. Deliberately based on the plan's FIXED duration
  /// (90 / 180 / 360 days) counted from the actual stored start/approval
  /// date — NOT on [maturityDate]'s calendar-month arithmetic, and NOT an
  /// inclusive day count. Both [startDate] and "today" are stripped to
  /// midnight first so the time-of-day never shifts the result.
  ///
  /// Example: 3-month plan (90 days), approved 14 Aug 2026.
  ///   14 Aug 2026 (day 0, elapsed = 0)  → 90 - 0  = 90 days left
  ///   15 Aug 2026 (day 1, elapsed = 1)  → 90 - 1  = 89 days left
  int get daysUntilMaturity {
    if (status == PlanStatus.completed) return 0;
    final remaining = totalPlanDays - daysElapsed;
    return remaining < 0 ? 0 : remaining;
  }

  /// Total fixed plan days: 3M = 90 days, 6M = 180 days, 12M = 360 days.
  /// Fixed day counts, never derived from calendar-month differences.
  /// For Pre Plan, uses the user-chosen [customDurationDays] instead, since
  /// that plan type has no fixed duration.
  int get totalPlanDays => customDurationDays ?? planType.durationDays;

  /// Days elapsed since the stored start date, NOT inclusive of "today".
  /// Both dates are stripped to midnight (time component removed) before
  /// diffing, so this is a pure calendar-day count — never an inclusive
  /// count and never calendar-month arithmetic.
  int get daysElapsed {
    final startOnly = DateTime(startDate.year, startDate.month, startDate.day);
    final now = DateTime.now();
    final todayOnly = DateTime(now.year, now.month, now.day);
    final d = todayOnly.difference(startOnly).inDays;
    return d.clamp(0, totalPlanDays);
  }

  /// Days elapsed including the start day (Day 0 = approval day = Day 1).
  /// 23 Jun → 30 Jun = 8 days (23,24,25,26,27,28,29,30).
  /// Both dates stripped to midnight so time-of-day doesn't affect count.
  int get daysElapsedInclusive {
    if (status == PlanStatus.underReview || status == PlanStatus.rejected) {
      return 0;
    }
    final startOnly = DateTime(startDate.year, startDate.month, startDate.day);
    final now = DateTime.now();
    final todayOnly = DateTime(now.year, now.month, now.day);
    final d = todayOnly.difference(startOnly).inDays + 1;
    return d.clamp(0, totalPlanDays);
  }

  double get progressPercent {
    if (monthsPaid == 0) return 0.0;
    if (totalPlanDays <= 0) return 0.0;
    return (daysElapsedInclusive / totalPlanDays).clamp(0.0, 1.0);
  }

  // ── Tiered ROI calculation ──────────────────────────────────────────────────
  // ROI must be calculated only on the invested amount actually paid-in as of
  // a given day — never on the plan's current (latest) total applied
  // retroactively across days before it was reached. Every successful
  // instalment raises the invested amount from the day it was paid onward;
  // a delayed or skipped instalment simply leaves the invested amount (and
  // therefore the daily ROI) flat until the next one is actually paid.
  // Mirrors accrueRoiForPlan() on the backend exactly, so both sides agree.
  List<({DateTime from, int amount})> get _investedAmountTiers {
    final paid = instalments.where((i) => i.isPaid && i.paidAt != null).toList()
      ..sort((a, b) => a.monthNumber.compareTo(b.monthNumber));
    if (paid.isEmpty) return const [];

    DateTime midnight(DateTime d) => DateTime(d.year, d.month, d.day);
    final storedStart = midnight(startDate);
    final earliestPaid = midnight(paid.first.paidAt!);
    final effectiveStart = earliestPaid.isBefore(storedStart)
        ? earliestPaid
        : storedStart;

    final tiers = <({DateTime from, int amount})>[
      (from: effectiveStart, amount: monthlyAmount * 1),
    ];
    for (int i = 1; i < paid.length; i++) {
      tiers.add((
        from: midnight(paid[i].paidAt!),
        amount: monthlyAmount * (i + 1),
      ));
    }
    return tiers;
  }

  /// Correctly tiered expected accrued ROI — each paid instalment only earns
  /// ROI from the day it was paid onward, not retroactively applied to days
  /// before it was paid. This is the authoritative accrued-ROI figure for
  /// display (replaces the old flat `dailyRoiAmount × daysElapsedInclusive`
  /// formula, which incorrectly applied the plan's latest invested amount to
  /// every day since the plan started).
  double get tieredExpectedAccruedRoi {
    if (status == PlanStatus.underReview || status == PlanStatus.rejected) {
      return 0.0;
    }
    final tiers = _investedAmountTiers;
    if (tiers.isEmpty) return 0.0;

    final now = DateTime.now();
    final rawToday = DateTime(now.year, now.month, now.day);
    // Never earn ROI on/after maturity_date itself — that day is settlement
    // (principal + remaining ROI credited to wallet by the backend), not an
    // earning day. Mirrors accrueRoiForPlan()'s lastEarningDayUtc cap on the
    // server so this client-side estimate never overstates ROI for an
    // already-matured (or matured-today) plan.
    final maturityOnly =
        DateTime(maturityDate.year, maturityDate.month, maturityDate.day);
    final lastEarningDay = maturityOnly.subtract(const Duration(days: 1));
    final today = rawToday.isAfter(lastEarningDay) ? lastEarningDay : rawToday;
    if (today.isBefore(tiers.first.from)) return 0.0;

    double total = 0;
    for (int i = 0; i < tiers.length; i++) {
      final segStart = tiers[i].from;
      final segEndExclusive = i + 1 < tiers.length ? tiers[i + 1].from : null;
      final segEndInclusive = segEndExclusive != null
          ? segEndExclusive.subtract(const Duration(days: 1))
          : today;
      if (segEndInclusive.isBefore(segStart)) continue;
      final days = segEndInclusive.difference(segStart).inDays + 1;
      if (days <= 0) continue;
      total += tiers[i].amount * dailyRoiRate * days;
    }
    return total;
  }

  // ── ROI calculation (client-side, for display verification) ───────────────
  /// Deprecated: use [tieredExpectedAccruedRoi] instead. This old formula
  /// applied the plan's CURRENT (latest) invested amount across every day
  /// since start, which overstates ROI for periods before later instalments
  /// were paid. Kept only so any lingering reference doesn't break; it now
  /// simply delegates to the correct tiered calculation.
  double get expectedAccruedRoi => tieredExpectedAccruedRoi;

  /// Daily ROI amount = monthlyAmount × monthsPaid × dailyRoiRate
  /// ROI starts on approval day (Day 0 = startDate inclusive).
  double get dailyRoiAmount {
    if (monthsPaid == 0) return 0;
    return monthlyAmount * monthsPaid * dailyRoiRate;
  }

  // ── Payment window ─────────────────────────────────────────────────────────
  // One-time investment model: the plan is funded by a single payment
  // submitted at enrollment — there is no recurring monthly payment to make,
  // so these always resolve to "nothing pending".
  bool get canPayThisMonth => false;

  int get daysUntilNextPayment => 0;

  bool get hasUpcomingPayment => false;

  // ── Instalment table ───────────────────────────────────────────────────────
  // One-time investment model: there is exactly one payment (the invested
  // amount, submitted at enrollment) — surface whatever the server returned
  // for it rather than generating a row per calendar month.
  List<PlanInstalment> get instalmentTable => instalments;

  // ── ROI history (client-computed, for display) ────────────────────────────
  /// Daily ROI entries from startDate (inclusive) to today.
  /// Day 0 = approval date = first ROI credit (bonus on same day).
  /// Each day's principal is whatever was actually invested (paid-in) as of
  /// that day — tiered by paid instalments, never the plan's current total
  /// applied retroactively to earlier days.
  List<RoiDayEntry> get roiHistory {
    if (status == PlanStatus.underReview ||
        status == PlanStatus.rejected ||
        monthsPaid == 0) {
      return [];
    }
    final tiers = _investedAmountTiers;
    if (tiers.isEmpty) return [];

    final List<RoiDayEntry> entries = [];
    final now = DateTime.now();
    final todayOnly = DateTime(now.year, now.month, now.day);
    final maturityOnly = DateTime(
      maturityDate.year,
      maturityDate.month,
      maturityDate.day,
    );
    final startOnly = tiers.first.from;

    int tierIdx = 0;
    for (int day = 0; ; day++) {
      final dateOnly = startOnly.add(Duration(days: day));
      if (dateOnly.isAfter(todayOnly)) break;
      // Stop BEFORE the maturity date itself — it's a settlement day
      // (principal + remaining ROI credited by the backend), never an
      // earning day. Previously this only broke when the date was AFTER
      // maturity, which included the maturity date as one extra ROI day —
      // the same off-by-one this whole fix addresses on the backend.
      if (!dateOnly.isBefore(maturityOnly)) break;

      while (tierIdx + 1 < tiers.length &&
          !dateOnly.isBefore(tiers[tierIdx + 1].from)) {
        tierIdx++;
      }
      final principal = tiers[tierIdx].amount.toDouble();
      final roi = principal * dailyRoiRate;
      entries.add(
        RoiDayEntry(date: dateOnly, amount: roi, principal: principal),
      );
    }
    return entries;
  }

  // ── fromJson ───────────────────────────────────────────────────────────────
  factory ActivePlan.fromJson(Map<String, dynamic> json) {
    final rawInstalments = json['instalments'] as List<dynamic>? ?? [];
    // Prefer the raw plan_type string (handles the forward-looking
    // 'pre_plan' key once the backend supports it); falls back to the
    // existing numeric-month resolution for 3/6/12 month plans.
    final planType = json['plan_type'] != null
        ? PlanTypeExt.fromApiValue(json['plan_type'])
        : PlanTypeExt.fromMonths(json['months'] as int? ?? 6);
    final customDurationDays = planType == PlanType.prePlan
        ? (int.tryParse(
                (json['duration_days'] ?? json['plan_duration_days'])
                        ?.toString() ??
                    '',
              ) ??
              int.tryParse(json['months']?.toString() ?? ''))
        : null;

    // Parse instalments first so we can use them to determine the true start date
    final parsedInstalments = rawInstalments
        .map((e) => PlanInstalment.fromJson(e as Map<String, dynamic>))
        .toList();

    // Start Date = Admin Approval Date (permanent).
    // Priority:
    //   1. Server's start_date field (most reliable when backend stores it correctly)
    //   2. Earliest instalment paid_at date (first payment = approval date)
    //   3. last_payment_date as last resort
    DateTime? serverStartDate = json['start_date'] != null
        ? DateTime.tryParse(json['start_date'].toString())
        : null;

    // Find earliest paid instalment date
    DateTime? earliestPaidAt;
    for (final ins in parsedInstalments) {
      if (ins.isPaid && ins.paidAt != null) {
        if (earliestPaidAt == null || ins.paidAt!.isBefore(earliestPaidAt)) {
          earliestPaidAt = ins.paidAt;
        }
      }
    }

    // Also check last_payment_date
    final lastPaymentDate = json['last_payment_date'] != null
        ? DateTime.tryParse(json['last_payment_date'].toString())
        : null;

    // Use the earliest known date as start date
    // If server start_date is today or later than earliest paid, prefer earliest paid
    DateTime startDate;
    if (serverStartDate != null && earliestPaidAt != null) {
      // Use whichever is earlier — the approval happened before or on first payment
      startDate = serverStartDate.isBefore(earliestPaidAt)
          ? serverStartDate
          : earliestPaidAt;
    } else if (earliestPaidAt != null) {
      startDate = earliestPaidAt;
    } else if (serverStartDate != null) {
      startDate = serverStartDate;
    } else if (lastPaymentDate != null) {
      startDate = lastPaymentDate;
    } else {
      startDate = DateTime.now();
    }

    // The server is authoritative because it uses calendar-month arithmetic
    // (for example, 31 January + 3 months = 30 April). Fall back to the same
    // calendar-month rule only for legacy responses without maturity_date.
    final maturityDate =
        parseServerDateTime(json['maturity_date']) ??
        (planType == PlanType.prePlan
            ? startDate.add(
                Duration(days: customDurationDays ?? planType.durationDays),
              )
            : addCalendarMonths(startDate, planType.months));

    return ActivePlan(
      id: json['id']?.toString() ?? '',
      planType: planType,
      customDurationDays: customDurationDays,
      monthlyAmount:
          int.tryParse(json['monthly_amount']?.toString() ?? '0') ?? 0,
      monthsPaid: int.tryParse(json['months_paid']?.toString() ?? '0') ?? 0,
      startDate: startDate,
      maturityDate: maturityDate,
      lastPaymentDate: lastPaymentDate,
      accruedRoi:
          double.tryParse(json['accrued_roi']?.toString() ?? '0') ?? 0.0,
      withdrawnRoi:
          double.tryParse(json['withdrawn_roi']?.toString() ?? '0') ?? 0.0,
      status: PlanStatusExt.fromString(
        json['status']?.toString() ?? 'under_review',
      ),
      rejectionReason: json['rejection_reason']?.toString(),
      instalments: parsedInstalments,
      roiWithdrawals: (json['roi_withdrawals'] as List<dynamic>? ?? [])
          .map((e) => RoiWithdrawal.fromJson(e as Map<String, dynamic>))
          .toList(),
      dailyRoiCredits: (json['daily_roi_credits'] as List<dynamic>? ?? [])
          .map((e) => DailyRoiCredit.fromJson(e as Map<String, dynamic>))
          .toList(),
      principalCreditedAmount: json['principal_credited_amount'] != null
          ? double.tryParse(json['principal_credited_amount'].toString())
          : null,
      principalCreditedAt: json['principal_credited_at'] != null
          ? DateTime.tryParse(json['principal_credited_at'].toString())
          : null,
      roiSettledAmount: json['roi_settled_amount'] != null
          ? double.tryParse(json['roi_settled_amount'].toString())
          : null,
      roiSettledAt: json['roi_settled_at'] != null
          ? DateTime.tryParse(json['roi_settled_at'].toString())
          : null,
    );
  }

  /// Creates a copy with updated fields
  ActivePlan copyWith({
    String? id,
    PlanType? planType,
    int? monthlyAmount,
    int? monthsPaid,
    DateTime? startDate,
    DateTime? maturityDate,
    DateTime? lastPaymentDate,
    double? accruedRoi,
    double? withdrawnRoi,
    PlanStatus? status,
    String? rejectionReason,
    List<PlanInstalment>? instalments,
    List<RoiWithdrawal>? roiWithdrawals,
    List<DailyRoiCredit>? dailyRoiCredits,
    double? principalCreditedAmount,
    DateTime? principalCreditedAt,
    double? roiSettledAmount,
    DateTime? roiSettledAt,
    int? customDurationDays,
  }) {
    final newStart = startDate ?? this.startDate;
    final newPlanType = planType ?? this.planType;
    final newCustomDurationDays = customDurationDays ?? this.customDurationDays;
    return ActivePlan(
      id: id ?? this.id,
      planType: newPlanType,
      monthlyAmount: monthlyAmount ?? this.monthlyAmount,
      monthsPaid: monthsPaid ?? this.monthsPaid,
      startDate: newStart,
      maturityDate: maturityDate ??
          (newPlanType == PlanType.prePlan
              ? newStart.add(
                  Duration(
                    days: newCustomDurationDays ?? newPlanType.durationDays,
                  ),
                )
              : addCalendarMonths(newStart, newPlanType.months)),
      lastPaymentDate: lastPaymentDate ?? this.lastPaymentDate,
      accruedRoi: accruedRoi ?? this.accruedRoi,
      withdrawnRoi: withdrawnRoi ?? this.withdrawnRoi,
      status: status ?? this.status,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      instalments: instalments ?? this.instalments,
      roiWithdrawals: roiWithdrawals ?? this.roiWithdrawals,
      dailyRoiCredits: dailyRoiCredits ?? this.dailyRoiCredits,
      principalCreditedAmount:
          principalCreditedAmount ?? this.principalCreditedAmount,
      principalCreditedAt: principalCreditedAt ?? this.principalCreditedAt,
      roiSettledAmount: roiSettledAmount ?? this.roiSettledAmount,
      roiSettledAt: roiSettledAt ?? this.roiSettledAt,
      customDurationDays: newCustomDurationDays,
    );
  }
}

// ── API Response Wrappers ─────────────────────────────────────────────────────

class RoiWithdrawalResponse {
  final bool success;
  final String message;
  final double amount;

  const RoiWithdrawalResponse({
    required this.success,
    required this.message,
    required this.amount,
  });

  factory RoiWithdrawalResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json;
    return RoiWithdrawalResponse(
      success:
          json['success'] == true ||
          (json['status']?.toString().toLowerCase() == 'success'),
      message: json['message']?.toString() ?? 'Withdrawal initiated',
      amount: double.tryParse(data['amount']?.toString() ?? '0') ?? 0.0,
    );
  }
}

class PrincipalWithdrawalResponse {
  final bool success;
  final String message;
  final int amount;

  const PrincipalWithdrawalResponse({
    required this.success,
    required this.message,
    required this.amount,
  });

  factory PrincipalWithdrawalResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json;
    return PrincipalWithdrawalResponse(
      success:
          json['success'] == true ||
          (json['status']?.toString().toLowerCase() == 'success'),
      message: json['message']?.toString() ?? 'Principal withdrawal initiated',
      amount: int.tryParse(data['amount']?.toString() ?? '0') ?? 0,
    );
  }
}