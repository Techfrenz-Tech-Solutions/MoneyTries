// lib/views/profile/security_settings_view.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/security/security_model.dart';
import '../../viewmodels/security/security_viewmodel.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _bgColor = Color(0xFFECEFF5);
const _white = Color(0xFFFFFFFF);
const _titleDark = Color(0xFF111827);
const _subtitleGrey = Color(0xFF6B7280);
const _labelGrey = Color(0xFF9CA3AF);
const _brandGreen = Color(0xFF166534);
const _accentGreen = Color(0xFF3D9E6A);
const _iconBg = Color(0xFFD0EDDC);
const _errorRed = Color(0xFFEF4444);
const _dotEmpty = Color(0xFFD1D5DB);
const _dotFilled = Color(0xFF166534);
const _keyBg = Color(0xFFFFFFFF);

// ── Entry point ───────────────────────────────────────────────────────────────
class SecuritySettingsView extends StatelessWidget {
  const SecuritySettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SecurityViewModel(),
      child: const _SecuritySettingsBody(),
    );
  }
}

class _SecuritySettingsBody extends StatelessWidget {
  const _SecuritySettingsBody();

  void _showSnack(BuildContext context, String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            msg,
            style: GoogleFonts.poppins(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              color: _white,
            ),
          ),
          backgroundColor: isError ? _errorRed : _accentGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 3),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SecurityViewModel>();

    // Consume messages
    if (vm.message != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final isError = vm.action == SecurityAction.error;
        _showSnack(context, vm.message!, isError: isError);
        vm.clearMessage();
      });
    }

    return Theme(
      data: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: _bgColor,
      ),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: Scaffold(
          backgroundColor: _bgColor,
          appBar: AppBar(
            backgroundColor: _bgColor,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: _titleDark,
                size: 20,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              'Security Settings',
              style: GoogleFonts.poppins(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: _titleDark,
              ),
            ),
            centerTitle: true,
          ),
          body: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── PIN & Auth ───────────────────────────────────────────
                _sectionLabel('PIN & Authentication'),
                const SizedBox(height: 12),
                _actionTile(
                  context: context,
                  icon: Icons.lock_outline_rounded,
                  title: 'Change PIN',
                  subtitle: 'Update your 4-digit security PIN',
                  onTap: () => _openChangePinSheet(context),
                ),
                const SizedBox(height: 12),
                _actionTile(
                  context: context,
                  icon: Icons.password_rounded,
                  title: vm.hasWithdrawalPin
                      ? 'Withdrawal PIN'
                      : 'Set Withdrawal PIN',
                  subtitle: vm.hasWithdrawalPin
                      ? 'Update the PIN used to confirm withdrawals'
                      : 'Required to confirm withdrawal requests',
                  onTap: () => _openWithdrawalPinSheet(context),
                ),
                const SizedBox(height: 12),
                _biometricTile(context, vm),

                // ── 2FA ─────────────────────────────────────────────────
                const SizedBox(height: 24),
                _sectionLabel('Two-Factor Authentication'),
                const SizedBox(height: 12),
                _twoFactorTile(context, vm),

                // ── Sessions ─────────────────────────────────────────────
                const SizedBox(height: 24),
                _sectionLabel('Active Sessions'),
                const SizedBox(height: 12),
                _actionTile(
                  context: context,
                  icon: Icons.devices_rounded,
                  title: 'Manage Devices',
                  subtitle: 'View and revoke active login sessions',
                  onTap: () => _openManageDevicesSheet(context),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Section label ─────────────────────────────────────────────────────────
  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: _subtitleGrey,
      ),
    );
  }

  // ── Action tile ───────────────────────────────────────────────────────────
  Widget _actionTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
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
              child: Icon(icon, color: _accentGreen, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _titleDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w400,
                      color: _subtitleGrey,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: _subtitleGrey,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  // ── Biometric tile ────────────────────────────────────────────────────────
  Widget _biometricTile(BuildContext context, SecurityViewModel vm) {
    return Container(
      padding: const EdgeInsets.all(16),
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
              Icons.fingerprint_rounded,
              color: _accentGreen,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Biometric Login',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _titleDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  vm.biometricsAvailable
                      ? 'Use fingerprint or Face ID to sign in'
                      : 'Not available on this device',
                  style: GoogleFonts.poppins(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w400,
                    color: _subtitleGrey,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: vm.biometricsEnabled,
            onChanged: vm.biometricsAvailable
                ? (v) async {
                    await vm.toggleBiometrics(v);
                  }
                : null,
            activeColor: _brandGreen,
          ),
        ],
      ),
    );
  }

  // ── 2FA tile ──────────────────────────────────────────────────────────────
  Widget _twoFactorTile(BuildContext context, SecurityViewModel vm) {
    return Container(
      padding: const EdgeInsets.all(16),
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
              Icons.verified_user_outlined,
              color: _accentGreen,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '2FA via SMS',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _titleDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Receive OTP on your registered mobile',
                  style: GoogleFonts.poppins(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w400,
                    color: _subtitleGrey,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: vm.twoFactorEnabled,
            onChanged: (v) {
              if (v) {
                _open2faSheet(context);
              } else {
                _showDisable2faDialog(context);
              }
            },
            activeColor: _brandGreen,
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BOTTOM SHEETS
  // ══════════════════════════════════════════════════════════════════════════

  // ── Change PIN sheet ──────────────────────────────────────────────────────
  void _openChangePinSheet(BuildContext context) {
    final vm = context.read<SecurityViewModel>()..resetChangePinFlow();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider.value(
        value: vm,
        child: const _ChangePinSheet(),
      ),
    );
  }

  // ── Withdrawal PIN sheet ──────────────────────────────────────────────────
  void _openWithdrawalPinSheet(BuildContext context) {
    final vm = context.read<SecurityViewModel>()..resetWithdrawalPinFlow();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider.value(
        value: vm,
        child: const _WithdrawalPinSheet(),
      ),
    );
  }

  // ── 2FA enable sheet ──────────────────────────────────────────────────────
  void _open2faSheet(BuildContext context) {
    final vm = context.read<SecurityViewModel>()..reset2faState();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          ChangeNotifierProvider.value(value: vm, child: const _TwoFaSheet()),
    );
  }

  // ── Disable 2FA dialog ────────────────────────────────────────────────────
  void _showDisable2faDialog(BuildContext context) {
    final vm = context.read<SecurityViewModel>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Disable 2FA',
          style: GoogleFonts.poppins(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: _titleDark,
          ),
        ),
        content: Text(
          'Disabling two-factor authentication will make your account less secure. Are you sure?',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: _subtitleGrey,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: _subtitleGrey,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              vm.disable2fa();
            },
            child: Text(
              'Disable',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                color: _errorRed,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Manage Devices sheet ──────────────────────────────────────────────────
  void _openManageDevicesSheet(BuildContext context) {
    final vm = context.read<SecurityViewModel>()..loadSessions();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider.value(
        value: vm,
        child: const _ManageDevicesSheet(),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// CHANGE PIN SHEET
// ══════════════════════════════════════════════════════════════════════════════
class _ChangePinSheet extends StatelessWidget {
  const _ChangePinSheet();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SecurityViewModel>();

    // Auto-close when done
    if (vm.pinChanged) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (Navigator.canPop(context)) Navigator.pop(context);
      });
    }

    return _SheetWrapper(
      height: 0.88,
      child: Column(
        children: [
          _SheetHandle(),
          const SizedBox(height: 20),
          // Step indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, (i) {
              final done = i < vm.changePinStep;
              final active = i == vm.changePinStep;
              return Container(
                width: active ? 24 : 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: done || active ? _brandGreen : _dotEmpty,
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
          const SizedBox(height: 20),
          // Lock icon
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: _iconBg,
            ),
            child: Icon(
              vm.changePinStep == 0
                  ? Icons.lock_open_rounded
                  : vm.changePinStep == 1
                  ? Icons.lock_outline_rounded
                  : Icons.lock_rounded,
              size: 30,
              color: _brandGreen,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            vm.changePinTitle,
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: _titleDark,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Text(
              vm.changePinSubtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13.5,
                fontWeight: FontWeight.w400,
                color: _subtitleGrey,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 28),
          // PIN dots
          _PinDots(
            length: SecurityViewModel.pinLength,
            filled: vm.activePinEntry.length,
          ),
          if (vm.pinError != null) ...[
            const SizedBox(height: 10),
            Text(
              vm.pinError!,
              style: GoogleFonts.poppins(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: _errorRed,
              ),
            ),
          ],
          const Spacer(),
          // Numpad
          _NumPad(
            onKey: vm.pinKeyPress,
            onDelete: vm.pinDelete,
            onConfirm: vm.action == SecurityAction.loading
                ? null
                : () => vm.pinConfirm(),
            confirmLabel: vm.changePinStep == 2 ? 'Confirm' : 'Next',
            isLoading: vm.action == SecurityAction.loading,
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// WITHDRAWAL PIN SHEET
// ══════════════════════════════════════════════════════════════════════════════
class _WithdrawalPinSheet extends StatelessWidget {
  const _WithdrawalPinSheet();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SecurityViewModel>();

    // Auto-close when done
    if (vm.withdrawalPinChanged) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (Navigator.canPop(context)) Navigator.pop(context);
      });
    }

    return _SheetWrapper(
      height: 0.88,
      child: Column(
        children: [
          _SheetHandle(),
          const SizedBox(height: 20),
          // Step indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(vm.withdrawalPinTotalSteps, (i) {
              final done = i < vm.withdrawalPinStep;
              final active = i == vm.withdrawalPinStep;
              return Container(
                width: active ? 24 : 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: done || active ? _brandGreen : _dotEmpty,
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
          const SizedBox(height: 20),
          // Lock icon
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: _iconBg,
            ),
            child: const Icon(
              Icons.password_rounded,
              size: 30,
              color: _brandGreen,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            vm.withdrawalPinTitle,
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: _titleDark,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Text(
              vm.withdrawalPinSubtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13.5,
                fontWeight: FontWeight.w400,
                color: _subtitleGrey,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 28),
          // PIN dots
          _PinDots(
            length: SecurityViewModel.pinLength,
            filled: vm.activeWithdrawalPinEntry.length,
          ),
          if (vm.withdrawalPinError != null) ...[
            const SizedBox(height: 10),
            Text(
              vm.withdrawalPinError!,
              style: GoogleFonts.poppins(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: _errorRed,
              ),
            ),
          ],
          const Spacer(),
          // Numpad
          _NumPad(
            onKey: vm.withdrawalPinKeyPress,
            onDelete: vm.withdrawalPinDelete,
            onConfirm: vm.action == SecurityAction.loading
                ? null
                : () => vm.withdrawalPinConfirm(),
            confirmLabel: vm.withdrawalPinStep == vm.withdrawalPinTotalSteps - 1
                ? 'Confirm'
                : 'Next',
            isLoading: vm.action == SecurityAction.loading,
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// 2FA SHEET
// ══════════════════════════════════════════════════════════════════════════════
class _TwoFaSheet extends StatefulWidget {
  const _TwoFaSheet();
  @override
  State<_TwoFaSheet> createState() => _TwoFaSheetState();
}

class _TwoFaSheetState extends State<_TwoFaSheet> {
  final List<TextEditingController> _ctrls = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _foci = List.generate(6, (_) => FocusNode());

  @override
  void dispose() {
    for (final c in _ctrls) c.dispose();
    for (final f in _foci) f.dispose();
    super.dispose();
  }

  String get _otp => _ctrls.map((c) => c.text).join();

  void _handleVerify(SecurityViewModel vm) async {
    final result = await vm.verify2faOtp(_otp);
    if (result && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SecurityViewModel>();

    return _SheetWrapper(
      height: 0.75,
      child: Column(
        children: [
          _SheetHandle(),
          const SizedBox(height: 20),
          Container(
            width: 60,
            height: 60,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: _iconBg,
            ),
            child: const Icon(Icons.sms_outlined, size: 28, color: _brandGreen),
          ),
          const SizedBox(height: 16),
          Text(
            'Verify your number',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: _titleDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            vm.otpSent
                ? 'Enter the 6-digit OTP sent to your\nregistered mobile number.'
                : 'We\'ll send an OTP to your registered\nmobile number to enable 2FA.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 13.5,
              fontWeight: FontWeight.w400,
              color: _subtitleGrey,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),

          if (!vm.otpSent) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: vm.action == SecurityAction.loading
                      ? null
                      : () => vm.send2faOtp(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _brandGreen,
                    foregroundColor: _white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: vm.action == SecurityAction.loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _white,
                          ),
                        )
                      : Text(
                          'Send OTP',
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: _white,
                          ),
                        ),
                ),
              ),
            ),
          ] else ...[
            // OTP input boxes
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (i) {
                  return SizedBox(
                    width: 46,
                    height: 54,
                    child: TextField(
                      controller: _ctrls[i],
                      focusNode: _foci[i],
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 1,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: _titleDark,
                      ),
                      decoration: InputDecoration(
                        counterText: '',
                        filled: true,
                        fillColor: _white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFD1D5DB),
                            width: 1.5,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: _accentGreen,
                            width: 2,
                          ),
                        ),
                      ),
                      onChanged: (v) {
                        if (v.isNotEmpty && i < 5) {
                          _foci[i + 1].requestFocus();
                        } else if (v.isEmpty && i > 0) {
                          _foci[i - 1].requestFocus();
                        }
                        setState(() {});
                      },
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 16),
            // Resend
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Didn't receive OTP? ",
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: _subtitleGrey,
                  ),
                ),
                vm.otpCountdown > 0
                    ? Text(
                        'Resend in ${vm.otpCountdown}s',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _accentGreen,
                        ),
                      )
                    : GestureDetector(
                        onTap: () => vm.send2faOtp(),
                        child: Text(
                          'Resend OTP',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _brandGreen,
                          ),
                        ),
                      ),
              ],
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed:
                      (_otp.length < 6 || vm.action == SecurityAction.loading)
                      ? null
                      : () => _handleVerify(vm),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _brandGreen,
                    disabledBackgroundColor: _brandGreen.withOpacity(0.4),
                    foregroundColor: _white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: vm.action == SecurityAction.loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _white,
                          ),
                        )
                      : Text(
                          'Verify & Enable',
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: _white,
                          ),
                        ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// MANAGE DEVICES SHEET
