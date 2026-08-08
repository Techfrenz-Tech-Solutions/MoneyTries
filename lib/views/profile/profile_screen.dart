import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../services/api_service.dart';
import '../../services/push_notification_service.dart';
import '../../core/api/api_config.dart';
import '../../utils/responsive.dart';
import '../../widgets/profile_photo_viewer.dart';
import '../../widgets/premium/premium.dart';
import '../../widgets/animations/animations.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _bgColor = Color(0xFFF7F5F2);
const _white = Color(0xFFFFFFFF);
const _titleDark = Color(0xFF111827);
const _subtitleGrey = Color(0xFF6B7280);
const _dividerColor = Color(0xFFE8E4DE);

const _brandGreen = Color(0xFF1F6B45); // banner dark green
const _accentGreen = Color(0xFF9AE0BC); // banner gradient end
const _iconGreen = Color(0xFF1F6B45); // banner dark green
const _cardGreenStart = Color(0xFFDCF3E5); // banner gradient start
const _cardGreenEnd = Color(0xFF9AE0BC); // banner gradient end
const _iconBg = Color(0xFFDCF3E5); // banner gradient start (soft mint)

const _chipBg = Color(0xFFDCF3E5); // banner gradient start
const _chipText = Color(0xFF1F6B45); // banner dark green

const _pendingBg = Color(0xFFFCE3E3);
const _pendingText = Color(0xFFDC4444);

const _logoutBg = Color(0xFFFBE0E0);
const _logoutText = Color(0xFFDC4444);

const _bottomNavSel = Color(0xFF1F6B45);
const _bottomNavUnsel = Color(0xFF9CA3AF);

