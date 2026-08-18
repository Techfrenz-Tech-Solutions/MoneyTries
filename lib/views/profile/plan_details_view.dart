import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:moneytries/config/app_fonts.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/plan/plan_models.dart';
import '../../routes/app_routes.dart';
import '../../viewmodels/plan/plan_viewmodel.dart';
import '../../utils/responsive.dart';
import '../../core/api/api_config.dart';

// ── Premium Fintech Palette — light green / light brown / beige / white ────
// Deliberately NO dark/deep green anywhere in this file.
const _bg = Color(0xFFF8F6F0);
const _white = Color(0xFFFFFFFF);
const _dark = Color(0xFF2B2620);
const _grey = Color(0xFF6B6459);
const _greyLight = Color(0xFF9B9488);
const _divider = Color(0xFFEEE8DC);

const _green = Color(0xFF1F6B45); // banner dark green
const _greenSoft = Color(0xFF9AE0BC); // banner gradient end
const _greenSurface = Color(0xFFDCF3E5); // banner gradient start
const _greenBorder = Color(0xFF9AE0BC); // banner gradient end
const _greenText = Color(0xFF1F6B45); // banner dark green

const _brown = Color(0xFFC29868); // light brown accent
const _brownSoft = Color(0xFFDAB68C);
const _brownSurface = Color(0xFFF7EFE3);
const _brownBorder = Color(0xFFEAD9BE);
const _brownText = Color(0xFF9C7443);

const _rose = Color(0xFFE0847C); // muted, used only for rejected status
const _roseSurface = Color(0xFFFBEAE8);

class PlanDetailsView extends StatefulWidget {
  const PlanDetailsView({super.key});

  @override
  State<PlanDetailsView> createState() => _PlanDetailsViewState();
}

