// lib/views/kyc/kyc_verification_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/kyc/kyc_viewmodel.dart';
import '../../models/kyc/kyc_model.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _bg            = Color(0xFFECEFF5);
const _white         = Color(0xFFFFFFFF);
const _titleDark     = Color(0xFF111827);
const _subtitleGrey  = Color(0xFF6B7280);
const _labelGrey     = Color(0xFF9CA3AF);

const _brandGreen     = Color(0xFF3D9E6A);
const _accentGreen    = Color(0xFF3D9E6A);
const _accentGreenEnd = Color(0xFF86C9A0);

const _infoBg      = Color(0xFFE9F3EE);
const _infoBorder  = Color(0xFFD4EDE0);
const _infoText    = Color(0xFF4B5563);

const _dashedBorder    = Color(0xFFD1D5DB);
const _checkBg         = Color(0xFFD4EDE0);
const _bankFieldBg     = Color(0xFFEEF4F0);
const _bankFieldBorder = Color(0xFFD6E8DC);
const _bankInstantBg   = Color(0xFF5DD99A);
const _bankInstantIcon = Color(0xFF3D9E6A);

// ── Entry widget ──────────────────────────────────────────────────────────────
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
    _scanAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scanCtrl, curve: Curves.easeInOut),
    );
    // Attach error listener after first frame so Provider is available
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
          content: Text(msg,
              style: GoogleFonts.poppins(
                  fontSize: 13.5, fontWeight: FontWeight.w500, color: _white)),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 3),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<KycViewModel>();

    // Show a loading spinner while we check if KYC was already submitted
    if (vm.checkingStatus) {
      return Theme(
        data: ThemeData(brightness: Brightness.light, scaffoldBackgroundColor: _bg),
        child: const Scaffold(
          backgroundColor: _bg,
          body: Center(
            child: CircularProgressIndicator(color: _accentGreen),
          ),
        ),
      );
    }

    // ── KEY FIX: If already submitted (pending/approved), go straight to
    //    the success/status screen — skip the upload flow entirely.
    if (vm.alreadySubmitted || vm.completed) {
      return _KycSuccessScreen(kycStatus: vm.serverKycStatus);
    }

    return Theme(
      data: ThemeData(brightness: Brightness.light, scaffoldBackgroundColor: _bg),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: Scaffold(
          backgroundColor: _bg,
          body: SafeArea(
            child: Column(
              children: [
                _buildTopBar(context, vm),
                _buildProgressBar(vm),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                    child: _buildStepContent(vm),
                  ),
                ),
                _buildBottomBar(vm),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Top bar ───────────────────────────────────────────────────────────────
  Widget _buildTopBar(BuildContext context, KycViewModel vm) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 20, 8),
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
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Icon(Icons.arrow_back, color: _brandGreen, size: 24),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              vm.stepTitle,
              textAlign: vm.currentStep == KycStep.aadhaar
                  ? TextAlign.start
                  : TextAlign.center,
              style: GoogleFonts.poppins(
                  fontSize: 17, fontWeight: FontWeight.w700, color: _brandGreen),
            ),
          ),
          if (vm.currentStep == KycStep.aadhaar)
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: _accentGreen.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.shield_outlined, color: _accentGreen, size: 20),
            )
          else
            const Icon(Icons.help_outline_rounded, color: _accentGreen, size: 24),
        ],
      ),
    );
  }

  // ── Progress bar ──────────────────────────────────────────────────────────
  Widget _buildProgressBar(KycViewModel vm) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: List.generate(KycStep.values.length, (i) {
          final isActive = i <= vm.currentStepIndex;
          return Expanded(
            child: Container(
              height: 4,
              margin: EdgeInsets.only(
                  right: i == KycStep.values.length - 1 ? 0 : 6),
              decoration: BoxDecoration(
                color: isActive
                    ? _accentGreen
                    : _accentGreenEnd.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── Step router ───────────────────────────────────────────────────────────
  Widget _buildStepContent(KycViewModel vm) {
    switch (vm.currentStep) {
      case KycStep.aadhaar: return _buildAadhaarStep(vm);
      case KycStep.pan:     return _buildPanStep(vm);
      case KycStep.selfie:  return _buildSelfieStep(vm);
      case KycStep.bank:    return _buildBankStep(vm);
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // AADHAAR STEP
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildAadhaarStep(KycViewModel vm) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Identity Proof',
            style: GoogleFonts.poppins(
                fontSize: 24, fontWeight: FontWeight.w800, color: _titleDark)),
        const SizedBox(height: 8),
        Text(
          'Please upload a clear picture of your original Aadhaar Card for instant verification.',
          style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: _subtitleGrey,
              height: 1.5),
        ),
        const SizedBox(height: 20),
        _buildUploadCard(
          title: 'Upload Aadhaar Front',
          subtitle: 'Any image format (Max 5MB)',
          imagePath: vm.form.aadhaarFrontPath,
          onTap: vm.pickAadhaarFront,
        ),
        const SizedBox(height: 16),
        _buildUploadCard(
          title: 'Upload Aadhaar Back',
          subtitle: 'Any image format (Max 5MB)',
          imagePath: vm.form.aadhaarBackPath,
          onTap: vm.pickAadhaarBack,
        ),
        const SizedBox(height: 20),
        _buildRequirementsCard(),
        const SizedBox(height: 18),
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
        Text('PAN Verification',
            style: GoogleFonts.poppins(
                fontSize: 24, fontWeight: FontWeight.w800, color: _titleDark)),
        const SizedBox(height: 8),
        Text(
          'Please upload a clear picture of your PAN card for tax compliance and identity verification.',
          style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: _subtitleGrey,
              height: 1.5),
        ),
        const SizedBox(height: 20),
        _buildUploadCard(
          title: 'Upload PAN Front',
          subtitle: 'Any image format (Max 5MB)',
          imagePath: vm.form.panFrontPath,
          onTap: vm.pickPanFront,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildFeatureCard(
                icon: Icons.shield_outlined,
                iconColor: const Color(0xFF3B82F6),
                iconBg: const Color(0xFFDBEAFE),
                bg: const Color(0xFFE7EEFB),
                title: 'Vault Secure',
                subtitle: 'AES-256 Encrypted',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildFeatureCard(
                icon: Icons.verified_user_rounded,
                iconColor: _accentGreen,
                iconBg: _checkBg,
                bg: _infoBg,
                title: 'Fast Review',
                subtitle: 'Under 2 mins',
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _buildPanRequirementsCard(),
        const SizedBox(height: 18),
        _buildTrustBanner(),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SELFIE STEP
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildSelfieStep(KycViewModel vm) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'Selfie Verification',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
              fontSize: 24, fontWeight: FontWeight.w800, color: _titleDark),
        ),
        const SizedBox(height: 10),
        Text(
          'Take a selfie to verify your identity. Ensure\nyour face is within the frame and clearly\nvisible.',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: _subtitleGrey,
              height: 1.55),
        ),
        const SizedBox(height: 28),
        _buildSelfiePreview(vm),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildSelfieActionBtn(
                icon: Icons.camera_alt_rounded,
                label: 'Open Camera',
                onTap: vm.captureSelfie,
                filled: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSelfieActionBtn(
                icon: Icons.photo_library_outlined,
                label: 'From Gallery',
                onTap: vm.pickSelfieFromGallery,
                filled: false,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _buildSelfieTipCard(
          icon: Icons.wb_sunny_outlined,
          iconColor: const Color(0xFFF59E0B),
          iconBg: const Color(0xFFFEF3C7),
          title: 'Good lighting',
          subtitle: 'Avoid shadows on your face',
        ),
        const SizedBox(height: 12),
        _buildSelfieTipCard(
          icon: Icons.flash_off_outlined,
          iconColor: const Color(0xFF6366F1),
          iconBg: const Color(0xFFE0E7FF),
          title: 'Remove glasses/hats',
          subtitle: 'Ensure eyes are clearly visible',
        ),
        const SizedBox(height: 12),
        _buildSelfieTipCard(
          icon: Icons.sentiment_neutral_outlined,
          iconColor: _accentGreen,
          iconBg: _checkBg,
          title: 'Neutral expression',
          subtitle: 'Look directly into the camera',
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline_rounded, size: 13, color: _labelGrey),
            const SizedBox(width: 5),
            Text(
              'Encrypted biometric transmission',
              style: GoogleFonts.poppins(
                  fontSize: 12, fontWeight: FontWeight.w500, color: _labelGrey),
            ),
          ],
        ),
        const SizedBox(height: 6),
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
              width: 240, height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _accentGreenEnd
                      .withOpacity(0.25 + _scanAnim.value * 0.25),
                  width: 2,
                ),
              ),
            ),
          ),
          Container(
            width: 208, height: 208,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _brandGreen.withOpacity(0.85)),
          ),
          Container(
            width: 192, height: 192,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF1E5C3A).withOpacity(0.95)),
          ),
          ClipOval(
            child: SizedBox(
              width: 176, height: 176,
              child: captured
                  ? Image.file(File(vm.form.selfiePath!), fit: BoxFit.cover)
                  : Stack(
                      children: [
                        Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF0F3D2B), Color(0xFF1A6645)],
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
            bottom: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: captured ? _accentGreen : _brandGreen.withOpacity(0.85),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                      color: _brandGreen.withOpacity(0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4)),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    captured
                        ? Icons.check_circle_outline_rounded
                        : Icons.face_retouching_natural,
                    color: _white, size: 17,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    captured ? 'Selfie Captured ✓' : 'No selfie yet',
                    style: GoogleFonts.poppins(
                        fontSize: 13, fontWeight: FontWeight.w700, color: _white),
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
        height: 48,
        decoration: BoxDecoration(
          color: filled ? _brandGreen : _white,
          borderRadius: BorderRadius.circular(14),
          border: filled ? null : Border.all(color: _bankFieldBorder, width: 1.5),
          boxShadow: filled
              ? [BoxShadow(color: _brandGreen.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 3))]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: filled ? _white : _accentGreen),
            const SizedBox(width: 8),
            Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: filled ? _white : _accentGreen)),
          ],
        ),
      ),
    );
  }

  Widget _buildSelfieTipCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(shape: BoxShape.circle, color: iconBg),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: GoogleFonts.poppins(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: _titleDark)),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: GoogleFonts.poppins(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w400,
                      color: _subtitleGrey)),
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
        Text(
          'Link Bank Account',
          style: GoogleFonts.poppins(
              fontSize: 26, fontWeight: FontWeight.w800, color: _titleDark),
        ),
        const SizedBox(height: 8),
        Text(
          "Enter your bank details where you'd like to receive your investment returns.",
          style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: _subtitleGrey,
              height: 1.55),
        ),
        const SizedBox(height: 28),
        _bankFieldLabel('Account Holder Name'),
        const SizedBox(height: 8),
        _buildBankTextField(
          hint: 'As per bank records',
          prefixIcon: Icons.person_outline_rounded,
          keyboardType: TextInputType.name,
          textCapitalization: TextCapitalization.words,
          onChanged: vm.updateAccountHolder,
          initialValue: vm.form.accountHolderName,
        ),
        const SizedBox(height: 20),
        _bankFieldLabel('Account Number'),
        const SizedBox(height: 8),
        _buildBankTextField(
          hint: 'Enter your account number',
          prefixIcon: Icons.account_balance_outlined,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: vm.updateAccountNumber,
          initialValue: vm.form.accountNumber,
        ),
        const SizedBox(height: 20),
        _bankFieldLabel('IFSC Code'),
        const SizedBox(height: 8),
        _buildIfscField(vm),
        if (vm.form.bankInfo != null) ...[
          const SizedBox(height: 12),
          _buildBankInfoCard(vm.form.bankInfo!),
        ],
        if (vm.ifscError != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.error_outline, size: 15, color: Colors.red),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  vm.ifscError!,
                  style: GoogleFonts.poppins(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: Colors.red.shade700),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 24),
        _buildInstantVerificationBanner(),
        const SizedBox(height: 28),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline_rounded, size: 13, color: _labelGrey),
            const SizedBox(width: 6),
            Text(
              'PCI-DSS Compliant • 256-bit Encryption',
              style: GoogleFonts.poppins(
                  fontSize: 12, fontWeight: FontWeight.w500, color: _labelGrey),
            ),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _bankFieldLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.poppins(
          fontSize: 13.5, fontWeight: FontWeight.w700, color: _accentGreen),
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
        color: _bankFieldBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _bankFieldBorder, width: 1.2),
      ),
      child: TextFormField(
        initialValue: initialValue.isEmpty ? null : initialValue,
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,
        inputFormatters: inputFormatters,
        onChanged: onChanged,
        style: GoogleFonts.poppins(
            fontSize: 15, fontWeight: FontWeight.w500, color: _titleDark),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.poppins(
              fontSize: 15, fontWeight: FontWeight.w400, color: _labelGrey),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 14, right: 10),
            child: Icon(prefixIcon, color: _labelGrey, size: 22),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        ),
      ),
    );
  }

  Widget _buildIfscField(KycViewModel vm) {
    return Container(
      decoration: BoxDecoration(
        color: _bankFieldBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: vm.form.bankInfo != null
              ? _accentGreen
              : vm.ifscError != null
                  ? Colors.red.shade300
                  : _bankFieldBorder,
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 14, right: 10),
            child: Icon(Icons.security_outlined, color: _labelGrey, size: 22),
          ),
          Expanded(
            child: TextFormField(
              initialValue: vm.form.ifscCode.isEmpty ? null : vm.form.ifscCode,
              textCapitalization: TextCapitalization.characters,
              maxLength: 11,
              onChanged: vm.updateIfsc,
              style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: _titleDark,
                  letterSpacing: 1.5),
              decoration: InputDecoration(
                hintText: 'e.g. SBIN0001234',
                hintStyle: GoogleFonts.poppins(
                    fontSize: 14, fontWeight: FontWeight.w400, color: _labelGrey),
                counterText: '',
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          GestureDetector(
            onTap: vm.ifscLoading ? null : vm.lookupIfsc,
            child: Padding(
              padding: const EdgeInsets.only(right: 14),
              child: vm.ifscLoading
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: _accentGreen),
                    )
                  : vm.form.bankInfo != null
                      ? const Icon(Icons.check_circle_rounded,
                          color: _accentGreen, size: 20)
                      : Text(
                          'FIND',
                          style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: _accentGreen,
                              letterSpacing: 0.5),
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBankInfoCard(IfscBankInfo info) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _infoBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _infoBorder, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
                shape: BoxShape.circle, color: _accentGreen.withOpacity(0.15)),
            child: const Icon(Icons.account_balance_rounded,
                size: 18, color: _accentGreen),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(info.bankName,
                    style: GoogleFonts.poppins(
                        fontSize: 14, fontWeight: FontWeight.w700, color: _titleDark)),
                const SizedBox(height: 2),
                Text('${info.branch} — ${info.city}, ${info.state}',
                    style: GoogleFonts.poppins(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w400,
                        color: _subtitleGrey)),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _bankInstantBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _bankInstantIcon.withOpacity(0.18),
            ),
            child: const Icon(Icons.verified_outlined,
                color: _bankInstantIcon, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Instant Verification',
                  style: GoogleFonts.poppins(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: _bankInstantIcon),
                ),
                const SizedBox(height: 4),
                Text(
                  "We'll deposit ₹1.00 to verify your account instantly.",
                  style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: _bankInstantIcon.withOpacity(0.85),
                      height: 1.4),
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
          color: _white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: uploaded ? _accentGreen : _dashedBorder,
            width: 1.5,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: uploaded
            ? Stack(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 160,
                    child: Image.file(File(imagePath), fit: BoxFit.cover),
                  ),
                  Positioned(
                    left: 0, right: 0, bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      color: _accentGreen.withOpacity(0.9),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded,
                              size: 18, color: _white),
                          const SizedBox(width: 8),
                          Text(
                            'Uploaded successfully — tap to change',
                            style: GoogleFonts.poppins(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: _white),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              )
            : Padding(
                padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                child: Column(
                  children: [
                    Container(
                      width: 56, height: 56,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle, color: _accentGreenEnd),
                      child: const Icon(Icons.add_a_photo_outlined,
                          size: 24, color: _white),
                    ),
                    const SizedBox(height: 14),
                    Text(title,
                        style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: _titleDark)),
                    const SizedBox(height: 6),
                    Text(subtitle,
                        style: GoogleFonts.poppins(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: _labelGrey)),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required Color bg,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(shape: BoxShape.circle, color: iconBg),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(height: 10),
          Text(title,
              style: GoogleFonts.poppins(
                  fontSize: 13.5, fontWeight: FontWeight.w800, color: _titleDark)),
          const SizedBox(height: 2),
          Text(subtitle,
              style: GoogleFonts.poppins(
                  fontSize: 12, fontWeight: FontWeight.w400, color: _subtitleGrey)),
        ],
      ),
    );
  }

  Widget _buildRequirementsCard() {
    const requirements = [
      'Information on the card should be clearly visible and legible.',
      'Avoid any glare, reflections, or shadows on the document.',
      'Card edges must be within the frame of the image.',
    ];
    return _requirementsCard(requirements);
  }

  Widget _buildPanRequirementsCard() {
    const requirements = [
      'Name and photo clearly visible',
      'Avoid glare and shadows',
      'Document must be valid',
    ];
    return _requirementsCard(requirements);
  }

  Widget _requirementsCard(List<String> requirements) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _infoBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _infoBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline_rounded, size: 18, color: _accentGreen),
              const SizedBox(width: 8),
              Text('Requirements',
                  style: GoogleFonts.poppins(
                      fontSize: 15, fontWeight: FontWeight.w800, color: _titleDark)),
            ],
          ),
          const SizedBox(height: 12),
          ...requirements.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 18, height: 18,
                      margin: const EdgeInsets.only(top: 1),
                      decoration: const BoxDecoration(
                          shape: BoxShape.circle, color: _checkBg),
                      child: const Icon(Icons.check_rounded,
                          size: 12, color: _accentGreen),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(r,
                          style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                              color: _infoText,
                              height: 1.45)),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildTrustBanner() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        height: 110,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFE5E7EB), Color(0xFFF3F4F6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _WavePainter())),
            Positioned(
              left: 14, bottom: 14, right: 14,
              child: Row(
                children: [
                  Container(
                    width: 38, height: 38,
                    decoration:
                        const BoxDecoration(shape: BoxShape.circle, color: _white),
                    child: const Icon(Icons.verified_user_outlined,
                        size: 18, color: _accentGreen),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('IDENTITY TRUST',
                          style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: _brandGreen,
                              letterSpacing: 0.6)),
                      const SizedBox(height: 2),
                      Text('Verified by Moneytries Global Compliance',
                          style: GoogleFonts.poppins(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w400,
                              color: _subtitleGrey)),
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

  Widget _buildSecureBanner() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        height: 130,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F2318), Color(0xFF1F3D2C)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -10, top: -10,
              child: Icon(Icons.credit_card,
                  size: 110, color: _white.withOpacity(0.08)),
            ),
            Positioned(
              left: 14, bottom: 14,
              child: Row(
                children: [
                  Icon(Icons.verified_user_rounded,
                      size: 16, color: _white.withOpacity(0.9)),
                  const SizedBox(width: 6),
                  Text('Secure Encryption Enabled',
                      style: GoogleFonts.poppins(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: _white)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Bottom bar ────────────────────────────────────────────────────────────
  Widget _buildBottomBar(KycViewModel vm) {
    final isLoading = vm.status == KycStatus.loading;
    final isSelfie  = vm.currentStep == KycStep.selfie;
    final isBank    = vm.currentStep == KycStep.bank;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24), topRight: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, -4))
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: isLoading ? null : vm.goNext,
                style: ElevatedButton.styleFrom(
                  backgroundColor: vm.canContinue
                      ? _brandGreen
                      : _brandGreen.withOpacity(0.5),
                  foregroundColor: _white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                ),
                child: isLoading
                    ? const SizedBox(
                        width: 22, height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: _white),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (isSelfie) ...[
                            const Icon(Icons.camera_alt_rounded,
                                size: 18, color: _white),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            vm.nextLabel,
                            style: GoogleFonts.poppins(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w700,
                                color: _white),
                          ),
                          if (!isSelfie && !isBank) ...[
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward,
                                size: 18, color: _white),
                          ],
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 10),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: GoogleFonts.poppins(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w400,
                    color: _subtitleGrey,
                    height: 1.5),
                children: [
                  const TextSpan(text: 'By continuing, you agree to our '),
                  TextSpan(
                    text: 'Privacy Policy',
                    style: GoogleFonts.poppins(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: _accentGreen,
                        height: 1.5),
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
// SUCCESS / STATUS SCREEN
// ══════════════════════════════════════════════════════════════════════════════

class _KycSuccessScreen extends StatefulWidget {
  /// The status from the server: 'pending' | 'approved' | 'not_submitted'
  final String kycStatus;
  const _KycSuccessScreen({this.kycStatus = 'pending'});

  @override
  State<_KycSuccessScreen> createState() => _KycSuccessScreenState();
}

class _KycSuccessScreenState extends State<_KycSuccessScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _scaleAnim = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    _fadeAnim  = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  bool get _isApproved => widget.kycStatus == 'approved';

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData(brightness: Brightness.light, scaffoldBackgroundColor: _bg),
      child: Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ── Back button ──────────────────────────────────────────
                Align(
                  alignment: Alignment.centerLeft,
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 40,
                      height: 40,
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
                      child: const Icon(Icons.arrow_back_ios_new_rounded,
                          size: 18, color: _titleDark),
                    ),
                  ),
                ),
                const Spacer(),
                FadeTransition(
                  opacity: _fadeAnim,
                  child: ScaleTransition(
                    scale: _scaleAnim,
                    child: Container(
                      width: 120, height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [_accentGreen, _brandGreen],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                              color: _accentGreen.withOpacity(0.35),
                              blurRadius: 30,
                              offset: const Offset(0, 10)),
                        ],
                      ),
                      child: const Icon(Icons.verified_rounded,
                          size: 56, color: _white),
                    ),
                  ),
                ),
                const SizedBox(height: 36),
                FadeTransition(
                  opacity: _fadeAnim,
                  child: Text(
                    _isApproved ? 'KYC Approved!' : 'Verification\nSubmitted!',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: _titleDark,
                        height: 1.2),
                  ),
                ),
                const SizedBox(height: 16),
                FadeTransition(
                  opacity: _fadeAnim,
                  child: Text(
                    _isApproved
                        ? 'Your KYC has been verified successfully. You can now access all Moneytries features.'
                        : 'Your KYC documents have been submitted successfully. Our team will review and verify your identity within 24 hours.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w400,
                        color: _subtitleGrey,
                        height: 1.6),
                  ),
                ),
                const SizedBox(height: 36),
                FadeTransition(
                  opacity: _fadeAnim,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 16,
                            offset: const Offset(0, 4)),
                      ],
                    ),
                    child: Column(
                      children: [
                        _statusRow(
                          icon: Icons.upload_file_rounded,
                          label: 'Documents Uploaded',
                          done: true,
                        ),
                        const SizedBox(height: 16),
                        _statusRow(
                          icon: Icons.manage_search_rounded,
                          label: 'Under Review',
                          done: _isApproved,
                          active: !_isApproved,
                        ),
                        const SizedBox(height: 16),
                        _statusRow(
                          icon: Icons.check_circle_rounded,
                          label: 'KYC Approved',
                          done: _isApproved,
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _brandGreen,
                      foregroundColor: _white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)),
                    ),
                    child: Text(
                      'Back to Home',
                      style: GoogleFonts.poppins(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: _white),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
              ],
            ),
          ),
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
          width: 40, height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done
                ? _accentGreen
                : active
                    ? _accentGreenEnd.withOpacity(0.3)
                    : _labelGrey.withOpacity(0.12),
          ),
          child: Icon(icon, size: 20,
              color: done ? _white : active ? _accentGreen : _labelGrey),
        ),
        const SizedBox(width: 14),
        Text(
          label,
          style: GoogleFonts.poppins(
              fontSize: 14.5,
              fontWeight: done || active ? FontWeight.w700 : FontWeight.w400,
              color: done
                  ? _accentGreen
                  : active
                      ? _titleDark
                      : _labelGrey),
        ),
        const Spacer(),
        if (done)
          const Icon(Icons.check_circle_rounded, size: 18, color: _accentGreen)
        else if (active)
          SizedBox(
            width: 16, height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: _accentGreen,
              backgroundColor: _accentGreenEnd.withOpacity(0.3),
            ),
          ),
      ],
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
      ..color = const Color(0xFF4A9B72).withOpacity(0.55)
      ..style = PaintingStyle.fill;
    canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, cy), width: 58, height: 74),
        facePaint);
    final shoulderPaint = Paint()
      ..color = const Color(0xFF3D9E6A).withOpacity(0.4)
      ..style = PaintingStyle.fill;
    final shoulderPath = Path()
      ..moveTo(cx - 50, size.height)
      ..quadraticBezierTo(cx - 30, size.height * 0.82, cx - 10, size.height * 0.72)
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
      ..color = const Color(0xFF86C9A0).withOpacity(0.55 + progress * 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(cx, cy),
          width: 68 + progress * 6,
          height: 86 + progress * 6),
      ringPaint,
    );
    final linePaint = Paint()
      ..color = const Color(0xFF86C9A0).withOpacity(0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final scanY = (cy - 40) + progress * 80;
    canvas.drawLine(Offset(cx - 30, scanY), Offset(cx + 30, scanY), linePaint);
    final bracketPaint = Paint()
      ..color = const Color(0xFF86C9A0).withOpacity(0.8)
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
      ..color = Colors.white.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (int i = 0; i < 4; i++) {
      final path = Path();
      final offsetY = size.height * (0.2 + i * 0.18);
      path.moveTo(-20, offsetY);
      path.quadraticBezierTo(
          size.width * 0.3, offsetY - 30, size.width * 0.6, offsetY);
      path.quadraticBezierTo(
          size.width * 0.85, offsetY + 25, size.width + 20, offsetY - 10);
      canvas.drawPath(path, paint);
    }
  }
  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) => false;
}