// ══════════════════════════════════════════════════════════════════════════════
class _ManageDevicesSheet extends StatelessWidget {
  const _ManageDevicesSheet();

  IconData _deviceIcon(String type) {
    if (type == 'ios') return Icons.phone_iphone_rounded;
    if (type == 'web') return Icons.laptop_mac_rounded;
    return Icons.phone_android_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SecurityViewModel>();

    return _SheetWrapper(
      height: 0.78,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SheetHandle(),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Active Sessions',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: _titleDark,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              vm.isLoadingSessions
                  ? 'Loading sessions...'
                  : '${vm.sessions.length} device${vm.sessions.length == 1 ? '' : 's'} currently signed in',
              style: GoogleFonts.poppins(fontSize: 13.5, color: _subtitleGrey),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: vm.isLoadingSessions
                ? const Center(
                    child: CircularProgressIndicator(color: _accentGreen),
                  )
                : vm.sessions.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.devices_other_rounded,
                          size: 48,
                          color: _labelGrey,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No active sessions found',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: _labelGrey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: vm.sessions.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) {
                      final s = vm.sessions[i];
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _white,
                          borderRadius: BorderRadius.circular(16),
                          border: s.isCurrent
                              ? Border.all(color: _accentGreen, width: 1.5)
                              : null,
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
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: s.isCurrent
                                    ? _iconBg
                                    : const Color(0xFFF3F4F6),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                _deviceIcon(s.deviceType),
                                color: s.isCurrent ? _accentGreen : _labelGrey,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          s.deviceName,
                                          style: GoogleFonts.poppins(
                                            fontSize: 14.5,
                                            fontWeight: FontWeight.w700,
                                            color: _titleDark,
                                          ),
                                        ),
                                      ),
                                      if (s.isCurrent) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _iconBg,
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                          ),
                                          child: Text(
                                            'This device',
                                            style: GoogleFonts.poppins(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w700,
                                              color: _accentGreen,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${s.location} • ${s.lastActive}',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: _subtitleGrey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (!s.isCurrent)
                              GestureDetector(
                                onTap: () => _confirmRevoke(context, vm, s),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _errorRed.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Sign out',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: _errorRed,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void _confirmRevoke(
    BuildContext context,
    SecurityViewModel vm,
    DeviceSession session,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Sign out device?',
          style: GoogleFonts.poppins(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: _titleDark,
          ),
        ),
        content: Text(
          'Are you sure you want to sign out "${session.deviceName}"?',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: _subtitleGrey,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: _subtitleGrey,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              vm.revokeSession(session.id);
            },
            child: Text(
              'Sign Out',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                color: _errorRed,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SHARED WIDGETS
// ══════════════════════════════════════════════════════════════════════════════
class _SheetWrapper extends StatelessWidget {
  final Widget child;
  final double height;
  const _SheetWrapper({required this.child, required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * height,
      decoration: const BoxDecoration(
        color: _bgColor,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      child: child,
    );
  }
}

class _SheetHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Center(
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: const Color(0xFFD1D5DB),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}

class _PinDots extends StatelessWidget {
  final int length;
  final int filled;
  const _PinDots({required this.length, required this.filled});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(length, (i) {
        final isFilled = i < filled;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: isFilled ? 16 : 14,
          height: isFilled ? 16 : 14,
          margin: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isFilled ? _dotFilled : _dotEmpty,
          ),
        );
      }),
    );
  }
}

