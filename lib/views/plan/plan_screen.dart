import 'package:flutter/material.dart';
import 'package:moneytries/config/app_fonts.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/plan/plan_models.dart';
import '../../routes/app_routes.dart';
import '../../viewmodels/plan/plan_viewmodel.dart';
import '../../utils/responsive.dart';
import '../../widgets/animations/animations.dart';
import '../../widgets/premium/premium.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _bgColor = Color(0xFFF7F5F2);
const _white = Color(0xFFFFFFFF);
const _subtitleGrey = Color(0xFF6B7280);
const _titleDark = Color(0xFF111827);
const _brandGreen = Color(0xFF1F6B45); // banner dark green (text/icons)
const _cardBg = Color(0xFFFFFFFF);
const _accentBrown = Color(0xFFB98A5E);
// Home page banner gradient — mint → light sea-green
const _bannerGradient = [Color(0xFFDCF3E5), Color(0xFF9AE0BC)];
// Vault motif recoloured to match banner palette
const _vaultGreen = Color(0xFFDCF3E5); // banner gradient start
const _vaultGreenDeep = Color(0xFF9AE0BC); // banner gradient end
const _vaultTextDark = Color(0xFF1F6B45); // banner tag dark green
const _ledgerPaper = Color(0xFFFBF9F5);
const _ledgerHairline = Color(0xFFE8E4DA);
const _accentBrownSoft = Color(0xFFE7D8C3);
const _accentBrownDeep = Color(0xFF8A6440);
const _brandGreenDeep = Color(0xFF1F6B45); // same banner dark green
const _noticeBrownBg = Color(0xFFF4EBDD);
const _noticeBrownBorder = Color(0xFFE0CBA8);