class _PlanDetailsViewState extends State<PlanDetailsView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pageAnim;

  @override
  void initState() {
    super.initState();
    _pageAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 560),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PlanViewModel>().loadPlans();
      _pageAnim.forward();
    });
  }

  @override
  void dispose() {
    _pageAnim.dispose();
    super.dispose();
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
                            color: _green,
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
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 6.h),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 38.w,
              height: 38.h,
              decoration: BoxDecoration(
                color: _white,
                borderRadius: BorderRadius.circular(13.r),
                border: Border.all(color: _divider, width: 1.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: _dark,
                size: 15.sp,
              ),
            ),
          ),
          SizedBox(width: 12.w),
          Text(
            'Plan Details',
            style: TextStyle(
              fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
              fontSize: 19.sp,
              fontWeight: FontWeight.w800,
              color: _dark,
              letterSpacing: -0.3,
            ),
          ),
          const Spacer(),
          Consumer<PlanViewModel>(
            builder: (_, vm, __) {
              final active = vm.plans.where((p) => p.status.isRunning).length;
              if (active == 0) return const SizedBox.shrink();
              return Container(
                padding: EdgeInsets.symmetric(horizontal: 11.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: _greenSurface,
                  borderRadius: BorderRadius.circular(18.r),
                  border: Border.all(color: _greenBorder, width: 1.r),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _PulsingDot(color: _green),
                    SizedBox(width: 5.w),
                    Text(
                      '$active Active',
                      style: TextStyle(
                        fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                        fontSize: 11.5.sp,
                        fontWeight: FontWeight.w700,
                        color: _greenText,
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
    // Only Approved and Pending (Under Review) plans are shown here —
    // Rejected plans are excluded from this list.
    final visiblePlans = vm.plans
        .where(
          (p) =>
              p.status == PlanStatus.approved ||
              p.status == PlanStatus.underReview,
        )
        .toList();

    final sorted = [...visiblePlans]
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
      color: _green,
      onRefresh: vm.loadPlans,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: EdgeInsets.fromLTRB(18.w, 12.h, 18.w, 32.h),
        itemCount: sorted.length + 2, // overview + section label + plans
        itemBuilder: (ctx, i) {
          if (i == 0) {
            return _StaggeredEntry(index: 0, child: _buildOverviewCard(vm));
          }
          if (i == 1) {
            return _StaggeredEntry(
              index: 1,
              child: Padding(
                padding: EdgeInsets.fromLTRB(4.w, 22.h, 4.w, 12.h),
                child: Text(
                  'Your Plans',
                  style: TextStyle(
                    fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w800,
                    color: _dark,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            );
          }
          return _StaggeredEntry(
            index: i,
            child: _PlanCard(plan: sorted[i - 2]),
          );
        },
      ),
    );
  }

  // ── Portfolio Overview Card ──────────────────────────────────────────────
  Widget _buildOverviewCard(PlanViewModel vm) {
    // Total Plans = Approved + Pending (Under Review) — rejected plans are
    // excluded from this count, same as the "Only Approved and Pending"
    // filtering already used for the plans list above.
    final total = vm.plans
        .where((p) => p.status != PlanStatus.rejected)
        .length;
    final active = vm.plans.where((p) => p.status.isRunning).length;
    final completed = vm.plans
        .where((p) => p.status == PlanStatus.completed)
        .length;
    final pending = vm.plans
        .where((p) => p.status == PlanStatus.underReview)
        .length;

    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(26.r),
        border: Border.all(color: _divider, width: 1.r),
        boxShadow: [
          BoxShadow(
            color: _brown.withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 40.w,
                height: 40.h,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFDCF3E5), Color(0xFF9AE0BC)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(13.r),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF9AE0BC).withOpacity(0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.pie_chart_rounded,
                  size: 20.sp,
                  color: _green,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Portfolio Overview',
                      style: TextStyle(
                        fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                        fontSize: 15.5.sp,
                        fontWeight: FontWeight.w800,
                        color: _dark,
                        letterSpacing: -0.2,
                      ),
                    ),
                    Text(
                      'Across all investment plans',
                      style: TextStyle(
                        fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                        fontSize: 11.sp,
                        color: _greyLight,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 20.h),
          // Total principal — big number band
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 16.h),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_greenSurface, _brownSurface],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18.r),
              border: Border.all(
                color: _greenBorder.withOpacity(0.6),
                width: 1.r,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TOTAL PRINCIPAL',
                        style: TextStyle(
                          fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w700,
                          color: _brownText,
                          letterSpacing: 1.0,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      _AnimatedRupeeCounter(
                        value: vm.planAmount,
                        style: TextStyle(
                          fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                          fontSize: 28.sp,
                          fontWeight: FontWeight.w800,
                          color: _dark,
                          height: 1.05,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 8.h,
                  ),
                  decoration: BoxDecoration(
                    color: _white,
                    borderRadius: BorderRadius.circular(20.r),
                    border: Border.all(
                      color: active > 0 ? _brownBorder : _greenBorder,
                      width: 1.r,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        active > 0
                            ? Icons.lock_rounded
                            : Icons.lock_open_rounded,
                        size: 13.sp,
                        color: active > 0 ? _brownText : _greenText,
                      ),
                      SizedBox(width: 5.w),
                      Text(
                        active > 0 ? 'Locked' : 'Available',
                        style: TextStyle(
                          fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w700,
                          color: active > 0 ? _brownText : _greenText,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 14.h),
          // 2x2 stat grid
          Row(
            children: [
              Expanded(
                child: _MiniStatCard(
                  label: 'Total Plans',
                  value: total,
                  icon: Icons.list_alt_rounded,
                  accent: _green,
                  accentBg: _greenSurface,
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: _MiniStatCard(
                  label: 'Active',
                  value: active,
                  icon: Icons.bolt_rounded,
                  accent: _greenText,
                  accentBg: _greenSurface,
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          Row(
            children: [
              Expanded(
                child: _MiniStatCard(
                  label: 'Completed',
                  value: completed,
                  icon: Icons.task_alt_rounded,
                  accent: _brownText,
                  accentBg: _brownSurface,
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: _MiniStatCard(
                  label: 'Pending',
                  value: pending,
                  icon: Icons.hourglass_top_rounded,
                  accent: _brown,
                  accentBg: _brownSurface,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── KYC gate ──────────────────────────────────────────────────────────────
  Future<String> _fetchKycStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';
      if (token.isEmpty) return 'not_submitted';
      const baseUrl = ApiConfig.baseUrl;
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22.r),
        ),
        backgroundColor: _white,
        title: Row(
          children: [
            Container(
              width: 36.w,
              height: 36.h,
              decoration: BoxDecoration(
                color: kycStatus == 'pending' ? _brownSurface : _greenSurface,
                borderRadius: BorderRadius.circular(11.r),
              ),
              child: Icon(
                kycStatus == 'pending'
                    ? Icons.hourglass_top_rounded
                    : Icons.verified_user_outlined,
                color: kycStatus == 'pending' ? _brownText : _greenText,
                size: 20.sp,
              ),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w800,
                  color: _dark,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: TextStyle(
            fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
            fontSize: 13.sp,
            color: _grey,
            height: 1.5,
          ),
        ),
        actions: [
          if (kycStatus != 'pending')
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(
                  fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                  fontSize: 13.sp,
                  color: _greyLight,
                ),
              ),
            ),
          TextButton(
            onPressed: onAction,
            child: Text(
              actionLabel,
              style: TextStyle(
                fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                fontSize: 13.sp,
                fontWeight: FontWeight.w700,
                color: _greenText,
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
        padding: EdgeInsets.all(36.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 92.w,
              height: 92.h,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_greenSurface, _brownSurface],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                border: Border.all(color: _greenBorder, width: 1.r),
              ),
              child: Icon(
                Icons.pie_chart_rounded,
                size: 40.sp,
                color: _greenText,
              ),
            ),
            SizedBox(height: 22.h),
            Text(
              'No Plans Yet',
              style: TextStyle(
                fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                fontSize: 20.sp,
                fontWeight: FontWeight.w800,
                color: _dark,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'Start your first investment plan\nand grow your wealth steadily.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                fontSize: 14.sp,
                color: _grey,
                height: 1.6,
              ),
            ),
            SizedBox(height: 28.h),
            _PressableScale(
              onTap: _onStartPlan,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 30.w, vertical: 14.h),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFDCF3E5), Color(0xFF9AE0BC)],
                  ),
                  borderRadius: BorderRadius.circular(28.r),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF9AE0BC).withOpacity(0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded, color: _green, size: 20.sp),
                    SizedBox(width: 8.w),
                    Text(
                      'Start Your First Plan',
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
          ],
        ),
      ),
    );
  }

  // ── Error State ───────────────────────────────────────────────────────────
  Widget _buildErrorState(PlanViewModel vm) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72.w,
              height: 72.h,
              decoration: BoxDecoration(
                color: _roseSurface,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 34.sp,
                color: _rose,
              ),
            ),
            SizedBox(height: 16.h),
            Text(
              'Failed to load plans',
              style: TextStyle(
                fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                fontSize: 16.sp,
                fontWeight: FontWeight.w800,
                color: _dark,
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              vm.listError ?? 'Something went wrong.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                fontSize: 13.sp,
                color: _grey,
                height: 1.5,
              ),
            ),
            SizedBox(height: 20.h),
            _PressableScale(
              onTap: vm.loadPlans,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFDCF3E5), Color(0xFF9AE0BC)],
                  ),
                  borderRadius: BorderRadius.circular(24.r),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF9AE0BC).withOpacity(0.4),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Text(
                  'Retry',
                  style: TextStyle(
                    fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    color: _green,
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

// ── Mini stat card (2x2 grid tile) ──────────────────────────────────────────
class _MiniStatCard extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color accent;
  final Color accentBg;
  const _MiniStatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
    required this.accentBg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: accentBg,
        borderRadius: BorderRadius.circular(15.r),
        border: Border.all(color: accent.withOpacity(0.18), width: 1.r),
      ),
      child: Row(
        children: [
          Container(
            width: 30.w,
            height: 30.h,
            decoration: BoxDecoration(
              color: _white,
              borderRadius: BorderRadius.circular(9.r),
            ),
            child: Icon(icon, size: 15.sp, color: accent),
          ),
          SizedBox(width: 9.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _AnimatedIntCounter(
                  value: value,
                  style: TextStyle(
                    fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w800,
                    color: _dark,
                    height: 1.05,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                    fontSize: 10.sp,
                    color: _greyLight,
                  ),
                ),
              ],
            ),
          ),
        ],
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
    final isHighlighted = p.status.isRunning;

    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(
          color: isHighlighted ? _greenBorder : _divider,
          width: 1.2.r,
        ),
        boxShadow: [
          BoxShadow(
            color: _brown.withOpacity(isHighlighted ? 0.10 : 0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(18.w, 16.h, 18.w, 0),
            child: _buildCardHeader(p, statusMeta),
          ),
          _buildRingAndStats(p),
          _buildExpandToggle(),
          AnimatedSize(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            child: _expanded
                ? Column(
                    children: [
                      Container(height: 1.h, color: _divider),
                      _buildTimeline(p),
                    ],
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }

  // ── Card Header ───────────────────────────────────────────────────────────
  Widget _buildCardHeader(ActivePlan p, _StatusMeta meta) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44.w,
          height: 44.h,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_greenSurface, _brownSurface],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(
              color: _greenBorder.withOpacity(0.6),
              width: 1.r,
            ),
          ),
          child: Icon(
            Icons.trending_up_rounded,
            color: _greenText,
            size: 22.sp,
          ),
        ),
        SizedBox(width: 13.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                p.planType.displayName,
                style: TextStyle(
                  fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                  fontSize: 15.5.sp,
                  fontWeight: FontWeight.w800,
                  color: _dark,
                ),
              ),
              SizedBox(height: 3.h),
              Text(
                p.planType == PlanType.prePlan
                    ? '${p.planType.dailyRoiPercent.toStringAsFixed(2)}% daily ROI  •  ${p.totalPlanDays} days'
                    : '${p.planType.dailyRoiPercent.toStringAsFixed(2)}% daily ROI  •  ${p.planType.months} months',
                style: TextStyle(
                  fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                  fontSize: 11.5.sp,
                  color: _grey,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
          decoration: BoxDecoration(
            color: meta.bgColor,
            borderRadius: BorderRadius.circular(20.r),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (p.status.isRunning)
                _PulsingDot(color: meta.dotColor)
              else
                Container(
                  width: 6.w,
                  height: 6.h,
                  decoration: BoxDecoration(
                    color: meta.dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
              SizedBox(width: 5.w),
              Text(
                p.status.displayLabel,
                style: TextStyle(
                  fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w700,
                  color: meta.textColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Ring + Stats block ───────────────────────────────────────────────────
  Widget _buildRingAndStats(ActivePlan p) {
    final pct = p.progressPercent;
    final daysLeft = p.daysUntilMaturity;
    final ringColor = pct >= 1.0 ? _greenText : _green;
    final label = p.isPrincipalCredited
        ? 'Principal credited to wallet'
        : p.monthsPaid > 0
        ? 'Payment confirmed'
        : 'Payment pending';

    return Padding(
      padding: EdgeInsets.fromLTRB(18.w, 18.h, 18.w, 0),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ── Ring column (fixed width, centered) ────────────────────────
            SizedBox(
              width: 92.w,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _RingProgress(value: pct, color: ringColor, size: 80),
                  SizedBox(height: 8.h),
                  SizedBox(
                    width: 90.w,
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                        fontSize: 10.5.sp,
                        color: _grey,
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 14.w),
            Container(width: 1.w, color: _divider),
            SizedBox(width: 14.w),
            // ── Stat table (icon · label · value, aligned rows) ─────────────
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _StatTableRow(
                    icon: Icons.payments_rounded,
                    label: 'Invested',
                    value: '₹ ${_fmtAmount(p.monthlyAmount.toDouble())}',
                    accent: _brownText,
                    accentBg: _brownSurface,
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.h),
                    child: Container(height: 1.h, color: _divider),
                  ),
                  _StatTableRow(
                    icon: Icons.account_balance_wallet_rounded,
                    label: 'Principal',
                    value: '₹ ${_fmtAmount(p.totalPrincipal.toDouble())}',
                    accent: _greenText,
                    accentBg: _greenSurface,
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.h),
                    child: Container(height: 1.h, color: _divider),
                  ),
                  _StatTableRow(
                    icon: p.isMatured
                        ? Icons.check_circle_outline_rounded
                        : Icons.schedule_rounded,
                    label: p.isMatured ? 'Status' : 'Days Left',
                    value: p.isMatured ? 'Matured' : '$daysLeft days',
                    accent: p.isMatured ? _greenText : _brown,
                    accentBg: p.isMatured ? _greenSurface : _brownSurface,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

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
      margin: EdgeInsets.fromLTRB(18.w, 16.h, 18.w, 0),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: _brownSurface,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: _brownBorder, width: 1.r),
      ),
      child: Row(
        children: [
          Container(
            width: 36.w,
            height: 36.h,
            decoration: BoxDecoration(
              color: _white,
              borderRadius: BorderRadius.circular(11.r),
            ),
            child: Icon(Icons.savings_rounded, size: 18.sp, color: _brownText),
          ),
          SizedBox(width: 11.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Accrued ROI',
                  style: TextStyle(
                    fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                    fontSize: 10.5.sp,
                    fontWeight: FontWeight.w600,
                    color: _brownText,
                  ),
                ),
                _AnimatedRupeeCounter(
                  value: accrued,
                  style: TextStyle(
                    fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w800,
                    color: _dark,
                  ),
                ),
              ],
            ),
          ),
          Container(width: 1.w, height: 30.h, color: _brownBorder),
          SizedBox(width: 11.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Withdrawn',
                style: TextStyle(
                  fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                  fontSize: 10.5.sp,
                  color: _grey,
                ),
              ),
              _AnimatedRupeeCounter(
                value: withdrawn,
                style: TextStyle(
                  fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
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
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 15.h, horizontal: 18.w),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _expanded ? 'Hide Payment Schedule' : 'View Payment Schedule',
                  style: TextStyle(
                    fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    color: _greenText,
                  ),
                ),
                SizedBox(width: 4.w),
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 220),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: _greenText,
                    size: 20.sp,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Payment Timeline ─────────────────────────────────────────────────────
  Widget _buildTimeline(ActivePlan p) {
    final instalments = p.instalmentTable;
    return Padding(
      padding: EdgeInsets.fromLTRB(18.w, 16.h, 18.w, 18.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Payment Schedule',
            style: TextStyle(
              fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
              fontSize: 14.sp,
              fontWeight: FontWeight.w800,
              color: _dark,
            ),
          ),
          SizedBox(height: 14.h),
          ...List.generate(instalments.length, (i) {
            final inst = instalments[i];
            final isLast = i == instalments.length - 1;
            return _TimelineRow(inst: inst, plan: p, isLast: isLast);
          }),
          SizedBox(height: 10.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 11.h),
            decoration: BoxDecoration(
              color: _greenSurface,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: _greenBorder, width: 1.r),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Investment Amount',
                  style: TextStyle(
                    fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                    color: _greenText,
                  ),
                ),
                Text(
                  '₹ ${_fmtAmount(p.totalCommitment.toDouble())}',
                  style: TextStyle(
                    fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                    fontSize: 13.5.sp,
                    fontWeight: FontWeight.w800,
                    color: _greenText,
                  ),
                ),
              ],
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
          bgColor: _greenSurface,
          textColor: _greenText,
          dotColor: _green,
        );
      case PlanStatus.approved:
        return _StatusMeta(
          bgColor: _greenSurface,
          textColor: _greenText,
          dotColor: _green,
        );
      case PlanStatus.underReview:
        return _StatusMeta(
          bgColor: _brownSurface,
          textColor: _brownText,
          dotColor: _brown,
        );
      case PlanStatus.completed:
        return _StatusMeta(
          bgColor: _brownSurface,
          textColor: _brownText,
          dotColor: _brownSoft,
        );
      case PlanStatus.rejected:
        return _StatusMeta(
          bgColor: _roseSurface,
          textColor: _rose,
          dotColor: _rose,
        );
    }
  }
}

// ── Stat table row — icon chip · label (left) · value (right), aligned ─────
class _StatTableRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color accent;
  final Color accentBg;
  const _StatTableRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
    required this.accentBg,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28.w,
          height: 28.h,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: accentBg,
            borderRadius: BorderRadius.circular(9.r),
          ),
          child: Icon(icon, size: 14.sp, color: accent),
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
              fontSize: 12.sp,
              color: _grey,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
            fontSize: 13.sp,
            fontWeight: FontWeight.w800,
            color: _dark,
          ),
        ),
      ],
    );
  }
}

// ── Timeline row (vertical connector + dot + content) ──────────────────────
class _TimelineRow extends StatelessWidget {
  final PlanInstalment inst;
  final ActivePlan plan;
  final bool isLast;
  const _TimelineRow({
    required this.inst,
    required this.plan,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final isPaid = inst.isPaid;
    final isNext =
        !isPaid &&
        inst.monthNumber == plan.monthsPaid + 1 &&
        plan.status.isRunning;
    final dotColor = isPaid ? _green : (isNext ? _brown : _divider);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 22.w,
                height: 22.h,
                decoration: BoxDecoration(
                  color: isPaid
                      ? _greenSurface
                      : isNext
                      ? _brownSurface
                      : _white,
                  shape: BoxShape.circle,
                  border: Border.all(color: dotColor, width: 1.6.r),
                ),
                child: isPaid
                    ? Icon(Icons.check_rounded, size: 13.sp, color: _greenText)
                    : isNext
                    ? Center(
                        child: Container(
                          width: 7.w,
                          height: 7.h,
                          decoration: BoxDecoration(
                            color: _brown,
                            shape: BoxShape.circle,
                          ),
                        ),
                      )
                    : null,
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2.w,
                    margin: EdgeInsets.symmetric(vertical: 2.h),
                    color: isPaid ? _greenBorder : _divider,
                  ),
                ),
            ],
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16.h),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '₹ ${_fmtAmount(inst.amount.toDouble())}',
                          style: TextStyle(
                            fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w700,
                            color: _dark,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          inst.paidAt != null
                              ? '${inst.paidAt!.day}/${inst.paidAt!.month}/${inst.paidAt!.year}'
                              : isNext
                              ? 'Due Now'
                              : 'Upcoming',
                          style: TextStyle(
                            fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                            fontSize: 11.sp,
                            color: isNext ? _brownText : _greyLight,
                            fontWeight: isNext
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 9.w,
                      vertical: 4.h,
                    ),
                    decoration: BoxDecoration(
                      color: isPaid
                          ? _greenSurface
                          : isNext
                          ? _brownSurface
                          : _bg,
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                    child: Text(
                      isPaid ? 'Paid' : (isNext ? 'Due' : 'Pending'),
                      style: TextStyle(
                        fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w700,
                        color: isPaid
                            ? _greenText
                            : isNext
                            ? _brownText
                            : _greyLight,
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

// ── Animated entrance wrapper — fade + slide-up, staggered by index ────────
class _StaggeredEntry extends StatefulWidget {
  final Widget child;
  final int index;
  const _StaggeredEntry({required this.child, required this.index});

  @override
  State<_StaggeredEntry> createState() => _StaggeredEntryState();
}

class _StaggeredEntryState extends State<_StaggeredEntry>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _fade = CurvedAnimation(parent: _c, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.07),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));
    final delay = Duration(milliseconds: 55 * widget.index.clamp(0, 7));
    Future.delayed(delay, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

// ── Animated ₹ counter — count-up on value change ───────────────────────────
class _AnimatedRupeeCounter extends StatelessWidget {
  final double value;
  final TextStyle style;
  const _AnimatedRupeeCounter({required this.value, required this.style});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, v, child) => Text('₹ ${_fmtAmount(v)}', style: style),
    );
  }
}

// ── Animated integer counter (for grid stat tiles) ──────────────────────────
class _AnimatedIntCounter extends StatelessWidget {
  final int value;
  final TextStyle style;
  const _AnimatedIntCounter({required this.value, required this.style});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeOutCubic,
      builder: (context, v, child) => Text('${v.round()}', style: style),
    );
  }
}

