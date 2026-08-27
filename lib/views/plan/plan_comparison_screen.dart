import 'package:flutter/material.dart';
import 'package:moneytries/config/app_fonts.dart';
import 'package:flutter/services.dart';
import '../../models/plan/plan_models.dart';
import '../../routes/app_routes.dart';
import '../../utils/responsive.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _bgColor = Color(0xFFF7F5F2);
const _subtitleGrey = Color(0xFF6B7280);
const _titleDark = Color(0xFF111827);
const _brandGreen = Color(0xFF1F6B45); // banner dark green
const _cardBg = Color(0xFFFFFFFF);

/// One row of computed comparison data for a single plan, derived entirely
/// from the monthly amount the user entered on the previous screen.
class _PlanComparison {
  final PlanType planType;
  final int monthlyAmount;
  final int totalInvestment;
  final double dailyRoiAmount;
  final double estimatedTotalRoi;
  final double estimatedTotalReturn;
  /// Resolved duration in days for this comparison — the fixed 90/180/360
  /// for 3/6/12 month plans, or the currently selected value (from the
  /// Pre Plan card's +/- day selector, minimum 1) for Pre Plan.
  final int durationDays;

  const _PlanComparison({
    required this.planType,
    required this.monthlyAmount,
    required this.totalInvestment,
    required this.dailyRoiAmount,
    required this.estimatedTotalRoi,
    required this.estimatedTotalReturn,
    required this.durationDays,
  });
}

/// Step 2 of the redesigned Investment Plan flow:
///   Enter Investment Amount → Show Plan Comparison → Select Plan → T&C →
///   Submit Request → Admin Approval → First Payment → Active Plan.
///
/// Renders the plan tiers (Pre Plan / 3M / 6M / 12M) side-by-side as
/// comparison cards, with every figure computed dynamically from the amount
/// entered on the previous screen, so the user can compare potential profit
/// before picking a plan. Selecting a plan continues into the existing,
/// unchanged flow (Terms & Conditions → Configure/Submit → Admin Approval →
/// Active Plan).
///
/// Pre Plan's card additionally carries a +/- day selector (defaults to 7
/// days, decreasable to a minimum of 1 day, capped at a maximum of 100
/// days) — the only plan whose duration isn't fixed. Changing it
/// live-recalculates that card's Daily ROI Amount, Estimated Total ROI,
/// Estimated Total Return, and Total Days; the 3/6/12 month cards are
/// unaffected and stay fixed at 90/180/360 days.
///
/// Optionally receives `excludeTypes` (a `List<String>` of `PlanType.name`
/// values) via route arguments — plan types the user already holds are
/// never shown here again, so only the plans still available to them are
/// compared. When omitted, all 4 plans are compared as before.
class PlanComparisonScreen extends StatefulWidget {
  const PlanComparisonScreen({super.key});

  @override
  State<PlanComparisonScreen> createState() => _PlanComparisonScreenState();
}

class _PlanComparisonScreenState extends State<PlanComparisonScreen> {
  /// Pre Plan's currently selected duration, controlled by the +/- selector
  /// on its card. Defaults to 7 days; the user can decrease it down to the
  /// minimum of 1, or increase it up to the maximum of 100.
  int _prePlanDays = 7;

  static const _prePlanMinDays = 1;
  static const _prePlanMaxDays = 100;

  void _incrementPrePlanDays() {
    if (_prePlanDays >= _prePlanMaxDays) return;
    setState(() => _prePlanDays++);
  }

  void _decrementPrePlanDays() {
    if (_prePlanDays <= _prePlanMinDays) return;
    setState(() => _prePlanDays--);
  }

  /// Estimated total ROI over the life of the plan.
  ///
  /// One-time investment model: the full `investedAmount` is paid in once at
  /// the start of the plan and earns ROI every day for the entire fixed
  /// duration — there is no staggered/partial funding to account for.
  ///
  ///   ROI = investedAmount × dailyRoiRate × totalDays
  static double _estimatedTotalRoi({
    required int investedAmount,
    required double dailyRoiRate,
    required int totalDays,
  }) {
    return investedAmount * dailyRoiRate * totalDays;
  }

