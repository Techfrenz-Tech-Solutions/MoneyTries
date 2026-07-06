import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/plan/plan_models.dart';
import '../../routes/app_routes.dart';
import '../../viewmodels/plan/plan_viewmodel.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../profile/personal_information_view.dart';
import '../profile/security_settings_view.dart';
import '../profile/notifications_view.dart';
import '../profile/plan_details_view.dart';
import '../../services/biometric_auth_service.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _bgColor = Color(0xFFECEFF5);
const _white = Color(0xFFFFFFFF);
const _titleDark = Color(0xFF111827);
const _subtitleGrey = Color(0xFF6B7280);
const _dividerColor = Color(0xFFE5E7EB);

const _brandGreen = Color(0xFF3D9E6A);
const _accentGreen = Color(0xFF3D9E6A);
const _iconGreen = Color(0xFF3D9E6A);
const _cardGreenStart = Color(0xFF3D9E6A);
const _cardGreenEnd = Color(0xFF86C9A0);
const _iconBg = Color(0xFFD0EDDC);

const _chipBg = Color(0xFFE6E9F4);
const _chipText = Color(0xFF4B5566);

const _pendingBg = Color(0xFFFCE3E3);
const _pendingText = Color(0xFFDC4444);

const _logoutBg = Color(0xFFFBE0E0);
const _logoutText = Color(0xFFDC4444);

