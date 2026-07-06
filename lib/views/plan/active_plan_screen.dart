import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/plan/plan_models.dart';
import '../../routes/app_routes.dart';
import '../../viewmodels/plan/plan_viewmodel.dart';

const _bg = Color(0xFFECEFF5);
const _white = Color(0xFFFFFFFF);
const _dark = Color(0xFF111827);
const _green = Color(0xFF3D9E6A);
const _greenMid = Color(0xFF3D9E6A);
const _grey = Color(0xFF6B7280);
const _greyLight = Color(0xFF9CA3AF);

const _heroGrad = LinearGradient(
  colors: [Color(0xFF3D9E6A), Color(0xFF86C9A0)],
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
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 20),
                          _buildAppBar(context),
                          const SizedBox(height: 24),
                          _buildHeroCard(),
                          const SizedBox(height: 20),
                          if (_plan.status == PlanStatus.rejected) ...[
                            _buildRejectedCard(),
                            const SizedBox(height: 20),
                          ],
                          if (_plan.status == PlanStatus.underReview) ...[
                            _buildUnderReviewCard(),
                            const SizedBox(height: 20),
                          ],
                          _buildPlanDetailsCard(),
                          const SizedBox(height: 20),
                          _buildInstalmentTable(),
                          const SizedBox(height: 20),
                          if ((_plan.status == PlanStatus.active ||
                                  _plan.status == PlanStatus.approved) &&
                              _plan.monthsPaid < _plan.totalMonths) ...[
                            _buildNextPaymentCard(),
                            const SizedBox(height: 20),
                          ],
                          if (_plan.status == PlanStatus.active ||
                              _plan.status == PlanStatus.approved) ...[
                            _buildRoiCard(vm),
                            const SizedBox(height: 20),
                            _buildRoiCalculationCard(),
                            const SizedBox(height: 20),
                            if (_showRoiHistory) ...[
                              _buildRoiHistoryTable(),
                              const SizedBox(height: 20),
                            ],
                          ],
                          if (_plan.isMatured &&
                              _plan.status != PlanStatus.rejected) ...[
                            _buildPrincipalCard(vm),
                            const SizedBox(height: 20),
                          ],
                          const SizedBox(height: 12),
                        ],
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
  Widget _buildAppBar(BuildContext ctx) => Row(
    children: [
      GestureDetector(
        onTap: () => Navigator.pop(ctx),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: _dark,
          ),
        ),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Text(
          'Plan Dashboard',
          style: GoogleFonts.poppins(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: _dark,
          ),
        ),
      ),
      if (_plan.status == PlanStatus.active ||
          _plan.status == PlanStatus.approved) ...[
        if (_plan.monthsPaid < _plan.totalMonths)
          _plan.canPayThisMonth
              ? GestureDetector(
                  onTap: () => Navigator.pushNamed(
                    ctx,
                    AppRoutes.planPayment,
                    arguments: {'plan': _plan},
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: _green,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Pay Month ${_plan.monthsPaid + 1}',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _white,
                      ),
                    ),
                  ),
                )
              : Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_plan.daysUntilNextPayment}d to pay M${_plan.monthsPaid + 1}',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _greyLight,
                    ),
                  ),
                ),
      ],
    ],
  );

  // ── Hero Card ──────────────────────────────────────────────────────────────
  Widget _buildHeroCard() {
    final (Color sBg, Color sTxt) = _statusColors(_plan.status);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: _heroGrad,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3D9E6A).withValues(alpha: 0.3),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: sBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _plan.status.displayLabel.toUpperCase(),
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: sTxt,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              Text(
                _plan.planType.displayName,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _white.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Total Plan Value',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: _white.withValues(alpha: 0.75),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '₹${_inr(_plan.totalCommitment)}',
            style: GoogleFonts.poppins(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              color: _white,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _heroStat('Monthly', '₹${_inr(_plan.monthlyAmount)}'),
              const SizedBox(width: 24),
              _heroStat(
                'Daily ROI',
                '${_plan.planType.rateLabel} / ${_plan.dailyRoiAmount > 0 ? '₹${_plan.dailyRoiAmount.toStringAsFixed(2)}' : '--'}',
              ),
              const SizedBox(width: 24),
              _heroStat(
                'Months Paid',
                '${_plan.monthsPaid}/${_plan.totalMonths}',
              ),
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
        style: GoogleFonts.poppins(
          fontSize: 10,
          color: _white.withValues(alpha: 0.65),
        ),
      ),
      const SizedBox(height: 2),
      Text(
        value,
        style: GoogleFonts.poppins(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: _white,
        ),
      ),
    ],
  );

  (Color, Color) _statusColors(PlanStatus s) {
    switch (s) {
      case PlanStatus.underReview:
        return (const Color(0xFFFEF3C7), const Color(0xFFD97706));
      case PlanStatus.approved:
        return (const Color(0xFFDCFCE7), const Color(0xFF3D9E6A));
      case PlanStatus.active:
        return (const Color(0xFFDCFCE7), const Color(0xFF3D9E6A));
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
        'Your first payment is under admin review. Plan will be activated and ROI will start from the approval date.',
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border, width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
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
    padding: const EdgeInsets.all(20),
    decoration: _cardDecor(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Plan Details',
          style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: _dark,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _summaryGreen('Total Value', '₹${_inr(_plan.totalCommitment)}'),
              _vDiv(),
              _summaryGreen('Paid', '₹${_inr(_plan.paidAmount)}'),
              _vDiv(),
              _summaryGreen('Remaining', '₹${_inr(_plan.remainingAmount)}'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _detailRow('Plan Type', _plan.planType.displayName),
        _divLine(),
        _detailRow('Monthly Amount (Fixed)', '₹${_inr(_plan.monthlyAmount)}'),
        _divLine(),
        _detailRow('Months Paid', '${_plan.monthsPaid} / ${_plan.totalMonths}'),
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
        // Maturity = startDate + fixed days (90/180/365)
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
        if (_plan.status == PlanStatus.active) ...[
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _plan.progressPercent,
              minHeight: 7,
              backgroundColor: const Color(0xFFE5E7EB),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF3D9E6A),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${(_plan.progressPercent * 100).toStringAsFixed(0)}% complete',
            style: GoogleFonts.poppins(fontSize: 11, color: _grey),
          ),
        ],
      ],
    ),
  );

  Widget _summaryGreen(String label, String value) => Column(
    children: [
      Text(label, style: GoogleFonts.poppins(fontSize: 10.5, color: _grey)),
      const SizedBox(height: 4),
      Text(
        value,
        style: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: _greenMid,
        ),
      ),
    ],
  );

  Widget _vDiv() =>
      Container(width: 1, height: 36, color: const Color(0xFFD1FAE5));

  Widget _detailRow(
    String label,
    String value, {
    Color? valueColor,
    String? note,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(fontSize: 13, color: _grey),
              ),
              if (note != null)
                Text(
                  note,
                  style: GoogleFonts.poppins(fontSize: 10, color: _greyLight),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: valueColor ?? _dark,
          ),
        ),
      ],
    ),
  );

  Widget _divLine() => const Divider(height: 1, color: Color(0xFFF3F4F6));
  BoxDecoration _cardDecor() => BoxDecoration(
    color: _white,
    borderRadius: BorderRadius.circular(18),
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
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Payment Schedule',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _dark,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_plan.monthsPaid}/${_plan.totalMonths} paid',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _green,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                _tHdr('Month', flex: 2),
                _tHdr('Amount', flex: 3),
                _tHdr('Date / Time', flex: 5),
                _tHdr('Status', flex: 3),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ...instalments.map(_instalmentRow),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _tHdr(String label, {required int flex}) => Expanded(
    flex: flex,
    child: Text(
      label,
      style: GoogleFonts.poppins(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: _greyLight,
      ),
    ),
  );

  Widget _instalmentRow(PlanInstalment ins) {
    final isPaid = ins.isPaid;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: isPaid ? const Color(0xFFF0FDF4) : _white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isPaid ? const Color(0xFFBBF7D0) : const Color(0xFFF3F4F6),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              'M${ins.monthNumber}',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _dark,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              '₹${_inr(ins.amount)}',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _dark,
              ),
            ),
          ),
          Expanded(
            flex: 5,
            child: Text(
              isPaid && ins.paidAt != null ? _fmtDateTime(ins.paidAt!) : '—',
              style: GoogleFonts.poppins(fontSize: 10.5, color: _grey),
            ),
          ),
          Expanded(
            flex: 3,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isPaid
                    ? const Color(0xFFDCFCE7)
                    : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                isPaid ? 'PAID' : 'NOT PAID',
                style: GoogleFonts.poppins(
                  fontSize: 9.5,
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

  // ── Next Payment Card ──────────────────────────────────────────────────────
  Widget _buildNextPaymentCard() {
    final canPay = _plan.canPayThisMonth;
    final days = _plan.daysUntilNextPayment;
    final nextM = _plan.monthsPaid + 1;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: canPay ? const Color(0xFFF0FDF4) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: canPay ? const Color(0xFF86EFAC) : const Color(0xFFE5E7EB),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: canPay ? const Color(0xFFDCFCE7) : const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              canPay ? Icons.payment_rounded : Icons.schedule_rounded,
              size: 22,
              color: canPay ? _green : const Color(0xFF3B82F6),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  canPay ? 'Month $nextM Payment Due' : 'Month $nextM Payment',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: canPay ? _green : _dark,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  canPay
                      ? 'Tap "Pay Now" to submit your payment.'
                      : 'Available in $days day${days == 1 ? '' : 's'}. One payment per month.',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: canPay ? const Color(0xFF3D9E6A) : _grey,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          if (canPay) ...[
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () => Navigator.pushNamed(
                context,
                AppRoutes.planPayment,
                arguments: {'plan': _plan},
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: _green,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Pay Now',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _white,
                  ),
                ),
              ),
            ),
          ],
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
      padding: const EdgeInsets.all(20),
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
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _dark,
                ),
              ),
              if (daily > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.trending_up_rounded,
                        size: 13,
                        color: _green,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '+₹${daily.toStringAsFixed(2)}/day',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _green,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          const SizedBox(height: 4),
          Text(
            'ROI starts on approval day & credited every day automatically.',
            style: GoogleFonts.poppins(
              fontSize: 11.5,
              color: _grey,
              height: 1.4,
            ),
          ),

          const SizedBox(height: 16),

          // ── Accrued + Withdrawn ──────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: _roiStatBox(
                  label: 'Total Accrued',
                  value: '₹${accrued.toStringAsFixed(2)}',
                  sub:
                      '$days day${days == 1 ? '' : 's'} × ₹${daily.toStringAsFixed(2)}',
                  txtColor: const Color(0xFF3D9E6A),
                  bgColor: const Color(0xFFDCFCE7),
                  icon: Icons.add_circle_outline_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _roiStatBox(
                  label: 'Withdrawn',
                  value: '₹${withdrawn.toStringAsFixed(2)}',
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

          const SizedBox(height: 14),

          // ── Available to Withdraw ────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF3D9E6A), Color(0xFF0F9D58), Color(0xFF14B872)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF3D9E6A).withOpacity(0.28),
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
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet_rounded,
                        size: 15,
                        color: _white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'AVAILABLE TO WITHDRAW',
                      style: GoogleFonts.poppins(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: Colors.white.withOpacity(0.85),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withOpacity(0.85),
                      ),
                    ),
                    const SizedBox(width: 2),
                    Text(
                      pending.toStringAsFixed(2),
                      style: GoogleFonts.poppins(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: _white,
                        height: 1.0,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
                if (accrued > 0) ...[
                  const SizedBox(height: 6),
                  Text(
                    '₹${accrued.toStringAsFixed(2)} accrued  •  ₹${withdrawn.toStringAsFixed(2)} withdrawn',
                    style: GoogleFonts.poppins(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withOpacity(0.78),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Divider(color: Colors.white.withOpacity(0.18), height: 1),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: vm.roiState == PlanVmState.loading
                      ? Container(
                          height: 48,
                          alignment: Alignment.center,
                          child: const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: _white,
                            ),
                          ),
                        )
                      : Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: canWithdraw
                                ? () => _confirmRoiWithdraw(vm, pending)
                                : null,
                            borderRadius: BorderRadius.circular(14),
                            child: AnimatedOpacity(
                              opacity: canWithdraw ? 1.0 : 0.45,
                              duration: const Duration(milliseconds: 200),
                              child: Container(
                                height: 48,
                                decoration: BoxDecoration(
                                  color: _white,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.download_rounded,
                                      size: 18,
                                      color: Color(0xFF3D9E6A),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      canWithdraw
                                          ? 'Withdraw to Wallet'
                                          : 'Nothing to Withdraw',
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF3D9E6A),
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
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 13,
                  color: Color(0xFF9CA3AF),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'ROI is being credited daily. Check back tomorrow.',
                    style: GoogleFonts.poppins(fontSize: 11, color: _greyLight),
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: txtColor),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.poppins(fontSize: 11, color: _greyLight),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: txtColor,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            sub,
            style: GoogleFonts.poppins(
              fontSize: 10,
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
      padding: const EdgeInsets.all(20),
      decoration: _cardDecor(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ROI Calculation',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _dark,
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _showRoiHistory = !_showRoiHistory),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _showRoiHistory ? 'Hide History' : 'View History',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF3B82F6),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Formula display
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _calcRow('Principal (invested)', '₹${_inr(principal)}'),
                const SizedBox(height: 8),
                _calcRow('Daily ROI Rate', _plan.planType.rateLabel),
                const SizedBox(height: 8),
                _calcRow('Daily ROI Amount', '₹${daily.toStringAsFixed(2)}'),
                const Divider(height: 20, color: Color(0xFFD1FAE5)),
                _calcRow('Days Active (approval day = Day 1)', '$days days'),
                const SizedBox(height: 8),
                _calcRow(
                  'Expected Accrued ROI',
                  '₹${expected.toStringAsFixed(2)}',
                  bold: true,
                  color: _green,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(
                Icons.info_outline,
                size: 13,
                color: Color(0xFF9CA3AF),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Backend credits ROI daily from Start Date. Missed days auto-credited on next backend job.',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
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
          style: GoogleFonts.poppins(fontSize: 12.5, color: _grey),
        ),
      ),
      Text(
        value,
        style: GoogleFonts.poppins(
          fontSize: 13,
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
        padding: const EdgeInsets.all(20),
        decoration: _cardDecor(),
        child: Center(
          child: Text(
            'No ROI history yet.',
            style: GoogleFonts.poppins(fontSize: 13, color: _grey),
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
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Daily ROI History',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _dark,
                  ),
                ),
                Text(
                  'Last ${displayList.length} days',
                  style: GoogleFonts.poppins(fontSize: 11, color: _greyLight),
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                _tHdr('Date', flex: 4),
                _tHdr('Principal', flex: 4),
                _tHdr('ROI', flex: 3),
              ],
            ),
          ),
          const SizedBox(height: 6),
          ...displayList.reversed
              .take(30)
              .map(
                (e) => Container(
                  margin: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: _white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFFF3F4F6),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 4,
                        child: Text(
                          _fmtDate(e.date),
                          style: GoogleFonts.poppins(
                            fontSize: 11.5,
                            color: _dark,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 4,
                        child: Text(
                          '₹${_inr(e.principal)}',
                          style: GoogleFonts.poppins(
                            fontSize: 11.5,
                            color: _grey,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          '+₹${e.amount.toStringAsFixed(2)}',
                          style: GoogleFonts.poppins(
                            fontSize: 11.5,
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
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total (${history.length} days)',
                    style: GoogleFonts.poppins(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: _green,
                    ),
                  ),
                  Text(
                    '₹${history.fold(0.0, (s, e) => s + e.amount).toStringAsFixed(2)}',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
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
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: const Color(0xFFF5F3FF),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFDDD6FE), width: 1.5),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFEDE9FE),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.lock_open_rounded,
                size: 20,
                color: Color(0xFF7C3AED),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Principal Unlocked!',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF5B21B6),
                    ),
                  ),
                  Text(
                    'All instalments paid — principal is withdrawable.',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: const Color(0xFF7C3AED),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFEDE9FE),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '₹${_inr(_plan.monthlyAmount)}/mo × ${_plan.totalMonths} months',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: const Color(0xFF7C3AED),
                ),
              ),
              Text(
                '= ₹${_inr(_plan.totalPrincipal)}',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF5B21B6),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Withdrawable Principal',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: const Color(0xFF7C3AED),
                  ),
                ),
                Text(
                  '₹${_inr(_plan.totalPrincipal)}',
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF5B21B6),
                  ),
                ),
              ],
            ),
            if (vm.principalState == PlanVmState.loading)
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Color(0xFF7C3AED),
                ),
              )
            else
              GestureDetector(
                onTap: () => _confirmPrincipalWithdraw(vm),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C3AED),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Withdraw Principal',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
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
                ? 'ROI withdrawal of ₹${amount.toStringAsFixed(2)} initiated!'
                : vm.roiError ?? 'Withdrawal failed.',
          );
        },
      ),
    );
  }

  void _confirmPrincipalWithdraw(PlanViewModel vm) {
    _confirmSheet(
      title: 'Withdraw Principal',
      amount: '₹${_inr(_plan.totalPrincipal)}',
      subtitle:
          'Locked principal from all ${_plan.totalMonths} instalments will be released to your wallet.',
      btnLabel: 'Withdraw ₹${_inr(_plan.totalPrincipal)}',
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
          decoration: const BoxDecoration(
            color: _white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(24, 20, 24, 16 + bp),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0E0E0),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: _dark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: GoogleFonts.poppins(fontSize: 13, color: _grey),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Amount',
                      style: GoogleFonts.poppins(fontSize: 14, color: _grey),
                    ),
                    Text(
                      amount,
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: _greenMid,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () {
                  Navigator.pop(ctx);
                  onConfirm();
                },
                child: Container(
                  width: double.infinity,
                  height: 54,
                  decoration: BoxDecoration(
                    color: _green,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Center(
                    child: Text(
                      btnLabel,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _white,
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
        content: Text(msg, style: GoogleFonts.poppins(fontSize: 13)),
        backgroundColor: _green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── Bottom nav ─────────────────────────────────────────────────────────────
  Widget _buildBottomBar() {
    const items = [
      (icon: Icons.home_rounded, label: 'HOME'),
      (icon: Icons.bar_chart_rounded, label: 'PLAN'),
      (icon: Icons.history_rounded, label: 'HISTORY'),
      (icon: Icons.person_rounded, label: 'PROFILE'),
    ];
    const selIdx = 1;
    return Container(
      decoration: BoxDecoration(
        color: _white,
        border: const Border(
          top: BorderSide(color: Color(0xFFE5E7EB), width: 1),
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
          height: 62,
          child: Row(
            children: List.generate(items.length, (i) {
              final sel = i == selIdx;
              const selC = Color(0xFF3D9E6A);
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
                        height: 3,
                        width: sel ? 32 : 0,
                        margin: const EdgeInsets.only(bottom: 7),
                        decoration: BoxDecoration(
                          color: selC,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Icon(items[i].icon, size: 22, color: c),
                      const SizedBox(height: 3),
                      Text(
                        items[i].label,
                        style: GoogleFonts.poppins(
                          fontSize: 10,
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
            'Amount cannot exceed ₹${widget.maxAmount.toStringAsFixed(2)}',
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
        decoration: const BoxDecoration(
          color: _white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(24, 20, 24, 16 + bp),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0E0E0),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Title
            Text(
              'Withdraw ROI Earnings',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: _dark,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Enter the amount you want to withdraw. It will be credited to your Wallet Balance.',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: _grey,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),

            // Available balance chip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Available to Withdraw',
                    style: GoogleFonts.poppins(fontSize: 12, color: _green),
                  ),
                  Text(
                    '₹${widget.maxAmount.toStringAsFixed(2)}',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: _green,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Amount input
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _error != null
                      ? const Color(0xFFDC2626)
                      : const Color(0xFFE5E7EB),
                  width: 1.5,
                ),
              ),
              child: TextField(
                controller: _ctrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: _onChanged,
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: _dark,
                ),
                decoration: InputDecoration(
                  hintText: '0.00',
                  hintStyle: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF9CA3AF),
                  ),
                  prefixText: '₹ ',
                  prefixStyle: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: _dark,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
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
                      margin: const EdgeInsets.all(8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'MAX',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
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
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    size: 13,
                    color: Color(0xFFDC2626),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    _error!,
                    style: GoogleFonts.poppins(
                      fontSize: 11.5,
                      color: const Color(0xFFDC2626),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 24),

            // Confirm button
            SizedBox(
              width: double.infinity,
              height: 54,
              child: AnimatedOpacity(
                opacity: _isValid ? 1.0 : 0.5,
                duration: const Duration(milliseconds: 200),
                child: ElevatedButton(
                  onPressed: _isValid ? _submit : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _green,
                    disabledBackgroundColor: _green,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    _isValid
                        ? 'Withdraw ₹${_enteredAmount.toStringAsFixed(2)}'
                        : 'Withdraw Now',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _white,
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