  _PlanComparison _computeFor(PlanType type, int amount) {
    final dailyRoiRate = type.dailyRoiPercent / 100;
    // Pre Plan's duration comes from the day selector's current state;
    // every other plan type has a fixed duration (3/6/12 month tiers =
    // 90/180/360 days).
    final totalDays = type == PlanType.prePlan
        ? _prePlanDays
        : type.durationDays;
    // One-time investment: the total invested amount IS the amount entered
    // — never multiplied by the plan's duration in months.
    final totalInvestment = amount;
    // Rupee amount credited per day — the flat rate applied once to the
    // full one-time investment, shown alongside the percentage so the
    // user can compare plans by actual daily payout, not just rate.
    final dailyRoiAmount = amount * dailyRoiRate;
    final estimatedTotalRoi = _estimatedTotalRoi(
      investedAmount: amount,
      dailyRoiRate: dailyRoiRate,
      totalDays: totalDays,
    );
    return _PlanComparison(
      planType: type,
      monthlyAmount: amount,
      totalInvestment: totalInvestment,
      dailyRoiAmount: dailyRoiAmount,
      estimatedTotalRoi: estimatedTotalRoi,
      estimatedTotalReturn: totalInvestment + estimatedTotalRoi,
      durationDays: totalDays,
    );
  }

  String _inr(num n) {
    final rounded = n.round();
    if (rounded <= 0) return '0';
    final s = rounded.toString();
    if (s.length <= 3) return s;
    final last3 = s.substring(s.length - 3);
    final rest = s.substring(0, s.length - 3);
    final buf = StringBuffer();
    for (int i = 0; i < rest.length; i++) {
      if (i > 0 && (rest.length - i) % 2 == 0) buf.write(',');
      buf.write(rest[i]);
    }
    return '${buf.toString()},$last3';
  }

  /// Same comma-grouping as [_inr] but keeps 2 decimal places — used for the
  /// daily ROI amount, which is often a small sum where rounding to whole
  /// rupees would hide the difference between plans.
  String _inrDecimal(num n) {
    final fixed = n.toStringAsFixed(2);
    final parts = fixed.split('.');
    final wholePart = int.tryParse(parts[0]) ?? 0;
    return '${_inr(wholePart)}.${parts[1]}';
  }