class _NumPad extends StatelessWidget {
  final ValueChanged<int> onKey;
  final VoidCallback onDelete;
  final VoidCallback? onConfirm;
  final String confirmLabel;
  final bool isLoading;

  const _NumPad({
    required this.onKey,
    required this.onDelete,
    required this.onConfirm,
    required this.confirmLabel,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final keys = [
      [1, 2, 3],
      [4, 5, 6],
      [7, 8, 9],
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          ...keys.map(
            (row) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: row.map((d) => _KeyBtn(d, onKey)).toList(),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(width: 72, height: 72),
              _KeyBtn(0, onKey),
              SizedBox(
                width: 72,
                height: 72,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onDelete,
                    borderRadius: BorderRadius.circular(36),
                    child: const Icon(
                      Icons.backspace_outlined,
                      size: 24,
                      color: _titleDark,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: onConfirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: _brandGreen,
                disabledBackgroundColor: _brandGreen.withOpacity(0.4),
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
                  : Text(
                      confirmLabel,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _white,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _KeyBtn extends StatelessWidget {
  final int digit;
  final ValueChanged<int> onTap;
  const _KeyBtn(this.digit, this.onTap);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      height: 72,
      child: Material(
        color: _keyBg,
        shape: const CircleBorder(),
        elevation: 1,
        shadowColor: Colors.black.withOpacity(0.08),
        child: InkWell(
          onTap: () => onTap(digit),
          customBorder: const CircleBorder(),
          child: Center(
            child: Text(
              '$digit',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: _titleDark,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