const _bottomNavSel = Color(0xFF3D9E6A);
const _bottomNavUnsel = Color(0xFF9CA3AF);

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _selectedNavIndex = 3;
  String _userName = '';
  String? _avatarUrl;
  String _joinYear = '';
  bool _isProfileLoading = true;
  double _planBalanceLocal = 0;
  double _planBalance = 0;
  int _referralCount = 0;
  String _userId = '';
  static const String _kBaseUrl = 'http://192.168.0.17:3000';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final vm = context.read<PlanViewModel>();
      if (vm.plans.isEmpty) {
        vm.loadPlans();
      } else {
        vm.loadPlanAmount();
      }
    });
    _loadUserName();
  }

  /// Fetches KYC status for the current user directly from the server.
  /// Used by the KYC tile in profile — avoids depending on a global KycViewModel.
  Future<String> _fetchKycStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null) return 'not_submitted';
      final res = await http
          .get(
            Uri.parse('$_kBaseUrl/api/kyc/status'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final data = body['data'] as Map<String, dynamic>?;
        return (data?['status'] as String?) ?? 'not_submitted';
      }
    } catch (_) {}
    return 'not_submitted';
  }

  Future<void> _loadUserName() async {
    if (mounted) setState(() => _isProfileLoading = true);
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
          final fn = data['first_name']?.toString() ?? '';
          final ln = data['last_name']?.toString() ?? '';
          final img = data['profile_image']?.toString();
          final ca = data['created_at']?.toString();
          setState(() {
            _userName = '$fn $ln'.trim();
            _avatarUrl = (img != null && img.isNotEmpty)
                ? '$_kBaseUrl/uploads/$img'
                : null;
            if (ca != null && ca.isNotEmpty) {
              final dt = DateTime.tryParse(ca);
              if (dt != null) _joinYear = dt.year.toString();
            }
            _userId =
                data['id']?.toString() ?? data['user_id']?.toString() ?? '';
            _isProfileLoading = false;
          });
        }
      }
    } catch (_) {}
    // fetch referral count
    _loadReferralCount();
  }

  Future<void> _loadReferralCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null) return;
      final res = await http
          .get(
            Uri.parse('$_kBaseUrl/api/referral/info'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final data = body['data'] as Map<String, dynamic>? ?? body;
        final count =
            int.tryParse(
              data['total_refers']?.toString() ??
                  data['referral_count']?.toString() ??
                  '0',
            ) ??
            0;
        if (mounted) setState(() => _referralCount = count);
      }
    } catch (_) {}
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
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTopBar(),
                        const SizedBox(height: 14),
                        _buildProfileCard(),
                        const SizedBox(height: 20),
                        _buildStatsCard(),
                        const SizedBox(height: 24),
                        _buildSectionHeader('Account Settings'),
                        const SizedBox(height: 12),
                        _buildSettingsTile(
                          icon: Icons.person_outline_rounded,
                          title: 'Personal Information',
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const PersonalInformationView(),
                              ),
                            );
                            // Refresh name/avatar after returning from edit
                            _loadUserName();
                          },
                        ),
                        const SizedBox(height: 12),
                        _buildSettingsTile(
                          icon: Icons.shield_outlined,
                          title: 'Security Settings',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const SecuritySettingsView(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        FutureBuilder<String>(
                          future: _fetchKycStatus(),
                          builder: (context, snapshot) {
                            final kycStatus = snapshot.data ?? 'not_submitted';
                            String? badge;
                            if (kycStatus == 'pending') badge = 'Pending';
                            return _buildSettingsTile(
                              icon: Icons.badge_outlined,
                              title: 'KYC Verification',
                              badgeText: badge,
                              onTap: () =>
                                  Navigator.pushNamed(context, AppRoutes.kyc),
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        _buildSettingsTile(
                          icon: Icons.notifications_none_rounded,
                          title: 'Notifications',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const NotificationScreen(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildPlanDetailsTile(),
                        const SizedBox(height: 24),
                        _buildSectionHeader('General'),
                        const SizedBox(height: 12),
                        _buildInviteFriendsTile(),
                        const SizedBox(height: 12),
                        _buildSettingsTile(
                          icon: Icons.help_outline_rounded,
                          title: 'Help & Support',
                          onTap: () =>
                              Navigator.pushNamed(context, AppRoutes.support),
                        ),
                        const SizedBox(height: 24),
                        _buildLogoutButton(),
                        const SizedBox(height: 16),
                        _buildAppVersion(),
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
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
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
          const SizedBox(width: 16),
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: _brandGreen, width: 2),
              color: _white,
            ),
            child: ClipOval(
              child: _avatarUrl != null
                  ? Image.network(
                      _avatarUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.person,
                        color: _brandGreen,
                        size: 18,
                      ),
                    )
                  : const Icon(Icons.person, color: _brandGreen, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  // ── Profile card ─────────────────────────────────────────────────────────
  Widget _buildProfileCard() {
    return Consumer<PlanViewModel>(
      builder: (context, planVm, _) {
        final hasActivePlan = planVm.plans.any((p) => p.status.isRunning);
        final tierLabel = hasActivePlan
            ? 'Premium Member'
            : 'MoneyTries Member';
        final avatarUrl = _avatarUrl;
        final userName = _userName;
        final joinYear = _joinYear;

        return Column(
          children: [
            // ── Large circle avatar ──
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: _cardGreenStart, width: 3),
                    color: const Color(0xFFE8F5E9),
                    boxShadow: [
                      BoxShadow(
                        color: _cardGreenStart.withOpacity(0.35),
                        blurRadius: 22,
                        spreadRadius: 2,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: avatarUrl != null
                        ? Image.network(
                            avatarUrl,
                            fit: BoxFit.cover,
                            loadingBuilder: (ctx, child, prog) => prog == null
                                ? child
                                : const Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: _brandGreen,
                                    ),
                                  ),
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.person,
                              color: _brandGreen,
                              size: 52,
                            ),
                          )
                        : const Icon(
                            Icons.person,
                            color: _brandGreen,
                            size: 52,
                          ),
                  ),
                ),
                // Camera/edit badge
                GestureDetector(
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PersonalInformationView(),
                      ),
                    );
                    _loadUserName();
                  },
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: _brandGreen,
                      shape: BoxShape.circle,
                      border: Border.all(color: _white, width: 2),
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      size: 14,
                      color: _white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // ── User name ──
            _isProfileLoading
                ? Container(
                    width: 140,
                    height: 22,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  )
                : Text(
                    userName.isEmpty ? '—' : userName,
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF111827),
                      height: 1.2,
                    ),
                  ),
            const SizedBox(height: 10),
            // ── Tier + Since pills ──
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_cardGreenStart, _cardGreenEnd],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: _cardGreenStart.withOpacity(0.28),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        hasActivePlan
                            ? Icons.workspace_premium
                            : Icons.person_outline,
                        color: _white,
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        tierLabel,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _white,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Divider(height: 1, color: Color(0xFFE5E7EB)),
          ],
        );
      },
    );
  }

  // ── Plan Amount Card ─────────────────────────────────────────────────────
  // ── Stats Card (Plan Balance | Referrals | User ID) ──────────────────────
  Widget _buildStatsCard() {
    return Consumer<PlanViewModel>(
      builder: (context, vm, _) {
        final planBalance = vm.planAmount;
        final isLoading = _isProfileLoading;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
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
          child: Row(
            children: [
              _buildStatPill(
                icon: Icons.trending_up_rounded,
                iconColor: _accentGreen,
                iconBg: _iconBg,
                label: 'Plan Balance',
                value: '₹${_fmtAmount(planBalance)}',
                isLoading: vm.listState == PlanVmState.loading,
              ),
              _buildPillDivider(),
              _buildStatPill(
                icon: Icons.people_outline_rounded,
                iconColor: const Color(0xFF7C3AED),
                iconBg: const Color(0xFFF5F3FF),
                label: 'Referrals',
                value: '$_referralCount',
                isLoading: isLoading,
              ),
              _buildPillDivider(),
              _buildStatPill(
                icon: Icons.tag_rounded,
                iconColor: const Color(0xFFD97706),
                iconBg: const Color(0xFFFEF3C7),
                label: 'User ID',
                value: _userId.isEmpty
                    ? '—'
                    : '#${_userId.length > 8 ? _userId.substring(0, 8) : _userId}',
                isLoading: isLoading,
                isMonospace: true,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatPill({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String label,
    required String value,
    bool isLoading = false,
    bool isMonospace = false,
  }) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, size: 22, color: iconColor),
          ),
          const SizedBox(height: 10),
          isLoading
              ? Container(
                  width: 48,
                  height: 13,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(6),
                  ),
                )
              : Text(
                  value,
                  style: isMonospace
                      ? GoogleFonts.robotoMono(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _titleDark,
                          height: 1.1,
                        )
                      : GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: _titleDark,
                          height: 1.1,
                        ),
                  overflow: TextOverflow.ellipsis,
                ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: _subtitleGrey,
              fontWeight: FontWeight.w400,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildPillDivider() => Container(
    width: 1,
    height: 56,
    color: _dividerColor,
    margin: const EdgeInsets.symmetric(horizontal: 4),
  );

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

  // ── Section header ───────────────────────────────────────────────────────
  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: _titleDark,
      ),
    );
  }

  // ── Generic settings tile ────────────────────────────────────────────────
  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    List<String>? chips,
    String? badgeText,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _iconBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: _iconGreen, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _titleDark,
                    ),
                  ),
                ),
                if (badgeText != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: _pendingBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      badgeText,
                      style: GoogleFonts.poppins(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: _pendingText,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                const Icon(
                  Icons.chevron_right_rounded,
                  color: _subtitleGrey,
                  size: 22,
                ),
              ],
            ),
            if (chips != null && chips.isNotEmpty) ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.only(left: 58),
                child: Row(
                  children: chips
                      .map(
                        (c) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _chipBg,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              c,
                              style: GoogleFonts.poppins(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                                color: _chipText,
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Plan Details tile ────────────────────────────────────────────────────
  Widget _buildPlanDetailsTile() {
    return Consumer<PlanViewModel>(
      builder: (context, vm, _) {
        final activePlans = vm.plans.where((p) => p.status.isRunning).toList();
        final totalPlans = vm.plans.length;
        final hasPlans = totalPlans > 0;

        return GestureDetector(
          onTap: () => Navigator.pushNamed(context, AppRoutes.planDetails),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _iconBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.bar_chart_rounded,
                    color: _iconGreen,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Plan Details',
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: _titleDark,
                        ),
                      ),
                      if (hasPlans) ...[
                        const SizedBox(height: 2),
                        Text(
                          activePlans.isNotEmpty
                              ? '${activePlans.length} active plan${activePlans.length > 1 ? 's' : ''} running'
                              : '$totalPlans plan${totalPlans > 1 ? 's' : ''} completed',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: _subtitleGrey,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (activePlans.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${activePlans.length} Active',
                      style: GoogleFonts.poppins(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF3D9E6A),
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: _subtitleGrey,
                  size: 22,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Invite friends tile ──────────────────────────────────────────────────
  Widget _buildInviteFriendsTile() {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, AppRoutes.referral),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE8E8E8)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF3D9E6A).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.person_add_alt_1_rounded,
                color: Color(0xFF3D9E6A),
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Invite Friends',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF3D9E6A),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  // ── Logout button ────────────────────────────────────────────────────────
  Widget _buildLogoutButton() {
    return GestureDetector(
      onTap: () => _handleLogout(context),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: _logoutBg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.logout_rounded, color: _logoutText, size: 20),
            const SizedBox(width: 8),
            Text(
              'Logout',
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: _logoutText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Clears the active session before leaving the app's protected area.
  //
  // Previously this only navigated to the login screen and left
  // `auth_token` / `logged_in_user_id` sitting in SharedPreferences. That
  // meant the next time the app was *opened* (not just navigated), the
  // splash screen still found a "logged in" session and showed the PIN-lock
  // screen for the account that had supposedly been logged out of — instead
  // of the proper email/password login screen. Clearing the session here
  // fixes that, while intentionally leaving the per-account PIN
  // (`app_pin_<userId>`) untouched so the same account won't need to set up
  // its PIN again the next time someone logs back into it.
  Future<void> _handleLogout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('logged_in_user_id') ?? '';
    await prefs.remove('auth_token');
    await prefs.remove('logged_in_user_id');
    await prefs.remove('logged_in_user_label');

    // Logout is a deliberate "sign out of this device" action, so also drop
    // the device-remembered biometric quick-login session for this account —
    // otherwise the fingerprint button on the login screen would silently
    // let the person straight back in right after they chose to log out.
    await BiometricAuthService.forgetSession(userId);

    if (!context.mounted) return;
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.login,
      (route) => false,
    );
  }

  // ── App version ──────────────────────────────────────────────────────────
  Widget _buildAppVersion() {
    return Center(
      child: Text(
        'App Version 4.12.0 (Gold-Tier)',
        style: GoogleFonts.poppins(
          fontSize: 12.5,
          fontWeight: FontWeight.w400,
          color: _subtitleGrey,
        ),
      ),
    );
  }

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
      default:
        setState(() => _selectedNavIndex = i);
    }
  }

  // ── Bottom nav ───────────────────────────────────────────────────────────
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

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}