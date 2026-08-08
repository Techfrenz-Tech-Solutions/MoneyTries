import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../routes/app_routes.dart';
import '../../viewmodels/referral/referral_viewmodel.dart';
import '../../models/referral/referral_model.dart';
import '../../utils/date_time_utils.dart';
import '../../utils/responsive.dart';
import '../../widgets/premium/premium.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _bg = Color(0xFFF7F5F2);
const _white = Color(0xFFFFFFFF);
const _titleDark = Color(0xFF111827);
const _subtitleGrey = Color(0xFF6B7280);

const _brandGreen = Color(0xFF4CAF7D);
const _brandGreenLight = Color(0xFF7DCB9E);

// Champagne gold — premium accent, paired with soft emerald tints so no
// surface on this screen ever leans on a dark green fill.
const _gold = Color(0xFFB8863B);
const _goldDeep = Color(0xFF9A6B25);
const _goldSurface = Color(0xFFFBF1DD);
const _goldBorder = Color(0xFFE7CFA0);

const _codeBg = Color(0xFFE8F5EE);
const _codeBorder = Color(0xFFE7CFA0);
const _codeText = Color(0xFF2D7A52);

const _amberBg = Color(0xFFFFF7ED);
const _amberText = Color(0xFFB45309);
const _progressTrack = Color(0xFFE8E4DE);

// ── Referral Candidates tab palette ─────────────────────────────────────────
const _tabBarBg = Color(0xFFEEEDE8);
const _candidateBonus = Color(0xFF4CAF7D);
const _planChipBg = Color(0xFFE8F5EE);
const _planChipText = Color(0xFF4CAF7D);
const _activatedBg = Color(0xFFFEF3C7);
const _activatedText = Color(0xFF92400E);
const _creditedBg = Color(0xFFE8F5EE);
const _creditedText = Color(0xFF4CAF7D);
const _avatarBg = Color(0xFFE8F5EE);

