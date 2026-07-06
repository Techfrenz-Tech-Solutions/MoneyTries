import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/plan/plan_models.dart';
import '../../routes/app_routes.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _bgColor = Color(0xFFECEFF5);
const _white = Color(0xFFFFFFFF);
const _subtitleGrey = Color(0xFF6B7280);
const _titleDark = Color(0xFF111827);
const _brandGreen = Color(0xFF3D9E6A);
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
  /// Each of the `months` monthly instalments of `monthlyAmount` is added to
  /// the principal roughly 30 days apart (matching the app's existing
  /// dailyRoiAmount model — `monthlyAmount × monthsPaid × dailyRoiRate` — used
  /// elsewhere in the app), so instalment `k` (0-indexed) only earns ROI for
  /// the days remaining in the plan after it is paid in:
  ///
  ///   ROI = Σ (monthlyAmount × dailyRoiRate × (totalDays − 30×k))  for k in [0, months)
  static double _estimatedTotalRoi({
    required int monthlyAmount,
    required int months,
    required double dailyRoiRate,
    required int totalDays,
  }) {
    double roi = 0;
    for (int k = 0; k < months; k++) {
      final daysEarning = (totalDays - (30 * k)).clamp(0, totalDays);
      roi += monthlyAmount * dailyRoiRate * daysEarning;
    }
    return roi;
  }

  _PlanComparison _computeFor(PlanType type, int amount) {
    final months = type.months;
    final dailyRoiRate = type.dailyRoiPercent / 100;
    final totalDays = type.durationDays;
    final totalInvestment = amount * months;
    final estimatedTotalRoi = _estimatedTotalRoi(
      monthlyAmount: amount,
      months: months,
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
                padding: const EdgeInsets.fromLTRB(8, 4, 20, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: _titleDark),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Text(
                      'Moneytries',
                      style: GoogleFonts.poppins(
                        fontSize: 17,
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
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      _buildHeader(amount, comparisons.length),
                      const SizedBox(height: 24),
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
                            const SizedBox(height: 16),
                        ],
                      const SizedBox(height: 28),
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
            ? 'Based on a monthly investment of ₹${_inr(amount)}, here\'s your remaining plan option.'
            : 'Based on a monthly investment of ₹${_inr(amount)}, here\'s how each plan performs.';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFFECFDF5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _brandGreen.withValues(alpha: 0.25),
              width: 1,
            ),
          ),
          child: Text(
            'Step 2 of 3 · Compare Plans',
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: _brandGreen,
              letterSpacing: 0.4,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Compare your returns',
          style: GoogleFonts.poppins(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: _titleDark,
            height: 1.2,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: GoogleFonts.poppins(
            fontSize: 14,
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _brandGreen.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_rounded, size: 18, color: _brandGreen),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'There are no more plan types left to enroll in.',
              style: GoogleFonts.poppins(
                fontSize: 12.5,
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
        borderRadius: BorderRadius.circular(22),
        border: isRecommended
            ? Border.all(color: _brandGreen, width: 1.5)
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: _brandGreen,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.auto_awesome_rounded,
                      size: 11,
                      color: _white,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'RECOMMENDED',
                      style: GoogleFonts.poppins(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: _white,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.planType.displayName,
                  style: GoogleFonts.poppins(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: _brandGreen,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${c.planType.durationDays} days total',
                  style: GoogleFonts.poppins(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w400,
                    color: _subtitleGrey,
                  ),
                ),
                const SizedBox(height: 16),
                _statGrid(c),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: isRecommended
                      ? ElevatedButton(
                          onPressed: () => _selectPlan(context, c),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _brandGreen,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            'Select Plan',
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: _white,
                              letterSpacing: 0.2,
                            ),
                          ),
                        )
                      : OutlinedButton(
                          onPressed: () => _selectPlan(context, c),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _brandGreen,
                            side: const BorderSide(
                              color: _brandGreen,
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            'Select Plan',
                            style: GoogleFonts.poppins(
                              fontSize: 15,
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
      ('Monthly Amount', '₹${_inr(c.monthlyAmount)}'),
      ('Total Investment', '₹${_inr(c.totalInvestment)}'),
      ('Est. Total ROI', '₹${_inr(c.estimatedTotalRoi)}'),
      ('Est. Total Return', '₹${_inr(c.estimatedTotalReturn)}'),
      ('Total Days', '${c.planType.durationDays} days'),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 14,
      crossAxisSpacing: 12,
      childAspectRatio: 2.6,
      children: stats
          .map((s) => _statTile(label: s.$1, value: s.$2))
          .toList(),
    );
  }

  Widget _statTile({required String label, required String value}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 10.5,
            fontWeight: FontWeight.w500,
            color: _subtitleGrey,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 14.5,
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