import 'package:flutter/material.dart';
import 'package:moneytries/config/app_fonts.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/plan/plan_models.dart';
import '../../routes/app_routes.dart';
import '../../viewmodels/plan/plan_viewmodel.dart';
import '../../utils/responsive.dart';

const _bg = Color(0xFFF7F5F2);
const _white = Color(0xFFFFFFFF);
const _dark = Color(0xFF111827);
const _green = Color(0xFF1F6B45); // banner dark green
const _greenMid = Color(0xFF9AE0BC); // banner gradient end
const _grey = Color(0xFF6B7280);
const _greyLight = Color(0xFF9CA3AF);

const _heroGrad = LinearGradient(
  colors: [Color(0xFFDCF3E5), Color(0xFF9AE0BC)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

class ActivePlanScreen extends StatefulWidget {
  const ActivePlanScreen({super.key});
  @override
  State<ActivePlanScreen> createState() => _ActivePlanScreenState();
}

class _ActivePlanScreenState extends State<ActivePlanScreen> {
  late ActivePlan _plan;
  bool _initialized = false;
  bool _showRoiHistory = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      _plan = args?['plan'] as ActivePlan? ?? _emptyPlan();
      _initialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<PlanViewModel>().loadPlans();
      });
    }
  }

  ActivePlan _emptyPlan() {
    final now = DateTime.now();
    return ActivePlan(
      id: '',
      planType: PlanType.sixMonth,
      monthlyAmount: 0,
      monthsPaid: 0,
      startDate: now,
      maturityDate: addCalendarMonths(now, 6),
      accruedRoi: 0,
      withdrawnRoi: 0,
      status: PlanStatus.underReview,
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  String _inr(num n) {
    final s = n.toInt().toString();
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

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')} ${_mon(d.month)} ${d.year}';

  String _fmtDateTime(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')} ${_mon(d.month)} ${d.year} · '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  String _mon(int m) => const [
    '',
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ][m];

  @override
  Widget build(BuildContext context) {
    return Consumer<PlanViewModel>(
      builder: (context, vm, _) {
        final fresh = vm.getActivePlan(_plan.planType);
        if (fresh != null) _plan = fresh;

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.dark,
          child: Scaffold(
            backgroundColor: _bg,
            body: SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: RefreshIndicator(
                      color: _green,
                      onRefresh: () => context.read<PlanViewModel>().loadPlans(),
                      child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      padding: EdgeInsets.symmetric(horizontal: 20.w),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: 20.h),
                          _buildAppBar(context, vm),
                          SizedBox(height: 24.h),
                          _buildHeroCard(),
                          SizedBox(height: 20.h),
                          if (_plan.status == PlanStatus.rejected) ...[
                            _buildRejectedCard(),
                            SizedBox(height: 20.h),
                          ],
                          if (_plan.status == PlanStatus.underReview) ...[
                            _buildUnderReviewCard(),
                            SizedBox(height: 20.h),
                          ],
                          _buildPlanDetailsCard(),
                          SizedBox(height: 20.h),
                          _buildInstalmentTable(),
                          SizedBox(height: 20.h),
                          if (_plan.status == PlanStatus.active ||
                              _plan.status == PlanStatus.approved) ...[
                            _buildRoiCard(vm),
                            SizedBox(height: 20.h),
                            _buildRoiCalculationCard(),
                            SizedBox(height: 20.h),
                            if (_showRoiHistory) ...[
                              _buildRoiHistoryTable(),
                              SizedBox(height: 20.h),
                            ],
                          ],
                          if (_plan.isMatured &&
                              _plan.status != PlanStatus.rejected) ...[
                            _buildPrincipalCard(vm),
                            SizedBox(height: 20.h),
                          ],
                          SizedBox(height: 12.h),
                        ],
                      ),
                      ),
                    ),
                  ),
                  _buildBottomBar(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── App Bar ────────────────────────────────────────────────────────────────
  Widget _buildAppBar(BuildContext ctx, PlanViewModel vm) {
    final isRefreshing = vm.listState == PlanVmState.loading;
    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.pop(ctx),
          child: Container(
            width: 40.w,
            height: 40.h,
            decoration: BoxDecoration(
              color: _white,
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 18.sp,
              color: _dark,
            ),
          ),
        ),
        SizedBox(width: 14.w),
        Expanded(
          child: Text(
            'Plan Dashboard',
            style: TextStyle(
              fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
              fontSize: 17.sp,
              fontWeight: FontWeight.w700,
              color: _dark,
            ),
          ),
        ),
        SizedBox(width: 14.w),
        GestureDetector(
          onTap: isRefreshing ? null : () => ctx.read<PlanViewModel>().loadPlans(),
          child: Container(
            width: 40.w,
            height: 40.h,
            decoration: BoxDecoration(
              color: _white,
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Center(
              child: isRefreshing
                  ? SizedBox(
                      width: 18.w,
                      height: 18.w,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(_green),
                      ),
                    )
                  : Icon(Icons.refresh_rounded, size: 20.sp, color: _dark),
            ),
          ),
        ),
      ],
    );
  }

  // ── Hero Card ──────────────────────────────────────────────────────────────
  Widget _buildHeroCard() {
    final (Color sBg, Color sTxt) = _statusColors(_plan.status);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        gradient: _heroGrad,
        borderRadius: BorderRadius.circular(22.r),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9AE0BC).withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 5.h),
                decoration: BoxDecoration(
                  color: sBg,
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Text(
                  _plan.status.displayLabel.toUpperCase(),
                  style: TextStyle(
                    fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w700,
                    color: sTxt,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              Text(
                _plan.planType.displayName,
                style: TextStyle(
                  fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                  color: _green,
                ),
              ),
            ],
          ),
          SizedBox(height: 20.h),
          Text(
            'Total Plan Value',
            style: TextStyle(
              fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
              fontSize: 12.sp,
              color: _green.withValues(alpha: 0.75),
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            '₹ ${_inr(_plan.totalCommitment)}',
            style: TextStyle(
              fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
              fontSize: 34.sp,
              fontWeight: FontWeight.w800,
              color: _dark,
              height: 1.0,
            ),
          ),
          SizedBox(height: 16.h),
          Row(
            children: [
              _heroStat('Invested', '₹ ${_inr(_plan.monthlyAmount)}'),
              SizedBox(width: 24.w),
              _heroStat(
                'Daily ROI',
                '${_plan.planType.rateLabel} / ${_plan.dailyRoiAmount > 0 ? '₹ ${_plan.dailyRoiAmount.toStringAsFixed(2)}' : '--'}',
              ),
              SizedBox(width: 24.w),
              _heroStat('Payment', _plan.monthsPaid > 0 ? 'Paid' : 'Under Review'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroStat(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: TextStyle(
          fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
          fontSize: 10.sp,
          color: _green.withValues(alpha: 0.75),
        ),
      ),
      SizedBox(height: 2.h),
      Text(
        value,
        style: TextStyle(
          fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
          fontSize: 13.sp,
          fontWeight: FontWeight.w700,
          color: _dark,
        ),
      ),
    ],
  );

  (Color, Color) _statusColors(PlanStatus s) {
    switch (s) {
      case PlanStatus.underReview:
        return (const Color(0xFFFEF3C7), const Color(0xFFD97706));
      case PlanStatus.approved:
        return (const Color(0xFFE8F5EE), const Color(0xFF4CAF7D));
      case PlanStatus.active:
        return (const Color(0xFFE8F5EE), const Color(0xFF4CAF7D));
      case PlanStatus.completed:
        return (const Color(0xFFEDE9FE), const Color(0xFF7C3AED));
      case PlanStatus.rejected:
        return (const Color(0xFFFEF2F2), const Color(0xFFDC2626));
    }
  }

  // ── Status cards ───────────────────────────────────────────────────────────
  Widget _buildUnderReviewCard() => _statusInfoCard(
    icon: Icons.hourglass_empty_rounded,
    iconColor: const Color(0xFFB45309),
    iconBg: const Color(0xFFFDE68A),
    bg: const Color(0xFFFFFBEB),
    border: const Color(0xFFFDE68A),
    title: 'Under Review',
    titleColor: const Color(0xFF92400E),
    body:
        'Your payment is under admin review. Plan will be activated and ROI will start from the approval date.',
    bodyColor: const Color(0xFFB45309),
  );

  Widget _buildRejectedCard() => _statusInfoCard(
    icon: Icons.cancel_rounded,
    iconColor: const Color(0xFFDC2626),
    iconBg: const Color(0xFFFCA5A5),
    bg: const Color(0xFFFEF2F2),
    border: const Color(0xFFFCA5A5),
    title: 'Plan Rejected',
    titleColor: const Color(0xFFDC2626),
    body: _plan.rejectionReason?.isNotEmpty == true
        ? 'Reason: ${_plan.rejectionReason}'
        : 'Your plan request was rejected. Please contact support for details.',
    bodyColor: const Color(0xFFEF4444),
  );

  Widget _statusInfoCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required Color bg,
    required Color border,
    required String title,
    required Color titleColor,
    required String body,
    required Color bodyColor,
  }) {
    return Container(
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: border, width: 1.5.r),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40.w,
            height: 40.h,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(icon, size: 20.sp, color: iconColor),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                    color: titleColor,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  body,
                  style: TextStyle(
                    fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                    fontSize: 13.sp,
                    color: bodyColor,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Plan Details Card ──────────────────────────────────────────────────────
  Widget _buildPlanDetailsCard() => Container(
    width: double.infinity,
    padding: EdgeInsets.all(20.w),
    decoration: _cardDecor(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Plan Details',
          style: TextStyle(
            fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
            fontSize: 15.sp,
            fontWeight: FontWeight.w700,
            color: _dark,
          ),
        ),
        SizedBox(height: 16.h),
        Container(
          padding: EdgeInsets.all(14.w),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FAF4),
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: _summaryGreen('Invested', '₹ ${_inr(_plan.totalCommitment)}'),
              ),
              _vDiv(),
              Expanded(
                child: _summaryGreen(
                  'Payment Status',
                  _plan.monthsPaid > 0 ? 'Paid' : 'Under Review',
                ),
              ),
              _vDiv(),
              Expanded(
                child: _summaryGreen(
                  'Locked Until Maturity',
                  '₹ ${_inr(_plan.paidAmount)}',
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 16.h),
        _detailRow('Plan Type', _plan.planType.displayName),
        _divLine(),
        _detailRow(
          'Investment Amount (Fixed)',
          '₹ ${_inr(_plan.monthlyAmount)}',
        ),
        _divLine(),
        _detailRow('Payment Status', _plan.monthsPaid > 0 ? 'Paid' : 'Under Review'),
        _divLine(),
        _detailRow('Daily ROI Rate', _plan.planType.rateLabel),
        _divLine(),
        // Start Date = Admin Approval Date (permanent)
        _detailRow(
          'Start Date (Approval Date)',
          _fmtDate(_plan.startDate),
          note: 'Permanent — set by admin on approval',
        ),
        _divLine(),
        // Maturity = startDate + fixed days (90/180/360)
        _detailRow(
          'Maturity Date',
          _fmtDate(_plan.maturityDate),
          note: '${_plan.planType.durationDays} days from start',
        ),
        _divLine(),
        _detailRow(
          'Status',
          _plan.status.displayLabel,
          valueColor: _statusColors(_plan.status).$2,
        ),
        if (!_plan.isMatured && _plan.status == PlanStatus.active) ...[
          _divLine(),
          _detailRow('Days Until Maturity', '${_plan.daysUntilMaturity} days'),
        ],
        if (_plan.isPrincipalCredited) ...[
          _divLine(),
          _detailRow(
            'Principal Credited',
            '₹ ${_inr((_plan.principalCreditedAmount ?? _plan.monthlyAmount).round())}',
            note: 'Auto-credited to wallet at maturity',
            valueColor: _green,
          ),
        ],
        if (_plan.isRoiSettled) ...[
          _divLine(),
          _detailRow(
            'ROI Settled',
            '₹ ${_inr((_plan.roiSettledAmount ?? 0).round())}',
            note: 'Remaining unpaid ROI auto-credited at maturity',
            valueColor: _green,
          ),
        ],
        if (_plan.status == PlanStatus.active) ...[
          SizedBox(height: 14.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(4.r),
            child: LinearProgressIndicator(
              value: _plan.progressPercent,
              minHeight: 7,
              backgroundColor: const Color(0xFFE8E4DE),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF4CAF7D),
              ),
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            '${(_plan.progressPercent * 100).toStringAsFixed(0)}% complete',
            style: TextStyle(
              fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
              fontSize: 11.sp,
              color: _grey,
            ),
          ),
        ],
      ],
    ),
  );

  Widget _summaryGreen(String label, String value) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        label,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
          fontSize: 10.5.sp,
          color: _grey,
        ),
      ),
      SizedBox(height: 4.h),
      Text(
        value,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
          fontSize: 14.sp,
          fontWeight: FontWeight.w800,
          color: _greenMid,
        ),
      ),
    ],
  );

  Widget _vDiv() =>
      Container(width: 1.w, height: 36.h, color: const Color(0xFFD4EDE0));

  Widget _detailRow(
    String label,
    String value, {
    Color? valueColor,
    String? note,
  }) => Padding(
    padding: EdgeInsets.symmetric(vertical: 12.h),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                  fontSize: 13.sp,
                  color: _grey,
                ),
              ),
              if (note != null)
                Text(
                  note,
                  style: TextStyle(
                    fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                    fontSize: 10.sp,
                    color: _greyLight,
                  ),
                ),
            ],
          ),
        ),
        SizedBox(width: 8.w),
        Text(
          value,
          style: TextStyle(
            fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
            color: valueColor ?? _dark,
          ),
        ),
      ],
    ),
  );

  Widget _divLine() => Divider(height: 1.h, color: Color(0xFFF3F4F6));
  BoxDecoration _cardDecor() => BoxDecoration(
    color: _white,
    borderRadius: BorderRadius.circular(18.r),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.06),
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
    ],
  );

  // ── Instalment Table ───────────────────────────────────────────────────────
  Widget _buildInstalmentTable() {
    final instalments = _plan.instalmentTable;
    return Container(
      width: double.infinity,
      decoration: _cardDecor(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 14.h),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Payment Details',
                  style: TextStyle(
                    fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                    color: _dark,
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10.w,
                    vertical: 4.h,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5EE),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Text(
                    _plan.monthsPaid > 0 ? 'Paid' : 'Under Review',
                    style: TextStyle(
                      fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w700,
                      color: _green,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            margin: EdgeInsets.symmetric(horizontal: 20.w),
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Row(
              children: [
                _tHdr('Amount', flex: 4),
                _tHdr('Date / Time', flex: 6),
                _tHdr('Status', flex: 3),
              ],
            ),
          ),
          SizedBox(height: 8.h),
          ...instalments.map(_instalmentRow),
          SizedBox(height: 16.h),
        ],
      ),
    );
  }

  Widget _tHdr(String label, {required int flex}) => Expanded(
    flex: flex,
    child: Text(
      label,
      style: TextStyle(
        fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
        fontSize: 11.sp,
        fontWeight: FontWeight.w600,
        color: _greyLight,
      ),
    ),
  );

  Widget _instalmentRow(PlanInstalment ins) {
    final isPaid = ins.isPaid;
    return Container(
      margin: EdgeInsets.fromLTRB(20.w, 0.h, 20.w, 6.h),
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 13.h),
      decoration: BoxDecoration(
        color: isPaid ? const Color(0xFFF0FAF4) : _white,
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(
          color: isPaid ? const Color(0xFFB2DFC5) : const Color(0xFFF3F4F6),
          width: 1.r,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              '₹ ${_inr(ins.amount)}',
              style: TextStyle(
                fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: _dark,
              ),
            ),
          ),
          Expanded(
            flex: 6,
            child: Text(
              isPaid && ins.paidAt != null ? _fmtDateTime(ins.paidAt!) : '—',
              style: TextStyle(
                fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                fontSize: 10.5.sp,
                color: _grey,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: isPaid
                    ? const Color(0xFFE8F5EE)
                    : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Text(
                isPaid ? 'PAID' : 'NOT PAID',
                style: TextStyle(
                  fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                  fontSize: 9.5.sp,
                  fontWeight: FontWeight.w700,
                  color: isPaid ? _green : _greyLight,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── ROI Card ───────────────────────────────────────────────────────────────
  Widget _buildRoiCard(PlanViewModel vm) {
    final daily = _plan.dailyRoiAmount;
    final days = _plan.daysElapsedInclusive;

    // ROI is tiered: each paid instalment only earns ROI from the day it was
    // actually paid onward, so this is no longer a flat daily × days figure.
    // See ActivePlan.tieredExpectedAccruedRoi for the full calculation.
    final accrued = _plan.tieredExpectedAccruedRoi;
    final withdrawn = _plan.withdrawnRoi;
    final pending = (accrued - withdrawn).clamp(0.0, double.infinity);
    final canWithdraw = pending >= 1;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.w),
      decoration: _cardDecor(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ROI Earnings',
                style: TextStyle(
                  fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w700,
                  color: _dark,
                ),
              ),
              if (daily > 0)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10.w,
                    vertical: 4.h,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5EE),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.trending_up_rounded,
                        size: 13.sp,
                        color: _green,
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        '+₹ ${daily.toStringAsFixed(2)}/day',
                        style: TextStyle(
                          fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w700,
                          color: _green,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          SizedBox(height: 4.h),
          Text(
            'ROI starts on approval day & credited every day automatically.',
            style: TextStyle(
              fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
              fontSize: 11.5.sp,
              color: _grey,
              height: 1.4,
            ),
          ),

          SizedBox(height: 16.h),

          // ── Accrued + Withdrawn ──────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: _roiStatBox(
                  label: 'Total Accrued',
                  value: '₹ ${accrued.toStringAsFixed(2)}',
                  sub:
                      '$days day${days == 1 ? '' : 's'} × ₹ ${daily.toStringAsFixed(2)}',
                  txtColor: const Color(0xFF4CAF7D),
                  bgColor: const Color(0xFFE8F5EE),
                  icon: Icons.add_circle_outline_rounded,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: _roiStatBox(
                  label: 'Withdrawn',
                  value: '₹ ${withdrawn.toStringAsFixed(2)}',
                  sub: withdrawn > 0
                      ? 'Credited to wallet'
                      : 'No withdrawals yet',
                  txtColor: _grey,
                  bgColor: const Color(0xFFF3F4F6),
                  icon: Icons.output_rounded,
                ),
              ),
            ],
          ),

          SizedBox(height: 14.h),

          // ── Available to Withdraw ────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(18.w, 18.h, 18.w, 16.h),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFDCF3E5), Color(0xFF9AE0BC)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18.r),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF9AE0BC).withOpacity(0.4),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(7.w),
                      decoration: BoxDecoration(
                        color: _green.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                      child: Icon(
                        Icons.account_balance_wallet_rounded,
                        size: 15.sp,
                        color: _green,
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      'AVAILABLE TO WITHDRAW',
                      style: TextStyle(
                        fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                        fontSize: 10.5.sp,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: _green,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12.h),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹',
                      style: TextStyle(
                        fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                        fontSize: 20.sp,
                        fontWeight: FontWeight.w700,
                        color: _green,
                      ),
                    ),
                    SizedBox(width: 2.w),
                    Text(
                      pending.toStringAsFixed(2),
                      style: TextStyle(
                        fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                        fontSize: 32.sp,
                        fontWeight: FontWeight.w800,
                        color: _dark,
                        height: 1.0,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
                if (accrued > 0) ...[
                  SizedBox(height: 6.h),
                  Text(
                    '₹ ${accrued.toStringAsFixed(2)} accrued  •  ₹ ${withdrawn.toStringAsFixed(2)} withdrawn',
                    style: TextStyle(
                      fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                      fontSize: 11.5.sp,
                      fontWeight: FontWeight.w500,
                      color: _green.withOpacity(0.75),
                    ),
                  ),
                ],
                SizedBox(height: 16.h),
                Divider(color: _green.withOpacity(0.2), height: 1.h),
                SizedBox(height: 16.h),
                SizedBox(
                  width: double.infinity,
                  child: vm.roiState == PlanVmState.loading
                      ? Container(
                          height: 48.h,
                          alignment: Alignment.center,
                          child: SizedBox(
                            width: 22.w,
                            height: 22.h,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: _green,
                            ),
                          ),
                        )
                      : Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: canWithdraw
                                ? () => _confirmRoiWithdraw(vm, pending)
                                : null,
                            borderRadius: BorderRadius.circular(14.r),
                            child: AnimatedOpacity(
                              opacity: canWithdraw ? 1.0 : 0.45,
                              duration: const Duration(milliseconds: 200),
                              child: Container(
                                height: 48.h,
                                decoration: BoxDecoration(
                                  color: _white,
                                  borderRadius: BorderRadius.circular(14.r),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.download_rounded,
                                      size: 18.sp,
                                      color: _green,
                                    ),
                                    SizedBox(width: 8.w),
                                    Text(
                                      canWithdraw
                                          ? 'Withdraw to Wallet'
                                          : 'Nothing to Withdraw',
                                      style: TextStyle(
                                        fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                                        fontSize: 14.sp,
                                        fontWeight: FontWeight.w700,
                                        color: _green,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),

          if (!canWithdraw && accrued == 0) ...[
            SizedBox(height: 10.h),
            Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 13.sp,
                  color: Color(0xFF9CA3AF),
                ),
                SizedBox(width: 6.w),
                Expanded(
                  child: Text(
                    'ROI is being credited daily. Check back tomorrow.',
                    style: TextStyle(
                      fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                      fontSize: 11.sp,
                      color: _greyLight,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _roiStatBox({
    required String label,
    required String value,
    required String sub,
    required Color txtColor,
    required Color bgColor,
    required IconData icon,
  }) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13.sp, color: txtColor),
              SizedBox(width: 5.w),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                    fontSize: 11.sp,
                    color: _greyLight,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          Text(
            value,
            style: TextStyle(
              fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
              fontSize: 15.sp,
              fontWeight: FontWeight.w800,
              color: txtColor,
            ),
          ),
          SizedBox(height: 3.h),
          Text(
            sub,
            style: TextStyle(
              fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
              fontSize: 10.sp,
              color: _greyLight,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  // ── ROI Calculation Card ───────────────────────────────────────────────────
  Widget _buildRoiCalculationCard() {
    final days = _plan.daysElapsedInclusive;
    final daily = _plan.dailyRoiAmount;
    final principal = _plan.monthlyAmount * _plan.monthsPaid;
    // Tiered: ROI is only calculated on the invested amount that was
    // actually paid-in on each day, not the plan's current total applied
    // retroactively across the whole elapsed period.
    final expected = _plan.tieredExpectedAccruedRoi;

    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: _cardDecor(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ROI Calculation',
                style: TextStyle(
                  fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w700,
                  color: _dark,
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _showRoiHistory = !_showRoiHistory),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10.w,
                    vertical: 4.h,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Text(
                    _showRoiHistory ? 'Hide History' : 'View History',
                    style: TextStyle(
                      fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF3B82F6),
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          // Formula display
          Container(
            padding: EdgeInsets.all(14.w),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FAF4),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Column(
              children: [
                _calcRow('Principal (invested)', '₹ ${_inr(principal)}'),
                SizedBox(height: 8.h),
                _calcRow('Daily ROI Rate', _plan.planType.rateLabel),
                SizedBox(height: 8.h),
                _calcRow('Daily ROI Amount', '₹ ${daily.toStringAsFixed(2)}'),
                Divider(height: 20.h, color: Color(0xFFD4EDE0)),
                _calcRow('Days Active (approval day = Day 1)', '$days days'),
                SizedBox(height: 8.h),
                _calcRow(
                  'Expected Accrued ROI',
                  '₹ ${expected.toStringAsFixed(2)}',
                  bold: true,
                  color: _green,
                ),
              ],
            ),
          ),
          SizedBox(height: 10.h),
          Row(
            children: [
              Icon(Icons.info_outline, size: 13.sp, color: Color(0xFF9CA3AF)),
              SizedBox(width: 6.w),
              Expanded(
                child: Text(
                  'Backend credits ROI daily from Start Date. Missed days auto-credited on next backend job.',
                  style: TextStyle(
                    fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                    fontSize: 11.sp,
                    color: _greyLight,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _calcRow(
    String label,
    String value, {
    bool bold = false,
    Color? color,
  }) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Expanded(
        child: Text(
          label,
          style: TextStyle(
            fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
            fontSize: 12.5.sp,
            color: _grey,
          ),
        ),
      ),
      Text(
        value,
        style: TextStyle(
          fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
          fontSize: 13.sp,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
          color: color ?? _dark,
        ),
      ),
    ],
  );

  // ── ROI History Table ──────────────────────────────────────────────────────
  Widget _buildRoiHistoryTable() {
    final history = _plan.roiHistory;
    if (history.isEmpty) {
      return Container(
        padding: EdgeInsets.all(20.w),
        decoration: _cardDecor(),
        child: Center(
          child: Text(
            'No ROI history yet.',
            style: TextStyle(
              fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
              fontSize: 13.sp,
              color: _grey,
            ),
          ),
        ),
      );
    }
    // Show last 30 entries max
    final displayList = history.length > 30
        ? history.sublist(history.length - 30)
        : history;

    return Container(
      decoration: _cardDecor(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 14.h),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Daily ROI History',
                  style: TextStyle(
                    fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                    color: _dark,
                  ),
                ),
                Text(
                  'Last ${displayList.length} days',
                  style: TextStyle(
                    fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                    fontSize: 11.sp,
                    color: _greyLight,
                  ),
                ),
              ],
            ),
          ),
          Container(
            margin: EdgeInsets.symmetric(horizontal: 20.w),
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Row(
              children: [
                _tHdr('Date', flex: 4),
                _tHdr('Principal', flex: 4),
                _tHdr('ROI', flex: 3),
              ],
            ),
          ),
          SizedBox(height: 6.h),
          ...displayList.reversed
              .take(30)
              .map(
                (e) => Container(
                  margin: EdgeInsets.fromLTRB(20.w, 0.h, 20.w, 4.h),
                  padding: EdgeInsets.symmetric(
                    horizontal: 14.w,
                    vertical: 10.h,
                  ),
                  decoration: BoxDecoration(
                    color: _white,
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(
                      color: const Color(0xFFF3F4F6),
                      width: 1.r,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 4,
                        child: Text(
                          _fmtDate(e.date),
                          style: TextStyle(
                            fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                            fontSize: 11.5.sp,
                            color: _dark,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 4,
                        child: Text(
                          '₹ ${_inr(e.principal)}',
                          style: TextStyle(
                            fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                            fontSize: 11.5.sp,
                            color: _grey,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          '+₹ ${e.amount.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                            fontSize: 11.5.sp,
                            fontWeight: FontWeight.w700,
                            color: _green,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          Padding(
            padding: EdgeInsets.fromLTRB(20.w, 10.h, 20.w, 16.h),
            child: Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FAF4),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total (${history.length} days)',
                    style: TextStyle(
                      fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                      fontSize: 12.5.sp,
                      fontWeight: FontWeight.w600,
                      color: _green,
                    ),
                  ),
                  Text(
                    '₹ ${history.fold(0.0, (s, e) => s + e.amount).toStringAsFixed(2)}',
                    style: TextStyle(
                      fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w800,
                      color: _green,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Principal Card ─────────────────────────────────────────────────────────
  Widget _buildPrincipalCard(PlanViewModel vm) => Container(
    width: double.infinity,
    padding: EdgeInsets.all(20.w),
    decoration: BoxDecoration(
      color: const Color(0xFFF5F3FF),
      borderRadius: BorderRadius.circular(18.r),
      border: Border.all(color: const Color(0xFFDDD6FE), width: 1.5.r),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 36.w,
              height: 36.h,
              decoration: BoxDecoration(
                color: const Color(0xFFEDE9FE),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Icon(
                Icons.lock_open_rounded,
                size: 20.sp,
                color: Color(0xFF7C3AED),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Principal Unlocked!',
                    style: TextStyle(
                      fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF5B21B6),
                    ),
                  ),
                  Text(
                    'Plan matured — locked principal is now withdrawable.',
                    style: TextStyle(
                      fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                      fontSize: 12.sp,
                      color: const Color(0xFF7C3AED),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: 16.h),
        Container(
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: const Color(0xFFEDE9FE),
            borderRadius: BorderRadius.circular(10.r),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'One-time investment (${_plan.planType.displayName})',
                style: TextStyle(
                  fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                  fontSize: 12.sp,
                  color: const Color(0xFF7C3AED),
                ),
              ),
              Text(
                '₹ ${_inr(_plan.totalPrincipal)}',
                style: TextStyle(
                  fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF5B21B6),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 16.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Withdrawable Principal',
                  style: TextStyle(
                    fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                    fontSize: 11.sp,
                    color: const Color(0xFF7C3AED),
                  ),
                ),
                Text(
                  '₹ ${_inr(_plan.totalPrincipal)}',
                  style: TextStyle(
                    fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                    fontSize: 22.sp,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF5B21B6),
                  ),
                ),
              ],
            ),
            if (vm.principalState == PlanVmState.loading)
              SizedBox(
                width: 24.w,
                height: 24.h,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Color(0xFF7C3AED),
                ),
              )
            else
              GestureDetector(
                onTap: () => _confirmPrincipalWithdraw(vm),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 20.w,
                    vertical: 12.h,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C3AED),
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: Text(
                    'Withdraw Principal',
                    style: TextStyle(
                      fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                      color: _white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    ),
  );

  // ── Confirm dialogs ────────────────────────────────────────────────────────
  void _confirmRoiWithdraw(PlanViewModel vm, double pendingAmount) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _RoiWithdrawSheet(
        maxAmount: pendingAmount,
        onConfirm: (amount) async {
          await vm.withdrawRoi(planId: _plan.id, amount: amount);
          if (!mounted) return;
          _toast(
            vm.roiState == PlanVmState.success
                ? 'ROI withdrawal of ₹ ${amount.toStringAsFixed(2)} initiated!'
                : vm.roiError ?? 'Withdrawal failed.',
          );
        },
      ),
    );
  }

  void _confirmPrincipalWithdraw(PlanViewModel vm) {
    _confirmSheet(
      title: 'Withdraw Principal',
      amount: '₹ ${_inr(_plan.totalPrincipal)}',
      subtitle:
          'Your locked principal is released to your wallet automatically once matured.',
      btnLabel: 'Withdraw ₹ ${_inr(_plan.totalPrincipal)}',
      onConfirm: () async {
        await vm.withdrawPrincipal(planId: _plan.id);
        if (!mounted) return;
        _toast(
          vm.principalState == PlanVmState.success
              ? 'Principal withdrawal initiated!'
              : vm.principalError ?? 'Withdrawal failed.',
        );
      },
    );
  }

  void _confirmSheet({
    required String title,
    required String amount,
    required String subtitle,
    required String btnLabel,
    required VoidCallback onConfirm,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final bp = MediaQuery.of(ctx).padding.bottom;
        return Container(
          decoration: BoxDecoration(
            color: _white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
          ),
          padding: EdgeInsets.fromLTRB(24.w, 20.h, 24.w, 16.h + bp),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0E0E0),
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                ),
              ),
              SizedBox(height: 20.h),
              Text(
                title,
                style: TextStyle(
                  fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w700,
                  color: _dark,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                subtitle,
                style: TextStyle(
                  fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                  fontSize: 13.sp,
                  color: _grey,
                ),
              ),
              SizedBox(height: 20.h),
              Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FAF4),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Amount',
                      style: TextStyle(
                        fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                        fontSize: 14.sp,
                        color: _grey,
                      ),
                    ),
                    Text(
                      amount,
                      style: TextStyle(
                        fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                        fontSize: 20.sp,
                        fontWeight: FontWeight.w800,
                        color: _greenMid,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24.h),
              GestureDetector(
                onTap: () {
                  Navigator.pop(ctx);
                  onConfirm();
                },
                child: Container(
                  width: double.infinity,
                  height: 54.h,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFDCF3E5), Color(0xFF9AE0BC)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(28.r),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF9AE0BC).withOpacity(0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      btnLabel,
                      style: TextStyle(
                        fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w700,
                        color: _green,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: TextStyle(fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks, fontSize: 13.sp),
        ),
        backgroundColor: const Color(0xFF1F6B45),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── Bottom nav ─────────────────────────────────────────────────────────────
  Widget _buildBottomBar() {
    const items = [
      (icon: Icons.home_rounded, label: 'HOME'),
      (icon: Icons.trending_up_rounded, label: 'PLAN'),
      (icon: Icons.history_rounded, label: 'HISTORY'),
      (icon: Icons.person_rounded, label: 'PROFILE'),
    ];
    const selIdx = 1;
    return Container(
      decoration: BoxDecoration(
        color: _white,
        border: Border(
          top: BorderSide(color: Color(0xFFE8E4DE), width: 1.r),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62.h,
          child: Row(
            children: List.generate(items.length, (i) {
              final sel = i == selIdx;
              const selC = Color(0xFF4CAF7D);
              const unselC = Color(0xFF9CA3AF);
              final c = sel ? selC : unselC;
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    if (i == selIdx) return;
                    switch (i) {
                      case 0:
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          AppRoutes.home,
                          (r) => false,
                        );
                      case 2:
                        Navigator.pushNamed(context, AppRoutes.history);
                      case 3:
                        Navigator.pushNamed(context, AppRoutes.profile);
                    }
                  },
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        height: 3.h,
                        width: sel ? 32 : 0,
                        margin: EdgeInsets.only(bottom: 7.h),
                        decoration: BoxDecoration(
                          color: selC,
                          borderRadius: BorderRadius.circular(2.r),
                        ),
                      ),
                      Icon(items[i].icon, size: 22.sp, color: c),
                      SizedBox(height: 3.h),
                      Text(
                        items[i].label,
                        style: TextStyle(
                          fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                          fontSize: 10.sp,
                          fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                          color: c,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

// ── ROI Withdraw Amount Sheet ─────────────────────────────────────────────────
class _RoiWithdrawSheet extends StatefulWidget {
  final double maxAmount;
  final void Function(double amount) onConfirm;

  const _RoiWithdrawSheet({required this.maxAmount, required this.onConfirm});

  @override
  State<_RoiWithdrawSheet> createState() => _RoiWithdrawSheetState();
}

class _RoiWithdrawSheetState extends State<_RoiWithdrawSheet> {
  final _ctrl = TextEditingController();
  String? _error;
  double _enteredAmount = 0;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    setState(() {
      _enteredAmount = double.tryParse(v) ?? 0;
      _error = null;
    });
  }

  bool get _isValid => _enteredAmount > 0 && _enteredAmount <= widget.maxAmount;

  void _submit() {
    final val = double.tryParse(_ctrl.text.trim()) ?? 0;
    if (val <= 0) {
      setState(() => _error = 'Please enter an amount');
      return;
    }
    if (val > widget.maxAmount) {
      setState(
        () => _error =
            'Amount cannot exceed ₹ ${widget.maxAmount.toStringAsFixed(2)}',
      );
      return;
    }
    Navigator.pop(context);
    widget.onConfirm(val);
  }

  @override
  Widget build(BuildContext context) {
    final bp = MediaQuery.of(context).padding.bottom;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: _white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        ),
        padding: EdgeInsets.fromLTRB(24.w, 20.h, 24.w, 16.h + bp),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0E0E0),
                  borderRadius: BorderRadius.circular(4.r),
                ),
              ),
            ),
            SizedBox(height: 20.h),

            // Title
            Text(
              'Withdraw ROI Earnings',
              style: TextStyle(
                fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                fontSize: 20.sp,
                fontWeight: FontWeight.w700,
                color: _dark,
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              'Enter the amount you want to withdraw. It will be credited to your Wallet Balance.',
              style: TextStyle(
                fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                fontSize: 13.sp,
                color: _grey,
                height: 1.5,
              ),
            ),
            SizedBox(height: 20.h),

            // Available balance chip
            Container(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5EE),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Available to Withdraw',
                    style: TextStyle(
                      fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                      fontSize: 12.sp,
                      color: _green,
                    ),
                  ),
                  Text(
                    '₹ ${widget.maxAmount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w800,
                      color: _green,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16.h),

            // Amount input
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(
                  color: _error != null
                      ? const Color(0xFFDC2626)
                      : const Color(0xFFE8E4DE),
                  width: 1.5.r,
                ),
              ),
              child: TextField(
                controller: _ctrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: _onChanged,
                style: TextStyle(
                  fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w700,
                  color: _dark,
                ),
                decoration: InputDecoration(
                  hintText: '0.00',
                  hintStyle: TextStyle(
                    fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF9CA3AF),
                  ),
                  prefixText: '₹ ',
                  prefixStyle: TextStyle(
                    fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w700,
                    color: _dark,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 14.h,
                  ),
                  suffixIcon: GestureDetector(
                    onTap: () {
                      _ctrl.text = widget.maxAmount.toStringAsFixed(2);
                      setState(() {
                        _enteredAmount = widget.maxAmount;
                        _error = null;
                      });
                    },
                    child: Container(
                      margin: EdgeInsets.all(8.w),
                      padding: EdgeInsets.symmetric(
                        horizontal: 10.w,
                        vertical: 6.h,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5EE),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Text(
                        'MAX',
                        style: TextStyle(
                          fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w700,
                          color: _green,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Error
            if (_error != null) ...[
              SizedBox(height: 6.h),
              Row(
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 13.sp,
                    color: Color(0xFFDC2626),
                  ),
                  SizedBox(width: 5.w),
                  Text(
                    _error!,
                    style: TextStyle(
                      fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                      fontSize: 11.5.sp,
                      color: const Color(0xFFDC2626),
                    ),
                  ),
                ],
              ),
            ],

            SizedBox(height: 24.h),

            // Confirm button
            SizedBox(
              width: double.infinity,
              height: 54.h,
              child: AnimatedOpacity(
                opacity: _isValid ? 1.0 : 0.5,
                duration: const Duration(milliseconds: 200),
                child: ElevatedButton(
                  onPressed: _isValid ? _submit : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    disabledBackgroundColor: const Color(
                      0xFF9AE0BC,
                    ).withOpacity(0.5),
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28.r),
                    ),
                    elevation: 0,
                    padding: EdgeInsets.zero,
                  ),
                  child: Ink(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFDCF3E5), Color(0xFF9AE0BC)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(28.r),
                    ),
                    child: Container(
                      alignment: Alignment.center,
                      child: Text(
                        _isValid
                            ? 'Withdraw ₹ ${_enteredAmount.toStringAsFixed(2)}'
                            : 'Withdraw Now',
                        style: TextStyle(
                          fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w700,
                          color: _green,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}