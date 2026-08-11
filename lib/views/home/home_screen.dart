import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import '../../routes/app_routes.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/home/home_repository.dart';
import '../../utils/date_time_utils.dart';
import '../profile/security_settings_view.dart';
import '../../utils/responsive.dart';
import '../../widgets/animations/animations.dart';
import '../../widgets/premium/premium.dart';
import '../../services/audio/interaction_feedback.dart';
import '../../core/api/api_config.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _bgColor = Color(0xFFF7F5F2); // warm beige-white background
const _brandGreen = Color(0xFF4CAF7D); // primary light green
const _white = Color(0xFFFFFFFF);
const _titleDark = Color(0xFF111827);
const _subtitleGrey = Color(0xFF6B7280);
const _labelGrey = Color(0xFF9CA3AF);
const _surfaceWhite = Color(0xFFFFFFFF);
const _dividerColor = Color(0xFFE8E4DE); // warm beige divider
const _successGreen = Color(0xFF4CAF7D); // matches brand green
const _successBg = Color(0xFFE8F5EE); // soft green surface
const _processingBg = Color(0xFFFEF3C7);
const _processingText = Color(0xFFD97706);
const _withdrawRed = Color(0xFFEF4444);
const _bottomNavSel = Color(0xFF9AE0BC); // banner light-green tone
const _bottomNavUnsel = Color(0xFF9CA3AF);

// ── Banner data model ─────────────────────────────────────────────────────────
class _BannerData {
  final List<Color> gradientColors;
  final String tag;
  final String title;
  final String subtitle;
  final IconData decoIcon;
  final _BannerPainterType painterType;
  const _BannerData({
    required this.gradientColors,
    required this.tag,
    required this.title,
    required this.subtitle,
    required this.decoIcon,
    required this.painterType,
  });
}

