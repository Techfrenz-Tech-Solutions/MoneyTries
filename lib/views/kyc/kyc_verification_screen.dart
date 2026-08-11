// lib/views/kyc/kyc_verification_screen.dart
//
// ── Premium / Luxury Redesign ────────────────────────────────────────────────
// Restyled to match the Moneytries app theme (lib/config/app_theme.dart):
// deep forest-green surfaces, emerald + champagne-gold accents, glass-morphic
// cards and soft glow shadows. Public API (KycVerificationScreen) and all
// KycViewModel / KycFormData bindings are unchanged — this is a visual-only
// rewrite, no ViewModel or backend changes required.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../viewmodels/kyc/kyc_viewmodel.dart';
import '../../models/kyc/kyc_model.dart';
import '../../utils/responsive.dart';
import '../../widgets/animations/shimmer_network_image.dart';

// ══════════════════════════════════════════════════════════════════════════
// PALETTE — matches the Moneytries brand (light green + beige + white)
// ══════════════════════════════════════════════════════════════════════════
const _bg = Color(0xFFF7F5F2); // warm beige-white background
const _surface = Color(0xFFFFFFFF); // white card surfaces
const _surfaceDeep = Color(0xFFFBF9F5); // soft beige card
const _primary = Color(0xFF4CAF7D); // brand light green
const _primaryDim = Color(0xFF7DCB9E); // light green secondary
const _emerald = Color(0xFF4CAF7D); // brand light green
const _mint = Color(0xFF111827); // dark title text
const _bodyGrey = Color(0xFF6B7280); // subtitle grey
const _muted = Color(0xFF9CA3AF); // label grey
const _white = Color(0xFFFFFFFF);
const _champagne = Color(0xFF4CAF7D); // brand light green accent
const _danger = Color(0xFFEF4444);

const _cardBorder = Color(0xFFEDE9E2); // warm beige card border
const _fieldBg = Color(0xFFFFFFFF); // white field background
const _fieldBorder = Color(0xFFD9D5CF); // warm grey border
const _pendingAmber = Color(0xFFB78A2E); // muted gold — "under review" accent
const _pendingAmberBg = Color(0xFFFBF3E1);

// ── Entry widget (public API — unchanged) ────────────────────────────────────
class KycVerificationScreen extends StatelessWidget {
  const KycVerificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Provide a FRESH KycViewModel scoped to this screen only.
    // This ensures every user (including newly logged-in accounts) always
    // gets a new instance that re-checks the server — never inheriting
    // another account's cached approved/pending state.
    return ChangeNotifierProvider(
      create: (_) => KycViewModel(),
      child: const _KycVerificationView(),
    );
  }
}

class _KycVerificationView extends StatefulWidget {
  const _KycVerificationView();

  @override
  State<_KycVerificationView> createState() => _KycVerificationViewState();
}

