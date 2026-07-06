import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../../routes/app_routes.dart';
import '../../viewmodels/referral/referral_viewmodel.dart';
import '../../models/referral/referral_model.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _bg = Color(0xFFF0F4F8);
const _white = Color(0xFFFFFFFF);
const _titleDark = Color(0xFF111827);
const _subtitleGrey = Color(0xFF6B7280);

const _cardGreenStart = Color(0xFF2D8A5A);
const _cardGreenEnd = Color(0xFF56C98A);
const _brandGreen = Color(0xFF3D9E6A);

const _codeBg = Color(0xFFE6F4EC);
const _codeBorder = Color(0xFFBEE3CE);
const _codeText = Color(0xFF2D8A5A);

const _whatsappGreen = Color(0xFF25D366);
const _moreOptionsTxt = Color(0xFF4B5566);

const _amberBg = Color(0xFFFFF7ED);
const _amberText = Color(0xFFB45309);
const _progressTrack = Color(0xFFE5E7EB);

// ── Referral Candidates tab palette ─────────────────────────────────────────
const _tabBarBg = Color(0xFFE9EDF3);
const _candidateBonus = Color(0xFF3D9E6A);
const _planChipBg = Color(0xFFE6F4EC);
const _planChipText = Color(0xFF3D9E6A);
const _activatedBg = Color(0xFFFEF3C7);
const _activatedText = Color(0xFF92400E);
const _creditedBg = Color(0xFFE6F4EC);
const _creditedText = Color(0xFF3D9E6A);
const _avatarBg = Color(0xFFE6F4EC);

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
                            padding: const EdgeInsets.symmetric(horizontal: 20),
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
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: _tabBarBg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(
            color: _white,
            borderRadius: BorderRadius.circular(11),
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
          labelStyle: GoogleFonts.poppins(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
          unselectedLabelStyle: GoogleFonts.poppins(
            fontSize: 12.5,
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
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                  child: _buildHeroBanner(vm),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildReferralCodeCard(context, vm),
                    const SizedBox(height: 14),
                    // Side-by-side share buttons
                    Row(
                      children: [
                        Expanded(child: _buildShareWhatsAppButton(vm)),
                        const SizedBox(width: 10),
                        Expanded(child: _buildMoreOptionsButton(vm)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildTaskProgressCard(context, vm),
                    const SizedBox(height: 28),
                    _buildHowItWorks(),
                    const SizedBox(height: 24),
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
          colors: [Color(0xFF145C38), Color(0xFF2D8A5A), Color(0xFF4DBF82)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2D8A5A).withOpacity(0.40),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Large bg circle — top right
          Positioned(
            right: -40,
            top: -40,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _white.withOpacity(0.06),
              ),
            ),
          ),
          // Small bg circle — bottom left
          Positioned(
            left: -20,
            bottom: -20,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _white.withOpacity(0.05),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title row
                Text(
                  'Refer & Earn 🌿',
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: _white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Invite friends & earn a bonus on their first\nplan payment — straight to your Wallet.',
                  style: GoogleFonts.poppins(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w400,
                    color: _white.withOpacity(0.80),
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 24),
                // Stats sit directly on the gradient — no box, no border
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            vm.isLoading ? '—' : '${vm.totalRefers}',
                            style: GoogleFonts.poppins(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: _white,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.people_alt_rounded,
                                size: 12,
                                color: _white.withOpacity(0.60),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Total Referred',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: _white.withOpacity(0.65),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Slim divider
                    Container(
                      width: 1,
                      height: 44,
                      color: _white.withOpacity(0.20),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            vm.isLoading ? '—' : earningsStr,
                            style: GoogleFonts.poppins(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: _white,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.account_balance_wallet_rounded,
                                size: 12,
                                color: _white.withOpacity(0.60),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Total Earned',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: _white.withOpacity(0.65),
                                ),
                              ),
                            ],
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
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
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
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              const SizedBox(height: 60),
              _buildCandidatesErrorState(vm),
            ]),
          ),
        ),
      ];
    }

    if (vm.candidates.isEmpty) {
      return [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverList(
            delegate: SliverChildListDelegate(const [
              SizedBox(height: 40),
              _CandidatesEmptyState(),
            ]),
          ),
        ),
      ];
    }

    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
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
          size: 40,
          color: _subtitleGrey.withOpacity(0.6),
        ),
        const SizedBox(height: 12),
        Text(
          vm.candidatesError ?? 'Could not load referral candidates.',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(fontSize: 13, color: _subtitleGrey),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () => vm.loadReferralCandidates(),
          child: Text(
            'Tap to retry',
            style: GoogleFonts.poppins(
              fontSize: 12.5,
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
      margin: const EdgeInsets.only(bottom: 12),
      height: 128,
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(18),
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
          width: 20,
          height: 20,
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(18),
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
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: _avatarBg,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  initials,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _brandGreen,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.userName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: _titleDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      c.mobileLast4 != null
                          ? '•••• •• ${c.mobileLast4}'
                          : 'Mobile not available',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 11.5,
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
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: _buildStatusBadge(c.status),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: _bg,
              borderRadius: BorderRadius.circular(12),
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
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                Icons.schedule_rounded,
                size: 13,
                color: _subtitleGrey.withOpacity(0.8),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  dateLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
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
          style: GoogleFonts.poppins(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: _subtitleGrey,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 4),
        if (chip)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _planChipBg,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: _planChipText,
              ),
            ),
          )
        else
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 12.5,
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              softWrap: true,
              style: GoogleFonts.poppins(
                fontSize: 10,
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
    final day = d.day.toString().padLeft(2, '0');
    final month = months[d.month - 1];
    final year = d.year;
    final hour24 = d.hour;
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    final minute = d.minute.toString().padLeft(2, '0');
    final ampm = hour24 >= 12 ? 'PM' : 'AM';
    return '$day $month $year, $hour12:$minute $ampm';
  }

  // ── Top bar ───────────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 38,
              height: 38,
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
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 17,
                color: _brandGreen,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Moneytries',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: _brandGreen,
              letterSpacing: -0.3,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, AppRoutes.notifications),
            child: const Icon(
              Icons.notifications_none_rounded,
              size: 26,
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

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(24),
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
          // Title — inline, no strip
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _codeBg,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.qr_code_2_rounded,
                  size: 19,
                  color: _brandGreen,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Referral Code',
                      style: GoogleFonts.poppins(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: _titleDark,
                      ),
                    ),
                    Text(
                      'Earn a bonus when they start any plan',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: _subtitleGrey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          // Double-tap the code to copy — no button
          GestureDetector(
            onDoubleTap: isLoading || code.isEmpty
                ? null
                : () {
                    Clipboard.setData(ClipboardData(text: code));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Referral code copied!'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              decoration: BoxDecoration(
                color: const Color(0xFFF4FBF7),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _brandGreen.withOpacity(0.25),
                  width: 1.5,
                ),
              ),
              child: isLoading
                  ? Container(
                      height: 28,
                      decoration: BoxDecoration(
                        color: _codeBorder.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    )
                  : hasError
                  ? Text(
                      'ERROR',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.red.shade400,
                      ),
                    )
                  : Text(
                      code,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: _codeText,
                        letterSpacing: 6,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.touch_app_rounded,
                size: 13,
                color: _subtitleGrey.withOpacity(0.6),
              ),
              const SizedBox(width: 4),
              Text(
                'Double-tap to copy',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: _subtitleGrey.withOpacity(0.7),
                ),
              ),
            ],
          ),
          if (hasError) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => vm.loadReferralInfo(),
              child: Text(
                'Tap to retry',
                style: GoogleFonts.poppins(
                  fontSize: 12,
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

  // ── Share on WhatsApp ─────────────────────────────────────────────────────
  Widget _buildShareWhatsAppButton(ReferralViewModel vm) {
    final disabled = vm.isLoading || vm.myReferralCode.isEmpty;
    return AnimatedOpacity(
      opacity: disabled ? 0.5 : 1.0,
      duration: const Duration(milliseconds: 200),
      child: GestureDetector(
        onTap: disabled
            ? null
            : () async {
                final code = vm.myReferralCode;
                final msg = Uri.encodeComponent(
                  'Join Moneytries — India\'s smartest investment app! '
                  'Use my referral code *$code* when you sign up and start '
                  'your first plan. '
                  'Download now and start growing your wealth! 🌿',
                );
                final url = Uri.parse('https://wa.me/?text=$msg');
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                } else if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'WhatsApp is not installed on this device.',
                      ),
                    ),
                  );
                }
              },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            color: _whatsappGreen,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: _whatsappGreen.withOpacity(0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.chat_rounded, color: _white, size: 18),
              const SizedBox(width: 8),
              Text(
                'WhatsApp',
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
    );
  }

  // ── More Options — opens the native Android/iOS share sheet ────────────────
  Widget _buildMoreOptionsButton(ReferralViewModel vm) {
    final disabled = vm.isLoading || vm.myReferralCode.isEmpty;
    return AnimatedOpacity(
      opacity: disabled ? 0.5 : 1.0,
      duration: const Duration(milliseconds: 200),
      child: GestureDetector(
        onTap: disabled
            ? null
            : () async {
                final code = vm.myReferralCode;
                final message =
                    'Join Moneytries — India\'s smartest investment app! '
                    'Use my referral code $code when you sign up and start '
                    'your first plan. Download now and start growing your '
                    'wealth! 🌿';
                await Share.share(message, subject: 'Join Moneytries');
              },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            color: _white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFD1D5DB), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.share_rounded, color: _moreOptionsTxt, size: 18),
              const SizedBox(width: 8),
              Text(
                'More',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _moreOptionsTxt,
                ),
              ),
            ],
          ),
        ),
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(24),
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
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _amberBg,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.emoji_events_rounded,
                  size: 22,
                  color: _amberText,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Invite 5 Users',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _titleDark,
                      ),
                    ),
                    Text(
                      'Get 5 friends to start any investment plan',
                      style: GoogleFonts.poppins(
                        fontSize: 11.5,
                        color: _subtitleGrey,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Circular progress counter
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 46,
                    height: 46,
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
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: completed ? _brandGreen : _titleDark,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Progress bar with label
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                completed
                    ? '🎉 Goal reached!'
                    : '${target - progress} more to unlock ₹500 reward',
                style: GoogleFonts.poppins(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: completed ? _brandGreen : _subtitleGrey,
                ),
              ),
              Text(
                '${(fraction * 100).toInt()}%',
                style: GoogleFonts.poppins(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: completed ? _brandGreen : _amberText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                Container(height: 8, color: _progressTrack),
                AnimatedFractionallySizedBox(
                  duration: const Duration(milliseconds: 500),
                  widthFactor: vm.isLoading ? 0 : fraction,
                  child: Container(
                    height: 8,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_cardGreenStart, _cardGreenEnd],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
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
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.red.shade400,
                  ),
                ),
                const SizedBox(height: 10),
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
          height: 50,
          decoration: BoxDecoration(
            gradient: enabled
                ? const LinearGradient(
                    colors: [Color(0xFF1F7A4E), Color(0xFF4DBF82)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  )
                : null,
            color: enabled ? null : _progressTrack,
            borderRadius: BorderRadius.circular(14),
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
              ? const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
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
                      size: 18,
                      color: enabled ? _white : _subtitleGrey,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Claim ₹500 Reward',
                      style: GoogleFonts.poppins(
                        fontSize: 14.5,
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
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 14,
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
        icon: Icons.share_rounded,
        title: 'Share Your Code',
        desc: 'Share your unique referral code with a friend.',
        color: Color(0xFF3D9E6A),
        bg: Color(0xFFE6F4EC),
      ),
      (
        icon: Icons.person_add_rounded,
        title: 'Friend Signs Up',
        desc: 'Your friend signs up on Moneytries using your code.',
        color: Color(0xFF6366F1),
        bg: Color(0xFFEEF2FF),
      ),
      (
        icon: Icons.currency_rupee_rounded,
        title: 'Earn a Bonus',
        desc:
            '0.30% (3M), 0.35% (6M), or 0.45% (12M) of their first payment — to your Wallet.',
        color: Color(0xFFD97706),
        bg: Color(0xFFFFF7ED),
      ),
      (
        icon: Icons.card_giftcard_rounded,
        title: 'Unlock ₹500',
        desc:
            'Invite 5 friends who each complete a first plan payment to unlock a ₹500 bonus.',
        color: Color(0xFFDB2777),
        bg: Color(0xFFFDF2F8),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 14),
          child: Text(
            'How it works',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _titleDark,
            ),
          ),
        ),
        // 2×2 grid of step cards
        Row(
          children: [
            Expanded(child: _buildStepCard(steps[0])),
            const SizedBox(width: 12),
            Expanded(child: _buildStepCard(steps[1])),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildStepCard(steps[2])),
            const SizedBox(width: 12),
            Expanded(child: _buildStepCard(steps[3])),
          ],
        ),
      ],
    );
  }

  Widget _buildStepCard(
    ({Color bg, Color color, String desc, IconData icon, String title}) step,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
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
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: step.bg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(step.icon, size: 20, color: step.color),
          ),
          const SizedBox(height: 12),
          Text(
            step.title,
            style: GoogleFonts.poppins(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: _titleDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            step.desc,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w400,
              color: _subtitleGrey,
              height: 1.45,
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
    const navItems = [
      (icon: Icons.home_rounded, label: 'HOME'),
      (icon: Icons.bar_chart_rounded, label: 'PLAN'),
      (icon: Icons.history_rounded, label: 'HISTORY'),
      (icon: Icons.person_rounded, label: 'PROFILE'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        border: const Border(
          top: BorderSide(color: Color(0xFFE5E7EB), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
            children: List.generate(navItems.length, (i) {
              final sel = i == _selectedNavIndex;
              final color = sel
                  ? const Color(0xFF3D9E6A)
                  : const Color(0xFF9CA3AF);
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
                          color: const Color(0xFF3D9E6A),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Icon(navItems[i].icon, size: 22, color: color),
                      const SizedBox(height: 3),
                      Text(
                        navItems[i].label,
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                          color: color,
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

// ── Empty state — "No referral candidates yet." ───────────────────────────
class _CandidatesEmptyState extends StatelessWidget {
  const _CandidatesEmptyState();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 84,
          height: 84,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: _avatarBg,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.people_alt_rounded,
            size: 38,
            color: _brandGreen,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'No referral candidates yet.',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: _titleDark,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Invite friends to start earning rewards.',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: _subtitleGrey,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}