  void _selectPlan(BuildContext context, _PlanComparison c) {
    HapticFeedback.lightImpact();
    Navigator.pushNamed(
      context,
      AppRoutes.terms,
      arguments: {
        'title': c.planType.displayName,
        'rate': c.planType.rateLabel,
        'months': c.planType.months,
        'amount': c.monthlyAmount,
        // Carried through unchanged by the Terms screen; used by Configure
        // to resolve the exact plan type (robust for Pre Plan, which has
        // no month count).
        'planType': c.planType.name,
        // The Pre Plan duration currently selected via this card's +/- day
        // selector, so it's used consistently through Terms → Configure →
        // enrollment. Omitted for every other plan type, whose duration is
        // fixed by planType.
        if (c.planType == PlanType.prePlan) 'days': c.durationDays,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final args =
        (ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?) ??
        {};
    final amount = (args['amount'] as int?) ?? 0;
    final rawExclude = args['excludeTypes'];
    final excludeNames = rawExclude is List
        ? rawExclude.map((e) => e.toString()).toSet()
        : const <String>{};

    final availableTypes = PlanType.values
        .where((t) => !excludeNames.contains(t.name))
        .toList();

    final comparisons = availableTypes
        .map((t) => _computeFor(t, amount))
        .toList();

    // Prefer the mid-tier (6M) as "recommended" when it's available; fall
    // back to 12M, then whatever single plan remains. With only one plan
    // left to compare there's no real choice to make, so no badge is shown.
    PlanType? recommendedType;
    if (comparisons.length > 1) {
      if (availableTypes.contains(PlanType.sixMonth)) {
        recommendedType = PlanType.sixMonth;
      } else if (availableTypes.contains(PlanType.twelveMonth)) {
        recommendedType = PlanType.twelveMonth;
      } else {
        recommendedType = availableTypes.first;
      }
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _bgColor,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(8.w, 4.h, 20.w, 0.h),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: _titleDark),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Text(
                      'Moneytries',
                      style: TextStyle(
                        fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                        fontSize: 17.sp,
                        fontWeight: FontWeight.w700,
                        color: _titleDark,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 12.h),
                      _buildHeader(amount, comparisons.length),
                      SizedBox(height: 24.h),
                      if (comparisons.isEmpty)
                        _noPlansLeftNotice()
                      else
                        for (int i = 0; i < comparisons.length; i++) ...[
                          _comparisonCard(
                            context,
                            comparisons[i],
                            comparisons[i].planType == recommendedType,
                          ),
                          if (i != comparisons.length - 1)
                            SizedBox(height: 16.h),
                        ],
                      SizedBox(height: 28.h),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(int amount, int planCount) {
    final subtitle = planCount == 0
        ? 'You\'ve already enrolled in every available plan.'
        : planCount == 1
        ? 'Based on an investment of ₹ ${_inr(amount)}, here\'s your remaining plan option.'
        : 'Based on an investment of ₹ ${_inr(amount)}, here\'s how each plan performs.';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 5.h),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5EE),
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(
              color: _brandGreen.withValues(alpha: 0.25),
              width: 1.r,
            ),
          ),
          child: Text(
            'Step 2 of 3 · Compare Plans',
            style: TextStyle(
              fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
              fontSize: 11.sp,
              fontWeight: FontWeight.w700,
              color: _brandGreen,
              letterSpacing: 0.4,
            ),
          ),
        ),
        SizedBox(height: 14.h),
        Text(
          'Compare your returns',
          style: TextStyle(
            fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
            fontSize: 26.sp,
            fontWeight: FontWeight.w800,
            color: _titleDark,
            height: 1.2,
            letterSpacing: -0.4,
          ),
        ),
        SizedBox(height: 8.h),
        Text(
          subtitle,
          style: TextStyle(
            fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
            fontSize: 14.sp,
            fontWeight: FontWeight.w400,
            color: _subtitleGrey,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _noPlansLeftNotice() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FAF4),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: _brandGreen.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.verified_rounded, size: 18.sp, color: _brandGreen),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              'There are no more plan types left to enroll in.',
              style: TextStyle(
                fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                fontSize: 12.5.sp,
                fontWeight: FontWeight.w600,
                color: _brandGreen,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _comparisonCard(
    BuildContext context,
    _PlanComparison c,
    bool isRecommended,
  ) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(22.r),
        border: isRecommended
            ? Border.all(color: _brandGreen, width: 1.5.r)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          if (isRecommended)
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 5.h),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFDCF3E5), Color(0xFF9AE0BC)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      size: 11.sp,
                      color: _brandGreen,
                    ),
                    SizedBox(width: 4.w),
                    Text(
                      'RECOMMENDED',
                      style: TextStyle(
                        fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                        fontSize: 9.5.sp,
                        fontWeight: FontWeight.w700,
                        color: _brandGreen,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(20.w, 22.h, 20.w, 20.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.planType.displayName,
                  style: TextStyle(
                    fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                    fontSize: 19.sp,
                    fontWeight: FontWeight.w800,
                    color: _brandGreen,
                    letterSpacing: -0.2,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  '${c.durationDays} days total',
                  style: TextStyle(
                    fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                    fontSize: 12.5.sp,
                    fontWeight: FontWeight.w400,
                    color: _subtitleGrey,
                  ),
                ),
                SizedBox(height: 16.h),
                _statGrid(c),
                if (c.planType == PlanType.prePlan) ...[
                  SizedBox(height: 16.h),
                  _prePlanDaySelector(),
                ],
                SizedBox(height: 18.h),
                SizedBox(
                  width: double.infinity,
                  height: 50.h,
                  child: isRecommended
                      ? DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFDCF3E5), Color(0xFF9AE0BC)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(14.r),
                          ),
                          child: ElevatedButton(
                            onPressed: () => _selectPlan(context, c),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14.r),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              'Select Plan',
                              style: TextStyle(
                                fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                                fontSize: 15.sp,
                                fontWeight: FontWeight.w700,
                                color: _brandGreen,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        )
                      : OutlinedButton(
                          onPressed: () => _selectPlan(context, c),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _brandGreen,
                            side: BorderSide(color: _brandGreen, width: 1.5.r),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14.r),
                            ),
                          ),
                          child: Text(
                            'Select Plan',
                            style: TextStyle(
                              fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w700,
                              color: _brandGreen,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Pre Plan's premium duration selector — a self-contained gradient
  /// "dial" card with comfortable +/- controls flanking a prominent day
  /// readout. Bounded to [_prePlanMinDays]–[_prePlanMaxDays]; the − button
  /// dims and disables at the floor, the + button dims and disables at the
  /// ceiling.
  Widget _prePlanDaySelector() {
    final atMin = _prePlanDays <= _prePlanMinDays;
    final atMax = _prePlanDays >= _prePlanMaxDays;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(14.w, 10.h, 14.w, 10.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _brandGreen.withValues(alpha: 0.06),
            _brandGreen.withValues(alpha: 0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: _brandGreen.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SELECT DURATION',
            style: TextStyle(
              fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
              fontSize: 9.sp,
              fontWeight: FontWeight.w700,
              color: _brandGreen.withValues(alpha: 0.75),
              letterSpacing: 1.0,
            ),
          ),
          SizedBox(height: 6.h),
          Row(
            children: [
              _PrePlanDayStepButton(
                icon: Icons.remove_rounded,
                enabled: !atMin,
                onTap: _decrementPrePlanDays,
              ),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      transitionBuilder: (child, animation) =>
                          ScaleTransition(scale: animation, child: child),
                      child: Text(
                        '$_prePlanDays',
                        key: ValueKey<int>(_prePlanDays),
                        style: TextStyle(
                          fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                          fontSize: 22.sp,
                          fontWeight: FontWeight.w800,
                          color: _brandGreen,
                          letterSpacing: -0.5,
                          height: 1.0,
                        ),
                      ),
                    ),
                    SizedBox(height: 1.h),
                    Text(
                      _prePlanDays == 1 ? 'DAY' : 'DAYS',
                      style: TextStyle(
                        fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                        fontSize: 9.sp,
                        fontWeight: FontWeight.w600,
                        color: _subtitleGrey,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              _PrePlanDayStepButton(
                icon: Icons.add_rounded,
                enabled: !atMax,
                onTap: _incrementPrePlanDays,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statGrid(_PlanComparison c) {
    final stats = [
      ('Daily ROI', '${c.planType.dailyRoiPercent.toStringAsFixed(2)}%'),
      ('Daily ROI Amount', '₹ ${_inrDecimal(c.dailyRoiAmount)}'),
      ('Investment Amount', '₹ ${_inr(c.monthlyAmount)}'),
      ('Est. Total ROI', '₹ ${_inr(c.estimatedTotalRoi)}'),
      ('Est. Total Return', '₹ ${_inr(c.estimatedTotalReturn)}'),
      ('Total Days', '${c.durationDays} days'),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        return GridView.count(
          crossAxisCount: responsiveGridColumns(constraints.maxWidth),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 14.h,
          crossAxisSpacing: 12.w,
          childAspectRatio: 2.6,
          children: stats
              .map((s) => _statTile(label: s.$1, value: s.$2))
              .toList(),
        );
      },
    );
  }

  Widget _statTile({required String label, required String value}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
            fontSize: 10.5.sp,
            fontWeight: FontWeight.w500,
            color: _subtitleGrey,
            letterSpacing: 0.2,
          ),
        ),
        SizedBox(height: 3.h),
        Text(
          value,
          style: TextStyle(
            fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
            fontSize: 14.5.sp,
            fontWeight: FontWeight.w700,
            color: _titleDark,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

/// Large, comfortable-to-tap +/- control used by the Pre Plan duration
/// selector. Self-contained so it can own its own press-scale animation
/// (a subtle "premium" squash on tap-down that springs back on release)
/// without adding animation state to the parent screen.
class _PrePlanDayStepButton extends StatefulWidget {
  const _PrePlanDayStepButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  State<_PrePlanDayStepButton> createState() => _PrePlanDayStepButtonState();
}

class _PrePlanDayStepButtonState extends State<_PrePlanDayStepButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (!widget.enabled) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled;
    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: enabled
          ? () {
              HapticFeedback.selectionClick();
              widget.onTap();
            }
          : null,
      child: AnimatedScale(
        scale: _pressed ? 0.90 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 34.w,
          height: 34.h,
          decoration: BoxDecoration(
            gradient: enabled
                ? const LinearGradient(
                    colors: [Color(0xFFDCF3E5), Color(0xFF9AE0BC)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: enabled ? null : const Color(0xFFEDEFEC),
            shape: BoxShape.circle,
            boxShadow: enabled && !_pressed
                ? [
                    BoxShadow(
                      color: _brandGreen.withValues(alpha: 0.18),
                      blurRadius: 7,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Icon(
            widget.icon,
            size: 16.sp,
            color: enabled ? _brandGreen : const Color(0xFFB4BAB6),
          ),
        ),
      ),
    );
  }
}