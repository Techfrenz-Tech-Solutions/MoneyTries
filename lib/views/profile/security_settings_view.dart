// lib/views/profile/security_settings_view.dart

import 'package:flutter/material.dart';
import 'package:moneytries/config/app_fonts.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/security/security_model.dart';
import '../../viewmodels/security/security_viewmodel.dart';
import 'change_password_screen.dart';
import 'change_login_pin_screen.dart';
import 'change_withdrawal_pin_screen.dart';
import '../../utils/responsive.dart';

// -- Palette -------------------------------------------------------------------
const _bgColor = Color(0xFFF7F5F2);
const _white = Color(0xFFFFFFFF);
const _titleDark = Color(0xFF111827);
const _subtitleGrey = Color(0xFF6B7280);
const _labelGrey = Color(0xFF9CA3AF);
const _brandGreen = Color(0xFF1F6B45); // banner dark green
const _accentGreen = Color(0xFF9AE0BC); // banner gradient end
const _iconBg = Color(0xFFDCF3E5); // banner gradient start
const _errorRed = Color(0xFFEF4444);
const _dotEmpty = Color(0xFFD9D5CF);
const _dotFilled = Color(0xFF1F6B45); // banner dark green
const _keyBg = Color(0xFFFFFFFF);

// -- Entry point ---------------------------------------------------------------
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
            style: TextStyle(
              fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
              fontSize: 13.5.sp,
              fontWeight: FontWeight.w500,
              color: _white,
            ),
          ),
          backgroundColor: isError ? _errorRed : _accentGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
          margin: EdgeInsets.all(16.w),
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
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: _titleDark,
                size: 20.sp,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              'Security Settings',
              style: TextStyle(
                fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                fontSize: 17.sp,
                fontWeight: FontWeight.w700,
                color: _titleDark,
              ),
            ),
            centerTitle: true,
          ),
          body: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // -- Login Credentials -----------------------------------
                _sectionLabel('Login Credentials'),
                SizedBox(height: 12.h),
                _actionTile(
                  context: context,
                  icon: Icons.key_rounded,
                  title: 'Change Password',
                  subtitle:
                      'Update the password used to sign in to your account',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ChangePasswordScreen(),
                    ),
                  ),
                ),

                // -- PIN & Auth -------------------------------------------
                SizedBox(height: 24.h),
                _sectionLabel('PIN & Authentication'),
                SizedBox(height: 12.h),
                _actionTile(
                  context: context,
                  icon: Icons.lock_outline_rounded,
                  title: 'Change PIN',
                  subtitle: 'Update your 4-digit security PIN',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ChangeLoginPinScreen(),
                    ),
                  ),
                ),
                SizedBox(height: 12.h),
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
                SizedBox(height: 12.h),
                _biometricTile(context, vm),

                // -- 2FA -------------------------------------------------
                SizedBox(height: 24.h),
                _sectionLabel('Two-Factor Authentication'),
                SizedBox(height: 12.h),
                _twoFactorTile(context, vm),

                // -- Sessions ---------------------------------------------
                SizedBox(height: 24.h),
                _sectionLabel('Active Sessions'),
                SizedBox(height: 12.h),
                _actionTile(
                  context: context,
                  icon: Icons.devices_rounded,
                  title: 'Manage Devices',
                  subtitle: 'View and revoke active login sessions',
                  onTap: () => _openManageDevicesSheet(context),
                ),
                SizedBox(height: 32.h),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // -- Section label ---------------------------------------------------------
  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
        fontSize: 14.sp,
        fontWeight: FontWeight.w600,
        color: _subtitleGrey,
      ),
    );
  }

  // -- Action tile -----------------------------------------------------------
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
        padding: EdgeInsets.all(16.w),
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
              child: Icon(icon, color: _accentGreen, size: 22.sp),
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                      color: _titleDark,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                      fontSize: 12.5.sp,
                      fontWeight: FontWeight.w400,
                      color: _subtitleGrey,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: _subtitleGrey,
              size: 22.sp,
            ),
          ],
        ),
      ),
    );
  }

  // -- Biometric tile --------------------------------------------------------
  Widget _biometricTile(BuildContext context, SecurityViewModel vm) {
    return Container(
      padding: EdgeInsets.all(16.w),
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
              Icons.fingerprint_rounded,
              color: _accentGreen,
              size: 22.sp,
            ),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Biometric Login',
                  style: TextStyle(
                    fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w600,
                    color: _titleDark,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  vm.biometricsAvailable
                      ? 'Use fingerprint or Face ID to sign in'
                      : 'Not available on this device',
                  style: TextStyle(
                    fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                    fontSize: 12.5.sp,
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

  // -- 2FA tile --------------------------------------------------------------
  Widget _twoFactorTile(BuildContext context, SecurityViewModel vm) {
    return Container(
      padding: EdgeInsets.all(16.w),
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
              Icons.verified_user_outlined,
              color: _accentGreen,
              size: 22.sp,
            ),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '2FA via SMS',
                  style: TextStyle(
                    fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w600,
                    color: _titleDark,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  'Receive OTP on your registered mobile',
                  style: TextStyle(
                    fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                    fontSize: 12.5.sp,
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

  // --------------------------------------------------------------------------
  // BOTTOM SHEETS
  // --------------------------------------------------------------------------

  // -- Withdrawal PIN ----------------------------------------------------
  // If a Withdrawal PIN already exists, use the dedicated Change Withdrawal
  // PIN flow (server-enforced current-PIN verification with a 5-attempt
  // cap and 5-minute lockout). If none is set yet, there's no "current
  // PIN" to verify, so first-time setup stays on the simpler bottom sheet.
  void _openWithdrawalPinSheet(BuildContext context) {
    final vm = context.read<SecurityViewModel>();
    if (vm.hasWithdrawalPin) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const ChangeWithdrawalPinScreen(),
        ),
      );
      return;
    }
    vm.resetWithdrawalPinFlow();
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

  // -- 2FA enable sheet ------------------------------------------------------
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

  // -- Disable 2FA dialog ----------------------------------------------------
  void _showDisable2faDialog(BuildContext context) {
    final vm = context.read<SecurityViewModel>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.r),
        ),
        title: Text(
          'Disable 2FA',
          style: TextStyle(
            fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
            fontSize: 17.sp,
            fontWeight: FontWeight.w700,
            color: _titleDark,
          ),
        ),
        content: Text(
          'Disabling two-factor authentication will make your account less secure. Are you sure?',
          style: TextStyle(
            fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
            fontSize: 14.sp,
            fontWeight: FontWeight.w400,
            color: _subtitleGrey,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(
                fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
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
              style: TextStyle(
                fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                fontWeight: FontWeight.w700,
                color: _errorRed,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // -- Manage Devices sheet --------------------------------------------------
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

// ------------------------------------------------------------------------------
// WITHDRAWAL PIN SHEET
// ------------------------------------------------------------------------------
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
      height: 0.88.h,
      child: Column(
        children: [
          _SheetHandle(),
          SizedBox(height: 20.h),
          // Step indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(vm.withdrawalPinTotalSteps, (i) {
              final done = i < vm.withdrawalPinStep;
              final active = i == vm.withdrawalPinStep;
              return Container(
                width: active ? 24 : 8,
                height: 8.h,
                margin: EdgeInsets.symmetric(horizontal: 3.w),
                decoration: BoxDecoration(
                  color: done || active ? _brandGreen : _dotEmpty,
                  borderRadius: BorderRadius.circular(4.r),
                ),
              );
            }),
          ),
          SizedBox(height: 20.h),
          // Lock icon
          Container(
            width: 64.w,
            height: 64.h,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: _iconBg,
            ),
            child: Icon(
              Icons.password_rounded,
              size: 30.sp,
              color: _brandGreen,
            ),
          ),
          SizedBox(height: 16.h),
          Text(
            vm.withdrawalPinTitle,
            style: TextStyle(
              fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
              fontSize: 20.sp,
              fontWeight: FontWeight.w800,
              color: _titleDark,
            ),
          ),
          SizedBox(height: 8.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 28.w),
            child: Text(
              vm.withdrawalPinSubtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                fontSize: 13.5.sp,
                fontWeight: FontWeight.w400,
                color: _subtitleGrey,
                height: 1.5,
              ),
            ),
          ),
          SizedBox(height: 28.h),
          // PIN dots
          _PinDots(
            length: SecurityViewModel.pinLength,
            filled: vm.activeWithdrawalPinEntry.length,
          ),
          if (vm.withdrawalPinError != null) ...[
            SizedBox(height: 10.h),
            Text(
              vm.withdrawalPinError!,
              style: TextStyle(
                fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                fontSize: 12.5.sp,
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
          SizedBox(height: 20.h),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------------------
// 2FA SHEET
// ------------------------------------------------------------------------------
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
      height: 0.75.h,
      child: Column(
        children: [
          _SheetHandle(),
          SizedBox(height: 20.h),
          Container(
            width: 60.w,
            height: 60.h,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: _iconBg,
            ),
            child: Icon(Icons.sms_outlined, size: 28.sp, color: _brandGreen),
          ),
          SizedBox(height: 16.h),
          Text(
            'Verify your number',
            style: TextStyle(
              fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
              fontSize: 20.sp,
              fontWeight: FontWeight.w800,
              color: _titleDark,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            vm.otpSent
                ? 'Enter the 6-digit OTP sent to your\nregistered mobile number.'
                : 'We\'ll send an OTP to your registered\nmobile number to enable 2FA.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
              fontSize: 13.5.sp,
              fontWeight: FontWeight.w400,
              color: _subtitleGrey,
              height: 1.5,
            ),
          ),
          SizedBox(height: 28.h),

          if (!vm.otpSent) ...[
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w),
              child: SizedBox(
                width: double.infinity,
                height: 52.h,
                child: ElevatedButton(
                  onPressed: vm.action == SecurityAction.loading
                      ? null
                      : () => vm.send2faOtp(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: const Color(0xFF1F6B45),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30.r),
                    ),
                    padding: EdgeInsets.zero,
                  ),
                  child: Ink(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFDCF3E5), Color(0xFF9AE0BC)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(30.r),
                    ),
                    child: Container(
                      alignment: Alignment.center,
                      child: vm.action == SecurityAction.loading
                          ? SizedBox(
                              width: 22.w,
                              height: 22.h,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: const Color(0xFF1F6B45),
                              ),
                            )
                          : Text(
                              'Send OTP',
                              style: TextStyle(
                                fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                                fontSize: 15.sp,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF1F6B45),
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ] else ...[
            // OTP input boxes
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (i) {
                  return SizedBox(
                    width: 46.w,
                    height: 54.h,
                    child: TextField(
                      controller: _ctrls[i],
                      focusNode: _foci[i],
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 1,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: TextStyle(
                        fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                        fontSize: 20.sp,
                        fontWeight: FontWeight.w700,
                        color: _titleDark,
                      ),
                      decoration: InputDecoration(
                        counterText: '',
                        filled: true,
                        fillColor: _white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.r),
                          borderSide: BorderSide(
                            color: Color(0xFFD9D5CF),
                            width: 1.5.r,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.r),
                          borderSide: BorderSide(
                            color: _accentGreen,
                            width: 2.r,
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
            SizedBox(height: 16.h),
            // Resend
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Didn't receive OTP? ",
                  style: TextStyle(
                    fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                    fontSize: 13.sp,
                    color: _subtitleGrey,
                  ),
                ),
                vm.otpCountdown > 0
                    ? Text(
                        'Resend in ${vm.otpCountdown}s',
                        style: TextStyle(
                          fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                          color: _accentGreen,
                        ),
                      )
                    : GestureDetector(
                        onTap: () => vm.send2faOtp(),
                        child: Text(
                          'Resend OTP',
                          style: TextStyle(
                            fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w700,
                            color: _brandGreen,
                          ),
                        ),
                      ),
              ],
            ),
            SizedBox(height: 24.h),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFDCF3E5), Color(0xFF9AE0BC)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(30.r),
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 52.h,
                  child: ElevatedButton(
                    onPressed:
                        (_otp.length < 6 || vm.action == SecurityAction.loading)
                        ? null
                        : () => _handleVerify(vm),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      disabledBackgroundColor: Colors.transparent,
                      foregroundColor: const Color(0xFF1F6B45),
                      elevation: 0,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30.r),
                      ),
                    ),
                    child: vm.action == SecurityAction.loading
                        ? SizedBox(
                            width: 22.w,
                            height: 22.h,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: const Color(0xFF1F6B45),
                            ),
                          )
                        : Text(
                            'Verify & Enable',
                            style: TextStyle(
                              fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1F6B45),
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ],
          SizedBox(height: 16.h),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------------------
// MANAGE DEVICES SHEET
// ------------------------------------------------------------------------------
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
      height: 0.78.h,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SheetHandle(),
          SizedBox(height: 16.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: Text(
              'Active Sessions',
              style: TextStyle(
                fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                fontSize: 20.sp,
                fontWeight: FontWeight.w800,
                color: _titleDark,
              ),
            ),
          ),
          SizedBox(height: 4.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: Text(
              vm.isLoadingSessions
                  ? 'Loading sessions...'
                  : '${vm.sessions.length} device${vm.sessions.length == 1 ? '' : 's'} currently signed in',
              style: TextStyle(
                fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                fontSize: 13.5.sp,
                color: _subtitleGrey,
              ),
            ),
          ),
          SizedBox(height: 20.h),
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
                          size: 48.sp,
                          color: _labelGrey,
                        ),
                        SizedBox(height: 12.h),
                        Text(
                          'No active sessions found',
                          style: TextStyle(
                            fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                            fontSize: 14.sp,
                            color: _labelGrey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: EdgeInsets.symmetric(horizontal: 20.w),
                    itemCount: vm.sessions.length,
                    separatorBuilder: (_, __) => SizedBox(height: 12.h),
                    itemBuilder: (_, i) {
                      final s = vm.sessions[i];
                      return Container(
                        padding: EdgeInsets.all(16.w),
                        decoration: BoxDecoration(
                          color: _white,
                          borderRadius: BorderRadius.circular(16.r),
                          border: s.isCurrent
                              ? Border.all(color: _accentGreen, width: 1.5.r)
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
                              width: 44.w,
                              height: 44.h,
                              decoration: BoxDecoration(
                                color: s.isCurrent
                                    ? _iconBg
                                    : const Color(0xFFF3F4F6),
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                              child: Icon(
                                _deviceIcon(s.deviceType),
                                color: s.isCurrent ? _accentGreen : _labelGrey,
                                size: 22.sp,
                              ),
                            ),
                            SizedBox(width: 14.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          s.deviceName,
                                          style: TextStyle(
                                            fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                                            fontSize: 14.5.sp,
                                            fontWeight: FontWeight.w700,
                                            color: _titleDark,
                                          ),
                                        ),
                                      ),
                                      if (s.isCurrent) ...[
                                        SizedBox(width: 8.w),
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 8.w,
                                            vertical: 2.h,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _iconBg,
                                            borderRadius: BorderRadius.circular(
                                              20.r,
                                            ),
                                          ),
                                          child: Text(
                                            'This device',
                                            style: TextStyle(
                                              fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                                              fontSize: 10.5.sp,
                                              fontWeight: FontWeight.w700,
                                              color: _accentGreen,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  SizedBox(height: 2.h),
                                  Text(
                                    '${s.location} � ${s.lastActive}',
                                    style: TextStyle(
                                      fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                                      fontSize: 12.sp,
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
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 10.w,
                                    vertical: 6.h,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _errorRed.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(8.r),
                                  ),
                                  child: Text(
                                    'Sign out',
                                    style: TextStyle(
                                      fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                                      fontSize: 12.5.sp,
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
          SizedBox(height: 20.h),
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.r),
        ),
        title: Text(
          'Sign out device?',
          style: TextStyle(
            fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
            fontSize: 17.sp,
            fontWeight: FontWeight.w700,
            color: _titleDark,
          ),
        ),
        content: Text(
          'Are you sure you want to sign out "${session.deviceName}"?',
          style: TextStyle(
            fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
            fontSize: 14.sp,
            fontWeight: FontWeight.w400,
            color: _subtitleGrey,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(
                fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
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
              style: TextStyle(
                fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
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

// ------------------------------------------------------------------------------
// SHARED WIDGETS
// ------------------------------------------------------------------------------
class _SheetWrapper extends StatelessWidget {
  final Widget child;
  final double height;
  const _SheetWrapper({required this.child, required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * height,
      decoration: BoxDecoration(
        color: _bgColor,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28.r),
          topRight: Radius.circular(28.r),
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
      padding: EdgeInsets.only(top: 12.h),
      child: Center(
        child: Container(
          width: 40.w,
          height: 4.h,
          decoration: BoxDecoration(
            color: const Color(0xFFD9D5CF),
            borderRadius: BorderRadius.circular(2.r),
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
          margin: EdgeInsets.symmetric(horizontal: 6.w),
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
      padding: EdgeInsets.symmetric(horizontal: 32.w),
      child: Column(
        children: [
          ...keys.map(
            (row) => Padding(
              padding: EdgeInsets.only(bottom: 14.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: row.map((d) => _KeyBtn(d, onKey)).toList(),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SizedBox(width: 72.w, height: 72.h),
              _KeyBtn(0, onKey),
              SizedBox(
                width: 72.w,
                height: 72.h,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onDelete,
                    borderRadius: BorderRadius.circular(36.r),
                    child: Icon(
                      Icons.backspace_outlined,
                      size: 24.sp,
                      color: _titleDark,
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 14.h),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFDCF3E5), Color(0xFF9AE0BC)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(30.r),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 52.h,
              child: ElevatedButton(
                onPressed: onConfirm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  disabledBackgroundColor: Colors.transparent,
                  foregroundColor: const Color(0xFF1F6B45),
                  elevation: 0,
                  shadowColor: Colors.transparent,
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
                          color: const Color(0xFF1F6B45),
                        ),
                      )
                    : Text(
                        confirmLabel,
                        style: TextStyle(
                          fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1F6B45),
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

class _KeyBtn extends StatelessWidget {
  final int digit;
  final ValueChanged<int> onTap;
  const _KeyBtn(this.digit, this.onTap);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72.w,
      height: 72.h,
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
              style: TextStyle(
                fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                fontSize: 22.sp,
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