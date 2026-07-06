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
const _bgColor = Color(0xFFECEFF5);
const _white = Color(0xFFFFFFFF);
const _subtitleGrey = Color(0xFF6B7280);
const _titleDark = Color(0xFF111827);
const _brandGreen = Color(0xFF3D9E6A);
const _cardBg = Color(0xFFFFFFFF);
const _gold = Color(0xFFCFA24A);
// Same gradient used by the Home screen's promo banners / balance card —
// reused here so the plan card header matches that look-and-feel exactly.
const _bannerGradient = [Color(0xFF3D9E6A), Color(0xFF86C9A0)];

/// Redesigned Investment Plan flow:
///
///  • No active plan  → Plan Info (benefits / ROI / features / rules) with a
///    single "Continue" button → Enter Investment Amount → Compare ALL plans
///    (3M / 6M / 12M) → Select Plan → T&C → Submit Request → Admin Approval →
///    Payment → Active Plan.
///
///  • Has active plan(s) → show ONLY the current plan's details (ROI,
///    Invested Amount, Accrued ROI, Payment Progress, Claim ROI, ...) for
///    each active plan. Plans the user already holds are never shown again
///    in the comparison list. A "Continue Another Plan" button below lets
///    the user enter a new amount and compare only the remaining plan
///    types they don't already hold.
class PlanScreen extends StatefulWidget {
  const PlanScreen({super.key});
  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PlanViewModel>().loadPlans();
    });
  }

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

  /// Navigates into the "enter amount → compare plans" flow, gated behind
  /// KYC approval. [excludeTypes] carries the plan types the user already
  /// holds (active/approved/under review) so the comparison screen only
  /// shows the plans still available to them.
  Future<void> _navigateToInvestWithKycCheck(
    BuildContext ctx, {
    List<PlanType> excludeTypes = const [],
  }) async {
    final kycStatus = await _fetchKycStatus();
    if (!ctx.mounted) return;

    if (kycStatus == 'approved') {
      Navigator.pushNamed(
        ctx,
        AppRoutes.investmentAmount,
        arguments: excludeTypes.isEmpty
            ? null
            : {'excludeTypes': excludeTypes.map((t) => t.name).toList()},
      );
      return;
    }

    String dlgTitle;
    String dlgMessage;
    String actionLabel;
    VoidCallback onAction;

    if (kycStatus == 'pending') {
      dlgTitle = 'KYC Under Review';
      dlgMessage =
          'Your KYC documents are being reviewed. You can start investing once they are approved.';
      actionLabel = 'OK';
      onAction = () => Navigator.pop(ctx);
    } else if (kycStatus == 'rejected') {
      dlgTitle = 'KYC Rejected';
      dlgMessage =
          'Your KYC was rejected. Please resubmit your documents to start investing.';
      actionLabel = 'Resubmit KYC';
      onAction = () {
        Navigator.pop(ctx);
        Navigator.pushNamed(ctx, AppRoutes.kyc);
      };
    } else {
      dlgTitle = 'KYC Required';
      dlgMessage =
          'Please complete your KYC verification before enrolling in a plan.';
      actionLabel = 'Complete KYC';
      onAction = () {
        Navigator.pop(ctx);
        Navigator.pushNamed(ctx, AppRoutes.kyc);
      };
    }

    showDialog(
      context: ctx,
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
                dlgTitle,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF111827),
                ),
              ),
            ),
          ],
        ),
        content: Text(
          dlgMessage,
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: const Color(0xFF6B7280),
            height: 1.5,
          ),
        ),
        actions: [
          if (kycStatus != 'pending')
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: const Color(0xFF9CA3AF),
                ),
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

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _bgColor,
        body: SafeArea(
          child: Consumer<PlanViewModel>(
            builder: (context, vm, _) {
              final activePlans = vm.plans
                  .where(
                    (p) =>
                        p.status == PlanStatus.active ||
                        p.status == PlanStatus.approved ||
                        p.status == PlanStatus.underReview,
                  )
                  .toList();
              final activeTypes = activePlans.map((p) => p.planType).toSet();
              final remainingTypes = PlanType.values
                  .where((t) => !activeTypes.contains(t))
                  .toList();
              final showContinueBtn =
                  activePlans.isNotEmpty && remainingTypes.isNotEmpty;

              return Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 20),
                          _buildHeader(),
                          const SizedBox(height: 24),
                          if (vm.listState == PlanVmState.loading &&
                              vm.plans.isEmpty)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 40),
                                child: CircularProgressIndicator(
                                  color: _brandGreen,
                                  strokeWidth: 2.5,
                                ),
                              ),
                            )
                          else
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (vm.listState == PlanVmState.error &&
                                    vm.plans.isEmpty)
                                  _buildApiErrorNotice(vm),
                                if (activePlans.isEmpty)
                                  ..._buildPlanInfoFlow(context)
                                else
                                  ..._buildActivePlansFlow(
                                    context,
                                    activePlans,
                                    activeTypes,
                                    remainingTypes,
                                  ),
                              ],
                            ),
                          const SizedBox(height: 28),
                        ],
                      ),
                    ),
                  ),
                  // ── "Continue Another Plan" pinned between scroll & nav ──
                  if (showContinueBtn)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 32, 20, 48),
                      child: Center(
                        child: _continueButton(
                          label: 'Continue Another Plan',
                          onTap: () => _navigateToInvestWithKycCheck(
                            context,
                            excludeTypes: activeTypes.toList(),
                          ),
                        ),
                      ),
                    ),
                  _buildBottomNav(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Investment Plans',
          style: GoogleFonts.poppins(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: _titleDark,
            height: 1.18,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Choose a plan and grow your wealth with\ndaily ROI credited directly to your wallet.',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: _subtitleGrey,
            height: 1.6,
          ),
        ),
      ],
    );
  }

  Widget _buildApiErrorNotice(PlanViewModel vm) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFDE68A), width: 1),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.wifi_off_rounded,
            size: 16,
            color: Color(0xFFD97706),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Could not load plan status. Plan info is still available below.',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: const Color(0xFFB45309),
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => vm.loadPlans(),
            child: Text(
              'Retry',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: const Color(0xFFD97706),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // NO ACTIVE PLAN → Plan Info (benefits / ROI / features / rules) + Continue
  // ═══════════════════════════════════════════════════════════════════════════
  List<Widget> _buildPlanInfoFlow(BuildContext context) {
    return [
      _infoSectionCard(
        title: 'Why invest with Moneytries',
        icon: Icons.workspace_premium_rounded,
        children: const [
          (
            icon: Icons.trending_up_rounded,
            text: 'Daily ROI credited straight to your wallet — no waiting.',
          ),
          (
            icon: Icons.shield_outlined,
            text: 'Your principal is secured and fully returned on maturity.',
          ),
          (
            icon: Icons.calendar_month_outlined,
            text: 'Flexible tenures — 3, 6 or 12 months to match your goals.',
          ),
          (
            icon: Icons.support_agent_outlined,
            text: 'Priority support and dedicated relationship assistance.',
          ),
        ],
      ),
      const SizedBox(height: 16),
      _roiTierOverviewCard(),
      const SizedBox(height: 16),
      _infoSectionCard(
        title: 'How it works',
        icon: Icons.timeline_rounded,
        children: const [
          (
            icon: Icons.payments_outlined,
            text: 'Pay your monthly instalment via UPI or Wallet balance.',
          ),
          (
            icon: Icons.fact_check_outlined,
            text: 'First payment is reviewed and approved by our admin team.',
          ),
          (
            icon: Icons.bolt_rounded,
            text: 'Once approved, daily ROI starts accruing automatically.',
          ),
          (
            icon: Icons.account_balance_wallet_outlined,
            text: 'Withdraw accrued ROI to your wallet anytime.',
          ),
        ],
      ),
      const SizedBox(height: 16),
      _rulesCard(),
      const SizedBox(height: 24),
      _continueButton(
        label: 'Continue',
        onTap: () => _navigateToInvestWithKycCheck(context),
      ),
    ];
  }

  Widget _infoSectionCard({
    required String title,
    required IconData icon,
    required List<({IconData icon, String text})> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: _brandGreen),
              const SizedBox(width: 10),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w700,
                  color: _titleDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children.map(
            (f) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _featureRow(icon: f.icon, text: f.text),
            ),
          ),
        ],
      ),
    );
  }

  Widget _roiTierOverviewCard() {
    final tiers = [
      (label: '3 Month', rate: '0.30%', sub: 'Short term'),
      (label: '6 Month', rate: '0.35%', sub: 'Mid term'),
      (label: '12 Month', rate: '0.45%', sub: 'Wealth preservation'),
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bar_chart_rounded, size: 20, color: _brandGreen),
              const SizedBox(width: 10),
              Text(
                'Daily ROI by tenure',
                style: GoogleFonts.poppins(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w700,
                  color: _titleDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: tiers
                .map(
                  (t) => Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        children: [
                          Text(
                            t.rate,
                            style: GoogleFonts.poppins(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: _brandGreen,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            t.label,
                            style: GoogleFonts.poppins(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: _titleDark,
                            ),
                          ),
                          Text(
                            t.sub,
                            style: GoogleFonts.poppins(
                              fontSize: 9.5,
                              color: _subtitleGrey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _rulesCard() {
    final rules = [
      'Monthly instalments must be paid on or after the due date each month.',
      'The first payment requires admin approval before the plan becomes active.',
      'Principal is locked for the selected tenure and returned in full on maturity.',
      'Start Date is fixed at admin approval and never changes for the life of the plan.',
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.rule_folder_outlined,
                size: 20,
                color: _brandGreen,
              ),
              const SizedBox(width: 10),
              Text(
                'Plan rules',
                style: GoogleFonts.poppins(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w700,
                  color: _titleDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...rules.map(
            (r) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        color: _brandGreen,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      r,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: const Color(0xFF374151),
                        height: 1.5,
                      ),
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

  Widget _continueButton({required String label, required VoidCallback onTap}) {
    return Container(
      width: 220,
      height: 48,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: _bannerGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: _bannerGradient.last.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _white,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.arrow_forward_rounded, size: 16, color: _white),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HAS ACTIVE PLAN(S) → current plan details only + Continue Another Plan
  // ═══════════════════════════════════════════════════════════════════════════
  List<Widget> _buildActivePlansFlow(
    BuildContext context,
    List<ActivePlan> activePlans,
    Set<PlanType> activeTypes,
    List<PlanType> remainingTypes,
  ) {
    return [
      for (int i = 0; i < activePlans.length; i++) ...[
        _currentPlanCard(context, activePlans[i]),
        const SizedBox(height: 16),
      ],
      if (remainingTypes.isEmpty) _allPlansEnrolledNotice(),
    ];
  }

  Widget _allPlansEnrolledNotice() {
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
              'You\'ve enrolled in all available plans (3, 6 & 12 month).',
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

  Widget _currentPlanCard(BuildContext context, ActivePlan plan) {
    final isRunning =
        plan.status == PlanStatus.active || plan.status == PlanStatus.approved;
    final statusAccent = _statusAccentColor(plan.status);
    final (_, __, badgeIcon) = _statusColors(plan.status);

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
          BoxShadow(
            color: _bannerGradient.last.withValues(alpha: 0.32),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: same gradient as the Home screen banners ────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: _bannerGradient,
              ),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Subtle decorative ring watermark — restrained signature touch.
                Positioned(
                  right: -36,
                  top: -46,
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.10),
                        width: 26,
                      ),
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          plan.planType.displayName.toUpperCase(),
                          style: GoogleFonts.poppins(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.55),
                            letterSpacing: 2.2,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.14),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(badgeIcon, size: 11, color: statusAccent),
                              const SizedBox(width: 5),
                              Text(
                                plan.status.displayLabel.toUpperCase(),
                                style: GoogleFonts.poppins(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Current Plan',
                      style: GoogleFonts.poppins(
                        fontSize: 25,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.15,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          decoration: const BoxDecoration(
                            color: _gold,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 7),
                        Text(
                          '${plan.planType.rateLabel} Daily ROI',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _gold,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Body ──────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _statTile(
                        Icons.account_balance_wallet_outlined,
                        'Invested Amount',
                        '₹${_inr(plan.totalPrincipal)}',
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 44,
                      margin: const EdgeInsets.symmetric(horizontal: 14),
                      color: const Color(0xFFEFF1F4),
                    ),
                    Expanded(
                      child: _statTile(
                        Icons.trending_up_rounded,
                        'Accrued ROI',
                        '₹${plan.accruedRoi.toStringAsFixed(0)}',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, color: Color(0xFFF0F2F5)),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _statTile(
                        Icons.redeem_outlined,
                        'Claim ROI',
                        '₹${plan.pendingRoi.toStringAsFixed(0)}',
                        accent: _gold,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 44,
                      margin: const EdgeInsets.symmetric(horizontal: 14),
                      color: const Color(0xFFEFF1F4),
                    ),
                    Expanded(
                      child: _statTile(
                        Icons.hourglass_bottom_rounded,
                        'Remaining',
                        '₹${_inr(plan.remainingAmount)}',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                _paymentProgressBar(plan),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pushNamed(
                            context,
                            AppRoutes.activePlan,
                            arguments: {'plan': plan},
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _brandGreen,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(26),
                            ),
                            elevation: 0,
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'View Details',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: _white,
                                    letterSpacing: 0.1,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 15,
                                  color: _white,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (isRunning && plan.pendingRoi > 0) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: SizedBox(
                          height: 52,
                          child: OutlinedButton(
                            onPressed: () => Navigator.pushNamed(
                              context,
                              AppRoutes.activePlan,
                              arguments: {'plan': plan},
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _brandGreen,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              side: const BorderSide(
                                color: _brandGreen,
                                width: 1.4,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(26),
                              ),
                            ),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'Claim ROI',
                                style: GoogleFonts.poppins(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: _brandGreen,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Icon-led stat tile — replaces the old boxed grey grid cell with a
  /// quieter, more editorial pairing of a soft icon chip, an uppercase
  /// tracked label, and a bold value. [accent] lets specific stats (e.g.
  /// Claim ROI) pick up the gold accent instead of brand green.
  Widget _statTile(
    IconData icon,
    String label,
    String value, {
    Color accent = _brandGreen,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.09),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 16, color: accent),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                  color: _subtitleGrey,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: _titleDark,
                  letterSpacing: -0.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _paymentProgressBar(ActivePlan plan) {
    final pct = (plan.progressPercent.clamp(0.0, 1.0) * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Payment Progress',
              style: GoogleFonts.poppins(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: _titleDark,
                letterSpacing: 0.1,
              ),
            ),
            Row(
              children: [
                Text(
                  '${plan.monthsPaid} of ${plan.totalMonths} months',
                  style: GoogleFonts.poppins(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: _subtitleGrey,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _brandGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$pct%',
                    style: GoogleFonts.poppins(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: _brandGreen,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            children: [
              Container(
                height: 10,
                decoration: const BoxDecoration(color: Color(0xFFEFF1F4)),
              ),
              FractionallySizedBox(
                widthFactor: plan.progressPercent.clamp(0.0, 1.0),
                child: Container(
                  height: 10,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_brandGreen, Color(0xFF34A166)],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Bright accent used for the status dot/icon against the dark header —
  /// distinct from [_statusColors], whose tones are tuned for a light pill.
  Color _statusAccentColor(PlanStatus s) {
    switch (s) {
      case PlanStatus.underReview:
        return const Color(0xFFFBBF24);
      case PlanStatus.approved:
      case PlanStatus.active:
        return const Color(0xFF4ADE80);
      case PlanStatus.completed:
        return const Color(0xFFA78BFA);
      case PlanStatus.rejected:
        return const Color(0xFFF87171);
    }
  }

  (Color, Color, IconData) _statusColors(PlanStatus s) {
    switch (s) {
      case PlanStatus.underReview:
        return (
          const Color(0xFFFEF3C7),
          const Color(0xFFD97706),
          Icons.schedule_rounded,
        );
      case PlanStatus.approved:
        return (
          const Color(0xFFECFDF5),
          _brandGreen,
          Icons.check_circle_rounded,
        );
      case PlanStatus.active:
        return (
          const Color(0xFFECFDF5),
          _brandGreen,
          Icons.check_circle_rounded,
        );
      case PlanStatus.completed:
        return (
          const Color(0xFFF5F3FF),
          const Color(0xFF7C3AED),
          Icons.verified_rounded,
        );
      case PlanStatus.rejected:
        return (
          const Color(0xFFFEF2F2),
          const Color(0xFFDC2626),
          Icons.cancel_rounded,
        );
    }
  }

  String _inr(int n) {
    if (n <= 0) return '0';
    final s = n.toString();
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

  Widget _featureRow({required IconData icon, required String text}) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 18, color: _brandGreen.withValues(alpha: 0.7)),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          text,
          style: GoogleFonts.poppins(
            fontSize: 13.5,
            fontWeight: FontWeight.w400,
            color: const Color(0xFF374151),
            height: 1.5,
          ),
        ),
      ),
    ],
  );

  // ── Bottom nav ─────────────────────────────────────────────────────────────
  void _onNavTap(int i) {
    if (i == 1) return;
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
  }

  Widget _buildBottomNav() {
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
                  onTap: () => _onNavTap(i),
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