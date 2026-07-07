import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../routes/app_routes.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/home/home_repository.dart';
import '../../utils/date_time_utils.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _bgColor = Color(0xFFECEFF5);
const _brandGreen = Color(0xFF3D9E6A);
const _white = Color(0xFFFFFFFF);
const _titleDark = Color(0xFF111827);
const _subtitleGrey = Color(0xFF6B7280);
const _labelGrey = Color(0xFF9CA3AF);
const _surfaceWhite = Color(0xFFFFFFFF);
const _dividerColor = Color(0xFFE5E7EB);
const _successGreen = Color(0xFF16A34A);
const _successBg = Color(0xFFDCFCE7);
const _processingBg = Color(0xFFFEF3C7);
const _processingText = Color(0xFFD97706);
const _withdrawRed = Color(0xFFEF4444);
const _bottomNavSel = Color(0xFF3D9E6A);
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
  static const String _kBaseUrl = 'http://192.168.0.17:3000';
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

  static const int _kBannerVirtualCount = 40000; // large even number
  static const int _kBannerMidpoint = _kBannerVirtualCount ~/ 2;

  static const _banners = [
    _BannerData(
      gradientColors: [Color(0xFF4DAA75), Color(0xFF86C9A0)],
      tag: '0.30% DAILY ROI',
      title: 'Grow Your Wealth with MoneyTries',
      subtitle:
          'Flexible plans, daily ROI, referral rewards.\nBuild your financial future with confidence.',
      decoIcon: Icons.trending_up_rounded,
      painterType: _BannerPainterType.chart,
    ),
    _BannerData(
      gradientColors: [Color(0xFF3D9E6A), Color(0xFF7DC49A)],
      tag: 'PLANS',
      title: 'Invest Today. Grow Every Day.',
      subtitle:
          '3, 6, or 12-month plans with daily ROI\ndirectly to your wallet.',
      decoIcon: Icons.rocket_launch_rounded,
      painterType: _BannerPainterType.star,
    ),
    _BannerData(
      gradientColors: [Color(0xFF56B47E), Color(0xFF90CFA8)],
      tag: 'REFER & EARN',
      title: 'Invite Friends. Earn Rewards.',
      subtitle:
          'Refer investors & receive one-time bonuses\ndirectly to your wallet.',
      decoIcon: Icons.people_alt_rounded,
      painterType: _BannerPainterType.referral,
    ),
    _BannerData(
      gradientColors: [Color(0xFF48A872), Color(0xFF82C99E)],
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

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: _white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 28),
            // Icon
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: isPending
                    ? const Color(0xFFFEF3C7)
                    : isRejected
                    ? const Color(0xFFFEE2E2)
                    : const Color(0xFFDCFCE7),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isPending
                    ? Icons.hourglass_top_rounded
                    : isRejected
                    ? Icons.cancel_outlined
                    : Icons.verified_user_outlined,
                size: 36,
                color: isPending
                    ? const Color(0xFFD97706)
                    : isRejected
                    ? const Color(0xFFDC2626)
                    : _brandGreen,
              ),
            ),
            const SizedBox(height: 20),
            // Title
            Text(
              isPending
                  ? 'KYC Under Review'
                  : isRejected
                  ? 'KYC Rejected'
                  : 'Complete KYC First',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: _titleDark,
              ),
            ),
            const SizedBox(height: 10),
            // Subtitle
            Text(
              isPending
                  ? 'Your KYC documents are being reviewed.\nThis usually takes 24–48 hours.'
                  : isRejected
                  ? 'Your KYC was rejected. Please re-submit\nyour documents to access this feature.'
                  : 'You need to complete KYC verification\nbefore you can use Deposit, Withdraw,\nor Investment Plans.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13.5,
                color: _subtitleGrey,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            // CTA button
            if (!isPending)
              SizedBox(
                width: double.infinity,
                height: 52,
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
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    isRejected ? 'Re-submit KYC' : 'Verify Now',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            if (isPending)
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: _brandGreen),
                    foregroundColor: _brandGreen,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'OK, Got It',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
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
            _avatarUrl = (img != null && img.isNotEmpty)
                ? '$_kBaseUrl/uploads/$img'
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
    super.dispose();
  }

  String _formatINR(double value) {
    final isWhole = value == value.roundToDouble();
    final intPart = value.truncate().toString();
    final buf = StringBuffer();
    final len = intPart.length;
    for (int i = 0; i < len; i++) {
      final pos = len - i;
      buf.write(intPart[i]);
      if (pos > 3 && (pos - 3) % 2 == 0) buf.write(',');
    }
    if (isWhole) return buf.toString();
    final decPart = value.toStringAsFixed(2).split('.')[1];
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
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTopBar(),
                        _buildBannerCarousel(),
                        const SizedBox(height: 16),
                        _buildBalanceCard(),
                        const SizedBox(height: 20),
                        _buildQuickActions(),
                        const SizedBox(height: 20),
                        _buildRecentTransactions(),
                        const SizedBox(height: 16),
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

  // ── Top bar ───────────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pushNamed(
              context,
              AppRoutes.profile,
            ).then((_) => _fetchBalance()),
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF1B2E4B),
                border: Border.all(color: _brandGreen, width: 2),
              ),
              child: ClipOval(
                child: _avatarUrl != null
                    ? Image.network(
                        _avatarUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 24,
                        ),
                      )
                    : const Icon(Icons.person, color: Colors.white, size: 24),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hello,',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: _subtitleGrey,
                  height: 1.2,
                ),
              ),
              Text(
                _userName.isEmpty ? '' : '$_userName!',
                style: GoogleFonts.poppins(
                  fontSize: 18,
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
            child: const Icon(
              Icons.notifications_outlined,
              size: 26,
              color: _brandGreen,
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
          height: 168,
          child: PageView.builder(
            controller: _bannerController,
            onPageChanged: (i) =>
                setState(() => _currentBannerIndex = i % _banners.length),
            itemCount: _kBannerVirtualCount,
            physics: const BouncingScrollPhysics(),
            itemBuilder: (context, index) {
              final b = _banners[index % _banners.length];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildBannerCard(b),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        // Dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_banners.length, (i) {
            final active = i == _currentBannerIndex;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: active ? 20 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: active ? _brandGreen : _brandGreen.withOpacity(0.3),
                borderRadius: BorderRadius.circular(3),
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
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: b.gradientColors.last.withOpacity(0.35),
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
              borderRadius: BorderRadius.circular(18),
              child: CustomPaint(
                painter: _BannerDecoPainter(type: b.painterType),
              ),
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Tag pill
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    b.tag,
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _white,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  b.title,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _white,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  b.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w400,
                    color: _white.withOpacity(0.88),
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

  // ── Balance card — "Check Balance" toggle ────────────────────────────────
  Widget _buildBalanceCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF3D9E6A), Color(0xFF86C9A0)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF3D9E6A).withOpacity(0.25),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Label row with eye toggle
            Row(
              children: [
                Text(
                  'TOTAL BALANCE',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: _white.withOpacity(0.75),
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () =>
                      setState(() => _balanceVisible = !_balanceVisible),
                  child: Icon(
                    _balanceVisible
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 16,
                    color: _white.withOpacity(0.75),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Balance row
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _balanceVisible
                  ? (_balanceLoading
                        ? SizedBox(
                            key: const ValueKey('loading'),
                            height: 34,
                            width: 34,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                _white.withOpacity(0.85),
                              ),
                            ),
                          )
                        : Text(
                            '₹${_formatINR(_walletBalance)}',
                            key: const ValueKey('visible'),
                            style: GoogleFonts.poppins(
                              fontSize: 34,
                              fontWeight: FontWeight.w800,
                              color: _white,
                              letterSpacing: -0.5,
                              height: 1.15,
                            ),
                          ))
                  : Row(
                      key: const ValueKey('hidden'),
                      children: List.generate(
                        6,
                        (_) => Container(
                          margin: const EdgeInsets.only(right: 5),
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: _white.withOpacity(0.6),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
            ),
            if (_balanceError != null && _balanceVisible)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Could not refresh balance. Pull down to retry.',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: _white.withOpacity(0.85),
                  ),
                ),
              ),
            const SizedBox(height: 6),
            // "Check Balance" tap hint when hidden
            if (!_balanceVisible)
              GestureDetector(
                onTap: () => setState(() => _balanceVisible = true),
                child: Row(
                  children: [
                    Icon(
                      Icons.remove_red_eye_outlined,
                      size: 13,
                      color: _white.withOpacity(0.7),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Tap to check balance',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: _white.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildCardButton(
                    icon: Icons.add_circle_outline,
                    label: 'Deposit',
                    filled: true,
                    onTap: () {
                      if (_requireKyc())
                        Navigator.pushNamed(
                          context,
                          AppRoutes.deposit,
                        ).then((_) => _fetchBalance());
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildCardButton(
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'Withdraw',
                    filled: false,
                    onTap: () {
                      if (_requireKyc())
                        Navigator.pushNamed(
                          context,
                          AppRoutes.withdrawal,
                          arguments: {'type': 'wallet'},
                        ).then((_) => _fetchBalance());
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardButton({
    required IconData icon,
    required String label,
    required bool filled,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap ?? () {},
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: filled ? _white : _white.withOpacity(0.18),
          borderRadius: BorderRadius.circular(30),
          border: filled
              ? null
              : Border.all(color: _white.withOpacity(0.5), width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: filled ? _brandGreen : _white),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: filled ? _brandGreen : _white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Quick Actions ─────────────────────────────────────────────────────────
  Widget _buildQuickActions() {
    final row1 = [
      _QuickAction(icon: Icons.swap_horiz_rounded, label: 'Deposit'),
      _QuickAction(icon: Icons.credit_card_outlined, label: 'Withdraw'),
      _QuickAction(icon: Icons.bar_chart_rounded, label: 'Plan'),
    ];
    final row2 = [
      _QuickAction(icon: Icons.verified_user_outlined, label: 'KYC'),
      _QuickAction(icon: Icons.history_rounded, label: 'History'),
      _QuickAction(icon: Icons.headset_mic_outlined, label: 'Support'),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Actions',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _titleDark,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: row1.map(_buildQuickActionItem).toList(),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: row2.map(_buildQuickActionItem).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionItem(_QuickAction action) {
    return GestureDetector(
      onTap: () {
        if (action.label == 'History') {
          Navigator.pushNamed(context, AppRoutes.history);
        } else if (action.label == 'Plan') {
          if (_requireKyc()) Navigator.pushNamed(context, AppRoutes.plan);
        } else if (action.label == 'Support') {
          Navigator.pushNamed(context, AppRoutes.support);
        } else if (action.label == 'Deposit') {
          if (_requireKyc())
            Navigator.pushNamed(
              context,
              AppRoutes.deposit,
            ).then((_) => _fetchBalance());
        } else if (action.label == 'Withdraw') {
          if (_requireKyc())
            Navigator.pushNamed(
              context,
              AppRoutes.withdrawal,
              arguments: {'type': 'wallet'},
            ).then((_) => _fetchBalance());
        } else if (action.label == 'KYC') {
          Navigator.pushNamed(context, AppRoutes.kyc);
        }
      },
      child: SizedBox(
        width: 80,
        child: Column(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                action.icon,
                size: 24,
                color: const Color(0xFF3B82F6),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              action.label,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: _subtitleGrey,
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
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Transactions',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _titleDark,
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.pushNamed(context, AppRoutes.history),
                child: Text(
                  'See All',
                  style: GoogleFonts.poppins(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: _successGreen,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_txnsLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: CircularProgressIndicator(
                  color: _successGreen,
                  strokeWidth: 2,
                ),
              ),
            )
          else if (_recentTxns.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No transactions yet',
                  style: GoogleFonts.poppins(fontSize: 13, color: _labelGrey),
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
                iconBg = const Color(0xFFECFDF5);
                iconColor = _successGreen;
              }

              // Amount widget
              final amountStr =
                  '${isCredit ? '+' : '-'}₹${t.amount.toStringAsFixed(2)}';
              final amountColor = isCredit ? _successGreen : _withdrawRed;
              final amountWidget = Text(
                amountStr,
                style: GoogleFonts.poppins(
                  fontSize: 14,
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

              return _buildTransactionItem(
                icon: iconData,
                iconBg: iconBg,
                iconColor: iconColor,
                title: t.title,
                date: dateStr,
                amountWidget: amountWidget,
                status: status == 'APPROVED' ? 'SUCCESS' : status,
                statusBg: statusBg,
                statusColor: statusColor,
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
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: _surfaceWhite,
        borderRadius: BorderRadius.circular(14),
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
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _titleDark,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  date,
                  style: GoogleFonts.poppins(
                    fontSize: 11.5,
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
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  status,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
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
                      // Active indicator line
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
      ..color = Colors.white.withOpacity(0.20)
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
        ..color = Colors.white.withOpacity(0.07)
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
        ..color = Colors.white.withOpacity(0.22)
        ..style = PaintingStyle.fill,
    );
  }

  void _paintStar(Canvas canvas, Size size) {
    final circlePaint = Paint()
      ..color = Colors.white.withOpacity(0.10)
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
        ..color = Colors.white.withOpacity(0.07)
        ..style = PaintingStyle.fill,
    );

    // Rocket-like deco lines
    final linePaint = Paint()
      ..color = Colors.white.withOpacity(0.18)
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
      ..color = Colors.white.withOpacity(0.10)
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
      ..color = Colors.white.withOpacity(0.25)
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
      ..color = Colors.white.withOpacity(0.15)
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
      ..color = Colors.white.withOpacity(0.12)
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
      ..color = Colors.white.withOpacity(0.30)
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