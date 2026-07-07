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
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/kyc/kyc_viewmodel.dart';
import '../../models/kyc/kyc_model.dart';

// ══════════════════════════════════════════════════════════════════════════
// PALETTE — matches the home page banner color scheme (light, fresh greens)
// ══════════════════════════════════════════════════════════════════════════
const _bg = Color(0xFFECEFF5); // home page background (light grey)
const _surface = Color(0xFFFFFFFF); // white card surfaces
const _surfaceDeep = Color(0xFFF0F4F0); // very light green-grey
const _primary = Color(0xFF3D9E6A); // home brand green
const _primaryDim = Color(0xFF4DAA75); // banner gradient start
const _emerald = Color(0xFF3D9E6A); // same brand green
const _mint = Color(0xFF111827); // dark title text (home _titleDark)
const _bodyGrey = Color(0xFF6B7280); // subtitle grey (home _subtitleGrey)
const _muted = Color(0xFF9CA3AF); // label grey (home _labelGrey)
const _white = Color(0xFFFFFFFF);
const _champagne = Color(0xFF3D9E6A); // repurposed to brand green
const _danger = Color(0xFFEF4444);

const _cardBorder = Color(0xFFE5E7EB); // light divider
const _fieldBg = Color(0xFFF9FAFB); // near-white field background
const _fieldBorder = Color(0xFFD1D5DB); // light grey border

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
              const Icon(Icons.error_outline_rounded, color: _white, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  msg,
                  style: GoogleFonts.poppins(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: _white,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF7F1D1D),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: _danger, width: 0.6),
          ),
          margin: const EdgeInsets.all(16),
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
      child: Column(
        children: [
          _buildTopBar(context, vm),
          _buildProgressBar(vm),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                20,
                12,
                20,
                MediaQuery.of(context).viewInsets.bottom > 0
                    ? MediaQuery.of(context).viewInsets.bottom + 20
                    : 20,
              ),
              child: _buildStepContent(vm),
            ),
          ),
          _buildBottomBar(vm),
        ],
      ),
    );
  }

  // ── Top bar ───────────────────────────────────────────────────────────────
  Widget _buildTopBar(BuildContext context, KycViewModel vm) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 14, 20, 6),
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
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _surface,
                shape: BoxShape.circle,
                border: Border.all(color: _cardBorder, width: 1),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: _emerald,
                size: 16,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  vm.stepTitle,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: _mint,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Step ${vm.currentStepIndex + 1} of ${KycStep.values.length} · Secure Verification',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: _muted,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 40,
            height: 40,
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
            child: const Icon(
              Icons.verified_user_rounded,
              color: _white,
              size: 19,
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
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
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
                      width: 30,
                      height: 30,
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
                          width: 1,
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
                        size: 15,
                        color: (isDone || isActive) ? _white : _muted,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      labels[i],
                      style: GoogleFonts.poppins(
                        fontSize: 9.5,
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
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Container(
                        height: 2,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: isDone ? _emerald : _cardBorder,
                          borderRadius: BorderRadius.circular(2),
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
        const SizedBox(height: 22),
        _buildUploadCard(
          title: 'Upload Aadhaar Front',
          subtitle: 'Any image format (Max 5MB)',
          imagePath: vm.form.aadhaarFrontPath,
          onTap: vm.pickAadhaarFront,
        ),
        const SizedBox(height: 14),
        _buildUploadCard(
          title: 'Upload Aadhaar Back',
          subtitle: 'Any image format (Max 5MB)',
          imagePath: vm.form.aadhaarBackPath,
          onTap: vm.pickAadhaarBack,
        ),
        const SizedBox(height: 20),
        _buildRequirementsCard(const [
          'Information on the card should be clearly visible and legible.',
          'Avoid any glare, reflections, or shadows on the document.',
          'Card edges must be within the frame of the image.',
        ]),
        const SizedBox(height: 16),
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
        const SizedBox(height: 22),
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
                title: 'Vault Secure',
                subtitle: 'AES-256 Encrypted',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildFeatureCard(
                icon: Icons.bolt_rounded,
                title: 'Fast Review',
                subtitle: 'Under 2 mins',
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _buildRequirementsCard(const [
          'Name and photo clearly visible',
          'Avoid glare and shadows',
          'Document must be valid',
        ]),
        const SizedBox(height: 16),
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
          style: GoogleFonts.playfairDisplay(
            fontSize: 23,
            fontWeight: FontWeight.w700,
            color: _mint,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Take a selfie to verify your identity. Ensure\nyour face is within the frame and clearly visible.',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 13.5,
            fontWeight: FontWeight.w400,
            color: _bodyGrey,
            height: 1.55,
          ),
        ),
        const SizedBox(height: 26),
        _buildSelfiePreview(vm),
        const SizedBox(height: 20),
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
        const SizedBox(height: 22),
        _buildSelfieTipCard(
          icon: Icons.wb_sunny_outlined,
          title: 'Good lighting',
          subtitle: 'Avoid shadows on your face',
        ),
        const SizedBox(height: 12),
        _buildSelfieTipCard(
          icon: Icons.flash_off_outlined,
          title: 'Remove glasses/hats',
          subtitle: 'Ensure eyes are clearly visible',
        ),
        const SizedBox(height: 12),
        _buildSelfieTipCard(
          icon: Icons.sentiment_neutral_outlined,
          title: 'Neutral expression',
          subtitle: 'Look directly into the camera',
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline_rounded, size: 13, color: _muted),
            const SizedBox(width: 6),
            Text(
              'Encrypted biometric transmission',
              style: GoogleFonts.poppins(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: _muted,
              ),
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
              width: 232,
              height: 232,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _champagne.withOpacity(0.20 + _scanAnim.value * 0.28),
                  width: 1.4,
                ),
              ),
            ),
          ),
          Container(
            width: 200,
            height: 200,
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
              width: 176,
              height: 176,
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: captured
                      ? [_primary, _emerald]
                      : [_surface, _surface],
                ),
                borderRadius: BorderRadius.circular(30),
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
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    captured ? 'Selfie Captured' : 'No selfie yet',
                    style: GoogleFonts.poppins(
                      fontSize: 12.5,
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
        height: 50,
        decoration: BoxDecoration(
          gradient: filled
              ? const LinearGradient(colors: [_primary, _emerald])
              : null,
          color: filled ? null : _surface,
          borderRadius: BorderRadius.circular(15),
          border: filled ? null : Border.all(color: _fieldBorder, width: 1.3),
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
            Icon(icon, size: 18, color: filled ? _white : _emerald),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 14,
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
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _emerald.withOpacity(0.12),
              border: Border.all(color: _emerald.withOpacity(0.25)),
            ),
            child: Icon(icon, color: _emerald, size: 20),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _mint,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: GoogleFonts.poppins(
                  fontSize: 12,
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
          fontSize: 24,
        ),
        const SizedBox(height: 26),
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
        const SizedBox(height: 18),
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
        const SizedBox(height: 18),
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
              const Icon(Icons.error_outline_rounded, size: 15, color: _danger),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  vm.ifscError!,
                  style: GoogleFonts.poppins(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: _danger,
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 22),
        _buildInstantVerificationBanner(),
        const SizedBox(height: 26),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline_rounded, size: 13, color: _muted),
            const SizedBox(width: 6),
            Text(
              'PCI-DSS Compliant · 256-bit Encryption',
              style: GoogleFonts.poppins(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: _muted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
      ],
    );
  }

  Widget _bankFieldLabel(String label) {
    return Text(
      label.toUpperCase(),
      style: GoogleFonts.poppins(
        fontSize: 11.5,
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
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _fieldBorder, width: 1.2),
      ),
      child: TextFormField(
        initialValue: initialValue.isEmpty ? null : initialValue,
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,
        inputFormatters: inputFormatters,
        onChanged: onChanged,
        cursorColor: _emerald,
        style: GoogleFonts.poppins(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: _mint,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.poppins(
            fontSize: 14.5,
            fontWeight: FontWeight.w400,
            color: _muted,
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 14, right: 10),
            child: Icon(prefixIcon, color: _muted, size: 21),
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 0,
            minHeight: 0,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 16,
            horizontal: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildIfscField(KycViewModel vm) {
    return Container(
      decoration: BoxDecoration(
        color: _fieldBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: vm.form.bankInfo != null
              ? _emerald
              : vm.ifscError != null
              ? _danger.withOpacity(0.6)
              : _fieldBorder,
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 14, right: 10),
            child: Icon(Icons.security_outlined, color: _muted, size: 21),
          ),
          Expanded(
            child: TextFormField(
              initialValue: vm.form.ifscCode.isEmpty ? null : vm.form.ifscCode,
              textCapitalization: TextCapitalization.characters,
              maxLength: 11,
              onChanged: vm.updateIfsc,
              cursorColor: _emerald,
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: _mint,
                letterSpacing: 1.5,
              ),
              decoration: InputDecoration(
                hintText: 'e.g. SBIN0001234',
                hintStyle: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: _muted,
                ),
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
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _emerald,
                      ),
                    )
                  : vm.form.bankInfo != null
                  ? const Icon(
                      Icons.check_circle_rounded,
                      color: _emerald,
                      size: 20,
                    )
                  : Text(
                      'FIND',
                      style: GoogleFonts.poppins(
                        fontSize: 12.5,
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
      padding: const EdgeInsets.all(14),
      borderColor: _emerald.withOpacity(0.3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _emerald.withOpacity(0.16),
            ),
            child: const Icon(
              Icons.account_balance_rounded,
              size: 18,
              color: _emerald,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  info.bankName,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _mint,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${info.branch} — ${info.city}, ${info.state}',
                  style: GoogleFonts.poppins(
                    fontSize: 12.5,
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_primary.withOpacity(0.18), _emerald.withOpacity(0.10)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _emerald.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _emerald.withOpacity(0.2),
            ),
            child: const Icon(
              Icons.verified_outlined,
              color: _emerald,
              size: 22,
            ),
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
                    color: _mint,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "We'll deposit ₹1.00 to verify your account instantly.",
                  style: GoogleFonts.poppins(
                    fontSize: 12.5,
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
              width: 4,
              height: 22,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_primary, _emerald]),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: GoogleFonts.playfairDisplay(
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
                color: _mint,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          subtitle,
          style: GoogleFonts.poppins(
            fontSize: 13.5,
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
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: uploaded ? _emerald.withOpacity(0.7) : _cardBorder,
            width: 1.4,
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
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
                        const Icon(
                          Icons.check_circle_rounded,
                          size: 18,
                          color: _white,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Uploaded successfully — tap to change',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 12.5,
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
                padding: const EdgeInsets.symmetric(
                  vertical: 34,
                  horizontal: 20,
                ),
                child: Column(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            _primary.withOpacity(0.85),
                            _emerald.withOpacity(0.85),
                          ],
                        ),
                      ),
                      child: const Icon(
                        Icons.add_a_photo_outlined,
                        size: 24,
                        color: _white,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: _mint,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: GoogleFonts.poppins(
                        fontSize: 12.5,
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
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _emerald.withOpacity(0.15),
            ),
            child: Icon(icon, size: 16, color: _emerald),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: _mint,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: GoogleFonts.poppins(
              fontSize: 11.5,
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
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.info_outline_rounded,
                size: 18,
                color: _champagne,
              ),
              const SizedBox(width: 8),
              Text(
                'Requirements',
                style: GoogleFonts.poppins(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: _mint,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...requirements.map(
            (r) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 18,
                    height: 18,
                    margin: const EdgeInsets.only(top: 1),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _emerald.withOpacity(0.15),
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      size: 12,
                      color: _emerald,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      r,
                      style: GoogleFonts.poppins(
                        fontSize: 12.5,
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
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
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
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _champagne.withOpacity(0.14),
                    border: Border.all(color: _champagne.withOpacity(0.4)),
                  ),
                  child: const Icon(
                    Icons.workspace_premium_rounded,
                    size: 19,
                    color: _champagne,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'IDENTITY TRUST',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: _champagne,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Verified by Moneytries Global Compliance',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 11.5,
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
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
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
                size: 108,
                color: _emerald.withOpacity(0.06),
              ),
            ),
            Row(
              children: [
                Icon(
                  Icons.verified_user_rounded,
                  size: 17,
                  color: _emerald.withOpacity(0.9),
                ),
                const SizedBox(width: 8),
                Text(
                  'Bank-Grade Encryption Enabled',
                  style: GoogleFonts.poppins(
                    fontSize: 12.5,
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
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor ?? _cardBorder, width: 1),
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
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
        border: const Border(top: BorderSide(color: _cardBorder, width: 1)),
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
              height: 54,
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
                  borderRadius: BorderRadius.circular(30),
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
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _white,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (isSelfie) ...[
                              const Icon(
                                Icons.camera_alt_rounded,
                                size: 18,
                                color: _white,
                              ),
                              const SizedBox(width: 8),
                            ],
                            Text(
                              vm.nextLabel,
                              style: GoogleFonts.poppins(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w700,
                                color: _white,
                              ),
                            ),
                            if (!isSelfie && !isBank) ...[
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.arrow_forward_rounded,
                                size: 18,
                                color: _white,
                              ),
                            ],
                          ],
                        ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  color: _muted,
                  height: 1.5,
                ),
                children: [
                  const TextSpan(text: 'By continuing, you agree to our '),
                  TextSpan(
                    text: 'Privacy Policy',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
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
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: _mint,
                        size: 24,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Review Your Selfie',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: _mint,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(
                        color: _emerald.withOpacity(0.35),
                        width: 1.4,
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
                      borderRadius: BorderRadius.circular(25),
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
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.pop(context, false),
                        icon: const Icon(
                          Icons.refresh_rounded,
                          color: _mint,
                          size: 20,
                        ),
                        label: Text(
                          'Retake',
                          style: GoogleFonts.poppins(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            color: _mint,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                            color: _fieldBorder,
                            width: 1.4,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [_primary, _emerald],
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.pop(context, true),
                          icon: const Icon(
                            Icons.check_rounded,
                            color: _white,
                            size: 20,
                          ),
                          label: Text(
                            'Use Photo',
                            style: GoogleFonts.poppins(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: _white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
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
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _surface,
                      shape: BoxShape.circle,
                      border: Border.all(color: _cardBorder),
                    ),
                    child: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 17,
                      color: _emerald,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(top: 16, bottom: 16),
                  child: Column(
                    children: [
                      FadeTransition(
                        opacity: _fadeAnim,
                        child: ScaleTransition(
                          scale: _scaleAnim,
                          child: Container(
                            width: 124,
                            height: 124,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [_primary, _emerald],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              border: Border.all(
                                color: _champagne.withOpacity(0.5),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: _emerald.withOpacity(0.45),
                                  blurRadius: 36,
                                  offset: const Offset(0, 12),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.verified_rounded,
                              size: 58,
                              color: _white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 36),
                      FadeTransition(
                        opacity: _fadeAnim,
                        child: Text(
                          _isApproved
                              ? 'KYC Approved!'
                              : 'Verification\nSubmitted!',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 30,
                            fontWeight: FontWeight.w700,
                            color: _mint,
                            height: 1.2,
                          ),
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
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: _bodyGrey,
                            height: 1.6,
                          ),
                        ),
                      ),
                      // Show the submitted documents + bank details once the
                      // admin has approved the KYC.
                      if (_isApproved && d != null) ...[
                        const SizedBox(height: 36),
                        FadeTransition(
                          opacity: _fadeAnim,
                          child: _buildSubmittedDetailsCard(d),
                        ),
                      ],
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [_primary, _emerald],
                            ),
                            borderRadius: BorderRadius.circular(30),
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
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            child: Text(
                              'Back to Home',
                              style: GoogleFonts.poppins(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w700,
                                color: _white,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
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

  // ── Submitted KYC details (shown after admin approval) ───────────────────
  Widget _buildSubmittedDetailsCard(KycSubmissionDetails d) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(22),
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
              const Icon(
                Icons.verified_user_rounded,
                size: 18,
                color: _emerald,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Your Submitted KYC Details',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: _mint,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Document images grid ─────────────────────────────────────────
          Row(
            children: [
              Expanded(child: _docThumb('Aadhaar Front', d.aadhaarFrontUrl)),
              const SizedBox(width: 10),
              Expanded(child: _docThumb('Aadhaar Back', d.aadhaarBackUrl)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _docThumb('PAN Card', d.panFrontUrl)),
              const SizedBox(width: 10),
              Expanded(child: _docThumb('Selfie', d.selfieUrl)),
            ],
          ),

          const SizedBox(height: 20),
          Text(
            'Bank Details',
            style: GoogleFonts.poppins(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: _muted,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 10),
          _detailRow('Account Holder', d.accountHolderName),
          _detailRow('Account Number', d.accountNumber),
          _detailRow('IFSC Code', d.ifscCode),
          _detailRow(
            'Bank',
            [
              d.bankName,
              d.bankBranch,
            ].where((s) => s.trim().isNotEmpty).join(', '),
          ),
          _detailRow(
            'Location',
            [
              d.bankCity,
              d.bankState,
            ].where((s) => s.trim().isNotEmpty).join(', '),
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _docThumb(String label, String? url) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: Container(
              color: _fieldBg,
              child: url == null
                  ? Icon(
                      Icons.image_not_supported_outlined,
                      color: _muted,
                      size: 22,
                    )
                  : Image.network(
                      url,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return Center(
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _emerald,
                              value: progress.expectedTotalBytes != null
                                  ? progress.cumulativeBytesLoaded /
                                        progress.expectedTotalBytes!
                                  : null,
                            ),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stack) => Icon(
                        Icons.broken_image_outlined,
                        color: _muted,
                        size: 22,
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.poppins(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: _bodyGrey,
          ),
        ),
      ],
    );
  }

  Widget _detailRow(String label, String value, {bool isLast = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 118,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: _muted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.trim().isEmpty ? '—' : value,
              style: GoogleFonts.poppins(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: _mint,
              ),
            ),
          ),
        ],
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
          width: 40,
          height: 40,
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
            size: 20,
            color: done
                ? _white
                : active
                ? _emerald
                : _muted,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 14.5,
              fontWeight: done || active ? FontWeight.w700 : FontWeight.w400,
              color: done
                  ? _mint
                  : active
                  ? _emerald
                  : _muted,
            ),
          ),
        ),
        const SizedBox(width: 8),
        if (done)
          const Icon(Icons.check_circle_rounded, size: 18, color: _emerald)
        else if (active)
          SizedBox(
            width: 16,
            height: 16,
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
      Rect.fromCenter(center: Offset(cx, cy), width: 58, height: 74),
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
        width: 68 + progress * 6,
        height: 86 + progress * 6,
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