// Hero tag connecting the profile card avatar to the full-screen photo viewer.
const String _kProfileAvatarHeroTag = 'profile-avatar-hero';

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
  static const String _kBaseUrl = ApiConfig.baseUrl;
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
            // profile_image is a full https:// URL when stored on Cloudinary,
            // or a bare relative path ("avatars/7/avatar-123.jpg") for the
            // legacy local-disk fallback. Only prefix the base URL for the
            // latter — prefixing an already-absolute Cloudinary URL produced
            // a malformed, unloadable address (base-url + full-url glued
            // together), which is why avatars silently failed to display.
            _avatarUrl = (img != null && img.isNotEmpty)
                ? (img.startsWith('http') ? img : '$_kBaseUrl/uploads/$img')
                : null;
            if (ca != null && ca.isNotEmpty) {
              final dt = DateTime.tryParse(ca);
              if (dt != null) _joinYear = dt.year.toString();
            }
            _userId =
                data['member_id']?.toString() ??
                data['user_code']?.toString() ??
                data['id']?.toString() ??
                data['user_id']?.toString() ??
                '';
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
                    padding: EdgeInsets.symmetric(horizontal: 20.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTopBar(),
                        SizedBox(height: 14.h),
                        _buildProfileCard(),
                        SizedBox(height: 20.h),
                        _buildStatsCard(),
                        SizedBox(height: 24.h),
                        _buildSectionHeader('Account Settings'),
                        SizedBox(height: 12.h),
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
                        SizedBox(height: 12.h),
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
                        SizedBox(height: 12.h),
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
                        SizedBox(height: 12.h),
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
                        SizedBox(height: 12.h),
                        _buildPlanDetailsTile(),
                        SizedBox(height: 24.h),
                        _buildSectionHeader('General'),
                        SizedBox(height: 12.h),
                        _buildInviteFriendsTile(),
                        SizedBox(height: 12.h),
                        _buildSettingsTile(
                          icon: Icons.help_outline_rounded,
                          title: 'Help & Support',
                          onTap: () =>
                              Navigator.pushNamed(context, AppRoutes.support),
                        ),
                        SizedBox(height: 24.h),
                        _buildLogoutButton(),
                        SizedBox(height: 16.h),
                        _buildAppVersion(),
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

  // ── Top bar ───────────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 16.h),
      child: Row(
        children: [
          Text(
            'Moneytries',
            style: TextStyle(
              fontFamily: 'Times New Roman',
              fontSize: 24.sp,
              fontWeight: FontWeight.w800,
              color: _titleDark,
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
          SizedBox(width: 16.w),
          Hero(
            tag: kAppTopbarAvatarHeroTag,
            child: Container(
              width: 38.w,
              height: 38.h,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _brandGreen, width: 2.r),
                color: _white,
              ),
              child: ClipOval(
                child: _avatarUrl != null
                    ? ShimmerNetworkImage(
                        url: _avatarUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            Icon(Icons.person, color: _brandGreen, size: 18.sp),
                      )
                    : Icon(Icons.person, color: _brandGreen, size: 18.sp),
              ),
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
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: avatarUrl == null
                      ? null
                      : () => ProfilePhotoViewer.show(
                          context,
                          imageUrl: avatarUrl,
                          heroTag: _kProfileAvatarHeroTag,
                          userName: userName,
                          sourceRadius: 55.r,
                        ),
                  child: Hero(
                    tag: avatarUrl != null
                        ? _kProfileAvatarHeroTag
                        : '_no_avatar_hero_',
                    child: Container(
                      width: 110.w,
                      height: 110.h,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: _cardGreenStart, width: 3.r),
                        color: const Color(0xFFE8F5EE),
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
                                loadingBuilder: (ctx, child, prog) =>
                                    prog == null
                                    ? child
                                    : const Center(
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: _brandGreen,
                                        ),
                                      ),
                                errorBuilder: (_, __, ___) => Icon(
                                  Icons.person,
                                  color: _brandGreen,
                                  size: 52.sp,
                                ),
                              )
                            : Icon(
                                Icons.person,
                                color: _brandGreen,
                                size: 52.sp,
                              ),
                      ),
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
                    width: 32.w,
                    height: 32.h,
                    decoration: BoxDecoration(
                      color: _brandGreen,
                      shape: BoxShape.circle,
                      border: Border.all(color: _white, width: 2.r),
                    ),
                    child: Icon(Icons.camera_alt, size: 14.sp, color: _white),
                  ),
                ),
              ],
            ),
            SizedBox(height: 14.h),
            // ── User name ──
            _isProfileLoading
                ? Container(
                    width: 140.w,
                    height: 22.h,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8E4DE),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                  )
                : Text(
                    userName.isEmpty ? '—' : userName,
                    style: TextStyle(
                      fontFamily: 'Times New Roman',
                      fontSize: 22.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF111827),
                      height: 1.2,
                    ),
                  ),
            SizedBox(height: 10.h),
            // ── Tier + Since pills ──
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 6.h,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_cardGreenStart, _cardGreenEnd],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(30.r),
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
                        color: _brandGreen,
                        size: 14.sp,
                      ),
                      SizedBox(width: 6.w),
                      Text(
                        tierLabel,
                        style: TextStyle(
                          fontFamily: 'Times New Roman',
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          color: _brandGreen,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 24.h),
            Divider(height: 1.h, color: Color(0xFFE8E4DE)),
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
          padding: EdgeInsets.symmetric(vertical: 20.h, horizontal: 8.w),
          decoration: BoxDecoration(
            color: _white,
            borderRadius: BorderRadius.circular(20.r),
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
            width: 44.w,
            height: 44.h,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(13.r),
            ),
            child: Icon(icon, size: 22.sp, color: iconColor),
          ),
          SizedBox(height: 10.h),
          isLoading
              ? Container(
                  width: 48.w,
                  height: 13.h,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8E4DE),
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                )
              : Text(
                  value,
                  style: isMonospace
                      ? TextStyle(
                          fontFamily: 'Times New Roman',
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w700,
                          color: _titleDark,
                          height: 1.1,
                        )
                      : TextStyle(
                          fontFamily: 'Times New Roman',
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w700,
                          color: _titleDark,
                          height: 1.1,
                        ),
                  overflow: TextOverflow.ellipsis,
                ),
          SizedBox(height: 4.h),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Times New Roman',
              fontSize: 11.sp,
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
    width: 1.w,
    height: 56.h,
    color: _dividerColor,
    margin: EdgeInsets.symmetric(horizontal: 4.w),
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
      style: TextStyle(
        fontFamily: 'Times New Roman',
        fontSize: 15.sp,
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
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          color: _white,
          borderRadius: BorderRadius.circular(16.r),
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
                  width: 44.w,
                  height: 44.h,
                  decoration: BoxDecoration(
                    color: _iconBg,
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Icon(icon, color: _iconGreen, size: 22.sp),
                ),
                SizedBox(width: 14.w),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Times New Roman',
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                      color: _titleDark,
                    ),
                  ),
                ),
                if (badgeText != null) ...[
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 5.h,
                    ),
                    decoration: BoxDecoration(
                      color: _pendingBg,
                      borderRadius: BorderRadius.circular(20.r),
                    ),
                    child: Text(
                      badgeText,
                      style: TextStyle(
                        fontFamily: 'Times New Roman',
                        fontSize: 12.5.sp,
                        fontWeight: FontWeight.w600,
                        color: _pendingText,
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                ],
                Icon(
                  Icons.chevron_right_rounded,
                  color: _subtitleGrey,
                  size: 22.sp,
                ),
              ],
            ),
            if (chips != null && chips.isNotEmpty) ...[
              SizedBox(height: 12.h),
              Padding(
                padding: EdgeInsets.only(left: 58.w),
                child: Row(
                  children: chips
                      .map(
                        (c) => Padding(
                          padding: EdgeInsets.only(right: 8.w),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 14.w,
                              vertical: 6.h,
                            ),
                            decoration: BoxDecoration(
                              color: _chipBg,
                              borderRadius: BorderRadius.circular(20.r),
                            ),
                            child: Text(
                              c,
                              style: TextStyle(
                                fontFamily: 'Times New Roman',
                                fontSize: 12.5.sp,
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
            padding: EdgeInsets.all(14.w),
            decoration: BoxDecoration(
              color: _white,
              borderRadius: BorderRadius.circular(16.r),
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
                  width: 44.w,
                  height: 44.h,
                  decoration: BoxDecoration(
                    color: _iconBg,
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Icon(
                    Icons.trending_up_rounded,
                    color: _iconGreen,
                    size: 22.sp,
                  ),
                ),
                SizedBox(width: 14.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Plan Details',
                        style: TextStyle(
                          fontFamily: 'Times New Roman',
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w600,
                          color: _titleDark,
                        ),
                      ),
                      if (hasPlans) ...[
                        SizedBox(height: 2.h),
                        Text(
                          activePlans.isNotEmpty
                              ? '${activePlans.length} active plan${activePlans.length > 1 ? 's' : ''} running'
                              : '$totalPlans plan${totalPlans > 1 ? 's' : ''} completed',
                          style: TextStyle(
                            fontFamily: 'Times New Roman',
                            fontSize: 12.sp,
                            color: _subtitleGrey,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (activePlans.isNotEmpty)
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 10.w,
                      vertical: 4.h,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5EE),
                      borderRadius: BorderRadius.circular(20.r),
                    ),
                    child: Text(
                      '${activePlans.length} Active',
                      style: TextStyle(
                        fontFamily: 'Times New Roman',
                        fontSize: 11.5.sp,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF4CAF7D),
                      ),
                    ),
                  ),
                SizedBox(width: 8.w),
                Icon(
                  Icons.chevron_right_rounded,
                  color: _subtitleGrey,
                  size: 22.sp,
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
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: const Color(0xFFE8E8E8)),
        ),
        child: Row(
          children: [
            Container(
              width: 44.w,
              height: 44.h,
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF7D).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Icon(
                Icons.person_add_alt_1_rounded,
                color: const Color(0xFF4CAF7D),
                size: 22.sp,
              ),
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Invite Friends',
                    style: TextStyle(
                      fontFamily: 'Times New Roman',
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: const Color(0xFF4CAF7D),
              size: 22.sp,
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
        padding: EdgeInsets.symmetric(vertical: 16.h),
        decoration: BoxDecoration(
          color: _logoutBg,
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout_rounded, color: _logoutText, size: 20.sp),
            SizedBox(width: 8.w),
            Text(
              'Logout',
              style: TextStyle(
                fontFamily: 'Times New Roman',
                fontSize: 15.sp,
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

    // Single Device Login: also clear the active session on the backend
    // (users.active_session_id) so this token can't be reused even before
    // it naturally expires. Best-effort — a failed/offline call here must
    // never block the local logout below.
    final token = prefs.getString('auth_token');
    if (token != null && token.isNotEmpty) {
      try {
        await PushNotificationService.instance.unregisterToken(
          authToken: token,
        );
      } catch (_) {}
      try {
        await ApiService.logout(token: token);
      } catch (_) {}
    }

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
        'App Version 1.1.14',
        style: TextStyle(
          fontFamily: 'Times New Roman',
          fontSize: 12.5.sp,
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