class ReferralScreen extends StatefulWidget {
  const ReferralScreen({super.key});
  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen>
    with SingleTickerProviderStateMixin {
  int _selectedNavIndex = 3;
  late ReferralViewModel _vm;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _vm = ReferralViewModel();
    _vm.loadReferralInfo();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      if (_tabController.index == 1) {
        // Refresh immediately every time the Referral Candidates tab is
        // opened, then keep polling in the background so a friend's status
        // (Pending Plan -> Under Review -> First Payment Completed ->
        // Reward Credited) keeps advancing live without needing to leave
        // and re-enter the screen.
        _vm.loadReferralCandidates();
        _vm.startCandidatesAutoRefresh();
      } else {
        _vm.stopCandidatesAutoRefresh();
      }
    });
  }

  @override
  void dispose() {
    _vm.stopCandidatesAutoRefresh();
    _tabController.dispose();
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ReferralViewModel>.value(
      value: _vm,
      child: Theme(
        data: ThemeData(
          brightness: Brightness.light,
          scaffoldBackgroundColor: _bg,
        ),
        child: AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.dark,
          child: Scaffold(
            backgroundColor: _bg,
            // NestedScrollView is the single source of scrolling for the
            // whole page: the header (top bar + tab bar) lives in
            // headerSliverBuilder as plain, non-pinned slivers, so it
            // scrolls away with the rest of the content instead of
            // staying stuck at the top, and each tab's own content is a
            // CustomScrollView in `body`. NestedScrollView coordinates the
            // outer header with each tab's inner scroll offset itself, so
            // there is exactly one scroll gesture end-to-end — no nested
            // SingleChildScrollView/ListView fighting each other, no fixed
            // -height Expanded clipping content, and nothing can disappear
            // or get cut off while scrolling on any screen size. Neither
            // NestedScrollView nor the tabs' CustomScrollViews are given an
            // explicit ScrollController or initialScrollOffset anywhere in
            // this file, so both tabs always open at offset 0 by default;
            // the only thing that ever moves a tab off 0 is the user's own
            // scrolling, which PageStorageKey below remembers per tab for
            // the current session only (it resets the next time the app
            // is fully restarted, since PageStorage isn't persisted to
            // disk).
            body: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  Expanded(
                    child: NestedScrollView(
                      headerSliverBuilder: (context, innerBoxIsScrolled) => [
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 20.w),
                            child: _buildTopBar(),
                          ),
                        ),
                        SliverToBoxAdapter(child: _buildTabBar()),
                      ],
                      body: TabBarView(
                        controller: _tabController,
                        children: [
                          Builder(
                            builder: (context) => _buildOverviewTab(context),
                          ),
                          Builder(
                            builder: (context) => _buildCandidatesTab(context),
                          ),
                        ],
                      ),
                    ),
                  ),
                  _buildBottomNav(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Tab bar ───────────────────────────────────────────────────────────────
  Widget _buildTabBar() {
    return Container(
      color: _bg,
      padding: EdgeInsets.fromLTRB(20.w, 4.h, 20.w, 12.h),
      child: Container(
        padding: EdgeInsets.all(4.w),
        decoration: BoxDecoration(
          color: _tabBarBg,
          borderRadius: BorderRadius.circular(14.r),
        ),
        child: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(
            color: _white,
            borderRadius: BorderRadius.circular(11.r),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          labelColor: _brandGreen,
          unselectedLabelColor: _subtitleGrey,
          labelStyle: TextStyle(fontFamily: 'Times New Roman',
            fontSize: 12.5.sp,
            fontWeight: FontWeight.w700,
          ),
          unselectedLabelStyle: TextStyle(fontFamily: 'Times New Roman',
            fontSize: 12.5.sp,
            fontWeight: FontWeight.w600,
          ),
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Referral Candidates'),
          ],
        ),
      ),
    );
  }

  // ── Overview tab ──────────────────────────────────────────────────────────
  Widget _buildOverviewTab(BuildContext context) {
    return Consumer<ReferralViewModel>(
      builder: (context, vm, _) {
        return RefreshIndicator(
          color: _brandGreen,
          onRefresh: vm.loadReferralInfo,
          child: CustomScrollView(
            key: const PageStorageKey('referral_overview_scroll'),
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              // Hero gradient banner with stats embedded
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20.w, 4.h, 20.w, 0.h),
                  child: _buildHeroBanner(vm),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(20.w, 18.h, 20.w, 0.h),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildReferralCodeCard(context, vm),
                    SizedBox(height: 20.h),
                    _buildTaskProgressCard(context, vm),
                    SizedBox(height: 28.h),
                    _buildHowItWorks(),
                    SizedBox(height: 24.h),
                  ]),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Hero banner ───────────────────────────────────────────────────────────
  Widget _buildHeroBanner(ReferralViewModel vm) {
    final earnings = vm.totalEarnings;
    final earningsStr = earnings >= 1000
        ? '₹${(earnings / 1000).toStringAsFixed(1)}k'
        : '₹${earnings.toStringAsFixed(2)}';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFFFFF), Color(0xFFF3FAF5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28.r),
        border: Border.all(color: const Color(0xFFEAE6DE), width: 1.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28.r),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Soft emerald blob — top right
            Positioned(
              right: -36,
              top: -36,
              child: Container(
                width: 140.w,
                height: 140.h,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _brandGreenLight.withOpacity(0.16),
                ),
              ),
            ),
            // Soft gold blob — bottom left
            Positioned(
              left: -30,
              bottom: -30,
              child: Container(
                width: 110.w,
                height: 110.h,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _gold.withOpacity(0.12),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(22.w, 22.h, 22.w, 22.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Gold-bordered badge pill
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 6.h,
                    ),
                    decoration: BoxDecoration(
                      color: _goldSurface,
                      borderRadius: BorderRadius.circular(20.r),
                      border: Border.all(color: _goldBorder, width: 1.r),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_awesome_rounded,
                            size: 12.sp, color: _goldDeep),
                        SizedBox(width: 5.w),
                        Text(
                          'REFER & EARN',
                          style: TextStyle(fontFamily: 'Times New Roman',
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w700,
                            color: _goldDeep,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 14.h),
                  Text(
                    'Give a plan.\nGet rewarded.',
                    style: TextStyle(fontFamily: 'Times New Roman',
                      fontSize: 21.sp,
                      fontWeight: FontWeight.w800,
                      color: _titleDark,
                      height: 1.2,
                      letterSpacing: -0.4,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'Invite friends & earn a bonus on their first\nplan payment — straight to your Wallet.',
                    style: TextStyle(fontFamily: 'Times New Roman',
                      fontSize: 12.5.sp,
                      fontWeight: FontWeight.w400,
                      color: _subtitleGrey,
                      height: 1.55,
                    ),
                  ),
                  SizedBox(height: 22.h),
                  // Stat chips — light cards, not a dark strip
                  Row(
                    children: [
                      Expanded(
                        child: _buildHeroStatChip(
                          icon: Icons.people_alt_rounded,
                          value: vm.isLoading ? '—' : '${vm.totalRefers}',
                          label: 'Total Referred',
                          iconBg: const Color(0xFFE8F5EE),
                          iconColor: _brandGreen,
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: _buildHeroStatChip(
                          icon: Icons.account_balance_wallet_rounded,
                          value: vm.isLoading ? '—' : earningsStr,
                          label: 'Total Earned',
                          iconBg: _goldSurface,
                          iconColor: _goldDeep,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroStatChip({
    required IconData icon,
    required String value,
    required String label,
    required Color iconBg,
    required Color iconColor,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFEDE9E2), width: 1.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30.w,
            height: 30.h,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(9.r),
            ),
            child: Icon(icon, size: 15.sp, color: iconColor),
          ),
          SizedBox(height: 10.h),
          Text(
            value,
            style: TextStyle(fontFamily: 'Times New Roman',
              fontSize: 19.sp,
              fontWeight: FontWeight.w800,
              color: _titleDark,
              letterSpacing: -0.3,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            label,
            style: TextStyle(fontFamily: 'Times New Roman',
              fontSize: 10.5.sp,
              fontWeight: FontWeight.w500,
              color: _subtitleGrey,
            ),
          ),
        ],
      ),
    );
  }

  // ── Referral Candidates tab ──────────────────────────────────────────────
  // Same CustomScrollView pattern as the Overview tab above, so this tab
  // also keeps its own independent scroll offset when switching away and
  // back, and stays fully scrollable (skeleton, error, empty, and
  // loaded-list states alike) without ever clipping content, on any
  // screen size.
  Widget _buildCandidatesTab(BuildContext context) {
    return Consumer<ReferralViewModel>(
      builder: (context, vm, _) {
        return RefreshIndicator(
          color: _brandGreen,
          onRefresh: vm.loadReferralCandidates,
          child: CustomScrollView(
            key: const PageStorageKey('referral_candidates_scroll'),
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: _buildCandidatesSlivers(vm),
          ),
        );
      },
    );
  }

  List<Widget> _buildCandidatesSlivers(ReferralViewModel vm) {
    if (vm.isLoadingCandidates && vm.candidates.isEmpty) {
      return [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(20.w, 4.h, 20.w, 20.h),
          sliver: SliverList(
            delegate: SliverChildListDelegate(
              List.generate(3, (i) => _buildCandidateCardSkeleton()),
            ),
          ),
        ),
      ];
    }

    if (vm.candidatesState == ReferralLoadState.error &&
        vm.candidates.isEmpty) {
      return [
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: 20.w),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              SizedBox(height: 60.h),
              _buildCandidatesErrorState(vm),
            ]),
          ),
        ),
      ];
    }

    if (vm.candidates.isEmpty) {
      return [
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: 20.w),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              SizedBox(height: 40.h),
              _CandidatesEmptyState(),
            ]),
          ),
        ),
      ];
    }

    return [
      SliverPadding(
        padding: EdgeInsets.fromLTRB(20.w, 4.h, 20.w, 20.h),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, i) => Padding(
              padding: EdgeInsets.only(
                bottom: i == vm.candidates.length - 1 ? 0 : 12,
              ),
              child: _buildCandidateCard(vm.candidates[i]),
            ),
            childCount: vm.candidates.length,
          ),
        ),
      ),
    ];
  }

  Widget _buildCandidatesErrorState(ReferralViewModel vm) {
    return Column(
      children: [
        Icon(
          Icons.error_outline_rounded,
          size: 40.sp,
          color: _subtitleGrey.withOpacity(0.6),
        ),
        SizedBox(height: 12.h),
        Text(
          vm.candidatesError ?? 'Could not load referral candidates.',
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: 'Times New Roman',fontSize: 13.sp, color: _subtitleGrey),
        ),
        SizedBox(height: 12.h),
        GestureDetector(
          onTap: () => vm.loadReferralCandidates(),
          child: Text(
            'Tap to retry',
            style: TextStyle(fontFamily: 'Times New Roman',
              fontSize: 12.5.sp,
              color: _brandGreen,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCandidateCardSkeleton() {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      height: 128.h,
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(18.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: SizedBox(
          width: 20.w,
          height: 20.h,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: _brandGreen.withOpacity(0.5),
          ),
        ),
      ),
    );
  }

  // ── Referral candidate card ───────────────────────────────────────────────
  Widget _buildCandidateCard(ReferralCandidate c) {
    final initials = _initialsOf(c.userName);
    final hasPlan = c.selectedPlan != null;
    final dateLabel = c.firstPaymentDate != null
        ? 'First payment: ${_fmtDateTime(c.firstPaymentDate)}'
        : (c.registeredAt != null
              ? 'Registered: ${_fmtDateTime(c.registeredAt)}'
              : '—');

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(18.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      // A plain Column with every row free to wrap/shrink as needed — no
      // fixed-width siblings fighting for horizontal space — so nothing on
      // this card can ever be clipped, regardless of how long the user's
      // name or status label is or how narrow the screen is.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40.w,
                height: 40.h,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: _avatarBg,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  initials,
                  style: TextStyle(fontFamily: 'Times New Roman',
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    color: _brandGreen,
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.userName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontFamily: 'Times New Roman',
                        fontSize: 14.5.sp,
                        fontWeight: FontWeight.w700,
                        color: _titleDark,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      c.mobileLast4 != null
                          ? '•••• •• ${c.mobileLast4}'
                          : 'Mobile not available',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontFamily: 'Times New Roman',
                        fontSize: 11.5.sp,
                        fontWeight: FontWeight.w400,
                        color: _subtitleGrey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Status badge sits on its own full-width row below the name —
          // never squeezed horizontally against the avatar/name, so longer
          // labels like "First Payment Completed" always wrap cleanly
          // instead of overflowing the card on narrow screens.
          SizedBox(height: 10.h),
          Align(
            alignment: Alignment.centerLeft,
            child: _buildStatusBadge(c.status),
          ),
          SizedBox(height: 14.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: _bg,
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildCandidateStat(
                    label: 'PLAN',
                    value: c.selectedPlan ?? 'Not started',
                    chip: hasPlan,
                  ),
                ),
                Expanded(
                  child: _buildCandidateStat(
                    label: 'FIRST PAYMENT',
                    value: c.firstPaymentAmount != null
                        ? '₹${_fmt(c.firstPaymentAmount!)}'
                        : '—',
                  ),
                ),
                Expanded(
                  child: _buildCandidateStat(
                    label: 'BONUS EARNED',
                    value: '₹${_fmt(c.bonusEarned)}',
                    valueColor: _candidateBonus,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 10.h),
          Row(
            children: [
              Icon(
                Icons.schedule_rounded,
                size: 13.sp,
                color: _subtitleGrey.withOpacity(0.8),
              ),
              SizedBox(width: 5.w),
              Expanded(
                child: Text(
                  dateLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontFamily: 'Times New Roman',
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w400,
                    color: _subtitleGrey,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCandidateStat({
    required String label,
    required String value,
    Color? valueColor,
    bool chip = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontFamily: 'Times New Roman',
            fontSize: 9.sp,
            fontWeight: FontWeight.w600,
            color: _subtitleGrey,
            letterSpacing: 0.4,
          ),
        ),
        SizedBox(height: 4.h),
        if (chip)
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
            decoration: BoxDecoration(
              color: _planChipBg,
              borderRadius: BorderRadius.circular(6.r),
            ),
            child: Text(
              value,
              style: TextStyle(fontFamily: 'Times New Roman',
                fontSize: 11.5.sp,
                fontWeight: FontWeight.w700,
                color: _planChipText,
              ),
            ),
          )
        else
          Text(
            value,
            style: TextStyle(fontFamily: 'Times New Roman',
              fontSize: 12.5.sp,
              fontWeight: FontWeight.w700,
              color: valueColor ?? _titleDark,
            ),
          ),
      ],
    );
  }

  // Badge styling + copy for every possible ReferralCandidateStatus. The
  // badge is rendered on its own full-width row on the candidate card (see
  // _buildCandidateCard), so even the longest label here ("First Payment
  // Completed") always has room to lay out without overflowing.
  Widget _buildStatusBadge(ReferralCandidateStatus status) {
    late final Color bg;
    late final Color fg;
    late final IconData icon;
    late final String label;

    switch (status) {
      case ReferralCandidateStatus.pendingPlan:
        bg = _tabBarBg;
        fg = _subtitleGrey;
        icon = Icons.hourglass_empty_rounded;
        label = 'Pending Plan';
        break;
      case ReferralCandidateStatus.underReview:
        bg = _activatedBg;
        fg = _activatedText;
        icon = Icons.pending_actions_rounded;
        label = 'Under Review';
        break;
      case ReferralCandidateStatus.firstPaymentCompleted:
        bg = _activatedBg;
        fg = _activatedText;
        icon = Icons.bolt_rounded;
        label = 'First Payment Completed';
        break;
      case ReferralCandidateStatus.rewardCredited:
        bg = _creditedBg;
        fg = _creditedText;
        icon = Icons.check_circle_rounded;
        label = 'Reward Credited';
        break;
      case ReferralCandidateStatus.rejected:
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFFB91C1C);
        icon = Icons.cancel_rounded;
        label = 'Rejected';
        break;
    }

    return Container(
      constraints: const BoxConstraints(maxWidth: double.infinity),
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12.sp, color: fg),
          SizedBox(width: 4.w),
          Flexible(
            child: Text(
              label,
              softWrap: true,
              style: TextStyle(fontFamily: 'Times New Roman',
                fontSize: 10.sp,
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _initialsOf(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0].substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }

  String _fmtDateTime(DateTime? d) {
    if (d == null) return '—';
    final local = toDeviceLocal(d);
    const months = [
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
    final day = local.day.toString().padLeft(2, '0');
    final month = months[local.month - 1];
    final year = local.year;
    final hour24 = local.hour;
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final ampm = hour24 >= 12 ? 'PM' : 'AM';
    return '$day $month $year, $hour12:$minute $ampm';
  }

  // ── Top bar ───────────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 16.h),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 38.w,
              height: 38.h,
              decoration: BoxDecoration(
                color: _white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.07),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 17.sp,
                color: _brandGreen,
              ),
            ),
          ),
          SizedBox(width: 12.w),
          Text(
            'Moneytries',
            style: TextStyle(fontFamily: 'Times New Roman',
              fontSize: 24.sp,
              fontWeight: FontWeight.w800,
              color: _brandGreen,
              letterSpacing: -0.3,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, AppRoutes.notifications),
            child: Icon(
              Icons.notifications_none_rounded,
              size: 26.sp,
              color: _brandGreen,
            ),
          ),
        ],
      ),
    );
  }

  // ── Referral code card ────────────────────────────────────────────────────
  Widget _buildReferralCodeCard(BuildContext context, ReferralViewModel vm) {
    final code = vm.myReferralCode;
    final isLoading = vm.isLoading;
    final hasError = vm.state == ReferralLoadState.error;

    void copyCode() {
      if (isLoading || code.isEmpty) return;
      Clipboard.setData(ClipboardData(text: code));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Referral code copied!'),
          duration: Duration(seconds: 1),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(24.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38.w,
                height: 38.h,
                decoration: BoxDecoration(
                  color: _goldSurface,
                  borderRadius: BorderRadius.circular(11.r),
                ),
                child: Icon(
                  Icons.confirmation_number_rounded,
                  size: 18.sp,
                  color: _goldDeep,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Referral Code',
                      style: TextStyle(fontFamily: 'Times New Roman',
                        fontSize: 14.5.sp,
                        fontWeight: FontWeight.w700,
                        color: _titleDark,
                      ),
                    ),
                    Text(
                      'Earn a bonus when they start any plan',
                      style: TextStyle(fontFamily: 'Times New Roman',
                        fontSize: 11.sp,
                        color: _subtitleGrey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 18.h),
          // Code pill — the code itself plus an inline tap-to-copy icon,
          // no separate button beneath it.
          GestureDetector(
            onTap: copyCode,
            onDoubleTap: copyCode,
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(20.w, 14.h, 12.w, 14.h),
              decoration: BoxDecoration(
                color: _codeBg,
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(color: _goldBorder, width: 1.r),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: isLoading
                        ? Container(
                            height: 24.h,
                            decoration: BoxDecoration(
                              color: _brandGreen.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6.r),
                            ),
                          )
                        : hasError
                        ? Text(
                            'ERROR',
                            style: TextStyle(fontFamily: 'Times New Roman',
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w700,
                              color: Colors.red.shade400,
                            ),
                          )
                        : Text(
                            code,
                            style: TextStyle(fontFamily: 'Times New Roman',
                              fontSize: 22.sp,
                              fontWeight: FontWeight.w800,
                              color: _codeText,
                              letterSpacing: 5,
                            ),
                          ),
                  ),
                  Container(
                    width: 38.w,
                    height: 38.h,
                    decoration: BoxDecoration(
                      color: _white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _brandGreen.withOpacity(0.30),
                        width: 1.r,
                      ),
                    ),
                    child: Icon(
                      Icons.copy_rounded,
                      size: 16.sp,
                      color: _brandGreen,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 10.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.touch_app_rounded,
                size: 12.sp,
                color: _subtitleGrey.withOpacity(0.6),
              ),
              SizedBox(width: 4.w),
              Text(
                'Tap the code to copy',
                style: TextStyle(fontFamily: 'Times New Roman',
                  fontSize: 11.sp,
                  color: _subtitleGrey.withOpacity(0.7),
                ),
              ),
            ],
          ),
          if (hasError) ...[
            SizedBox(height: 10.h),
            GestureDetector(
              onTap: () => vm.loadReferralInfo(),
              child: Text(
                'Tap to retry',
                style: TextStyle(fontFamily: 'Times New Roman',
                  fontSize: 12.sp,
                  color: _brandGreen,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Task progress card ────────────────────────────────────────────────────
  Widget _buildTaskProgressCard(BuildContext context, ReferralViewModel vm) {
    final progress = vm.taskProgress;
    final target = vm.taskTarget;
    final fraction = vm.taskProgressFraction;
    final completed = vm.taskCompleted;
    final claimed = vm.rewardClaimed;
    final claiming = vm.claimState == ClaimRewardState.claiming;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(24.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: icon + text + counter — all inline, no strip
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 44.w,
                height: 44.h,
                decoration: BoxDecoration(
                  color: _amberBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.emoji_events_rounded,
                  size: 22.sp,
                  color: _amberText,
                ),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Invite 5 Users',
                      style: TextStyle(fontFamily: 'Times New Roman',
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w700,
                        color: _titleDark,
                      ),
                    ),
                    Text(
                      'Get 5 friends to start any investment plan',
                      style: TextStyle(fontFamily: 'Times New Roman',
                        fontSize: 11.5.sp,
                        color: _subtitleGrey,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 10.w),
              // Circular progress counter
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 46.w,
                    height: 46.h,
                    child: CircularProgressIndicator(
                      value: vm.isLoading ? 0 : fraction,
                      strokeWidth: 4,
                      backgroundColor: _progressTrack,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        completed ? _brandGreen : _amberText,
                      ),
                    ),
                  ),
                  Text(
                    '$progress/$target',
                    style: TextStyle(fontFamily: 'Times New Roman',
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w800,
                      color: completed ? _brandGreen : _titleDark,
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 20.h),
          // Progress bar with label
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                completed
                    ? '🎉 Goal reached!'
                    : '${target - progress} more to unlock ₹500 reward',
                style: TextStyle(fontFamily: 'Times New Roman',
                  fontSize: 11.5.sp,
                  fontWeight: FontWeight.w500,
                  color: completed ? _brandGreen : _subtitleGrey,
                ),
              ),
              Text(
                '${(fraction * 100).toInt()}%',
                style: TextStyle(fontFamily: 'Times New Roman',
                  fontSize: 11.5.sp,
                  fontWeight: FontWeight.w700,
                  color: completed ? _brandGreen : _amberText,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(20.r),
            child: Stack(
              children: [
                Container(height: 8.h, color: _progressTrack),
                AnimatedFractionallySizedBox(
                  duration: const Duration(milliseconds: 500),
                  widthFactor: vm.isLoading ? 0 : fraction,
                  child: Container(
                    height: 8.h,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_brandGreen, _brandGreenLight],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 18.h),
          if (claimed)
            _buildRewardStatusPill(
              icon: Icons.check_circle_rounded,
              label: 'Reward Claimed',
              color: _brandGreen,
              bg: _codeBg,
            )
          else if (vm.claimState == ClaimRewardState.error &&
              vm.claimError != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  vm.claimError!,
                  style: TextStyle(fontFamily: 'Times New Roman',
                    fontSize: 12.sp,
                    color: Colors.red.shade400,
                  ),
                ),
                SizedBox(height: 10.h),
                _buildClaimButton(vm, completed, claiming),
              ],
            )
          else
            _buildClaimButton(vm, completed, claiming),
        ],
      ),
    );
  }

  Widget _buildClaimButton(
    ReferralViewModel vm,
    bool completed,
    bool claiming,
  ) {
    final enabled = vm.canClaimReward;
    return GestureDetector(
      onTap: enabled
          ? () async {
              await vm.claimReward();
              if (!mounted) return;
              if (vm.claimState == ClaimRewardState.claimed) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('₹500 reward added to your Wallet!'),
                    backgroundColor: _brandGreen,
                  ),
                );
              }
            }
          : null,
      child: AnimatedOpacity(
        opacity: enabled ? 1.0 : 0.45,
        duration: const Duration(milliseconds: 200),
        child: Container(
          width: double.infinity,
          height: 50.h,
          decoration: BoxDecoration(
            gradient: enabled
                ? const LinearGradient(
                    colors: [Color(0xFF4CAF7D), Color(0xFF7DCB9E)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  )
                : null,
            color: enabled ? null : _progressTrack,
            borderRadius: BorderRadius.circular(14.r),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: _brandGreen.withOpacity(0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : null,
          ),
          child: claiming
              ? Center(
                  child: SizedBox(
                    width: 20.w,
                    height: 20.h,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: _white,
                    ),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.card_giftcard_rounded,
                      size: 18.sp,
                      color: enabled ? _white : _subtitleGrey,
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      'Claim ₹500 Reward',
                      style: TextStyle(fontFamily: 'Times New Roman',
                        fontSize: 14.5.sp,
                        fontWeight: FontWeight.w700,
                        color: enabled ? _white : _subtitleGrey,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildRewardStatusPill({
    required IconData icon,
    required String label,
    required Color color,
    required Color bg,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 13.h),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18.sp, color: color),
          SizedBox(width: 8.w),
          Text(
            label,
            style: TextStyle(fontFamily: 'Times New Roman',
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ── How it works ──────────────────────────────────────────────────────────
  Widget _buildHowItWorks() {
    const steps = [
      (
        icon: Icons.ios_share_rounded,
        title: 'Share Your Code',
        desc: 'Share your unique referral code with a friend.',
        color: Color(0xFF4CAF7D),
        bg: Color(0xFFE8F5EE),
      ),
      (
        icon: Icons.person_add_alt_1_rounded,
        title: 'Friend Signs Up',
        desc: 'Your friend signs up on Moneytries using your code.',
        color: Color(0xFF6366F1),
        bg: Color(0xFFEEF0FF),
      ),
      (
        icon: Icons.currency_rupee_rounded,
        title: 'Earn a Bonus',
        desc: 'A share of their first payment is credited straight '
            'to your Wallet — see rates below.',
        color: _goldDeep,
        bg: _goldSurface,
      ),
      (
        icon: Icons.card_giftcard_rounded,
        title: 'Unlock ₹500',
        desc: 'Invite 5 friends who each complete a first plan payment '
            'to unlock an extra ₹500 bonus.',
        color: Color(0xFFDB2777),
        bg: Color(0xFFFDF2F8),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 2.w, bottom: 16.h),
          child: Text(
            'How it works',
            style: TextStyle(fontFamily: 'Times New Roman',
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
              color: _titleDark,
            ),
          ),
        ),
        // Connected vertical stepper — a clear step-by-step flow instead
        // of a flat 2×2 grid.
        Container(
          padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 6.h),
          decoration: BoxDecoration(
            color: _white,
            borderRadius: BorderRadius.circular(22.r),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 16,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            children: List.generate(steps.length, (i) {
              final step = steps[i];
              final isLast = i == steps.length - 1;
              return _buildStepRow(step, isLast: isLast);
            }),
          ),
        ),
        SizedBox(height: 16.h),
        // Bonus tier chips
        Row(
          children: [
            Expanded(child: _buildTierChip('3M', '0.30%')),
            SizedBox(width: 10.w),
            Expanded(child: _buildTierChip('6M', '0.35%')),
            SizedBox(width: 10.w),
            Expanded(child: _buildTierChip('12M', '0.45%')),
          ],
        ),
      ],
    );
  }

  Widget _buildStepRow(
    ({Color bg, Color color, String desc, IconData icon, String title}) step, {
    required bool isLast,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon + connecting line
          Column(
            children: [
              SizedBox(height: 12.h),
              Container(
                width: 38.w,
                height: 38.h,
                decoration: BoxDecoration(
                  color: step.bg,
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Icon(step.icon, size: 18.sp, color: step.color),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 1.5.r,
                    margin: EdgeInsets.symmetric(vertical: 4.h),
                    color: const Color(0xFFEDE9E2),
                  ),
                ),
            ],
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                top: 12.h,
                bottom: isLast ? 14.h : 20.h,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.title,
                    style: TextStyle(fontFamily: 'Times New Roman',
                      fontSize: 13.5.sp,
                      fontWeight: FontWeight.w700,
                      color: _titleDark,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    step.desc,
                    style: TextStyle(fontFamily: 'Times New Roman',
                      fontSize: 11.5.sp,
                      fontWeight: FontWeight.w400,
                      color: _subtitleGrey,
                      height: 1.45,
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

  Widget _buildTierChip(String period, String rate) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12.h),
      decoration: BoxDecoration(
        color: _goldSurface,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: _goldBorder, width: 1.r),
      ),
      child: Column(
        children: [
          Text(
            rate,
            style: TextStyle(fontFamily: 'Times New Roman',
              fontSize: 15.sp,
              fontWeight: FontWeight.w800,
              color: _goldDeep,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            period,
            style: TextStyle(fontFamily: 'Times New Roman',
              fontSize: 10.sp,
              fontWeight: FontWeight.w600,
              color: _subtitleGrey,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  String _fmt(double v) {
    final s = v.toStringAsFixed(2);
    final parts = s.split('.');
    final intPart = parts[0];
    final isNeg = intPart.startsWith('-');
    final digits = isNeg ? intPart.substring(1) : intPart;

    // Indian-style grouping (##,##,###).
    String grouped;
    if (digits.length <= 3) {
      grouped = digits;
    } else {
      final last3 = digits.substring(digits.length - 3);
      var rest = digits.substring(0, digits.length - 3);
      final chunks = <String>[];
      while (rest.length > 2) {
        chunks.insert(0, rest.substring(rest.length - 2));
        rest = rest.substring(0, rest.length - 2);
      }
      if (rest.isNotEmpty) chunks.insert(0, rest);
      grouped = '${chunks.join(',')},$last3';
    }
    return '${isNeg ? '-' : ''}$grouped.${parts[1]}';
  }

  // ── Bottom nav ────────────────────────────────────────────────────────────
  void _onNavTap(int i) {
    if (i == _selectedNavIndex) return;
    switch (i) {
      case 0:
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.home,
          (r) => false,
        );
        break;
      case 1:
        Navigator.pushNamed(context, AppRoutes.plan);
        break;
      case 2:
        Navigator.pushNamed(context, AppRoutes.history);
        break;
      case 3:
        Navigator.pushNamed(context, AppRoutes.profile);
        break;
    }
  }

  Widget _buildBottomNav() {
    return PremiumBottomNav(
      selectedIndex: _selectedNavIndex,
      onTap: _onNavTap,
      items: const [
        PremiumNavItem(icon: Icons.home_rounded),
        PremiumNavItem(icon: Icons.trending_up_rounded),
        PremiumNavItem(icon: Icons.history_rounded),
        PremiumNavItem(icon: Icons.person_rounded),
      ],
    );
  }
}

// ── Empty state — "No referral candidates yet." ───────────────────────────
class _CandidatesEmptyState extends StatelessWidget {
  const _CandidatesEmptyState();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 84.w,
          height: 84.h,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: _avatarBg,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.people_alt_rounded,
            size: 38.sp,
            color: _brandGreen,
          ),
        ),
        SizedBox(height: 20.h),
        Text(
          'No referral candidates yet.',
          style: TextStyle(fontFamily: 'Times New Roman',
            fontSize: 16.sp,
            fontWeight: FontWeight.w700,
            color: _titleDark,
          ),
        ),
        SizedBox(height: 8.h),
        Text(
          'Invite friends to start earning rewards.',
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: 'Times New Roman',
            fontSize: 13.sp,
            fontWeight: FontWeight.w400,
            color: _subtitleGrey,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}