// ── Circular ring progress indicator ────────────────────────────────────────
class _RingProgress extends StatelessWidget {
  final double value; // 0..1
  final Color color;
  final double size;
  const _RingProgress({
    required this.value,
    required this.color,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final clamped = value.clamp(0.0, 1.0);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: clamped),
      duration: const Duration(milliseconds: 950),
      curve: Curves.easeOutCubic,
      builder: (context, v, child) {
        return SizedBox(
          width: size.w,
          height: size.h,
          child: CustomPaint(
            painter: _RingPainter(progress: v, color: color),
            child: Center(
              child: Text(
                '${(v * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w800,
                  color: _dark,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress; // 0..1
  final Color color;
  _RingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - 10) / 2;
    final strokeWidth = 8.0;

    final bgPaint = Paint()
      ..color = const Color(0xFFEEE8DC)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    final fgPaint = Paint()
      ..shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: -math.pi / 2 + 2 * math.pi,
        colors: [const Color(0xFF9AE0BC), color],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final sweep = 2 * math.pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweep,
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

// ── Pulsing status dot ──────────────────────────────────────────────────────
class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final scale = 1.0 + (_c.value * 0.6);
        return SizedBox(
          width: 12.w,
          height: 12.h,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.scale(
                scale: scale,
                child: Container(
                  width: 7.w,
                  height: 7.h,
                  decoration: BoxDecoration(
                    color: widget.color.withOpacity(1 - _c.value),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Container(
                width: 7.w,
                height: 7.h,
                decoration: BoxDecoration(
                  color: widget.color,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Pressable scale-down button wrapper ─────────────────────────────────────
class _PressableScale extends StatefulWidget {
  final VoidCallback onTap;
  final Widget child;
  const _PressableScale({required this.onTap, required this.child});

  @override
  State<_PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<_PressableScale> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.96),
      onTapUp: (_) => setState(() => _scale = 1.0),
      onTapCancel: () => setState(() => _scale = 1.0),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}