/// Redesigned Investment Plan flow:
///
///  • No active plan  → Plan Info (benefits / ROI / features / rules) with a
///    single "Continue" button → Enter Investment Amount → Compare ALL plans
///    (3M / 6M / 12M) → Select Plan → T&C → Submit Request → Admin Approval →
///    Payment → Active Plan.
///
///  • Has active plan(s) → show ONLY the current plan's details (ROI,
///    Invested Amount, Accrued ROI, Maturity Progress, Claim ROI, ...) for
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

  /// Navigates into the "enter amount → compare plans" flow. Plans can be
  /// viewed and enrolled in without KYC verification — KYC is required only
  /// for Deposit and Withdrawal (see depositController.js /
  /// withdrawalController.js on the backend). [excludeTypes] carries the
  /// plan types the user already holds (active/approved/under review) so
  /// the comparison screen only shows the plans still available to them.
  Future<void> _navigateToInvest(
    BuildContext ctx, {
    List<PlanType> excludeTypes = const [],
  }) async {
    // Pre Plan has no fixed duration — if it's still available (i.e. not
    // already active/under review), ask for its 3–80 day duration up
    // front so the comparison screen can show it alongside the fixed
    // 3/6/12 month tiers. If Pre Plan is already active, it's in
    // excludeTypes and this is skipped entirely.
    int? prePlanDays;
    if (!excludeTypes.contains(PlanType.prePlan)) {
      prePlanDays = await _askPrePlanDuration(ctx);
      if (prePlanDays == null) return; // user cancelled
    }
    if (!ctx.mounted) return;

    final args = <String, dynamic>{
      if (excludeTypes.isNotEmpty)
        'excludeTypes': excludeTypes.map((t) => t.name).toList(),
      if (prePlanDays != null) 'prePlanDays': prePlanDays,
    };

    Navigator.pushNamed(
      ctx,
      AppRoutes.investmentAmount,
      arguments: args.isEmpty ? null : args,
    );
  }

  /// Prompts for Pre Plan's duration (3–80 days) before showing the plan
  /// comparison. Returns the chosen day count, or null if the user
  /// cancelled (in which case the caller should abort navigation).
  Future<int?> _askPrePlanDuration(BuildContext ctx) async {
    final controller = TextEditingController();
    String? errorText;

    return showDialog<int>(
      context: ctx,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            void submit() {
              final days = int.tryParse(controller.text.trim());
              if (days == null || days < 3 || days > 80) {
                setDialogState(() {
                  errorText = 'Enter a number of days between 3 and 80';
                });
                return;
              }
              Navigator.pop(dialogCtx, days);
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20.r),
              ),
              title: Row(
                children: [
                  Icon(
                    Icons.timelapse_rounded,
                    color: _brandGreen,
                    size: 22.sp,
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      'Pre Plan Duration',
                      style: TextStyle(
                        fontFamily: AppFonts.primary,
                        fontFamilyFallback: AppFonts.fallbacks,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF111827),
                      ),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pre Plan is available — enter how many days you\'d like to run it for (3–80 days) to see it in the comparison.',
                    style: TextStyle(
                      fontFamily: AppFonts.primary,
                      fontFamilyFallback: AppFonts.fallbacks,
                      fontSize: 13.sp,
                      color: const Color(0xFF6B7280),
                      height: 1.5,
                    ),
                  ),
                  SizedBox(height: 14.h),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    // Digits only — blocks letters/symbols at the input
                    // level (not just at submit-time validation), and caps
                    // length at 2 digits since the max valid value is 80.
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(2),
                    ],
                    onChanged: (_) {
                      if (errorText != null) {
                        setDialogState(() => errorText = null);
                      }
                    },
                    onSubmitted: (_) => submit(),
                    decoration: InputDecoration(
                      hintText: 'e.g. 30',
                      errorText: errorText,
                      isDense: true,
                      suffixText: 'days',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                    ),
                    style: TextStyle(
                      fontFamily: AppFonts.primary,
                      fontFamilyFallback: AppFonts.fallbacks,
                      fontSize: 14.sp,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx, null),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      fontFamily: AppFonts.primary,
                      fontFamilyFallback: AppFonts.fallbacks,
                      fontSize: 13.sp,
                      color: const Color(0xFF9CA3AF),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: submit,
                  child: Text(
                    'Continue',
                    style: TextStyle(
                      fontFamily: AppFonts.primary,
                      fontFamilyFallback: AppFonts.fallbacks,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                      color: _brandGreen,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
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
                    child: RefreshIndicator(
                      color: _brandGreen,
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
                          _buildHeader(vm),
                          SizedBox(height: 24.h),
                          if (vm.listState == PlanVmState.loading &&
                              vm.plans.isEmpty)
                            Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 40.h),
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
                          // ── "Continue Another Plan" — scrolls with content,
                          // appears after all plan cards ─────────────────────
                          if (showContinueBtn)
                            Padding(
                              padding: EdgeInsets.fromLTRB(0, 32.h, 0, 8.h),
                              child: Center(
                                child: _continueButton(
                                  label: 'Continue Another Plan',
                                  onTap: () => _navigateToInvest(
                                    context,
                                    excludeTypes: activeTypes.toList(),
                                  ),
                                ),
                              ),
                            ),
                          SizedBox(height: 28.h),
                        ],
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
  Widget _buildHeader(PlanViewModel vm) {
    final isRefreshing = vm.listState == PlanVmState.loading;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Investment Plans',
                style: TextStyle(
                  fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                  fontSize: 28.sp,
                  fontWeight: FontWeight.w800,
                  color: _titleDark,
                  height: 1.18,
                  letterSpacing: -0.5,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                'Choose a plan and grow your wealth with\ndaily ROI credited directly to your wallet.',
                style: TextStyle(
                  fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w400,
                  color: _subtitleGrey,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: 12.w),
        GestureDetector(
          onTap: isRefreshing
              ? null
              : () => context.read<PlanViewModel>().loadPlans(),
          child: Container(
            width: 40.w,
            height: 40.h,
            margin: EdgeInsets.only(top: 2.h),
            decoration: BoxDecoration(
              color: _white,
              borderRadius: BorderRadius.circular(12.r),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: isRefreshing
                  ? SizedBox(
                      width: 18.w,
                      height: 18.w,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(_brandGreen),
                      ),
                    )
                  : Icon(
                      Icons.refresh_rounded,
                      size: 20.sp,
                      color: _titleDark,
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildApiErrorNotice(PlanViewModel vm) {
    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: _noticeBrownBg,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: _noticeBrownBorder, width: 1.r),
      ),
      child: Row(
        children: [
          Icon(Icons.wifi_off_rounded, size: 16.sp, color: _accentBrownDeep),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              'Could not load plan status. Plan info is still available below.',
              style: TextStyle(
                fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                fontSize: 12.sp,
                color: _accentBrownDeep,
                height: 1.4,
              ),
            ),
          ),
          SizedBox(width: 8.w),
          GestureDetector(
            onTap: () => vm.loadPlans(),
            child: Text(
              'Retry',
              style: TextStyle(
                fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
                color: _accentBrownDeep,
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
            text: 'Flexible tenures — 3, 6, 12 months, or a 3–80 day Pre Plan.',
          ),
          (
            icon: Icons.support_agent_outlined,
            text: 'Priority support and dedicated relationship assistance.',
          ),
        ],
      ),
      SizedBox(height: 16.h),
      _roiTierOverviewCard(),
      SizedBox(height: 16.h),
      _infoSectionCard(
        title: 'How it works',
        icon: Icons.timeline_rounded,
        children: const [
          (
            icon: Icons.payments_outlined,
            text: 'Pay your investment amount once from your wallet balance.',
          ),
          (
            icon: Icons.fact_check_outlined,
            text: 'Your payment is reviewed and approved by our admin team.',
          ),
          (
            icon: Icons.bolt_rounded,
            text: 'Once approved, daily ROI starts accruing automatically.',
          ),
          (
            icon: Icons.account_balance_wallet_outlined,
            text: 'Withdraw accrued ROI to your wallet anytime.',
          ),
          (
            icon: Icons.lock_outline_rounded,
            text: 'Your invested amount stays locked until the plan matures.',
          ),
          (
            icon: Icons.lock_open_rounded,
            text:
                'At maturity, your locked amount is credited back to your wallet automatically.',
          ),
        ],
      ),
      SizedBox(height: 16.h),
      _rulesCard(),
      SizedBox(height: 24.h),
      _continueButton(
        label: 'Continue',
        onTap: () => _navigateToInvest(context),
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
      padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 20.h),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(22.r),
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
              Icon(icon, size: 20.sp, color: _brandGreen),
              SizedBox(width: 10.w),
              Text(
                title,
                style: TextStyle(
                  fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                  fontSize: 16.5.sp,
                  fontWeight: FontWeight.w700,
                  color: _titleDark,
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          ...children.map(
            (f) => Padding(
              padding: EdgeInsets.only(bottom: 12.h),
              child: _featureRow(icon: f.icon, text: f.text),
            ),
          ),
        ],
      ),
    );
  }

  Widget _roiTierOverviewCard() {
    final fixedTiers = [
      (label: '3 Month', rate: '0.30%', sub: 'Short term'),
      (label: '6 Month', rate: '0.40%', sub: 'Mid term'),
      (label: '12 Month', rate: '0.50%', sub: 'Wealth preservation'),
    ];
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 20.h),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(22.r),
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
              Icon(Icons.bar_chart_rounded, size: 20.sp, color: _brandGreen),
              SizedBox(width: 10.w),
              Text(
                'Daily ROI by plan',
                style: TextStyle(
                  fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                  fontSize: 16.5.sp,
                  fontWeight: FontWeight.w700,
                  color: _titleDark,
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          // Pre Plan is flexible-duration (not a fixed tenure like the 3
          // tiles below), so it gets its own "hero" row — a round rate
          // badge instead of a bare number, a NEW tag, and a proper
          // subtitle line — rather than being squeezed into the grid.
          _prePlanHeroTile(),
          SizedBox(height: 12.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int i = 0; i < fixedTiers.length; i++) ...[
                if (i > 0) SizedBox(width: 10.w),
                Expanded(child: _roiTierTile(fixedTiers[i])),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _prePlanHeroTile() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_vaultGreen, _vaultGreen.withValues(alpha: 0.55)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: _brandGreen.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 52.w,
            height: 52.w,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _brandGreen,
              shape: BoxShape.circle,
            ),
            child: Text(
              '0.20%',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                fontSize: 10.sp,
                fontWeight: FontWeight.w800,
                color: _white,
                height: 1.1,
              ),
            ),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Pre Plan',
                      style: TextStyle(
                        fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                        fontSize: 14.5.sp,
                        fontWeight: FontWeight.w800,
                        color: _titleDark,
                      ),
                    ),
                    SizedBox(width: 6.w),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 6.w,
                        vertical: 2.h,
                      ),
                      decoration: BoxDecoration(
                        color: _brandGreen,
                        borderRadius: BorderRadius.circular(6.r),
                      ),
                      child: Text(
                        'NEW',
                        style: TextStyle(
                          fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                          fontSize: 8.5.sp,
                          fontWeight: FontWeight.w800,
                          color: _white,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 3.h),
                Text(
                  'Flexible 3–80 days · One-time investment',
                  style: TextStyle(
                    fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                    fontSize: 11.sp,
                    color: _brandGreenDeep,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _roiTierTile(({String label, String rate, String sub}) t) {
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(minHeight: 96.h),
      padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 8.w),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FAF4),
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            t.rate,
            style: TextStyle(
              fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
              fontSize: 18.sp,
              fontWeight: FontWeight.w800,
              color: _brandGreen,
            ),
          ),
          SizedBox(height: 3.h),
          Text(
            t.label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
              fontSize: 11.5.sp,
              fontWeight: FontWeight.w600,
              color: _titleDark,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            t.sub,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
              fontSize: 9.sp,
              color: _subtitleGrey,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }

  Widget _rulesCard() {
    final rules = [
      'Your investment is a single one-time payment made at the start of the plan.',
      'The payment requires admin approval before the plan becomes active.',
      'Principal is locked for the selected tenure and returned in full on maturity.',
      'Start Date is fixed at admin approval and never changes for the life of the plan.',
      'Pre Plan duration is flexible — choose any term from 3 to 80 days at enrollment.',
    ];
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 20.h),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(22.r),
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
              Icon(Icons.rule_folder_outlined, size: 20.sp, color: _brandGreen),
              SizedBox(width: 10.w),
              Text(
                'Plan rules',
                style: TextStyle(
                  fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                  fontSize: 16.5.sp,
                  fontWeight: FontWeight.w700,
                  color: _titleDark,
                ),
              ),
            ],
          ),
          SizedBox(height: 14.h),
          ...rules.map(
            (r) => Padding(
              padding: EdgeInsets.only(bottom: 10.h),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.only(top: 6.h),
                    child: Container(
                      width: 5.w,
                      height: 5.h,
                      decoration: const BoxDecoration(
                        color: _brandGreen,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Text(
                      r,
                      style: TextStyle(
                        fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                        fontSize: 13.sp,
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
      width: 220.w,
      height: 48.h,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: _bannerGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14.r),
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
          borderRadius: BorderRadius.circular(14.r),
          onTap: onTap,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                  color: _brandGreen,
                  letterSpacing: 0.2,
                ),
              ),
              SizedBox(width: 6.w),
              Icon(
                Icons.arrow_forward_rounded,
                size: 16.sp,
                color: _brandGreen,
              ),
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
        StaggeredEntrance(index: i, child: _currentPlanCard(context, activePlans[i])),
        SizedBox(height: 16.h),
      ],
      if (remainingTypes.isEmpty) _allPlansEnrolledNotice(),
    ];
  }

  // ── Claim ROI (distinct from "View Details") ──────────────────────────────
  // Opens a confirm sheet and withdraws the plan's claimable ROI straight to
  // the wallet — this is the actual claim action, separate from navigating
  // into the plan's detail screen via "View Details".
  void _claimRoi(BuildContext context, ActivePlan plan) {
    final vm = context.read<PlanViewModel>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _RoiClaimSheet(
        maxAmount: plan.pendingRoi,
        onConfirm: (amount) async {
          await vm.withdrawRoi(planId: plan.id, amount: amount);
          if (!mounted) return;
          _toast(
            vm.roiState == PlanVmState.success
                ? 'ROI claim of ₹ ${amount.toStringAsFixed(2)} initiated!'
                : vm.roiError ?? 'ROI claim failed. Please try again.',
          );
        },
      ),
    );
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: TextStyle(fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks, fontSize: 13.sp),
        ),
        backgroundColor: _brandGreen,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _allPlansEnrolledNotice() {
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
              'You\'ve enrolled in all available plans (Pre Plan, 3, 6 & 12 month).',
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

  Widget _currentPlanCard(BuildContext context, ActivePlan plan) {
    final isRunning =
        plan.status == PlanStatus.active || plan.status == PlanStatus.approved;
    final statusAccent = _statusAccentColor(plan.status);
    final (_, __, badgeIcon) = _statusColors(plan.status);

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _ledgerPaper,
        borderRadius: BorderRadius.circular(28.r),
        boxShadow: [
          BoxShadow(
            color: _vaultGreen.withValues(alpha: 0.16),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Seal panel: a vault door, not a gradient banner ───────────────
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(22.w, 22.h, 22.w, 26.h),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_vaultGreen, _vaultGreenDeep],
              ),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Bolt-circle watermark — the vault-door motif this card is
                // built around, echoed later by the maturity dial below.
                Positioned(
                  right: -30,
                  bottom: -54,
                  child: Container(
                    width: 168.w,
                    height: 168.h,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _accentBrown.withValues(alpha: 0.14),
                        width: 1.r,
                      ),
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.shield_outlined,
                                  size: 11.sp,
                                  color: _accentBrown.withValues(alpha: 0.85),
                                ),
                                SizedBox(width: 6.w),
                                Text(
                                  'VAULT · ${plan.planType.displayName.toUpperCase()}',
                                  style: TextStyle(
                                    fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                                    fontSize: 10.5.sp,
                                    fontWeight: FontWeight.w600,
                                    color: _accentBrown.withValues(alpha: 0.85),
                                    letterSpacing: 2.4,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 14.h),
                            // ── Invested amount ─────────────────────────────
                            // Always the amount the user actually paid at
                            // enrollment (plan.totalCommitment == monthlyAmount,
                            // the one-time payment — see ActivePlan). This is
                            // the SAME figure and the SAME backend field the
                            // Plan Dashboard (active_plan_screen.dart) reads,
                            // so this card and the dashboard can never show
                            // different numbers for the same plan again.
                            //
                            // Deliberately NOT plan.totalPrincipal
                            // (monthlyAmount × monthsPaid): monthsPaid is 0
                            // until admin approval, which made this figure
                            // incorrectly show ₹0 for an Under Review plan
                            // even though the user had already paid in full.
                            Text(
                              '₹ ${_inr(plan.totalCommitment)}',
                              style: TextStyle(
                                fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                                fontSize: 34.sp,
                                fontWeight: FontWeight.w800,
                                color: _vaultTextDark,
                                height: 1.0,
                                letterSpacing: -0.8,
                              ),
                            ),
                            SizedBox(height: 6.h),
                            Text(
                              plan.status == PlanStatus.underReview
                                  // Under review: money is paid but not yet
                                  // locked/earning — say so plainly instead
                                  // of implying it's already sealed/accruing.
                                  ? 'Under review · locks once approved'
                                  : 'Sealed principal · ${plan.planType.rateLabel} daily',
                              style: TextStyle(
                                fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w500,
                                color: _vaultTextDark.withValues(alpha: 0.62),
                                letterSpacing: 0.1,
                              ),
                            ),
                          ],
                        ),
                        // Wax-seal status badge — replaces the old pill.
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              width: 38.w,
                              height: 38.h,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.55),
                                border: Border.all(
                                  color: statusAccent.withValues(alpha: 0.55),
                                  width: 1.2.r,
                                ),
                              ),
                              child: Icon(
                                badgeIcon,
                                size: 16.sp,
                                color: statusAccent,
                              ),
                            ),
                            SizedBox(height: 6.h),
                            Text(
                              plan.status.displayLabel,
                              style: TextStyle(
                                fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                                fontSize: 9.sp,
                                fontWeight: FontWeight.w700,
                                color: statusAccent,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Body: dial + ledger, on warm paper ────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(22.w, 22.h, 22.w, 22.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _MaturityDial(plan: plan),
                    SizedBox(width: 20.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _ledgerRow(
                            'Accrued ROI',
                            '₹ ${plan.accruedRoi.toStringAsFixed(0)}',
                          ),
                          _ledgerDivider(),
                          _ledgerRow(
                            'Claimable now',
                            '₹ ${plan.pendingRoi.toStringAsFixed(0)}',
                            accent: _accentBrown,
                            emphasis: true,
                          ),
                          _ledgerDivider(),
                          _ledgerRow(
                            'Matures on',
                            _fmtShortDate(plan.maturityDate),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 22.h),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 50.h,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pushNamed(
                            context,
                            AppRoutes.activePlan,
                            arguments: {'plan': plan},
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _vaultGreen,
                            shadowColor: Colors.transparent,
                            padding: EdgeInsets.symmetric(horizontal: 4.w),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14.r),
                            ),
                            elevation: 0,
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'VIEW DETAILS',
                                  style: TextStyle(
                                    fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                                    fontSize: 12.5.sp,
                                    fontWeight: FontWeight.w700,
                                    color: _vaultTextDark,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                                SizedBox(width: 6.w),
                                Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 14.sp,
                                  color: _vaultTextDark,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (isRunning && plan.pendingRoi > 0) ...[
                      SizedBox(width: 10.w),
                      Expanded(
                        child: SizedBox(
                          height: 50.h,
                          child: ElevatedButton(
                            onPressed: () => _claimRoi(context, plan),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _vaultGreen,
                              shadowColor: Colors.transparent,
                              padding: EdgeInsets.symmetric(horizontal: 4.w),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14.r),
                              ),
                              elevation: 0,
                            ),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'CLAIM ROI',
                                style: TextStyle(
                                  fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                                  fontSize: 12.5.sp,
                                  fontWeight: FontWeight.w700,
                                  color: _vaultTextDark,
                                  letterSpacing: 1.1,
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

  /// A two-column ledger line: label left, tabular value right, hairline
  /// beneath. Replaces the old icon-chip stat grid with something that
  /// reads like an actual account statement.
  Widget _ledgerRow(
    String label,
    String value, {
    Color accent = _titleDark,
    bool emphasis = false,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 7.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
              color: _subtitleGrey,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
              fontSize: emphasis ? 15.sp : 13.5.sp,
              fontWeight: FontWeight.w800,
              color: accent,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _ledgerDivider() =>
      Divider(height: 1.h, thickness: 1.r, color: _ledgerHairline);

  static const _shortMonths = [
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
  ];

  String _fmtShortDate(DateTime d) =>
      '${d.day} ${_shortMonths[d.month - 1]} ${d.year}';

  /// Bright accent used for the status dot/icon against the dark header —
  /// distinct from [_statusColors], whose tones are tuned for a light pill.
  Color _statusAccentColor(PlanStatus s) {
    switch (s) {
      case PlanStatus.underReview:
        return _accentBrownDeep;
      case PlanStatus.approved:
      case PlanStatus.active:
        return _brandGreen;
      case PlanStatus.completed:
        return _brandGreenDeep;
      case PlanStatus.rejected:
        return _accentBrown;
    }
  }

  (Color, Color, IconData) _statusColors(PlanStatus s) {
    switch (s) {
      case PlanStatus.underReview:
        return (_accentBrownSoft, _accentBrownDeep, Icons.schedule_rounded);
      case PlanStatus.approved:
        return (
          const Color(0xFFE8F5EE),
          _brandGreen,
          Icons.check_circle_rounded,
        );
      case PlanStatus.active:
        return (
          const Color(0xFFE8F5EE),
          _brandGreen,
          Icons.check_circle_rounded,
        );
      case PlanStatus.completed:
        return (_vaultGreen, _brandGreenDeep, Icons.verified_rounded);
      case PlanStatus.rejected:
        return (_accentBrownSoft, _accentBrown, Icons.cancel_rounded);
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
      Icon(icon, size: 18.sp, color: _brandGreen.withValues(alpha: 0.7)),
      SizedBox(width: 10.w),
      Expanded(
        child: Text(
          text,
          style: TextStyle(
            fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
            fontSize: 13.5.sp,
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
    const selIdx = 1;
    return PremiumBottomNav(
      selectedIndex: selIdx,
      onTap: _onNavTap,
      backgroundColor: _white,
      items: const [
        PremiumNavItem(icon: Icons.home_rounded),
        PremiumNavItem(icon: Icons.trending_up_rounded),
        PremiumNavItem(icon: Icons.history_rounded),
        PremiumNavItem(icon: Icons.person_rounded),
      ],
    );
  }
}

/// The signature element of the Current Plan card: a vault-dial gauge in
/// place of a linear "progress bar". The arc traces the plan's journey to
/// maturity — the same act, visually, as a combination dial turning toward
/// the point a vault unlocks. Center shows days remaining (or "Ready" once
/// matured), not a bare percentage, since that's the number a holder of a
/// locked plan actually wants to know.
class _MaturityDial extends StatelessWidget {
  const _MaturityDial({required this.plan});

  final ActivePlan plan;

  @override
  Widget build(BuildContext context) {
    final progress = plan.progressPercent.clamp(0.0, 1.0);
    final matured = plan.isMatured;
    return SizedBox(
      width: 104.w,
      height: 104.w,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(104.w, 104.w),
            painter: _MaturityDialPainter(
              progress: matured ? 1.0 : progress,
              trackColor: _ledgerHairline,
              progressColor: matured ? _accentBrown : _brandGreen,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                matured ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
                size: 15.sp,
                color: matured ? _accentBrown : _brandGreen,
              ),
              SizedBox(height: 4.h),
              Text(
                matured ? 'Ready' : '${plan.daysUntilMaturity}',
                style: TextStyle(
                  fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                  fontSize: matured ? 15.sp : 22.sp,
                  fontWeight: FontWeight.w800,
                  color: _titleDark,
                  height: 1.0,
                  letterSpacing: -0.3,
                ),
              ),
              if (!matured) ...[
                SizedBox(height: 2.h),
                Text(
                  'days left',
                  style: TextStyle(
                    fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                    fontSize: 9.5.sp,
                    fontWeight: FontWeight.w600,
                    color: _subtitleGrey,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _MaturityDialPainter extends CustomPainter {
  _MaturityDialPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
  });

  final double progress;
  final Color trackColor;
  final Color progressColor;

  static const double _strokeWidth = 8;
  static const double _startAngle = -1.5707963267948966; // -90°, 12 o'clock

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - _strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, 6.283185307179586, false, trackPaint);

    if (progress > 0) {
      final progressPaint = Paint()
        ..color = progressColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = _strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        rect,
        _startAngle,
        6.283185307179586 * progress,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MaturityDialPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.progressColor != progressColor;
}

/// Confirm sheet for the "Claim ROI" action on the Plan list card. Kept
/// visually distinct from the plan's own detail screen — this is a quick
/// claim shortcut, not a navigation shortcut — and stays within the
/// light-green / light-brown palette used across this screen.
class _RoiClaimSheet extends StatefulWidget {
  const _RoiClaimSheet({required this.maxAmount, required this.onConfirm});

  final double maxAmount;
  final void Function(double amount) onConfirm;

  @override
  State<_RoiClaimSheet> createState() => _RoiClaimSheetState();
}

class _RoiClaimSheetState extends State<_RoiClaimSheet> {
  final _ctrl = TextEditingController();
  String? _error;
  double _enteredAmount = 0;

  @override
  void initState() {
    super.initState();
    _ctrl.text = widget.maxAmount.toStringAsFixed(2);
    _enteredAmount = widget.maxAmount;
  }

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
          color: _ledgerPaper,
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
                  color: _ledgerHairline,
                  borderRadius: BorderRadius.circular(4.r),
                ),
              ),
            ),
            SizedBox(height: 20.h),
            Text(
              'Claim Your ROI',
              style: TextStyle(
                fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                fontSize: 20.sp,
                fontWeight: FontWeight.w700,
                color: _titleDark,
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              'Enter the amount to claim. It will be credited to your Wallet Balance.',
              style: TextStyle(
                fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                fontSize: 13.sp,
                color: _subtitleGrey,
                height: 1.5,
              ),
            ),
            SizedBox(height: 20.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
              decoration: BoxDecoration(
                color: _vaultGreen,
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Claimable Now',
                    style: TextStyle(
                      fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                      fontSize: 12.sp,
                      color: _vaultTextDark,
                    ),
                  ),
                  Text(
                    '₹ ${widget.maxAmount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w800,
                      color: _vaultTextDark,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16.h),
            Container(
              decoration: BoxDecoration(
                color: _ledgerPaper,
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(
                  color: _error != null ? _accentBrown : _ledgerHairline,
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
                  color: _titleDark,
                ),
                decoration: InputDecoration(
                  hintText: '0.00',
                  hintStyle: TextStyle(
                    fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w400,
                    color: _subtitleGrey,
                  ),
                  prefixText: '₹ ',
                  prefixStyle: TextStyle(
                    fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w700,
                    color: _titleDark,
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
                        color: _vaultGreen,
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Text(
                        'MAX',
                        style: TextStyle(
                          fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w700,
                          color: _brandGreenDeep,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (_error != null) ...[
              SizedBox(height: 6.h),
              Row(
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 13.sp,
                    color: _accentBrown,
                  ),
                  SizedBox(width: 5.w),
                  Text(
                    _error!,
                    style: TextStyle(
                      fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                      fontSize: 11.5.sp,
                      color: _accentBrown,
                    ),
                  ),
                ],
              ),
            ],
            SizedBox(height: 24.h),
            SizedBox(
              width: double.infinity,
              height: 54.h,
              child: AnimatedOpacity(
                opacity: _isValid ? 1.0 : 0.5,
                duration: const Duration(milliseconds: 200),
                child: ElevatedButton(
                  onPressed: _isValid ? _submit : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accentBrown,
                    disabledBackgroundColor: _accentBrown,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28.r),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    _isValid
                        ? 'Claim ₹ ${_enteredAmount.toStringAsFixed(2)}'
                        : 'Claim Now',
                    style: TextStyle(
                      fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                      fontSize: 16.sp,
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