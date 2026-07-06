import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/plan/plan_models.dart';
import '../../routes/app_routes.dart';
import '../../viewmodels/plan/plan_viewmodel.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _bg = Color(0xFFF4F6FA);
const _white = Color(0xFFFFFFFF);
const _dark = Color(0xFF111827);
const _grey = Color(0xFF6B7280);
const _greyLight = Color(0xFF9CA3AF);
const _divider = Color(0xFFE5E7EB);
const _brandGreen = Color(0xFF3D9E6A); // matches home banner primary
const _accentGreen = Color(0xFF3D9E6A); // matches home banner primary
const _iconBg = Color(0xFFD1FAE5); // light green tint
// Card gradient — matches home page banner palette
const _cardGradStart = Color(0xFF3D9E6A); // home banner green
const _cardGradEnd = Color(0xFF7DC49A); // home banner light green

class PlanDetailsView extends StatefulWidget {
  const PlanDetailsView({super.key});

  @override
  State<PlanDetailsView> createState() => _PlanDetailsViewState();
}

class _PlanDetailsViewState extends State<PlanDetailsView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PlanViewModel>().loadPlans();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: _bg,
      ),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: Scaffold(
          backgroundColor: _bg,
          body: SafeArea(
            child: Column(
              children: [
                _buildTopBar(),
                Expanded(
                  child: Consumer<PlanViewModel>(
                    builder: (context, vm, _) {
                      if (vm.listState == PlanVmState.loading &&
                          vm.plans.isEmpty) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: _accentGreen,
                            strokeWidth: 2,
                          ),
                        );
                      }
                      if (vm.listState == PlanVmState.error &&
                          vm.plans.isEmpty) {
                        return _buildErrorState(vm);
                      }
                      if (vm.plans.isEmpty) {
                        return _buildEmptyState();
                      }
                      return _buildPlanList(vm);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Top Bar ───────────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Container(
      color: _white,
      padding: const EdgeInsets.fromLTRB(8, 12, 16, 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              margin: const EdgeInsets.all(6),
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: _dark,
                size: 16,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'Plan Details',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _dark,
            ),
          ),
          const Spacer(),
          Consumer<PlanViewModel>(
            builder: (_, vm, __) {
              final active = vm.plans.where((p) => p.status.isRunning).length;
              if (active == 0) return const SizedBox.shrink();
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _brandGreen.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: _brandGreen,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '$active Active',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _brandGreen,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Plan List ─────────────────────────────────────────────────────────────
  Widget _buildPlanList(PlanViewModel vm) {
    // Sort: active first, then approved, then under review, then completed, rejected last
    final sorted = [...vm.plans]
      ..sort((a, b) {
        int order(PlanStatus s) {
          switch (s) {
            case PlanStatus.active:
              return 0;
            case PlanStatus.approved:
              return 1;
            case PlanStatus.underReview:
              return 2;
            case PlanStatus.completed:
              return 3;
            case PlanStatus.rejected:
              return 4;
          }
        }

        return order(a.status).compareTo(order(b.status));
      });

    return RefreshIndicator(
      color: _accentGreen,
      onRefresh: vm.loadPlans,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        itemCount: sorted.length + 1, // +1 for summary card
        itemBuilder: (ctx, i) {
          if (i == 0) return _buildSummaryCard(vm);
          return _PlanCard(plan: sorted[i - 1]);
        },
      ),
    );
  }

  // ── Summary card ──────────────────────────────────────────────────────────
  Widget _buildSummaryCard(PlanViewModel vm) {
    final total = vm.plans.length;
    final active = vm.plans.where((p) => p.status.isRunning).length;
    final completed = vm.plans
        .where((p) => p.status == PlanStatus.completed)
        .length;
    final pending = vm.plans
        .where((p) => p.status == PlanStatus.underReview)
        .length;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_cardGradStart, _cardGradEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _cardGradStart.withOpacity(0.3),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Decorative circle (top-right)
          Positioned(
            top: -30,
            right: -20,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _white.withOpacity(0.05),
              ),
            ),
          ),
          Positioned(
            bottom: -40,
            left: -10,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _white.withOpacity(0.04),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.bar_chart_rounded,
                        size: 22,
                        color: _white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Portfolio Summary',
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: _white,
                          ),
                        ),
                        Text(
                          'Your investment overview',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: _white.withOpacity(0.55),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                // Stats row
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      _buildSumStat(
                        'Total Plans',
                        '$total',
                        icon: Icons.list_alt_rounded,
                        iconColor: const Color(0xFFBAE6FD),
                      ),
                      _buildSumDivider(),
                      _buildSumStat(
                        'Active',
                        '$active',
                        icon: Icons.play_circle_outline_rounded,
                        iconColor: const Color(0xFF6EE7B7),
                        valueColor: const Color(0xFF6EE7B7),
                      ),
                      _buildSumDivider(),
                      _buildSumStat(
                        'Completed',
                        '$completed',
                        icon: Icons.check_circle_outline_rounded,
                        iconColor: const Color(0xFFA5B4FC),
                        valueColor: const Color(0xFFA5B4FC),
                      ),
                      _buildSumDivider(),
                      _buildSumStat(
                        'Pending',
                        '$pending',
                        icon: Icons.schedule_rounded,
                        iconColor: const Color(0xFFFCD34D),
                        valueColor: const Color(0xFFFCD34D),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                // Principal row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Principal',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: _white.withOpacity(0.55),
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '₹${_fmtAmount(vm.planAmount)}',
                          style: GoogleFonts.poppins(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            color: _white,
                            height: 1.1,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: active > 0
                            ? const Color(0xFFFCD34D).withOpacity(0.18)
                            : const Color(0xFF6EE7B7).withOpacity(0.18),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: active > 0
                              ? const Color(0xFFFCD34D).withOpacity(0.5)
                              : const Color(0xFF6EE7B7).withOpacity(0.5),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            active > 0
                                ? Icons.lock_rounded
                                : Icons.lock_open_rounded,
                            size: 14,
                            color: active > 0
                                ? const Color(0xFFFCD34D)
                                : const Color(0xFF6EE7B7),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            active > 0 ? 'Locked' : 'Available',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: active > 0
                                  ? const Color(0xFFFCD34D)
                                  : const Color(0xFF6EE7B7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSumStat(
    String label,
    String value, {
    Color valueColor = const Color(0xFFFFFFFF),
    IconData icon = Icons.circle,
    Color iconColor = const Color(0xFFFFFFFF),
  }) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: valueColor,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 10,
              color: _white.withOpacity(0.5),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSumDivider() => Container(
    width: 1,
    height: 44,
    color: _white.withOpacity(0.12),
    margin: const EdgeInsets.symmetric(horizontal: 2),
  );

  // ── KYC gate ──────────────────────────────────────────────────────────────
  Future<String> _fetchKycStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';
      if (token.isEmpty) return 'not_submitted';
      const baseUrl = 'http://192.168.0.17:3000';
      final res = await http
          .get(
            Uri.parse('$baseUrl/api/kyc/status'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        return (body['data']?['status'] as String?) ?? 'not_submitted';
      }
    } catch (_) {}
    return 'not_submitted';
  }

  Future<void> _onStartPlan() async {
    final kycStatus = await _fetchKycStatus();
    if (!mounted) return;

    if (kycStatus == 'approved') {
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.plan,
        (r) => r.settings.name == AppRoutes.home,
      );
      return;
    }

    String title;
    String message;
    String actionLabel;
    VoidCallback onAction;

    if (kycStatus == 'pending') {
      title = 'KYC Under Review';
      message =
          'Your KYC documents are being reviewed. You can start investing once they are approved.';
      actionLabel = 'OK';
      onAction = () => Navigator.pop(context);
    } else if (kycStatus == 'rejected') {
      title = 'KYC Rejected';
      message =
          'Your KYC was rejected. Please resubmit your documents to start investing.';
      actionLabel = 'Resubmit KYC';
      onAction = () {
        Navigator.pop(context);
        Navigator.pushNamed(context, AppRoutes.kyc);
      };
    } else {
      title = 'KYC Required';
      message =
          'You need to complete KYC verification before starting an investment plan.';
      actionLabel = 'Complete KYC';
      onAction = () {
        Navigator.pop(context);
        Navigator.pushNamed(context, AppRoutes.kyc);
      };
    }

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              kycStatus == 'pending'
                  ? Icons.hourglass_top_rounded
                  : Icons.verified_user_outlined,
              color: kycStatus == 'pending'
                  ? const Color(0xFFD97706)
                  : _brandGreen,
              size: 22,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _dark,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: GoogleFonts.poppins(fontSize: 13, color: _grey, height: 1.5),
        ),
        actions: [
          if (kycStatus != 'pending')
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(fontSize: 13, color: _greyLight),
              ),
            ),
          TextButton(
            onPressed: onAction,
            child: Text(
              actionLabel,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _brandGreen,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Empty State ───────────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: _accentGreen.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.bar_chart_rounded,
                size: 44,
                color: _accentGreen,
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'No Plans Yet',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: _dark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start your first investment plan\nand grow your wealth steadily.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: _grey,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 28),
            GestureDetector(
              onTap: _onStartPlan,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_cardGradStart, _cardGradEnd],
                  ),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: _cardGradStart.withOpacity(0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add_rounded, color: _white, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Start Your First Plan',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Error State ───────────────────────────────────────────────────────────
  Widget _buildErrorState(PlanViewModel vm) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 52,
              color: Color(0xFFDC2626),
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load plans',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _dark,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              vm.listError ?? 'Something went wrong.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: _grey,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: vm.loadPlans,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: _brandGreen,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Text(
                  'Retry',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _white,
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

// ── Individual Plan Card ──────────────────────────────────────────────────────
class _PlanCard extends StatefulWidget {
  final ActivePlan plan;
  const _PlanCard({required this.plan});

  @override
  State<_PlanCard> createState() => _PlanCardState();
}

class _PlanCardState extends State<_PlanCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.plan;
    final statusMeta = _statusMeta(p.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────
          _buildCardHeader(p, statusMeta),

          // ── Progress bar ────────────────────────────────────────────
          _buildProgressBar(p),

          // ── Stats row ───────────────────────────────────────────────
          _buildStatsRow(p),

          // ── Expand toggle ───────────────────────────────────────────
          _buildExpandToggle(),

          // ── Expanded content ────────────────────────────────────────
          if (_expanded) ...[
            Container(height: 1, color: _divider),
            _buildInstalmentTable(p),
          ],
        ],
      ),
    );
  }

  // ── Card Header ───────────────────────────────────────────────────────────
  Widget _buildCardHeader(ActivePlan p, _StatusMeta meta) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: _iconBg,
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.trending_up_rounded,
              color: _accentGreen,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.planType.displayName,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _dark,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${p.planType.dailyRoiPercent.toStringAsFixed(2)}% daily ROI  •  ${p.planType.months} months',
                  style: GoogleFonts.poppins(fontSize: 12, color: _grey),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: meta.bgColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: meta.dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  p.status.displayLabel,
                  style: GoogleFonts.poppins(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: meta.textColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Progress Bar ─────────────────────────────────────────────────────────
  Widget _buildProgressBar(ActivePlan p) {
    final pct = p.progressPercent;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${p.monthsPaid} of ${p.totalMonths} payments',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: _grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '${(pct * 100).toStringAsFixed(0)}%',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _accentGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 8,
              backgroundColor: const Color(0xFFE5E7EB),
              valueColor: AlwaysStoppedAnimation<Color>(
                pct >= 1.0 ? _brandGreen : _accentGreen,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Stats Row ─────────────────────────────────────────────────────────────
  Widget _buildStatsRow(ActivePlan p) {
    final daysLeft = p.daysUntilMaturity;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
      child: Row(
        children: [
          _buildStat(
            'Monthly',
            '₹${_fmtAmount(p.monthlyAmount.toDouble())}',
            Icons.payments_rounded,
            const Color(0xFF3B82F6),
          ),
          _buildStatDivider(),
          _buildStat(
            'Principal',
            '₹${_fmtAmount(p.totalPrincipal.toDouble())}',
            Icons.account_balance_wallet_rounded,
            _accentGreen,
          ),
          _buildStatDivider(),
          _buildStat(
            p.isMatured ? 'Matured' : 'Days Left',
            p.isMatured ? 'Done' : '$daysLeft days',
            p.isMatured
                ? Icons.check_circle_outline_rounded
                : Icons.hourglass_bottom_rounded,
            p.isMatured ? _brandGreen : const Color(0xFFD97706),
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _dark,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.poppins(fontSize: 10.5, color: _greyLight),
          ),
        ],
      ),
    );
  }

  Widget _buildStatDivider() => Container(
    width: 1,
    height: 42,
    color: _divider,
    margin: const EdgeInsets.symmetric(horizontal: 6),
  );

  // ── ROI Info Row ──────────────────────────────────────────────────────────
  Widget _buildRoiInfo(ActivePlan p) {
    // Client-computed ROI is authoritative (same formula used on the Active
    // Plan screen), now correctly tiered by paid instalment date so each
    // instalment only earns ROI from the day it was actually paid — see
    // ActivePlan.tieredExpectedAccruedRoi. The server's p.accruedRoi can lag
    // behind because its catch-up only runs via cron or on-fetch, which was
    // causing this page to show a stale figure (e.g. ₹7 instead of the true
    // ₹45).
    final accrued = p.tieredExpectedAccruedRoi;
    final withdrawn = p.withdrawnRoi;
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 14, 18, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7).withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFFCD34D).withOpacity(0.4),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.trending_up_rounded,
            size: 18,
            color: Color(0xFFD97706),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Accrued ROI',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: const Color(0xFFD97706),
                  ),
                ),
                Text(
                  '₹${_fmtAmount(accrued)}',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF92400E),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Total Withdrawal Amount',
                style: GoogleFonts.poppins(fontSize: 11, color: _grey),
              ),
              Text(
                '₹${_fmtAmount(withdrawn)}',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _dark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Expand Toggle ─────────────────────────────────────────────────────────
  Widget _buildExpandToggle() {
    final p = widget.plan;
    final showRoi = p.status.isRunning || p.status == PlanStatus.completed;
    return Column(
      children: [
        if (showRoi) _buildRoiInfo(p),
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _expanded ? 'Hide Payment Schedule' : 'View Payment Schedule',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _accentGreen,
                  ),
                ),
                const SizedBox(width: 4),
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 220),
                  child: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: _accentGreen,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Instalment Table ──────────────────────────────────────────────────────
  Widget _buildInstalmentTable(ActivePlan p) {
    final instalments = p.instalmentTable;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Payment Schedule',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _dark,
            ),
          ),
          const SizedBox(height: 12),
          // Table header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                _buildTableHeader('Month', flex: 2),
                _buildTableHeader('Amount', flex: 3),
                _buildTableHeader('Date', flex: 3),
                _buildTableHeader('Status', flex: 2),
              ],
            ),
          ),
          const SizedBox(height: 4),
          ...instalments.map((inst) => _buildInstalmentRow(inst, p)),
          const SizedBox(height: 8),
          // Summary footer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _iconBg.withOpacity(0.6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Commitment',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _brandGreen,
                  ),
                ),
                Text(
                  '₹${_fmtAmount(p.totalCommitment.toDouble())}',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _brandGreen,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader(String text, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: _grey,
        ),
      ),
    );
  }

  Widget _buildInstalmentRow(PlanInstalment inst, ActivePlan p) {
    final isPaid = inst.isPaid;
    final isNext =
        !isPaid && inst.monthNumber == p.monthsPaid + 1 && p.status.isRunning;

    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isPaid
            ? const Color(0xFFF0FDF4)
            : isNext
            ? const Color(0xFFFFF7ED)
            : _white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isPaid
              ? const Color(0xFFBBF7D0)
              : isNext
              ? const Color(0xFFFDE68A)
              : _divider,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Month
          Expanded(
            flex: 2,
            child: Text(
              'M${inst.monthNumber}',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _dark,
              ),
            ),
          ),
          // Amount
          Expanded(
            flex: 3,
            child: Text(
              '₹${_fmtAmount(inst.amount.toDouble())}',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: _dark,
              ),
            ),
          ),
          // Date
          Expanded(
            flex: 3,
            child: Text(
              inst.paidAt != null
                  ? '${inst.paidAt!.day}/${inst.paidAt!.month}/${inst.paidAt!.year}'
                  : isNext
                  ? 'Due Now'
                  : '—',
              style: GoogleFonts.poppins(
                fontSize: 11.5,
                color: isNext ? const Color(0xFFD97706) : _grey,
                fontWeight: isNext ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
          // Status
          Expanded(
            flex: 2,
            child: isPaid
                ? const Icon(
                    Icons.check_circle_rounded,
                    color: _brandGreen,
                    size: 18,
                  )
                : isNext
                ? const Icon(
                    Icons.radio_button_unchecked_rounded,
                    color: Color(0xFFD97706),
                    size: 18,
                  )
                : const Icon(
                    Icons.radio_button_unchecked_rounded,
                    color: Color(0xFFD1D5DB),
                    size: 18,
                  ),
          ),
        ],
      ),
    );
  }

  // ── Status Meta ───────────────────────────────────────────────────────────
  _StatusMeta _statusMeta(PlanStatus s) {
    switch (s) {
      case PlanStatus.active:
        return _StatusMeta(
          bgColor: const Color(0xFFECFDF5),
          textColor: _brandGreen,
          dotColor: _brandGreen,
        );
      case PlanStatus.approved:
        return _StatusMeta(
          bgColor: const Color(0xFFECFDF5),
          textColor: _brandGreen,
          dotColor: _brandGreen,
        );
      case PlanStatus.underReview:
        return _StatusMeta(
          bgColor: const Color(0xFFFEF3C7),
          textColor: const Color(0xFF92400E),
          dotColor: const Color(0xFFD97706),
        );
      case PlanStatus.completed:
        return _StatusMeta(
          bgColor: const Color(0xFFEFF6FF),
          textColor: const Color(0xFF1E40AF),
          dotColor: const Color(0xFF3B82F6),
        );
      case PlanStatus.rejected:
        return _StatusMeta(
          bgColor: const Color(0xFFFEE2E2),
          textColor: const Color(0xFF991B1B),
          dotColor: const Color(0xFFDC2626),
        );
    }
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────
class _StatusMeta {
  final Color bgColor;
  final Color textColor;
  final Color dotColor;
  const _StatusMeta({
    required this.bgColor,
    required this.textColor,
    required this.dotColor,
  });
}

String _fmtAmount(double v) {
  final s = v.toInt().toString();
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