enum _BannerPainterType { chart, star, referral, shield }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentBannerIndex = 0;
  int _selectedNavIndex = 0;
  bool _balanceVisible = false;

  final HomeRepository _homeRepo = HomeRepository();
  String _userName = '';
  String? _avatarUrl;
  static const String _kBaseUrl = ApiConfig.baseUrl;
  double _walletBalance = 0;
  bool _balanceLoading = true;
  String? _balanceError;

  /// 'not_submitted' | 'pending' | 'approved' | 'rejected'
  String _kycStatus = 'not_submitted';

  List<dynamic> _recentTxns = [];
  bool _txnsLoading = true;

  final PageController _bannerController = PageController(
    viewportFraction: 1.0,
    initialPage: _kBannerMidpoint,
  );
  Timer? _autoScrollTimer;

  // Drives the top-bar parallax/fade as the page scrolls — purely visual,
  // no effect on data fetching or navigation.
  final ScrollController _scrollController = ScrollController();
  double _scrollFade = 0.0; // 0 = fully settled, 1 = fully scrolled-past

  static const int _kBannerVirtualCount = 40000; // large even number
  static const int _kBannerMidpoint = _kBannerVirtualCount ~/ 2;

  static const _banners = [
    _BannerData(
      gradientColors: [Color(0xFFDCF3E5), Color(0xFF9AE0BC)],
      tag: '0.30% DAILY ROI',
      title: 'Grow Your Wealth with MoneyTries',
      subtitle:
          'Flexible plans, daily ROI, referral rewards.\nBuild your financial future with confidence.',
      decoIcon: Icons.trending_up_rounded,
      painterType: _BannerPainterType.chart,
    ),
    _BannerData(
      gradientColors: [Color(0xFFDCF3E5), Color(0xFF9AE0BC)],
      tag: 'PLANS',
      title: 'Invest Today. Grow Every Day.',
      subtitle:
          '3, 6, or 12-month plans with daily ROI\ndirectly to your wallet.',
      decoIcon: Icons.rocket_launch_rounded,
      painterType: _BannerPainterType.star,
    ),
    _BannerData(
      gradientColors: [Color(0xFFDCF3E5), Color(0xFF9AE0BC)],
      tag: 'REFER & EARN',
      title: 'Invite Friends. Earn Rewards.',
      subtitle:
          'Refer investors & receive one-time bonuses\ndirectly to your wallet.',
      decoIcon: Icons.people_alt_rounded,
      painterType: _BannerPainterType.referral,
    ),
    _BannerData(
      gradientColors: [Color(0xFFDCF3E5), Color(0xFF9AE0BC)],
      tag: 'SECURE & TRUSTED',
      title: 'Secure Investments, Trusted Future',
      subtitle:
          'Your funds protected with secure verification\nand transparent management.',
      decoIcon: Icons.verified_user_rounded,
      painterType: _BannerPainterType.shield,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _startAutoScroll();
    _fetchBalance();
    _fetchRecentTransactions();
    _loadUserName();
    _fetchKycStatus();
    _scrollController.addListener(_onScroll);
  }

  // Animated app bar: subtle parallax lift + fade on the greeting/avatar
  // as the page scrolls, over the first 60px of scroll — matches the
  // "shrinking header" feel of premium fintech apps without altering
  // layout or requiring a CustomScrollView/sliver restructure.
  void _onScroll() {
    final t = (_scrollController.offset / 60).clamp(0.0, 1.0);
    if (t != _scrollFade) setState(() => _scrollFade = t);
  }

  Future<void> _fetchBalance() async {
    setState(() {
      _balanceLoading = true;
      _balanceError = null;
    });
    try {
      final balances = await _homeRepo.fetchBalances();
      if (!mounted) return;
      setState(() {
        _walletBalance = balances.walletBalance;
        _balanceLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _balanceError = e.toString().replaceFirst('Exception: ', '');
        _balanceLoading = false;
      });
    }
  }

  // ── KYC gate ─────────────────────────────────────────────────────────────

  Future<void> _fetchKycStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null) return;
      final res = await http
          .get(
            Uri.parse('$_kBaseUrl/api/kyc/status'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200 && mounted) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final data = body['data'] as Map<String, dynamic>?;
        setState(() {
          _kycStatus = (data?['status'] as String?) ?? 'not_submitted';
        });
      }
    } catch (_) {}
  }

  /// Returns true if KYC is approved and the caller may proceed.
  /// If not approved, shows the KYC gate bottom-sheet and returns false.
  bool _requireKyc() {
    if (_kycStatus == 'approved') return true;
    _showKycGateSheet();
    return false;
  }

  void _showKycGateSheet() {
    final isPending = _kycStatus == 'pending';
    final isRejected = _kycStatus == 'rejected';

    showPremiumBottomSheet(
      context: context,
      // Drag handle + frosted glass chrome are now drawn by
      // showPremiumBottomSheet itself — this builder only supplies the
      // sheet's own content, unchanged from before.
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(24.w, 12.h, 24.w, 36.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 16.h),
            // Icon
            Container(
              width: 72.w,
              height: 72.h,
              decoration: BoxDecoration(
                color: isPending
                    ? const Color(0xFFFEF3C7)
                    : isRejected
                    ? const Color(0xFFFEE2E2)
                    : const Color(0xFFE8F5EE),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isPending
                    ? Icons.hourglass_top_rounded
                    : isRejected
                    ? Icons.cancel_outlined
                    : Icons.verified_user_outlined,
                size: 36.sp,
                color: isPending
                    ? const Color(0xFFD97706)
                    : isRejected
                    ? const Color(0xFFDC2626)
                    : _brandGreen,
              ),
            ),
            SizedBox(height: 20.h),
            // Title
            Text(
              isPending
                  ? 'KYC Under Review'
                  : isRejected
                  ? 'KYC Rejected'
                  : 'Complete KYC First',
              style: TextStyle(
                fontFamily: GoogleFonts.inter().fontFamily,
                fontSize: 20.sp,
                fontWeight: FontWeight.w700,
                color: _titleDark,
              ),
            ),
            SizedBox(height: 10.h),
            // Subtitle
            Text(
              isPending
                  ? 'Your KYC documents are being reviewed.\nThis usually takes 24–48 hours.'
                  : isRejected
                  ? 'Your KYC was rejected. Please re-submit\nyour documents to access this feature.'
                  : 'You need to complete KYC verification\nbefore you can use Deposit, Withdraw,\nor Investment Plans.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: GoogleFonts.inter().fontFamily,
                fontSize: 13.5.sp,
                color: _subtitleGrey,
                height: 1.5,
              ),
            ),
            SizedBox(height: 28.h),
            // CTA button
            if (!isPending)
              SizedBox(
                width: double.infinity,
                height: 52.h,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(
                      context,
                      AppRoutes.kyc,
                    ).then((_) => _fetchKycStatus());
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _brandGreen,
                    foregroundColor: _white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    isRejected ? 'Re-submit KYC' : 'Verify Now',
                    style: TextStyle(
                      fontFamily: GoogleFonts.inter().fontFamily,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            if (isPending)
              SizedBox(
                width: double.infinity,
                height: 52.h,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: _brandGreen),
                    foregroundColor: _brandGreen,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                  ),
                  child: Text(
                    'OK, Got It',
                    style: TextStyle(
                      fontFamily: GoogleFonts.inter().fontFamily,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadUserName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null) return;
      final res = await http
          .get(
            Uri.parse('$_kBaseUrl/api/profile'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final data = body['data'] as Map<String, dynamic>?;
        if (data != null && mounted) {
          setState(() {
            final fn = data['first_name']?.toString() ?? '';
            final ln = data['last_name']?.toString() ?? '';
            _userName = '$fn $ln'.trim();
            final img = data['profile_image']?.toString();
            // See profile_screen.dart for why this check matters: Cloudinary
            // returns a full https:// URL, local disk returns a bare
            // relative path — only the latter needs the base URL prefixed.
            _avatarUrl = (img != null && img.isNotEmpty)
                ? (img.startsWith('http') ? img : '$_kBaseUrl/uploads/$img')
                : null;
          });
        }
      }
    } catch (_) {}
  }

  void _startAutoScroll() {
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;
      _bannerController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  Future<void> _fetchRecentTransactions() async {
    setState(() => _txnsLoading = true);
    try {
      final txns = await _homeRepo.fetchRecentTransactions();
      if (!mounted) return;
      setState(() {
        _recentTxns = txns;
        _txnsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _txnsLoading = false);
    }
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _bannerController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  String _formatINR(double value) {
    final fixed = value.toStringAsFixed(2);
    final parts = fixed.split('.');
    final intPart = parts[0];
    final decPart = parts[1];
    final buf = StringBuffer();
    final len = intPart.length;
    for (int i = 0; i < len; i++) {
      final pos = len - i;
      buf.write(intPart[i]);
      if (pos > 3 && (pos - 3) % 2 == 0) buf.write(',');
    }
    return '${buf.toString()}.$decPart';
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: _bgColor,
      ),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: Scaffold(
          backgroundColor: _bgColor,
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildAnimatedTopBar(),
                        _buildBannerCarousel(),
                        SizedBox(height: 16.h),
                        _TotalBalanceCard(
                          walletBalance: _walletBalance,
                          balanceLoading: _balanceLoading,
                          balanceError: _balanceError,
                          formatINR: _formatINR,
                          onDeposit: () {
                            if (_requireKyc()) {
                              Navigator.pushNamed(
                                context,
                                AppRoutes.deposit,
                              ).then((_) => _fetchBalance());
                            }
                          },
                          onWithdraw: () {
                            if (_requireKyc()) {
                              Navigator.pushNamed(
                                context,
                                AppRoutes.withdrawal,
                                arguments: {'type': 'wallet'},
                              ).then((_) => _fetchBalance());
                            }
                          },
                        ),
                        SizedBox(height: 20.h),
                        _buildQuickActions(),
                        SizedBox(height: 20.h),
                        _buildRecentTransactions(),
                        SizedBox(height: 16.h),
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
    );
  }

  // ── Animated app bar wrapper ─────────────────────────────────────────────
  // Wraps _buildTopBar with a scroll-driven parallax lift + fade, driven by
  // _scrollFade (see _onScroll). _buildTopBar's own content/logic is
  // untouched — this only transforms it as a whole.
  Widget _buildAnimatedTopBar() {
    return Transform.translate(
      offset: Offset(0, -6 * _scrollFade),
      child: Opacity(
        opacity: 1 - (0.35 * _scrollFade),
        child: _buildTopBar(),
      ),
    );
  }

  // ── Top bar ───────────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
      child: Row(
        children: [
          AnimatedTapScale(
            scaleDown: 0.9,
            onTap: () => Navigator.pushNamed(
              context,
              AppRoutes.profile,
            ).then((_) => _fetchBalance()),
            child: Hero(
              tag: kAppTopbarAvatarHeroTag,
              child: Container(
                width: 46.w,
                height: 46.h,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFE8F5EE),
                  border: Border.all(color: const Color(0xFF4CAF7D), width: 2.r),
                ),
                child: ClipOval(
                  child: _avatarUrl != null
                      ? ShimmerNetworkImage(
                          url: _avatarUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 24.sp,
                          ),
                        )
                      : Icon(
                          Icons.person,
                          color: const Color(0xFF4CAF7D),
                          size: 24.sp,
                        ),
                ),
              ),
            ),
          ),
          SizedBox(width: 12.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hello,',
                style: TextStyle(
                  fontFamily: GoogleFonts.inter().fontFamily,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w400,
                  color: _subtitleGrey,
                  height: 1.2,
                ),
              ),
              Text(
                _userName.isEmpty ? '' : '$_userName!',
                style: TextStyle(
                  fontFamily: GoogleFonts.inter().fontFamily,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w700,
                  color: _titleDark,
                  height: 1.2,
                ),
              ),
            ],
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, AppRoutes.notifications),
            child: Icon(
              Icons.notifications_outlined,
              size: 26.sp,
              color: Color(0xFF4CAF7D),
            ),
          ),
        ],
      ),
    );
  }

  // ── Banner carousel — 4 cards, auto-scroll + user swipe ──────────────────
  Widget _buildBannerCarousel() {
    return Column(
      children: [
        SizedBox(
          height: 168.h,
          child: PageView.builder(
            controller: _bannerController,
            onPageChanged: (i) =>
                setState(() => _currentBannerIndex = i % _banners.length),
            itemCount: _kBannerVirtualCount,
            physics: const BouncingScrollPhysics(),
            itemBuilder: (context, index) {
              final b = _banners[index % _banners.length];
              return Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                child: _buildBannerCard(b),
              );
            },
          ),
        ),
        SizedBox(height: 10.h),
        // Dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_banners.length, (i) {
            final active = i == _currentBannerIndex;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: EdgeInsets.symmetric(horizontal: 3.w),
              width: active ? 20 : 6,
              height: 6.h,
              decoration: BoxDecoration(
                color: active ? _brandGreen : _brandGreen.withOpacity(0.3),
                borderRadius: BorderRadius.circular(3.r),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildBannerCard(_BannerData b) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: b.gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: const Color(0xFFAEE5C6), width: 1.r),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6FC79A).withOpacity(0.25),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Deco painter — right side
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18.r),
              child: CustomPaint(
                painter: _BannerDecoPainter(type: b.painterType),
              ),
            ),
          ),
          // Content
          Padding(
            padding: EdgeInsets.fromLTRB(20.w, 18.h, 20.w, 18.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Tag pill
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10.w,
                    vertical: 4.h,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: Text(
                    b.tag,
                    style: TextStyle(
                      fontFamily: GoogleFonts.inter().fontFamily,
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1F6B45),
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
                SizedBox(height: 10.h),
                Text(
                  b.title,
                  style: TextStyle(
                    fontFamily: GoogleFonts.inter().fontFamily,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1E2A22),
                    height: 1.2,
                  ),
                ),
                SizedBox(height: 6.h),
                Text(
                  b.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: GoogleFonts.inter().fontFamily,
                    fontSize: 12.5.sp,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF3F5B4C).withOpacity(0.88),
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

  // ── Quick Actions ─────────────────────────────────────────────────────────
  Widget _buildQuickActions() {
    final row1 = [
      _QuickAction(icon: Icons.verified_user_rounded, label: 'KYC'),
      _QuickAction(icon: Icons.trending_up_rounded, label: 'Plan'),
      _QuickAction(icon: Icons.history_rounded, label: 'History'),
    ];
    final row2 = [
      _QuickAction(icon: Icons.headset_mic_rounded, label: 'Support'),
      _QuickAction(icon: Icons.lock_rounded, label: 'Security'),
      _QuickAction(icon: Icons.group_add_rounded, label: 'Referral'),
    ];

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Actions',
            style: TextStyle(
              fontFamily: GoogleFonts.inter().fontFamily,
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
              color: _titleDark,
            ),
          ),
          SizedBox(height: 16.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: row1.map(_buildQuickActionItem).toList(),
          ),
          SizedBox(height: 18.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: row2.map(_buildQuickActionItem).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionItem(_QuickAction action) {
    return AnimatedTapScale(
      scaleDown: 0.92,
      onTap: () {
        if (action.label == 'History') {
          Navigator.pushNamed(context, AppRoutes.history);
        } else if (action.label == 'Plan') {
          if (_requireKyc()) Navigator.pushNamed(context, AppRoutes.plan);
        } else if (action.label == 'Support') {
          Navigator.pushNamed(context, AppRoutes.support);
        } else if (action.label == 'KYC') {
          Navigator.pushNamed(context, AppRoutes.kyc);
        } else if (action.label == 'Referral') {
          Navigator.pushNamed(context, AppRoutes.referral);
        } else if (action.label == 'Security') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SecuritySettingsView()),
          );
        }
      },
      child: SizedBox(
        width: 84.w,
        child: Column(
          children: [
            Container(
              width: 66.w,
              height: 66.h,
              decoration: BoxDecoration(
                color: const Color(0xFFDCF3E4),
                borderRadius: BorderRadius.circular(22.r),
              ),
              child: Center(
                child: Icon(action.icon, size: 28.sp, color: _brandGreen),
              ),
            ),
            SizedBox(height: 10.h),
            Text(
              action.label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: GoogleFonts.inter().fontFamily,
                fontSize: 12.5.sp,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1E2A22),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Recent Transactions ───────────────────────────────────────────────────
  Widget _buildRecentTransactions() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Transactions',
                style: TextStyle(
                  fontFamily: GoogleFonts.inter().fontFamily,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w700,
                  color: _titleDark,
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.pushNamed(context, AppRoutes.history),
                child: Text(
                  'See All',
                  style: TextStyle(
                    fontFamily: GoogleFonts.inter().fontFamily,
                    fontSize: 13.5.sp,
                    fontWeight: FontWeight.w600,
                    color: _successGreen,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          if (_txnsLoading)
            Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24.h),
                child: CircularProgressIndicator(
                  color: _successGreen,
                  strokeWidth: 2,
                ),
              ),
            )
          else if (_recentTxns.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 24.h),
              child: Center(
                child: Text(
                  'No transactions yet',
                  style: TextStyle(
                    fontFamily: GoogleFonts.inter().fontFamily,
                    fontSize: 13.sp,
                    color: _labelGrey,
                  ),
                ),
              ),
            )
          else
            ..._recentTxns.map((txn) {
              final t = txn as RecentTransaction;
              final isCredit = t.isCredit;
              final status = t.status.toUpperCase();

              // Icon style based on type
              IconData iconData;
              Color iconBg;
              Color iconColor;
              if (t.type == 'deposit') {
                iconData = Icons.account_balance_outlined;
                iconBg = const Color(0xFFEFF6FF);
                iconColor = const Color(0xFF3B82F6);
              } else if (t.type == 'withdrawal') {
                iconData = Icons.wallet_outlined;
                iconBg = const Color(0xFFFEF2F2);
                iconColor = _withdrawRed;
              } else if (t.type == 'referral') {
                iconData = Icons.people_alt_outlined;
                iconBg = const Color(0xFFF3E8FF);
                iconColor = const Color(0xFF9333EA);
              } else {
                iconData = Icons.trending_up_rounded;
                iconBg = const Color(0xFFE8F5EE);
                iconColor = _successGreen;
              }

              // Amount widget
              final amountStr =
                  '${isCredit ? '+' : '-'}₹ ${t.amount.toStringAsFixed(2)}';
              final amountColor = isCredit ? _successGreen : _withdrawRed;
              final amountWidget = Text(
                amountStr,
                style: TextStyle(
                  fontFamily: GoogleFonts.inter().fontFamily,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                  color: amountColor,
                ),
              );

              // Status badge colours
              Color statusBg;
              Color statusColor;
              if (status == 'APPROVED') {
                statusBg = _successBg;
                statusColor = _successGreen;
              } else if (status == 'REJECTED') {
                statusBg = const Color(0xFFFEE2E2);
                statusColor = _withdrawRed;
              } else {
                statusBg = _processingBg;
                statusColor = _processingText;
              }

              // Date formatting
              // The backend always returns this as a correctly UTC-tagged
              // instant (see config/db.js), so converting to the device's
              // real local timezone here is what makes this card show the
              // exact same time as the Transaction History screen.
              final dt = toDeviceLocal(t.date);
              final months = [
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
              final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
              final ampm = dt.hour < 12 ? 'AM' : 'PM';
              final dateStr =
                  '${dt.day} ${months[dt.month - 1]} ${dt.year} • ${hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} $ampm';

              return StaggeredEntrance(
                index: _recentTxns.indexOf(txn),
                child: _buildTransactionItem(
                  icon: iconData,
                  iconBg: iconBg,
                  iconColor: iconColor,
                  title: t.title,
                  date: dateStr,
                  amountWidget: amountWidget,
                  status: status == 'APPROVED' ? 'SUCCESS' : status,
                  statusBg: statusBg,
                  statusColor: statusColor,
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildTransactionItem({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String date,
    required Widget amountWidget,
    required String status,
    required Color statusBg,
    required Color statusColor,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
      decoration: BoxDecoration(
        color: _surfaceWhite,
        borderRadius: BorderRadius.circular(14.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42.w,
            height: 42.h,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(icon, size: 20.sp, color: iconColor),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: GoogleFonts.inter().fontFamily,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: _titleDark,
                  ),
                ),
                SizedBox(height: 3.h),
                Text(
                  date,
                  style: TextStyle(
                    fontFamily: GoogleFonts.inter().fontFamily,
                    fontSize: 11.5.sp,
                    fontWeight: FontWeight.w400,
                    color: _labelGrey,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              amountWidget,
              SizedBox(height: 4.h),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(6.r),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontFamily: GoogleFonts.inter().fontFamily,
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _onNavTap(int i) {
    if (i == _selectedNavIndex) return;
    switch (i) {
      case 1:
        if (_requireKyc())
          Navigator.pushNamed(
            context,
            AppRoutes.plan,
          ).then((_) => _fetchKycStatus());
        break;
      case 2:
        Navigator.pushNamed(context, AppRoutes.history);
        break;
      case 3:
        Navigator.pushNamed(context, AppRoutes.profile);
        break;
      default:
        setState(() => _selectedNavIndex = i);
    }
  }

  // ── Bottom nav ───────────────────────────────────────────────────────────
  Widget _buildBottomNav() {
    // 0=Home  1=Plan  2=History  3=Profile
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

// ── Total Balance card ───────────────────────────────────────────────────────
// Isolated as its own StatefulWidget so tapping the eye/show-hide toggle only
// rebuilds this small subtree instead of the entire (very large) HomeScreen.
// The real amount widget and the masked-dots widget both stay permanently
// mounted inside a fixed-height Stack and simply cross-fade opacity — nothing
// is destroyed/recreated on toggle, so CountUpText never restarts its count
// animation, and there's no layout jump/overflow between the two states.
class _TotalBalanceCard extends StatefulWidget {
  final double walletBalance;
  final bool balanceLoading;
  final String? balanceError;
  final String Function(double) formatINR;
  final VoidCallback onDeposit;
  final VoidCallback onWithdraw;

  const _TotalBalanceCard({
    required this.walletBalance,
    required this.balanceLoading,
    required this.balanceError,
    required this.formatINR,
    required this.onDeposit,
    required this.onWithdraw,
  });

  @override
  State<_TotalBalanceCard> createState() => _TotalBalanceCardState();
}

class _TotalBalanceCardState extends State<_TotalBalanceCard> {
  bool _visible = false;
  // Bumped every time the balance is *revealed* (hidden → visible). Passed
  // to CountUpText as its replayTrigger so each reveal counts up from 0
  // instead of just fading in the already-settled amount.
  int _revealCount = 0;

  void _toggleVisible() {
    setState(() {
      _visible = !_visible;
      if (_visible) {
        _revealCount++;
        InteractionFeedback.walletBalanceRevealed();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      // Frosted glassmorphism treatment (CRED/Revolut-style): the same
      // brand gradient as before, now with a backdrop blur, soft light
      // border, and a diagonal sheen so the card catches light instead of
      // reading as a flat gradient fill. Content below is untouched.
      child: SizedBox(
        width: double.infinity,
        child: GlassCard(
          padding: EdgeInsets.fromLTRB(20.w, 18.h, 20.w, 20.h),
          borderRadius: BorderRadius.circular(20.r),
          gradientColors: const [Color(0xFFDCF3E5), Color(0xFF9AE0BC)],
          glassOpacity: 0.88,
          shadowColor: const Color(0xFF6FC79A),
          shadowOpacity: 0.28,
          border: Border.all(color: const Color(0xFFAEE5C6), width: 1.r),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Label row with eye toggle
            Row(
              children: [
                Text(
                  'TOTAL BALANCE',
                  style: TextStyle(
                    fontFamily: GoogleFonts.inter().fontFamily,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                    letterSpacing: 1.0,
                  ),
                ),
                SizedBox(width: 8.w),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _toggleVisible,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    transitionBuilder: (child, anim) =>
                        ScaleTransition(scale: anim, child: child),
                    child: Icon(
                      _visible
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      key: ValueKey(_visible),
                      size: 16.sp,
                      color: Colors.black,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            // Balance row — real amount and masked dots coexist; only opacity
            // animates, so nothing remounts and the box never resizes.
            SizedBox(
              height: 40.h,
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                    opacity: _visible ? 1 : 0,
                    child: IgnorePointer(
                      ignoring: !_visible,
                      child: widget.balanceLoading
                          ? SizedBox(
                              height: 28.h,
                              width: 28.w,
                              child: const CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.black,
                                ),
                              ),
                            )
                          : CountUpText(
                              key: const ValueKey('wallet-balance-amount'),
                              value: widget.walletBalance,
                              replayTrigger: _revealCount,
                              formatter: (v) => '₹ ${widget.formatINR(v)}',
                              style: TextStyle(
                                fontFamily: GoogleFonts.inter().fontFamily,
                                fontSize: 34.sp,
                                fontWeight: FontWeight.w800,
                                color: Colors.black,
                                letterSpacing: -0.5,
                                height: 1.15,
                              ),
                            ),
                    ),
                  ),
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                    opacity: _visible ? 0 : 1,
                    child: IgnorePointer(
                      ignoring: _visible,
                      child: Row(
                        children: List.generate(
                          6,
                          (_) => Container(
                            margin: EdgeInsets.only(right: 5.w),
                            width: 14.w,
                            height: 14.h,
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.4),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Error line and "tap to check" hint animate their height in via
            // AnimatedSize instead of snapping the card taller/shorter.
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              alignment: Alignment.topLeft,
              child: (widget.balanceError != null && _visible)
                  ? Padding(
                      padding: EdgeInsets.only(top: 4.h),
                      child: Text(
                        'Could not refresh balance. Pull down to retry.',
                        style: TextStyle(
                          fontFamily: GoogleFonts.inter().fontFamily,
                          fontSize: 11.sp,
                          color: Colors.black,
                        ),
                      ),
                    )
                  : const SizedBox(width: double.infinity, height: 0),
            ),
            SizedBox(height: 6.h),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              alignment: Alignment.topLeft,
              child: !_visible
                  ? GestureDetector(
                      onTap: _toggleVisible,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.remove_red_eye_outlined,
                            size: 13.sp,
                            color: Colors.black,
                          ),
                          SizedBox(width: 4.w),
                          Text(
                            'Tap to check balance',
                            style: TextStyle(
                              fontFamily: GoogleFonts.inter().fontFamily,
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w500,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox(width: double.infinity, height: 0),
            ),
            SizedBox(height: 16.h),
            Row(
              children: [
                Expanded(
                  child: _CardButton(
                    icon: Icons.add_circle_outline,
                    label: 'Deposit',
                    filled: true,
                    onTap: widget.onDeposit,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: _CardButton(
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'Withdraw',
                    filled: false,
                    onTap: widget.onWithdraw,
                  ),
                ),
              ],
            ),
          ],
        ),
        ),
      ),
    );
  }
}

class _CardButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool filled;
  final VoidCallback? onTap;

  const _CardButton({
    required this.icon,
    required this.label,
    required this.filled,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedTapScale(
      onTap: onTap ?? () {},
      child: Container(
        height: 46.h,
        decoration: BoxDecoration(
          color: filled ? _white : Colors.white.withOpacity(0.35),
          borderRadius: BorderRadius.circular(30.r),
          border: filled
              ? null
              : Border.all(color: Colors.white.withOpacity(0.8), width: 1.r),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18.sp, color: const Color(0xFF1F6B45)),
            SizedBox(width: 6.w),
            Text(
              label,
              style: TextStyle(
                fontFamily: GoogleFonts.inter().fontFamily,
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1F6B45),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Data models ───────────────────────────────────────────────────────────────
class _QuickAction {
  final IconData icon;
  final String label;
  const _QuickAction({required this.icon, required this.label});
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}

// ── Banner deco painter — 4 variants ─────────────────────────────────────────
class _BannerDecoPainter extends CustomPainter {
  final _BannerPainterType type;
  const _BannerDecoPainter({required this.type});

  @override
  void paint(Canvas canvas, Size size) {
    switch (type) {
      case _BannerPainterType.chart:
        _paintChart(canvas, size);
      case _BannerPainterType.star:
        _paintStar(canvas, size);
      case _BannerPainterType.referral:
        _paintReferral(canvas, size);
      case _BannerPainterType.shield:
        _paintShield(canvas, size);
    }
  }

  void _paintChart(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = const Color(0xFF3E9E71).withOpacity(0.20)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path()
      ..moveTo(size.width * 0.52, size.height * 0.85)
      ..lineTo(size.width * 0.62, size.height * 0.60)
      ..lineTo(size.width * 0.72, size.height * 0.70)
      ..lineTo(size.width * 0.82, size.height * 0.35)
      ..lineTo(size.width * 0.95, size.height * 0.15);
    canvas.drawPath(path, stroke);

    canvas.drawPath(
      Path()
        ..moveTo(size.width * 0.52, size.height * 0.85)
        ..lineTo(size.width * 0.62, size.height * 0.60)
        ..lineTo(size.width * 0.72, size.height * 0.70)
        ..lineTo(size.width * 0.82, size.height * 0.35)
        ..lineTo(size.width * 0.95, size.height * 0.15)
        ..lineTo(size.width * 0.95, size.height)
        ..lineTo(size.width * 0.52, size.height)
        ..close(),
      Paint()
        ..color = const Color(0xFF3E9E71).withOpacity(0.07)
        ..style = PaintingStyle.fill,
    );

    // Arrowhead
    canvas.drawPath(
      Path()
        ..moveTo(size.width * 0.89, size.height * 0.08)
        ..lineTo(size.width * 0.98, size.height * 0.16)
        ..lineTo(size.width * 0.90, size.height * 0.26)
        ..close(),
      Paint()
        ..color = const Color(0xFF3E9E71).withOpacity(0.22)
        ..style = PaintingStyle.fill,
    );
  }

  void _paintStar(Canvas canvas, Size size) {
    final circlePaint = Paint()
      ..color = const Color(0xFF3E9E71).withOpacity(0.10)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(size.width * 0.82, size.height * 0.25),
      38,
      circlePaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.92, size.height * 0.70),
      20,
      Paint()
        ..color = const Color(0xFF3E9E71).withOpacity(0.07)
        ..style = PaintingStyle.fill,
    );

    // Rocket-like deco lines
    final linePaint = Paint()
      ..color = const Color(0xFF3E9E71).withOpacity(0.18)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    for (int i = 0; i < 5; i++) {
      final x = size.width * (0.60 + i * 0.07);
      canvas.drawLine(
        Offset(x, size.height * 0.5),
        Offset(x - 10, size.height * 0.85),
        linePaint,
      );
    }
  }

  void _paintReferral(Canvas canvas, Size size) {
    final circlePaint = Paint()
      ..color = const Color(0xFF3E9E71).withOpacity(0.10)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(size.width * 0.78, size.height * 0.30),
      30,
      circlePaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.92, size.height * 0.65),
      22,
      circlePaint,
    );

    // Connection dots
    final dotPaint = Paint()
      ..color = const Color(0xFF3E9E71).withOpacity(0.25)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(size.width * 0.72, size.height * 0.28),
      5,
      dotPaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.88, size.height * 0.22),
      5,
      dotPaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.85, size.height * 0.62),
      5,
      dotPaint,
    );

    final linePaint = Paint()
      ..color = const Color(0xFF3E9E71).withOpacity(0.15)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(size.width * 0.72, size.height * 0.28),
      Offset(size.width * 0.88, size.height * 0.22),
      linePaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.88, size.height * 0.22),
      Offset(size.width * 0.85, size.height * 0.62),
      linePaint,
    );
  }

  void _paintShield(Canvas canvas, Size size) {
    final shieldPaint = Paint()
      ..color = const Color(0xFF3E9E71).withOpacity(0.12)
      ..style = PaintingStyle.fill;
    final shieldPath = Path();
    final cx = size.width * 0.80;
    final cy = size.height * 0.42;
    const w = 52.0;
    const h = 58.0;
    shieldPath.moveTo(cx, cy - h / 2);
    shieldPath.lineTo(cx + w / 2, cy - h / 4);
    shieldPath.lineTo(cx + w / 2, cy + h / 5);
    shieldPath.quadraticBezierTo(cx + w / 2, cy + h / 2, cx, cy + h / 2);
    shieldPath.quadraticBezierTo(
      cx - w / 2,
      cy + h / 2,
      cx - w / 2,
      cy + h / 5,
    );
    shieldPath.lineTo(cx - w / 2, cy - h / 4);
    shieldPath.close();
    canvas.drawPath(shieldPath, shieldPaint);

    // Checkmark inside shield
    final checkPaint = Paint()
      ..color = const Color(0xFF3E9E71).withOpacity(0.30)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final checkPath = Path()
      ..moveTo(cx - 10, cy + 2)
      ..lineTo(cx - 3, cy + 10)
      ..lineTo(cx + 12, cy - 8);
    canvas.drawPath(checkPath, checkPaint);
  }

  @override
  bool shouldRepaint(covariant _BannerDecoPainter old) => old.type != type;
}

// ── Plan chart icon — bar chart + zigzag trend arrow ─────────────────────────
class _PlanChartIcon extends StatelessWidget {
  const _PlanChartIcon();
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.all(9.w),
    child: CustomPaint(
      size: const Size(38, 38),
      painter: const _PlanChartPainter(Colors.white),
    ),
  );
}

class _PlanChartIconColored extends StatelessWidget {
  final Color color;
  const _PlanChartIconColored({required this.color});
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.all(9.w),
    child: CustomPaint(
      size: const Size(38, 38),
      painter: _PlanChartPainter(color),
    ),
  );
}

class _PlanChartPainter extends CustomPainter {
  final Color color;
  const _PlanChartPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Base platform
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, h * 0.87, w, h * 0.13),
        Radius.circular(3.r),
      ),
      p,
    );

    // 3 ascending bars
    final bw = w * 0.24;
    final gap = w * 0.035;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, h * 0.70, bw, h * 0.17),
        Radius.circular(2.r),
      ),
      p,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(bw + gap, h * 0.48, bw, h * 0.39),
        Radius.circular(2.r),
      ),
      p,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH((bw + gap) * 2, h * 0.24, bw, h * 0.63),
        Radius.circular(2.r),
      ),
      p,
    );

    // Bold zigzag line
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.02, h * 0.60)
        ..lineTo(w * 0.25, h * 0.28)
        ..lineTo(w * 0.50, h * 0.46)
        ..lineTo(w * 0.70, h * 0.10),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = h * 0.13
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Bold arrowhead
    canvas.drawPath(
      Path()
        ..moveTo(w * 1.00, h * 0.00)
        ..lineTo(w * 0.65, h * 0.00)
        ..lineTo(w * 0.76, h * 0.18)
        ..lineTo(w * 0.86, h * 0.14)
        ..close(),
      p,
    );
  }

  @override
  bool shouldRepaint(covariant _PlanChartPainter old) => old.color != color;
}

// ── Premium Security Icon — shield + lock stack ───────────────────────────────
class _SecurityShieldIcon extends StatelessWidget {
  const _SecurityShieldIcon();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Shield — large, fills most of the button
        Icon(Icons.shield_rounded, size: 36.sp, color: const Color(0xFF8B5E3C)),
        // Lock padlock centred on shield, slightly lower
        Positioned(
          bottom: 10,
          child: Icon(
            Icons.lock_rounded,
            size: 15.sp,
            color: const Color(0xFFF5EFE6),
          ),
        ),
      ],
    );
  }
}