class _KycVerificationViewState extends State<_KycVerificationView>
    with SingleTickerProviderStateMixin {
  late AnimationController _scanCtrl;
  late Animation<double> _scanAnim;

  KycViewModel? _vm;

  @override
  void initState() {
    super.initState();
    _scanCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _scanAnim = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _scanCtrl, curve: Curves.easeInOut));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _vm = context.read<KycViewModel>();
      _vm!.addListener(_onVmChanged);
    });
  }

  void _onVmChanged() {
    if (!mounted) return;
    final vm = _vm;
    if (vm == null) return;
    if (vm.errorMessage != null) {
      final msg = vm.errorMessage!;
      vm.clearError();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showError(msg);
      });
    }
  }

  @override
  void dispose() {
    _vm?.removeListener(_onVmChanged);
    _scanCtrl.dispose();
    super.dispose();
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline_rounded, color: _white, size: 18.sp),
              SizedBox(width: 10.w),
              Expanded(
                child: Text(
                  msg,
                  style: TextStyle(
                    fontFamily: GoogleFonts.inter().fontFamily,
                    fontSize: 13.5.sp,
                    fontWeight: FontWeight.w500,
                    color: _white,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFFEE2E2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14.r),
            side: BorderSide(color: _danger, width: 0.6.r),
          ),
          margin: EdgeInsets.all(16.w),
          duration: const Duration(seconds: 3),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<KycViewModel>();

    if (vm.checkingStatus) {
      return const _DarkScaffold(
        child: Center(
          child: CircularProgressIndicator(color: _emerald, strokeWidth: 2.4),
        ),
      );
    }

    // KEY FIX preserved: if already submitted (pending/approved), go straight
    // to the success/status screen — skip the upload flow entirely.
    if (vm.alreadySubmitted || vm.completed) {
      return _KycSuccessScreen(
        kycStatus: vm.serverKycStatus,
        details: vm.submissionDetails,
      );
    }

    return _DarkScaffold(
      // Everything — header, progress stepper, upload cards, requirements,
      // security banners, and the Continue button — now lives inside one
      // SingleChildScrollView. Nothing is pinned outside the scroll area, so
      // on short screens or with the keyboard open the user can always
      // scroll to reach content or the Continue button; nothing is ever
      // clipped or hidden behind a fixed bar.
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom > 0
              ? MediaQuery.of(context).viewInsets.bottom + 20
              : 0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTopBar(context, vm),
            _buildProgressBar(vm),
            Padding(
              padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 20.h),
              child: _buildStepContent(vm),
            ),
            _buildBottomBar(vm),
          ],
        ),
      ),
    );
  }

  // ── Top bar ───────────────────────────────────────────────────────────────
  Widget _buildTopBar(BuildContext context, KycViewModel vm) {
    return Padding(
      padding: EdgeInsets.fromLTRB(12.w, 14.h, 20.w, 6.h),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              if (vm.currentStepIndex > 0) {
                vm.goBack();
              } else {
                Navigator.pop(context);
              }
            },
            child: Container(
              width: 40.w,
              height: 40.h,
              decoration: BoxDecoration(
                color: _surface,
                shape: BoxShape.circle,
                border: Border.all(color: _cardBorder, width: 1.r),
              ),
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: _emerald,
                size: 16.sp,
              ),
            ),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  vm.stepTitle,
                  style: TextStyle(
                    fontFamily: GoogleFonts.inter().fontFamily,
                    fontSize: 19.sp,
                    fontWeight: FontWeight.w700,
                    color: _mint,
                    letterSpacing: 0.2,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  'Step ${vm.currentStepIndex + 1} of ${KycStep.values.length} · Secure Verification',
                  style: TextStyle(
                    fontFamily: GoogleFonts.inter().fontFamily,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w500,
                    color: _muted,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 40.w,
            height: 40.h,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [_primary, _emerald],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: _emerald.withOpacity(0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              Icons.verified_user_rounded,
              color: _white,
              size: 19.sp,
            ),
          ),
        ],
      ),
    );
  }

  // ── Progress bar (premium segmented stepper) ─────────────────────────────
  Widget _buildProgressBar(KycViewModel vm) {
    const labels = ['Aadhaar', 'PAN', 'Selfie', 'Bank'];
    const icons = [
      Icons.badge_outlined,
      Icons.credit_card_rounded,
      Icons.face_retouching_natural_rounded,
      Icons.account_balance_rounded,
    ];
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 14.h, 20.w, 4.h),
      child: Row(
        children: List.generate(KycStep.values.length, (i) {
          final isDone = i < vm.currentStepIndex;
          final isActive = i == vm.currentStepIndex;
          final isLast = i == KycStep.values.length - 1;
          return Expanded(
            child: Row(
              children: [
                Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 30.w,
                      height: 30.h,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: (isDone || isActive)
                            ? const LinearGradient(colors: [_primary, _emerald])
                            : null,
                        color: (isDone || isActive) ? null : _surface,
                        border: Border.all(
                          color: (isDone || isActive)
                              ? Colors.transparent
                              : _cardBorder,
                          width: 1.r,
                        ),
                        boxShadow: isActive
                            ? [
                                BoxShadow(
                                  color: _emerald.withOpacity(0.45),
                                  blurRadius: 10,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                      child: Icon(
                        isDone ? Icons.check_rounded : icons[i],
                        size: 15.sp,
                        color: (isDone || isActive) ? _white : _muted,
                      ),
                    ),
                    SizedBox(height: 5.h),
                    Text(
                      labels[i],
                      style: TextStyle(
                        fontFamily: GoogleFonts.inter().fontFamily,
                        fontSize: 9.5.sp,
                        fontWeight: isActive
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: isActive ? _mint : _muted,
                      ),
                    ),
                  ],
                ),
                if (!isLast)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 16.h),
                      child: Container(
                        height: 2.h,
                        margin: EdgeInsets.symmetric(horizontal: 4.w),
                        decoration: BoxDecoration(
                          color: isDone ? _emerald : _cardBorder,
                          borderRadius: BorderRadius.circular(2.r),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  // ── Step router ───────────────────────────────────────────────────────────
  Widget _buildStepContent(KycViewModel vm) {
    switch (vm.currentStep) {
      case KycStep.aadhaar:
        return _buildAadhaarStep(vm);
      case KycStep.pan:
        return _buildPanStep(vm);
      case KycStep.selfie:
        return _buildSelfieStep(vm);
      case KycStep.bank:
        return _buildBankStep(vm);
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // AADHAAR STEP
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildAadhaarStep(KycViewModel vm) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeading(
          'Identity Proof',
          'Upload a clear picture of your original Aadhaar Card for instant verification.',
        ),
        SizedBox(height: 22.h),
        _buildUploadCard(
          title: 'Upload Aadhaar Front',
          subtitle: 'Any image format (Max 5MB)',
          imagePath: vm.form.aadhaarFrontPath,
          onTap: vm.pickAadhaarFront,
        ),
        SizedBox(height: 14.h),
        _buildUploadCard(
          title: 'Upload Aadhaar Back',
          subtitle: 'Any image format (Max 5MB)',
          imagePath: vm.form.aadhaarBackPath,
          onTap: vm.pickAadhaarBack,
        ),
        SizedBox(height: 20.h),
        _buildRequirementsCard(const [
          'Information on the card should be clearly visible and legible.',
          'Avoid any glare, reflections, or shadows on the document.',
          'Card edges must be within the frame of the image.',
        ]),
        SizedBox(height: 16.h),
        _buildSecureBanner(),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PAN STEP
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildPanStep(KycViewModel vm) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeading(
          'PAN Verification',
          'Upload a clear picture of your PAN card for tax compliance and identity verification.',
        ),
        SizedBox(height: 22.h),
        _buildUploadCard(
          title: 'Upload PAN Front',
          subtitle: 'Any image format (Max 5MB)',
          imagePath: vm.form.panFrontPath,
          onTap: vm.pickPanFront,
        ),
        SizedBox(height: 16.h),
        Row(
          children: [
            Expanded(
              child: _buildFeatureCard(
                icon: Icons.shield_outlined,
                title: 'Vault Secure',
                subtitle: 'AES-256 Encrypted',
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: _buildFeatureCard(
                icon: Icons.bolt_rounded,
                title: 'Fast Review',
                subtitle: 'Under 2 mins',
              ),
            ),
          ],
        ),
        SizedBox(height: 20.h),
        _buildRequirementsCard(const [
          'Name and photo clearly visible',
          'Avoid glare and shadows',
          'Document must be valid',
        ]),
        SizedBox(height: 16.h),
        _buildTrustBanner(),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SELFIE STEP
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> _handleCaptureSelfie(KycViewModel vm) async {
    final path = await vm.captureSelfiePhoto();
    if (path == null || !mounted) return;

    final usePhoto = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _SelfiePreviewScreen(imagePath: path),
        fullscreenDialog: true,
      ),
    );

    if (!mounted) return;

    if (usePhoto == true) {
      vm.confirmSelfie(path);
    } else if (usePhoto == false) {
      _handleCaptureSelfie(vm);
    }
  }

  Widget _buildSelfieStep(KycViewModel vm) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'Selfie Verification',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: GoogleFonts.inter().fontFamily,
            fontSize: 23.sp,
            fontWeight: FontWeight.w700,
            color: _mint,
          ),
        ),
        SizedBox(height: 10.h),
        Text(
          'Take a selfie to verify your identity. Ensure\nyour face is within the frame and clearly visible.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: GoogleFonts.inter().fontFamily,
            fontSize: 13.5.sp,
            fontWeight: FontWeight.w400,
            color: _bodyGrey,
            height: 1.55,
          ),
        ),
        SizedBox(height: 26.h),
        _buildSelfiePreview(vm),
        SizedBox(height: 20.h),
        SizedBox(
          width: double.infinity,
          child: _buildSelfieActionBtn(
            icon: Icons.camera_alt_rounded,
            label: vm.form.selfiePath != null
                ? 'Retake Selfie'
                : 'Capture Selfie',
            onTap: () => _handleCaptureSelfie(vm),
            filled: true,
          ),
        ),
        SizedBox(height: 22.h),
        _buildSelfieTipCard(
          icon: Icons.wb_sunny_outlined,
          title: 'Good lighting',
          subtitle: 'Avoid shadows on your face',
        ),
        SizedBox(height: 12.h),
        _buildSelfieTipCard(
          icon: Icons.flash_off_outlined,
          title: 'Remove glasses/hats',
          subtitle: 'Ensure eyes are clearly visible',
        ),
        SizedBox(height: 12.h),
        _buildSelfieTipCard(
          icon: Icons.sentiment_neutral_outlined,
          title: 'Neutral expression',
          subtitle: 'Look directly into the camera',
        ),
        SizedBox(height: 20.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline_rounded, size: 13.sp, color: _muted),
            SizedBox(width: 6.w),
            Text(
              'Encrypted biometric transmission',
              style: TextStyle(
                fontFamily: GoogleFonts.inter().fontFamily,
                fontSize: 11.5.sp,
                fontWeight: FontWeight.w500,
                color: _muted,
              ),
            ),
          ],
        ),
        SizedBox(height: 6.h),
      ],
    );
  }

  Widget _buildSelfiePreview(KycViewModel vm) {
    final captured = vm.form.selfiePath != null;
    return SizedBox(
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _scanAnim,
            builder: (context, child) => Container(
              width: 232.w,
              height: 232.h,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _champagne.withOpacity(0.20 + _scanAnim.value * 0.28),
                  width: 1.4.r,
                ),
              ),
            ),
          ),
          Container(
            width: 200.w,
            height: 200.h,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [_surfaceDeep, _surface],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: _primary.withOpacity(0.22),
                  blurRadius: 28,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          ClipOval(
            child: SizedBox(
              width: 176.w,
              height: 176.h,
              child: captured
                  ? Image.file(File(vm.form.selfiePath!), fit: BoxFit.cover)
                  : Stack(
                      children: [
                        Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [_surfaceDeep, _primaryDim],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                        CustomPaint(painter: _FaceSilhouettePainter()),
                        AnimatedBuilder(
                          animation: _scanAnim,
                          builder: (context, child) => CustomPaint(
                            painter: _FaceScanPainter(_scanAnim.value),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          Positioned(
            bottom: 2,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: captured
                      ? [_primary, _emerald]
                      : [_surface, _surface],
                ),
                borderRadius: BorderRadius.circular(30.r),
                border: captured ? null : Border.all(color: _cardBorder),
                boxShadow: captured
                    ? [
                        BoxShadow(
                          color: _emerald.withOpacity(0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    captured
                        ? Icons.check_circle_outline_rounded
                        : Icons.face_retouching_natural,
                    color: captured ? _white : _muted,
                    size: 16.sp,
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    captured ? 'Selfie Captured' : 'No selfie yet',
                    style: TextStyle(
                      fontFamily: GoogleFonts.inter().fontFamily,
                      fontSize: 12.5.sp,
                      fontWeight: FontWeight.w700,
                      color: captured ? _white : _muted,
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

  Widget _buildSelfieActionBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool filled,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 50.h,
        decoration: BoxDecoration(
          gradient: filled
              ? const LinearGradient(colors: [_primary, _emerald])
              : null,
          color: filled ? null : _surface,
          borderRadius: BorderRadius.circular(15.r),
          border: filled ? null : Border.all(color: _fieldBorder, width: 1.3.r),
          boxShadow: filled
              ? [
                  BoxShadow(
                    color: _emerald.withOpacity(0.32),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18.sp, color: filled ? _white : _emerald),
            SizedBox(width: 8.w),
            Text(
              label,
              style: TextStyle(
                fontFamily: GoogleFonts.inter().fontFamily,
                fontSize: 14.sp,
                fontWeight: FontWeight.w700,
                color: filled ? _white : _emerald,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelfieTipCard({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return _glassCard(
      padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 16.w),
      child: Row(
        children: [
          Container(
            width: 42.w,
            height: 42.h,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _emerald.withOpacity(0.12),
              border: Border.all(color: _emerald.withOpacity(0.25)),
            ),
            child: Icon(icon, color: _emerald, size: 20.sp),
          ),
          SizedBox(width: 14.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontFamily: GoogleFonts.inter().fontFamily,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                  color: _mint,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                subtitle,
                style: TextStyle(
                  fontFamily: GoogleFonts.inter().fontFamily,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w400,
                  color: _bodyGrey,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BANK STEP
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildBankStep(KycViewModel vm) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeading(
          'Link Bank Account',
          "Enter your bank details where you'd like to receive your investment returns.",
          fontSize: 24.sp,
        ),
        SizedBox(height: 26.h),
        _bankFieldLabel('Account Holder Name'),
        SizedBox(height: 8.h),
        _buildBankTextField(
          hint: 'As per bank records',
          prefixIcon: Icons.person_outline_rounded,
          keyboardType: TextInputType.name,
          textCapitalization: TextCapitalization.words,
          onChanged: vm.updateAccountHolder,
          initialValue: vm.form.accountHolderName,
        ),
        SizedBox(height: 18.h),
        _bankFieldLabel('Account Number'),
        SizedBox(height: 8.h),
        _buildBankTextField(
          hint: 'Enter your account number',
          prefixIcon: Icons.account_balance_outlined,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: vm.updateAccountNumber,
          initialValue: vm.form.accountNumber,
        ),
        SizedBox(height: 18.h),
        _bankFieldLabel('IFSC Code'),
        SizedBox(height: 8.h),
        _buildIfscField(vm),
        if (vm.form.bankInfo != null) ...[
          SizedBox(height: 12.h),
          _buildBankInfoCard(vm.form.bankInfo!),
        ],
        if (vm.ifscError != null) ...[
          SizedBox(height: 8.h),
          Row(
            children: [
              Icon(Icons.error_outline_rounded, size: 15.sp, color: _danger),
              SizedBox(width: 6.w),
              Expanded(
                child: Text(
                  vm.ifscError!,
                  style: TextStyle(
                    fontFamily: GoogleFonts.inter().fontFamily,
                    fontSize: 12.5.sp,
                    fontWeight: FontWeight.w500,
                    color: _danger,
                  ),
                ),
              ),
            ],
          ),
        ],
        SizedBox(height: 22.h),
        _buildInstantVerificationBanner(),
        SizedBox(height: 26.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline_rounded, size: 13.sp, color: _muted),
            SizedBox(width: 6.w),
            Text(
              'PCI-DSS Compliant · 256-bit Encryption',
              style: TextStyle(
                fontFamily: GoogleFonts.inter().fontFamily,
                fontSize: 11.5.sp,
                fontWeight: FontWeight.w500,
                color: _muted,
              ),
            ),
          ],
        ),
        SizedBox(height: 6.h),
      ],
    );
  }

  Widget _bankFieldLabel(String label) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        fontFamily: GoogleFonts.inter().fontFamily,
        fontSize: 11.5.sp,
        fontWeight: FontWeight.w700,
        color: _emerald,
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _buildBankTextField({
    required String hint,
    required IconData prefixIcon,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization textCapitalization = TextCapitalization.none,
    List<TextInputFormatter>? inputFormatters,
    required ValueChanged<String> onChanged,
    String initialValue = '',
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _fieldBg,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: _fieldBorder, width: 1.2.r),
      ),
      child: TextFormField(
        initialValue: initialValue.isEmpty ? null : initialValue,
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,
        inputFormatters: inputFormatters,
        onChanged: onChanged,
        cursorColor: _emerald,
        style: TextStyle(
          fontFamily: GoogleFonts.inter().fontFamily,
          fontSize: 15.sp,
          fontWeight: FontWeight.w500,
          color: _mint,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            fontFamily: GoogleFonts.inter().fontFamily,
            fontSize: 14.5.sp,
            fontWeight: FontWeight.w400,
            color: _muted,
          ),
          prefixIcon: Padding(
            padding: EdgeInsets.only(left: 14.w, right: 10.w),
            child: Icon(prefixIcon, color: _muted, size: 21.sp),
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 0,
            minHeight: 0,
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            vertical: 16.h,
            horizontal: 16.w,
          ),
        ),
      ),
    );
  }

  Widget _buildIfscField(KycViewModel vm) {
    return Container(
      decoration: BoxDecoration(
        color: _fieldBg,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: vm.form.bankInfo != null
              ? _emerald
              : vm.ifscError != null
              ? _danger.withOpacity(0.6)
              : _fieldBorder,
          width: 1.2.r,
        ),
      ),
      child: Row(
        children: [
          Padding(
            padding: EdgeInsets.only(left: 14.w, right: 10.w),
            child: Icon(Icons.security_outlined, color: _muted, size: 21.sp),
          ),
          Expanded(
            child: TextFormField(
              initialValue: vm.form.ifscCode.isEmpty ? null : vm.form.ifscCode,
              textCapitalization: TextCapitalization.characters,
              maxLength: 11,
              onChanged: vm.updateIfsc,
              cursorColor: _emerald,
              style: TextStyle(
                fontFamily: GoogleFonts.inter().fontFamily,
                fontSize: 15.sp,
                fontWeight: FontWeight.w600,
                color: _mint,
                letterSpacing: 1.5,
              ),
              decoration: InputDecoration(
                hintText: 'e.g. SBIN0001234',
                hintStyle: TextStyle(
                  fontFamily: GoogleFonts.inter().fontFamily,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w400,
                  color: _muted,
                ),
                counterText: '',
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 16.h),
              ),
            ),
          ),
          GestureDetector(
            onTap: vm.ifscLoading ? null : vm.lookupIfsc,
            child: Padding(
              padding: EdgeInsets.only(right: 14.w),
              child: vm.ifscLoading
                  ? SizedBox(
                      width: 18.w,
                      height: 18.h,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _emerald,
                      ),
                    )
                  : vm.form.bankInfo != null
                  ? Icon(
                      Icons.check_circle_rounded,
                      color: _emerald,
                      size: 20.sp,
                    )
                  : Text(
                      'FIND',
                      style: TextStyle(
                        fontFamily: GoogleFonts.inter().fontFamily,
                        fontSize: 12.5.sp,
                        fontWeight: FontWeight.w800,
                        color: _emerald,
                        letterSpacing: 0.6,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBankInfoCard(IfscBankInfo info) {
    return _glassCard(
      padding: EdgeInsets.all(14.w),
      borderColor: _emerald.withOpacity(0.3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38.w,
            height: 38.h,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _emerald.withOpacity(0.16),
            ),
            child: Icon(
              Icons.account_balance_rounded,
              size: 18.sp,
              color: _emerald,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  info.bankName,
                  style: TextStyle(
                    fontFamily: GoogleFonts.inter().fontFamily,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    color: _mint,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  '${info.branch} — ${info.city}, ${info.state}',
                  style: TextStyle(
                    fontFamily: GoogleFonts.inter().fontFamily,
                    fontSize: 12.5.sp,
                    fontWeight: FontWeight.w400,
                    color: _bodyGrey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstantVerificationBanner() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_primary.withOpacity(0.18), _emerald.withOpacity(0.10)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: _emerald.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42.w,
            height: 42.h,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _emerald.withOpacity(0.2),
            ),
            child: Icon(Icons.verified_outlined, color: _emerald, size: 22.sp),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Instant Verification',
                  style: TextStyle(
                    fontFamily: GoogleFonts.inter().fontFamily,
                    fontSize: 14.5.sp,
                    fontWeight: FontWeight.w800,
                    color: _mint,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  "We'll deposit ₹1.00 to verify your account instantly.",
                  style: TextStyle(
                    fontFamily: GoogleFonts.inter().fontFamily,
                    fontSize: 12.5.sp,
                    fontWeight: FontWeight.w400,
                    color: _bodyGrey,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SHARED WIDGETS
  // ══════════════════════════════════════════════════════════════════════════
  Widget _sectionHeading(
    String title,
    String subtitle, {
    double fontSize = 22,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4.w,
              height: 22.h,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_primary, _emerald]),
                borderRadius: BorderRadius.circular(4.r),
              ),
            ),
            SizedBox(width: 10.w),
            Text(
              title,
              style: TextStyle(
                fontFamily: GoogleFonts.inter().fontFamily,
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
                color: _mint,
              ),
            ),
          ],
        ),
        SizedBox(height: 10.h),
        Text(
          subtitle,
          style: TextStyle(
            fontFamily: GoogleFonts.inter().fontFamily,
            fontSize: 13.5.sp,
            fontWeight: FontWeight.w400,
            color: _bodyGrey,
            height: 1.55,
          ),
        ),
      ],
    );
  }

  Widget _buildUploadCard({
    required String title,
    required String subtitle,
    required String? imagePath,
    required VoidCallback onTap,
  }) {
    final uploaded = imagePath != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(18.r),
          border: Border.all(
            color: uploaded ? _emerald.withOpacity(0.7) : _cardBorder,
            width: 1.4.r,
          ),
          boxShadow: uploaded
              ? [
                  BoxShadow(
                    color: _emerald.withOpacity(0.15),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: uploaded
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Image.file(File(imagePath), fit: BoxFit.cover),
                  ),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 10.h,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _primary.withOpacity(0.92),
                          _emerald.withOpacity(0.92),
                        ],
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          size: 18.sp,
                          color: _white,
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text(
                            'Uploaded successfully — tap to change',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: GoogleFonts.inter().fontFamily,
                              fontSize: 12.5.sp,
                              fontWeight: FontWeight.w600,
                              color: _white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : Padding(
                padding: EdgeInsets.symmetric(vertical: 34.h, horizontal: 20.w),
                child: Column(
                  children: [
                    Container(
                      width: 56.w,
                      height: 56.h,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            _primary.withOpacity(0.85),
                            _emerald.withOpacity(0.85),
                          ],
                        ),
                      ),
                      child: Icon(
                        Icons.add_a_photo_outlined,
                        size: 24.sp,
                        color: _white,
                      ),
                    ),
                    SizedBox(height: 14.h),
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: GoogleFonts.inter().fontFamily,
                        fontSize: 15.5.sp,
                        fontWeight: FontWeight.w800,
                        color: _mint,
                      ),
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontFamily: GoogleFonts.inter().fontFamily,
                        fontSize: 12.5.sp,
                        fontWeight: FontWeight.w500,
                        color: _muted,
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return _glassCard(
      padding: EdgeInsets.all(14.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32.w,
            height: 32.h,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _emerald.withOpacity(0.15),
            ),
            child: Icon(icon, size: 16.sp, color: _emerald),
          ),
          SizedBox(height: 10.h),
          Text(
            title,
            style: TextStyle(
              fontFamily: GoogleFonts.inter().fontFamily,
              fontSize: 13.5.sp,
              fontWeight: FontWeight.w800,
              color: _mint,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            subtitle,
            style: TextStyle(
              fontFamily: GoogleFonts.inter().fontFamily,
              fontSize: 11.5.sp,
              fontWeight: FontWeight.w400,
              color: _bodyGrey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequirementsCard(List<String> requirements) {
    return _glassCard(
      padding: EdgeInsets.all(18.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 18.sp, color: _champagne),
              SizedBox(width: 8.w),
              Text(
                'Requirements',
                style: TextStyle(
                  fontFamily: GoogleFonts.inter().fontFamily,
                  fontSize: 14.5.sp,
                  fontWeight: FontWeight.w800,
                  color: _mint,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          ...requirements.map(
            (r) => Padding(
              padding: EdgeInsets.only(bottom: 10.h),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 18.w,
                    height: 18.h,
                    margin: EdgeInsets.only(top: 1.h),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _emerald.withOpacity(0.15),
                    ),
                    child: Icon(
                      Icons.check_rounded,
                      size: 12.sp,
                      color: _emerald,
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Text(
                      r,
                      style: TextStyle(
                        fontFamily: GoogleFonts.inter().fontFamily,
                        fontSize: 12.5.sp,
                        fontWeight: FontWeight.w400,
                        color: _bodyGrey,
                        height: 1.45,
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

  Widget _buildTrustBanner() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18.r),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_surface, _surfaceDeep],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: _champagne.withOpacity(0.25)),
        ),
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _WavePainter())),
            Row(
              children: [
                Container(
                  width: 40.w,
                  height: 40.h,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _champagne.withOpacity(0.14),
                    border: Border.all(color: _champagne.withOpacity(0.4)),
                  ),
                  child: Icon(
                    Icons.workspace_premium_rounded,
                    size: 19.sp,
                    color: _champagne,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'IDENTITY TRUST',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: GoogleFonts.inter().fontFamily,
                          fontSize: 11.5.sp,
                          fontWeight: FontWeight.w800,
                          color: _champagne,
                          letterSpacing: 0.8,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        'Verified by Moneytries Global Compliance',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: GoogleFonts.inter().fontFamily,
                          fontSize: 11.5.sp,
                          fontWeight: FontWeight.w400,
                          color: _bodyGrey,
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
    );
  }

  Widget _buildSecureBanner() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18.r),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(18.w),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_surfaceDeep, _surface],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: _cardBorder),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -10,
              top: -14,
              child: Icon(
                Icons.shield_moon_rounded,
                size: 108.sp,
                color: _emerald.withOpacity(0.06),
              ),
            ),
            Row(
              children: [
                Icon(
                  Icons.verified_user_rounded,
                  size: 17.sp,
                  color: _emerald.withOpacity(0.9),
                ),
                SizedBox(width: 8.w),
                Text(
                  'Bank-Grade Encryption Enabled',
                  style: TextStyle(
                    fontFamily: GoogleFonts.inter().fontFamily,
                    fontSize: 12.5.sp,
                    fontWeight: FontWeight.w700,
                    color: _mint,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Reusable glass-morphic card matching the app's dark premium surfaces.
  Widget _glassCard({
    required Widget child,
    EdgeInsetsGeometry? padding,
    Color? borderColor,
  }) {
    return Container(
      width: double.infinity,
      padding: padding ?? EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: borderColor ?? _cardBorder, width: 1.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  // ── Bottom bar ────────────────────────────────────────────────────────────
  Widget _buildBottomBar(KycViewModel vm) {
    final isLoading = vm.status == KycStatus.loading;
    final isSelfie = vm.currentStep == KycStep.selfie;
    final isBank = vm.currentStep == KycStep.bank;

    return Container(
      padding: EdgeInsets.fromLTRB(20.w, 14.h, 20.w, 8.h),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28.r),
          topRight: Radius.circular(28.r),
        ),
        border: Border(
          top: BorderSide(color: _cardBorder, width: 1.r),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 20,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            SizedBox(
              width: double.infinity,
              height: 54.h,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: vm.canContinue
                        ? [_primary, _emerald]
                        : [
                            _primary.withOpacity(0.35),
                            _emerald.withOpacity(0.35),
                          ],
                  ),
                  borderRadius: BorderRadius.circular(30.r),
                  boxShadow: vm.canContinue
                      ? [
                          BoxShadow(
                            color: _emerald.withOpacity(0.35),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                        ]
                      : null,
                ),
                child: ElevatedButton(
                  onPressed: isLoading ? null : vm.goNext,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: _white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30.r),
                    ),
                  ),
                  child: isLoading
                      ? SizedBox(
                          width: 22.w,
                          height: 22.h,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _white,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (isSelfie) ...[
                              Icon(
                                Icons.camera_alt_rounded,
                                size: 18.sp,
                                color: _white,
                              ),
                              SizedBox(width: 8.w),
                            ],
                            Text(
                              vm.nextLabel,
                              style: TextStyle(
                                fontFamily: GoogleFonts.inter().fontFamily,
                                fontSize: 15.5.sp,
                                fontWeight: FontWeight.w700,
                                color: _white,
                              ),
                            ),
                            if (!isSelfie && !isBank) ...[
                              SizedBox(width: 8.w),
                              Icon(
                                Icons.arrow_forward_rounded,
                                size: 18.sp,
                                color: _white,
                              ),
                            ],
                          ],
                        ),
                ),
              ),
            ),
            SizedBox(height: 12.h),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: TextStyle(
                  fontFamily: GoogleFonts.inter().fontFamily,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w400,
                  color: _muted,
                  height: 1.5,
                ),
                children: [
                  const TextSpan(text: 'By continuing, you agree to our '),
                  TextSpan(
                    text: 'Privacy Policy',
                    style: TextStyle(
                      fontFamily: GoogleFonts.inter().fontFamily,
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w700,
                      color: _emerald,
                    ),
                  ),
                  const TextSpan(text: ' regarding document storage.'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SELFIE PREVIEW — Retake / Use Photo confirmation before committing the shot
// ══════════════════════════════════════════════════════════════════════════════

class _SelfiePreviewScreen extends StatelessWidget {
  final String imagePath;
  const _SelfiePreviewScreen({required this.imagePath});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(8.w, 4.h, 8.w, 0.h),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.close_rounded,
                        color: _mint,
                        size: 24.sp,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Review Your Selfie',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: GoogleFonts.inter().fontFamily,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w700,
                          color: _mint,
                        ),
                      ),
                    ),
                    SizedBox(width: 48.w),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(20.w),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(26.r),
                      border: Border.all(
                        color: _emerald.withOpacity(0.35),
                        width: 1.4.r,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _emerald.withOpacity(0.18),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(25.r),
                      child: Image.file(
                        File(imagePath),
                        fit: BoxFit.cover,
                        width: double.infinity,
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 20.h),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.pop(context, false),
                        icon: Icon(
                          Icons.refresh_rounded,
                          color: _mint,
                          size: 20.sp,
                        ),
                        label: Text(
                          'Retake',
                          style: TextStyle(
                            fontFamily: GoogleFonts.inter().fontFamily,
                            fontSize: 14.5.sp,
                            fontWeight: FontWeight.w600,
                            color: _mint,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: _fieldBorder, width: 1.4.r),
                          padding: EdgeInsets.symmetric(vertical: 15.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14.r),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 14.w),
                    Expanded(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [_primary, _emerald],
                          ),
                          borderRadius: BorderRadius.circular(14.r),
                        ),
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.pop(context, true),
                          icon: Icon(
                            Icons.check_rounded,
                            color: _white,
                            size: 20.sp,
                          ),
                          label: Text(
                            'Use Photo',
                            style: TextStyle(
                              fontFamily: GoogleFonts.inter().fontFamily,
                              fontSize: 14.5.sp,
                              fontWeight: FontWeight.w700,
                              color: _white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            elevation: 0,
                            padding: EdgeInsets.symmetric(vertical: 15.h),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14.r),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SUBMITTED DOCUMENT CARD + WHATSAPP-STYLE FULL-SCREEN PREVIEW
// ══════════════════════════════════════════════════════════════════════════════

/// Premium rounded document thumbnail — soft shadow, shimmer placeholder
/// while the image loads, and a tap-to-view full-screen preview (pinch to
/// zoom, drag down to dismiss) matching the WhatsApp media-viewer feel.
class _KycDocCard extends StatelessWidget {
  final String label;
  final String? url;
  final String? authToken;
  final double aspectRatio;

  const _KycDocCard({
    required this.label,
    required this.url,
    required this.authToken,
    this.aspectRatio = 4 / 3,
  });

  String get _heroTag => 'kyc-doc-${label.toLowerCase().replaceAll(' ', '-')}';

  Map<String, String> get _headers =>
      authToken != null ? {'Authorization': 'Bearer $authToken'} : const {};

  void _openPreview(BuildContext context) {
    if (url == null) return;
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        transitionDuration: const Duration(milliseconds: 220),
        reverseTransitionDuration: const Duration(milliseconds: 180),
        pageBuilder: (context, animation, __) => FadeTransition(
          opacity: animation,
          child: _DocumentPreviewScreen(
            heroTag: _heroTag,
            label: label,
            url: url!,
            headers: _headers,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: GoogleFonts.inter().fontFamily,
            fontSize: 11.5.sp,
            fontWeight: FontWeight.w700,
            color: _bodyGrey,
            letterSpacing: 0.2,
          ),
        ),
        SizedBox(height: 8.h),
        GestureDetector(
          onTap: url == null ? null : () => _openPreview(context),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16.r),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.10),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Hero(
              tag: _heroTag,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16.r),
                child: AspectRatio(
                  aspectRatio: aspectRatio,
                  child: Container(
                    color: _fieldBg,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        url == null
                            ? Center(
                                child: Icon(
                                  Icons.image_not_supported_outlined,
                                  color: _muted,
                                  size: 22.sp,
                                ),
                              )
                            : ShimmerNetworkImage(
                                url: url!,
                                fit: BoxFit.cover,
                                headers: _headers,
                                errorBuilder: (context, error, stack) => Center(
                                  child: Icon(
                                    Icons.broken_image_outlined,
                                    color: _muted,
                                    size: 22.sp,
                                  ),
                                ),
                              ),
                        if (url != null)
                          Positioned(
                            right: 8.w,
                            bottom: 8.h,
                            child: Container(
                              padding: EdgeInsets.all(5.w),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.45),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.zoom_in_rounded,
                                size: 13.sp,
                                color: _white,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Full-screen document viewer — black backdrop, pinch/double-tap to zoom
/// via [InteractiveViewer], and a drag-down-to-dismiss gesture that fades
/// the backdrop and shrinks the image as it follows the finger, matching
/// the familiar WhatsApp media-preview interaction.
class _DocumentPreviewScreen extends StatefulWidget {
  final String heroTag;
  final String label;
  final String url;
  final Map<String, String> headers;

  const _DocumentPreviewScreen({
    required this.heroTag,
    required this.label,
    required this.url,
    required this.headers,
  });

  @override
  State<_DocumentPreviewScreen> createState() => _DocumentPreviewScreenState();
}

class _DocumentPreviewScreenState extends State<_DocumentPreviewScreen> {
  Offset _dragOffset = Offset.zero;
  double _dragProgress = 0; // 0 (settled) → 1 (about to dismiss)

  void _onDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragOffset += details.delta;
      _dragProgress = (_dragOffset.dy.abs() / 260).clamp(0.0, 1.0);
    });
  }

  void _onDragEnd(DragEndDetails details) {
    final flungDown = details.velocity.pixelsPerSecond.dy > 600;
    if (_dragProgress > 0.25 || flungDown) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _dragOffset = Offset.zero;
      _dragProgress = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scale = 1 - (_dragProgress * 0.2);
    return Scaffold(
      backgroundColor: Colors.black.withOpacity(1 - _dragProgress * 0.7),
      body: Stack(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onVerticalDragUpdate: _onDragUpdate,
            onVerticalDragEnd: _onDragEnd,
            onTap: () => Navigator.of(context).pop(),
            child: Center(
              child: Transform.translate(
                offset: _dragOffset,
                child: Transform.scale(
                  scale: scale,
                  child: Hero(
                    tag: widget.heroTag,
                    child: GestureDetector(
                      // Swallow taps that land on the image itself so only
                      // tapping the backdrop dismisses the preview.
                      onTap: () {},
                      child: InteractiveViewer(
                        minScale: 1,
                        maxScale: 4,
                        child: Image(
                          image: NetworkImage(
                            widget.url,
                            headers: widget.headers,
                          ),
                          fit: BoxFit.contain,
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return SizedBox(
                              width: 220.w,
                              height: 220.w,
                              child: Center(
                                child: SizedBox(
                                  width: 28.w,
                                  height: 28.w,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                    color: _white,
                                    value: progress.expectedTotalBytes != null
                                        ? progress.cumulativeBytesLoaded /
                                              progress.expectedTotalBytes!
                                        : null,
                                  ),
                                ),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stack) => Icon(
                            Icons.broken_image_outlined,
                            color: Colors.white38,
                            size: 48.sp,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: IgnorePointer(
              ignoring: _dragProgress > 0.5,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 120),
                opacity: 1 - _dragProgress,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(8.w, 4.h, 8.w, 0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(
                          Icons.close_rounded,
                          color: _white,
                          size: 24.sp,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          widget.label,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: GoogleFonts.inter().fontFamily,
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w700,
                            color: _white,
                          ),
                        ),
                      ),
                      SizedBox(width: 48.w),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SUCCESS / STATUS SCREEN
// ══════════════════════════════════════════════════════════════════════════════

class _KycSuccessScreen extends StatefulWidget {
  /// The status from the server: 'pending' | 'approved' | 'not_submitted'
  final String kycStatus;

  /// The submitted documents + bank details, shown once the KYC has been
  /// approved by an admin. Null if not yet available.
  final KycSubmissionDetails? details;

  const _KycSuccessScreen({this.kycStatus = 'pending', this.details});

  @override
  State<_KycSuccessScreen> createState() => _KycSuccessScreenState();
}

class _KycSuccessScreenState extends State<_KycSuccessScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  String? _authToken;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _scaleAnim = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _ctrl.forward();
    _loadToken();
  }

  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (mounted && token != null) {
      setState(() => _authToken = token);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  bool get _isApproved => widget.kycStatus == 'approved';

  @override
  Widget build(BuildContext context) {
    final d = widget.details;
    return _DarkScaffold(
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 28.w),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 40.w,
                    height: 40.h,
                    decoration: BoxDecoration(
                      color: _surface,
                      shape: BoxShape.circle,
                      border: Border.all(color: _cardBorder),
                    ),
                    child: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 17.sp,
                      color: _emerald,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.only(top: 16.h, bottom: 16.h),
                  child: Column(
                    children: [
                      FadeTransition(
                        opacity: _fadeAnim,
                        child: ScaleTransition(
                          scale: _scaleAnim,
                          child: SizedBox(
                            width: 140.w,
                            height: 140.h,
                            child: Stack(
                              clipBehavior: Clip.none,
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  width: 124.w,
                                  height: 124.h,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      colors: _isApproved
                                          ? const [_primary, _emerald]
                                          : [
                                              _pendingAmber,
                                              _pendingAmber.withOpacity(0.75),
                                            ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    border: Border.all(
                                      color: _champagne.withOpacity(0.5),
                                      width: 2.r,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color:
                                            (_isApproved
                                                    ? _emerald
                                                    : _pendingAmber)
                                                .withOpacity(0.4),
                                        blurRadius: 36,
                                        offset: const Offset(0, 12),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    _isApproved
                                        ? Icons.verified_rounded
                                        : Icons.hourglass_top_rounded,
                                    size: 56.sp,
                                    color: _white,
                                  ),
                                ),
                                // Overlapping status ribbon — the one detail
                                // missing before that made "submitted" and
                                // "approved" look identical at a glance.
                                Positioned(
                                  bottom: -6.h,
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 14.w,
                                      vertical: 6.h,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _surface,
                                      borderRadius: BorderRadius.circular(30.r),
                                      border: Border.all(
                                        color: _isApproved
                                            ? _emerald.withOpacity(0.35)
                                            : _pendingAmber.withOpacity(0.35),
                                        width: 1.2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.08),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          _isApproved
                                              ? Icons.check_circle_rounded
                                              : Icons.access_time_rounded,
                                          size: 12.sp,
                                          color: _isApproved
                                              ? _emerald
                                              : _pendingAmber,
                                        ),
                                        SizedBox(width: 5.w),
                                        Text(
                                          _isApproved
                                              ? 'VERIFIED'
                                              : 'UNDER REVIEW',
                                          style: TextStyle(
                                            fontFamily:
                                                GoogleFonts.inter().fontFamily,
                                            fontSize: 10.sp,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.8,
                                            color: _isApproved
                                                ? _emerald
                                                : _pendingAmber,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 44.h),
                      FadeTransition(
                        opacity: _fadeAnim,
                        child: Text(
                          _isApproved
                              ? 'KYC Approved!'
                              : 'Verification\nSubmitted!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: GoogleFonts.inter().fontFamily,
                            fontSize: 30.sp,
                            fontWeight: FontWeight.w700,
                            color: _mint,
                            height: 1.2,
                          ),
                        ),
                      ),
                      SizedBox(height: 16.h),
                      FadeTransition(
                        opacity: _fadeAnim,
                        child: Text(
                          _isApproved
                              ? 'Your KYC has been verified successfully. You can now access all Moneytries features.'
                              : 'Your KYC documents have been submitted successfully. Our team will review and verify your identity within 24 hours.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: GoogleFonts.inter().fontFamily,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w400,
                            color: _bodyGrey,
                            height: 1.6,
                          ),
                        ),
                      ),
                      // Show the submitted documents + bank details for both
                      // pending review and approved KYC.
                      SizedBox(height: 32.h),
                      FadeTransition(
                        opacity: _fadeAnim,
                        child: _buildProgressCard(),
                      ),
                      if (d != null) ...[
                        SizedBox(height: 36.h),
                        FadeTransition(
                          opacity: _fadeAnim,
                          child: _buildSubmittedDetailsCard(d, _authToken),
                        ),
                      ],
                      SizedBox(height: 32.h),
                      SizedBox(
                        width: double.infinity,
                        height: 54.h,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [_primary, _emerald],
                            ),
                            borderRadius: BorderRadius.circular(30.r),
                            boxShadow: [
                              BoxShadow(
                                color: _emerald.withOpacity(0.35),
                                blurRadius: 18,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: () => Navigator.of(
                              context,
                            ).popUntil((route) => route.isFirst),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              foregroundColor: _white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30.r),
                              ),
                            ),
                            child: Text(
                              'Back to Home',
                              style: TextStyle(
                                fontFamily: GoogleFonts.inter().fontFamily,
                                fontSize: 15.5.sp,
                                fontWeight: FontWeight.w700,
                                color: _white,
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 12.h),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Verification progress — gives the pending state a sense of motion
  // instead of a single static paragraph, and gives the approved state a
  // clear "here's how you got here" recap. ─────────────────────────────────
  Widget _buildProgressCard() {
    final approved = _isApproved;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 22.h),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(color: _cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          _statusRow(
            icon: Icons.upload_file_rounded,
            label: 'Documents Submitted',
            done: true,
          ),
          _timelineConnector(done: true),
          _statusRow(
            icon: Icons.fact_check_rounded,
            label: 'Under Admin Review',
            done: approved,
            active: !approved,
          ),
          _timelineConnector(done: approved),
          _statusRow(
            icon: Icons.verified_user_rounded,
            label: 'Verified & Approved',
            done: approved,
            active: false,
          ),
        ],
      ),
    );
  }

  Widget _timelineConnector({required bool done}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2.h),
      child: Row(
        children: [
          SizedBox(width: 19.5.w),
          Container(
            width: 2,
            height: 22.h,
            color: done ? _emerald.withOpacity(0.4) : _cardBorder,
          ),
        ],
      ),
    );
  }

  // ── Submitted KYC details (shown after admin approval) ───────────────────
  Widget _buildSubmittedDetailsCard(KycSubmissionDetails d, String? authToken) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(color: _cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.verified_user_rounded, size: 18.sp, color: _emerald),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  'Your Submitted KYC Details',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: GoogleFonts.inter().fontFamily,
                    fontSize: 14.5.sp,
                    fontWeight: FontWeight.w800,
                    color: _mint,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 18.h),

          // ── Aadhaar Card — front + back side by side ──────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _KycDocCard(
                  label: 'Aadhaar Front',
                  url: d.aadhaarFrontUrl,
                  authToken: authToken,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: _KycDocCard(
                  label: 'Aadhaar Back',
                  url: d.aadhaarBackUrl,
                  authToken: authToken,
                ),
              ),
            ],
          ),

          SizedBox(height: 22.h),

          // ── PAN Card — its own full-width section ──────────────────────────
          _KycDocCard(
            label: 'PAN Card',
            url: d.panFrontUrl,
            authToken: authToken,
            aspectRatio: 8 / 5,
          ),

          SizedBox(height: 22.h),

          // ── Selfie — its own section, portrait card ────────────────────────
          Center(
            child: SizedBox(
              width: 160.w,
              child: _KycDocCard(
                label: 'Selfie',
                url: d.selfieUrl,
                authToken: authToken,
                aspectRatio: 3 / 4,
              ),
            ),
          ),

          SizedBox(height: 24.h),
          Row(
            children: [
              Icon(Icons.account_balance_rounded, size: 15.sp, color: _muted),
              SizedBox(width: 6.w),
              Text(
                'Bank Details',
                style: TextStyle(
                  fontFamily: GoogleFonts.inter().fontFamily,
                  fontSize: 12.5.sp,
                  fontWeight: FontWeight.w800,
                  color: _muted,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: _surfaceDeep,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: _cardBorder),
            ),
            child: Column(
              children: [
                _detailRow(
                  Icons.person_outline_rounded,
                  'Account Holder',
                  d.accountHolderName,
                ),
                _detailRow(
                  Icons.pin_outlined,
                  'Account Number',
                  d.accountNumber,
                  copyable: true,
                ),
                _detailRow(
                  Icons.tag_rounded,
                  'IFSC Code',
                  d.ifscCode,
                  copyable: true,
                ),
                _detailRow(
                  Icons.apartment_rounded,
                  'Bank',
                  [
                    d.bankName,
                    d.bankBranch,
                  ].where((s) => s.trim().isNotEmpty).join(', '),
                ),
                _detailRow(
                  Icons.location_on_outlined,
                  'Location',
                  [
                    d.bankCity,
                    d.bankState,
                  ].where((s) => s.trim().isNotEmpty).join(', '),
                  isLast: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(
    IconData icon,
    String label,
    String value, {
    bool isLast = false,
    bool copyable = false,
  }) {
    final hasValue = value.trim().isNotEmpty;
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12.h),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: _cardBorder, width: 1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15.sp, color: _muted),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: GoogleFonts.inter().fontFamily,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w500,
                    color: _muted,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  hasValue ? value : '—',
                  style: TextStyle(
                    fontFamily: GoogleFonts.inter().fontFamily,
                    fontSize: 13.5.sp,
                    fontWeight: FontWeight.w700,
                    color: _mint,
                  ),
                ),
              ],
            ),
          ),
          if (copyable && hasValue)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _copyToClipboard(value, label),
              child: Padding(
                padding: EdgeInsets.only(left: 8.w, top: 2.h),
                child: Icon(Icons.copy_rounded, size: 15.sp, color: _emerald),
              ),
            ),
        ],
      ),
    );
  }

  void _copyToClipboard(String value, String label) {
    Clipboard.setData(ClipboardData(text: value));
    HapticFeedback.selectionClick();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: _mint,
        duration: const Duration(seconds: 2),
        content: Text(
          '$label copied',
          style: TextStyle(fontFamily: GoogleFonts.inter().fontFamily),
        ),
      ),
    );
  }

  Widget _statusRow({
    required IconData icon,
    required String label,
    required bool done,
    bool active = false,
  }) {
    return Row(
      children: [
        Container(
          width: 40.w,
          height: 40.h,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: done
                ? const LinearGradient(colors: [_primary, _emerald])
                : null,
            color: done
                ? null
                : active
                ? _emerald.withOpacity(0.16)
                : _fieldBg,
            border: done ? null : Border.all(color: _cardBorder),
          ),
          child: Icon(
            icon,
            size: 20.sp,
            color: done
                ? _white
                : active
                ? _emerald
                : _muted,
          ),
        ),
        SizedBox(width: 14.w),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: GoogleFonts.inter().fontFamily,
              fontSize: 14.5.sp,
              fontWeight: done || active ? FontWeight.w700 : FontWeight.w400,
              color: done
                  ? _mint
                  : active
                  ? _emerald
                  : _muted,
            ),
          ),
        ),
        SizedBox(width: 8.w),
        if (done)
          Icon(Icons.check_circle_rounded, size: 18.sp, color: _emerald)
        else if (active)
          SizedBox(
            width: 16.w,
            height: 16.h,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: _emerald,
              backgroundColor: _emerald.withOpacity(0.2),
            ),
          ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SHARED SCAFFOLD — clean light background matching home page banner style
// ══════════════════════════════════════════════════════════════════════════════

class _DarkScaffold extends StatelessWidget {
  final Widget child;
  const _DarkScaffold({required this.child});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _bg,
        body: SafeArea(child: child),
      ),
    );
  }
}

// ── Painters ──────────────────────────────────────────────────────────────────
class _FaceSilhouettePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.42;
    final facePaint = Paint()
      ..color = _emerald.withOpacity(0.5)
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy), width: 58.w, height: 74.h),
      facePaint,
    );
    final shoulderPaint = Paint()
      ..color = _primary.withOpacity(0.38)
      ..style = PaintingStyle.fill;
    final shoulderPath = Path()
      ..moveTo(cx - 50, size.height)
      ..quadraticBezierTo(
        cx - 30,
        size.height * 0.82,
        cx - 10,
        size.height * 0.72,
      )
      ..lineTo(cx + 10, size.height * 0.72)
      ..quadraticBezierTo(cx + 30, size.height * 0.82, cx + 50, size.height)
      ..close();
    canvas.drawPath(shoulderPath, shoulderPaint);
  }

  @override
  bool shouldRepaint(covariant _FaceSilhouettePainter oldDelegate) => false;
}

class _FaceScanPainter extends CustomPainter {
  final double progress;
  _FaceScanPainter(this.progress);
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.42;
    final ringPaint = Paint()
      ..color = _champagne.withOpacity(0.5 + progress * 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, cy),
        width: 68.w + progress * 6,
        height: 86.h + progress * 6,
      ),
      ringPaint,
    );
    final linePaint = Paint()
      ..color = _emerald.withOpacity(0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final scanY = (cy - 40) + progress * 80;
    canvas.drawLine(Offset(cx - 30, scanY), Offset(cx + 30, scanY), linePaint);
    final bracketPaint = Paint()
      ..color = _champagne.withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(14, 22), const Offset(14, 34), bracketPaint);
    canvas.drawLine(const Offset(14, 22), const Offset(26, 22), bracketPaint);
    final tr = size.width - 14;
    canvas.drawLine(Offset(tr, 22), Offset(tr, 34), bracketPaint);
    canvas.drawLine(Offset(tr - 12, 22), Offset(tr, 22), bracketPaint);
    final bY = size.height - 22;
    canvas.drawLine(Offset(14, bY - 12), Offset(14, bY), bracketPaint);
    canvas.drawLine(Offset(14, bY), Offset(26, bY), bracketPaint);
    canvas.drawLine(Offset(tr, bY - 12), Offset(tr, bY), bracketPaint);
    canvas.drawLine(Offset(tr - 12, bY), Offset(tr, bY), bracketPaint);
  }

  @override
  bool shouldRepaint(covariant _FaceScanPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _WavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _champagne.withOpacity(0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (int i = 0; i < 3; i++) {
      final path = Path();
      final offsetY = size.height * (0.25 + i * 0.28);
      path.moveTo(-20, offsetY);
      path.quadraticBezierTo(
        size.width * 0.3,
        offsetY - 22,
        size.width * 0.6,
        offsetY,
      );
      path.quadraticBezierTo(
        size.width * 0.85,
        offsetY + 18,
        size.width + 20,
        offsetY - 8,
      );
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) => false;
}
