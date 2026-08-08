import 'package:flutter/material.dart';
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
  final double estimatedTotalRoi;
  final double estimatedTotalReturn;

  const _PlanComparison({
    required this.planType,
    required this.monthlyAmount,
    required this.totalInvestment,
    required this.estimatedTotalRoi,
    required this.estimatedTotalReturn,
  });
}

/// Step 2 of the redesigned Investment Plan flow:
///   Enter Investment Amount → Show Plan Comparison → Select Plan → T&C →
///   Submit Request → Admin Approval → First Payment → Active Plan.
///
/// Renders the plan tiers (3M / 6M / 12M) side-by-side as comparison cards,
/// with every figure computed dynamically from the amount entered on the
/// previous screen, so the user can compare potential profit before picking
/// a plan. Selecting a plan continues into the existing, unchanged flow
/// (Terms & Conditions → Configure/Submit → Admin Approval → Active Plan).
///
/// Optionally receives `excludeTypes` (a `List<String>` of `PlanType.name`
/// values) via route arguments — plan types the user already holds are
/// never shown here again, so only the plans still available to them are
/// compared. When omitted, all 3 plans are compared as before.
class PlanComparisonScreen extends StatelessWidget {
  const PlanComparisonScreen({super.key});

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
    final totalDays = type.durationDays;
    // One-time investment: the total invested amount IS the amount entered
    // — never multiplied by the plan's duration in months.
    final totalInvestment = amount;
    final estimatedTotalRoi = _estimatedTotalRoi(
      investedAmount: amount,
      dailyRoiRate: dailyRoiRate,
      totalDays: totalDays,
    );
    return _PlanComparison(
      planType: type,
      monthlyAmount: amount,
      totalInvestment: totalInvestment,
      estimatedTotalRoi: estimatedTotalRoi,
      estimatedTotalReturn: totalInvestment + estimatedTotalRoi,
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
                        fontFamily: 'Times New Roman',
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
        ? 'Based on an investment of ₹${_inr(amount)}, here\'s your remaining plan option.'
        : 'Based on an investment of ₹${_inr(amount)}, here\'s how each plan performs.';
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
              fontFamily: 'Times New Roman',
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
            fontFamily: 'Times New Roman',
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
            fontFamily: 'Times New Roman',
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
                fontFamily: 'Times New Roman',
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
                        fontFamily: 'Times New Roman',
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
                    fontFamily: 'Times New Roman',
                    fontSize: 19.sp,
                    fontWeight: FontWeight.w800,
                    color: _brandGreen,
                    letterSpacing: -0.2,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  '${c.planType.durationDays} days total',
                  style: TextStyle(
                    fontFamily: 'Times New Roman',
                    fontSize: 12.5.sp,
                    fontWeight: FontWeight.w400,
                    color: _subtitleGrey,
                  ),
                ),
                SizedBox(height: 16.h),
                _statGrid(c),
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
                                fontFamily: 'Times New Roman',
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
                              fontFamily: 'Times New Roman',
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

  Widget _statGrid(_PlanComparison c) {
    final stats = [
      ('Daily ROI', '${c.planType.dailyRoiPercent.toStringAsFixed(2)}%'),
      ('Investment Amount', '₹${_inr(c.monthlyAmount)}'),
      ('Total Investment', '₹${_inr(c.totalInvestment)}'),
      ('Est. Total ROI', '₹${_inr(c.estimatedTotalRoi)}'),
      ('Est. Total Return', '₹${_inr(c.estimatedTotalReturn)}'),
      ('Total Days', '${c.planType.durationDays} days'),
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
            fontFamily: 'Times New Roman',
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
            fontFamily: 'Times New Roman',
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
