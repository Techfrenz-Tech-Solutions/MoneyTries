import 'dart:async';
import 'package:flutter/material.dart';
import 'package:moneytries/config/app_fonts.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../config/app_constants.dart';
import '../../models/withdrawal/withdrawal_models.dart';
import '../../viewmodels/withdrawal/withdrawal_viewmodel.dart';
import '../../viewmodels/security/security_viewmodel.dart';
import '../../services/pin_lockout_service.dart';
import '../profile/security_settings_view.dart';
import '../../utils/responsive.dart';
import '../../widgets/animations/animations.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _bg           = Color(0xFFF7F5F2);
const _white        = Color(0xFFFFFFFF);
const _titleDark    = Color(0xFF111827);
const _subtitleGrey = Color(0xFF6B7280);
const _labelGrey    = Color(0xFF9CA3AF);
const _brandGreen   = Color(0xFF4CAF7D);
const _accentGreen  = Color(0xFF4CAF7D);
const _infoBg       = Color(0xFFF0FAF4);
const _infoBorder   = Color(0xFFD4EDE0);
const _infoText     = Color(0xFF4B5563);
const _errorRed     = Color(0xFFDC2626);
const _warningAmber = Color(0xFFD97706);
const _greenInfoBg  = Color(0xFFE8F5EE);
const _greenBorder  = Color(0xFFD4EDE0);

// ── Entry point ───────────────────────────────────────────────────────────────
/// Navigator.pushNamed(context, AppRoutes.withdrawal,
///   arguments: {'type': 'wallet'})   → wallet mode
/// Navigator.pushNamed(context, AppRoutes.withdrawal)  → deposit/capital mode
class WithdrawalScreen extends StatelessWidget {
  const WithdrawalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    final isWallet =
        args is Map && args['type'] == 'wallet';

    return ChangeNotifierProvider(
      create: (_) => WithdrawalViewModel(
        mode: isWallet ? WithdrawalMode.wallet : WithdrawalMode.deposit,
      ),
      child: const _WithdrawalScreenContent(),
    );
  }
}

// ── Main content ──────────────────────────────────────────────────────────────
class _WithdrawalScreenContent extends StatefulWidget {
  const _WithdrawalScreenContent();
  @override
  State<_WithdrawalScreenContent> createState() => _WithdrawalScreenContentState();
}

class _WithdrawalScreenContentState extends State<_WithdrawalScreenContent> {
  final TextEditingController _amountController = TextEditingController(text: '0');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final vm = context.read<WithdrawalViewModel>();
      // Fetch real wallet/vault balances from the backend.
      vm.fetchBalances();
      // Enable FLAG_SECURE (Android only — prevents screenshots)
      SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
      // Fetch KYC
      vm.fetchKycStatus();
      // Check if there is an existing withdrawal request under review.
      vm.checkPendingWithdrawal();
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _setPercentAmount(double fraction, WithdrawalViewModel vm) {
    final val = vm.availableBalance * fraction;
    vm.setAmount(val);
    _amountController.text = val.toStringAsFixed(0);
  }

  Future<void> _submit(WithdrawalViewModel vm) async {
    FocusScope.of(context).unfocus();
    final err = vm.validate();
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), backgroundColor: _errorRed),
      );
      return;
    }

    // A withdrawal PIN must be set in Security Settings before any request
    // can go through.
    final hasWithdrawalPin = await SecurityViewModel.isWithdrawalPinSet();
    if (!mounted) return;
    if (!hasWithdrawalPin) {
      _promptSetWithdrawalPin();
      return;
    }

    // Ask for the withdrawal PIN; only proceed once it's verified correct.
    final verified = await _showWithdrawalPinSheet();
    if (!mounted || verified != true) return;

    await vm.submitWithdrawal();
    // On success, call ProfileViewModel.fetchUserInfo() here to refresh balances
  }

  // Shown when no withdrawal PIN has been set up yet — sends the user to
  // Security Settings to set one before they can submit a request.
  void _promptSetWithdrawalPin() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
        title: Text(
          'Set a Withdrawal PIN',
          style: TextStyle(fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
              fontSize: 17.sp, fontWeight: FontWeight.w700, color: _titleDark),
        ),
        content: Text(
          'For your security, you need to set a 4-digit withdrawal PIN '
          'before submitting a withdrawal request.',
          style: TextStyle(fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
              fontSize: 14.sp, fontWeight: FontWeight.w400, color: _subtitleGrey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: TextStyle(fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                    fontWeight: FontWeight.w600, color: _subtitleGrey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SecuritySettingsView()),
              );
            },
            child: Text('Set PIN Now',
                style: TextStyle(fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                    fontWeight: FontWeight.w700, color: _brandGreen)),
          ),
        ],
      ),
    );
  }

  // Shows the withdrawal-PIN entry sheet and returns true only once the
  // entered PIN has been verified as correct.
  Future<bool?> _showWithdrawalPinSheet() {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      builder: (_) => const _WithdrawalPinEntrySheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<WithdrawalViewModel>(
      builder: (context, vm, _) {
        // ── Success view ────────────────────────────────────────────────────
        if (vm.state == WithdrawalState.success) {
          return _SuccessView(
            vm: vm,
            onDone: () {
              vm.reset();
              _amountController.text = '0';
              Navigator.pop(context);
            },
          );
        }

        if (vm.isCheckingPending) {
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
                      const Expanded(
                        child: Center(child: CircularProgressIndicator(color: _accentGreen)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        if (vm.hasPendingWithdrawal) {
          return _PendingWithdrawalBlocker(
            record: vm.pendingWithdrawal!,
            onRefresh: vm.refreshPendingStatus,
            isRefreshing: vm.isCheckingPending,
          );
        }

        // ── Normal form ─────────────────────────────────────────────────────
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
                    Expanded(
                      child: vm.state == WithdrawalState.loadingKyc
                          ? const Center(child: CircularProgressIndicator(color: _accentGreen))
                          : SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 20.h),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildModeChip(vm),
                                  SizedBox(height: 16.h),
                                  _buildBalanceCard(vm),
                                  SizedBox(height: 22.h),
                                  _buildAmountInput(vm),
                                  SizedBox(height: 14.h),
                                  _buildPercentRow(vm),
                                  SizedBox(height: 24.h),
                                  _buildBankAccountSection(vm),
                                  SizedBox(height: 18.h),
                                  _buildFeeSummary(vm),
                                  SizedBox(height: 14.h),
                                  _buildInfoCard(vm),
                                  if (vm.state == WithdrawalState.error && vm.errorMessage != null)
                                    _buildErrorBanner(vm.errorMessage!),
                                  SizedBox(height: 28.h),
                                  _buildSubmitAction(vm),
                                  SizedBox(height: MediaQuery.of(context).padding.bottom + 8.h),
                                ],
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Top bar ───────────────────────────────────────────────────────────────
  Widget _buildTopBar(BuildContext context, WithdrawalViewModel vm) {
    return Padding(
      padding: EdgeInsets.fromLTRB(8.w, 12.h, 12.w, 8.h),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Padding(
              padding: EdgeInsets.all(8.w),
              child: Icon(Icons.arrow_back, color: _brandGreen, size: 24.sp),
            ),
          ),
          Expanded(
            child: Text(
              vm.isWalletMode ? 'Wallet Withdrawal' : 'Capital Withdrawal',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,fontSize: 18.sp, fontWeight: FontWeight.w700, color: _brandGreen),
            ),
          ),
          SizedBox(width: 40.w),
        ],
      ),
    );
  }

  // ── Mode chip ─────────────────────────────────────────────────────────────
  Widget _buildModeChip(WithdrawalViewModel vm) {
    return Center(
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: vm.isWalletMode ? _greenInfoBg : _infoBg,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(color: vm.isWalletMode ? _greenBorder : _infoBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              vm.isWalletMode ? Icons.account_balance_wallet_rounded : Icons.savings_rounded,
              size: 15.sp,
              color: vm.isWalletMode ? _accentGreen : const Color(0xFF3B82F6),
            ),
            SizedBox(width: 6.w),
            Text(
              vm.isWalletMode
                  ? 'Instant bank transfer'
                  : 'Moves earnings → main wallet (admin review)',
              style: TextStyle(fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: vm.isWalletMode ? _brandGreen : const Color(0xFF1D4ED8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Balance card ──────────────────────────────────────────────────────────
  Widget _buildBalanceCard(WithdrawalViewModel vm) {
    final balance = vm.availableBalance;
    final progress = balance > 0 ? (vm.amount / balance).clamp(0.0, 1.0) : 0.0;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(18.w, 16.h, 18.w, 16.h),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF7F5F2), _white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18.r),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    vm.isWalletMode ? 'WALLET BALANCE' : 'VAULT BALANCE',
                    style: TextStyle(fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,fontSize: 11.sp, fontWeight: FontWeight.w600, color: _labelGrey, letterSpacing: 0.8),
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    '₹ ${_fmt(balance)}',
                    style: TextStyle(fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,fontSize: 26.sp, fontWeight: FontWeight.w800, color: _brandGreen),
                  ),
                ],
              ),
              Container(
                width: 40.w, height: 40.h,
                decoration: BoxDecoration(
                  color: _accentGreen.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Icon(
                  vm.isWalletMode ? Icons.account_balance_wallet_outlined : Icons.savings_outlined,
                  color: _accentGreen, size: 20.sp,
                ),
              ),
            ],
          ),
          SizedBox(height: 14.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(3.r),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: const Color(0xFFE8E4DE),
              valueColor: AlwaysStoppedAnimation<Color>(
                vm.amountExceedsBalance ? _errorRed : _accentGreen,
              ),
            ),
          ),
          if (vm.amount > 0)
            Padding(
              padding: EdgeInsets.only(top: 8.h),
              child: Text(
                'Withdrawing ₹ ${_fmt(vm.amount)} of ₹ ${_fmt(balance)}',
                style: TextStyle(fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                  color: vm.amountExceedsBalance ? _errorRed : _subtitleGrey,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Amount input ──────────────────────────────────────────────────────────
  Widget _buildAmountInput(WithdrawalViewModel vm) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Enter Amount',
          style: TextStyle(fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,fontSize: 13.5.sp, fontWeight: FontWeight.w500, color: _subtitleGrey),
        ),
        SizedBox(height: 8.h),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Padding(
              padding: EdgeInsets.only(bottom: 4.h, right: 6.w),
              child: Text('₹', style: TextStyle(fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,fontSize: 28.sp, fontWeight: FontWeight.w600, color: _labelGrey)),
            ),
            Expanded(
              child: TextField(
                controller: _amountController,
                onChanged: (v) => vm.setAmount(double.tryParse(v) ?? 0),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                cursorColor: _accentGreen,
                style: TextStyle(fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                  fontSize: 40.sp, fontWeight: FontWeight.w800,
                  color: (vm.amountExceedsBalance || vm.amountBelowMinimum || vm.amountAboveMaximum)
                      ? _errorRed
                      : _titleDark,
                ),
                decoration: const InputDecoration(
                  isDense: true, border: InputBorder.none, contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 6.h),
        Container(height: 1.h, width: double.infinity, color: const Color(0xFFE8E4DE)),
        if (vm.amountBelowMinimum)
          Padding(
            padding: EdgeInsets.only(top: 8.h),
            child: Text(
              AppConstants.minWithdrawalAmountMessage,
              style: TextStyle(fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,fontSize: 12.sp, fontWeight: FontWeight.w600, color: _errorRed),
            ),
          )
        else if (vm.amountAboveMaximum)
          Padding(
            padding: EdgeInsets.only(top: 8.h),
            child: Text(
              AppConstants.maxWithdrawalAmountMessage,
              style: TextStyle(fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,fontSize: 12.sp, fontWeight: FontWeight.w600, color: _errorRed),
            ),
          )
        else if (vm.amountExceedsBalance)
          Padding(
            padding: EdgeInsets.only(top: 8.h),
            child: Text(
              'Amount exceeds available balance',
              style: TextStyle(fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,fontSize: 12.sp, fontWeight: FontWeight.w600, color: _errorRed),
            ),
          ),
      ],
    );
  }

  // ── Percent row ───────────────────────────────────────────────────────────
  Widget _buildPercentRow(WithdrawalViewModel vm) {
    const options = ['25%', '50%', '75%', 'MAX'];
    const fractions = [0.25, 0.50, 0.75, 1.0];
    return Row(
      children: List.generate(options.length, (i) {
        final fraction = fractions[i];
        final targetVal = vm.availableBalance * fraction;
        final selected = vm.availableBalance > 0 &&
            (vm.amount - targetVal).abs() < 0.01 &&
            vm.amount > 0;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i == options.length - 1 ? 0 : 10),
            child: GestureDetector(
              onTap: () {
                _setPercentAmount(fraction, vm);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: EdgeInsets.symmetric(vertical: 12.h),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _white,
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(
                    color: selected ? _accentGreen : const Color(0xFFE8E4DE),
                    width: selected ? 2 : 1,
                  ),
                ),
                child: Text(
                  options[i],
                  style: TextStyle(fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                    fontSize: 13.5.sp, fontWeight: FontWeight.w700,
                    color: selected ? _brandGreen : _titleDark,
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  // ── Bank account section ──────────────────────────────────────────────────
  Widget _buildBankAccountSection(WithdrawalViewModel vm) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Destination Account',
          style: TextStyle(fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,fontSize: 15.5.sp, fontWeight: FontWeight.w800, color: _titleDark),
        ),
        SizedBox(height: 12.h),
        if (!vm.kycVerified)
          _buildKycWarning()
        else if (vm.bankDetail == null)
          _buildNoBankCard()
        else
          _buildBankCard(vm.bankDetail!),
      ],
    );
  }

  Widget _buildBankCard(KycBankDetail bank) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: _accentGreen, width: 2.r),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            width: 42.w, height: 42.h,
            decoration: BoxDecoration(
              color: const Color(0xFF1F2937),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Icon(Icons.account_balance, size: 20.sp, color: _white),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(bank.bankName,
                    style: TextStyle(fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,fontSize: 14.5.sp, fontWeight: FontWeight.w700, color: _titleDark)),
                SizedBox(height: 3.h),
                Text(
                  '${bank.accountType}  ${bank.maskedNumber}',
                  style: TextStyle(fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,fontSize: 12.5.sp, fontWeight: FontWeight.w400, color: _subtitleGrey),
                ),
                if (bank.ifsc.isNotEmpty)
                  Text(
                    'IFSC: ${bank.ifsc}',
                    style: TextStyle(fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,fontSize: 12.sp, fontWeight: FontWeight.w400, color: _labelGrey),
                  ),
              ],
            ),
          ),
          Container(
            width: 22.w, height: 22.h,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: _accentGreen, width: 2.r),
            ),
            child: Center(
              child: Container(
                width: 11.w, height: 11.h,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: _accentGreen),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKycWarning() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, size: 20.sp, color: _warningAmber),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              'KYC verification required. Please complete KYC to enable withdrawals.',
              style: TextStyle(fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,fontSize: 13.sp, fontWeight: FontWeight.w500, color: const Color(0xFF92400E), height: 1.45),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoBankCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: _infoBg,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: _infoBorder),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, size: 18.sp, color: _accentGreen),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              'No bank account found in your KYC. Please update your KYC details.',
              style: TextStyle(fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,fontSize: 13.sp, fontWeight: FontWeight.w500, color: _infoText, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }

  // ── Info card ─────────────────────────────────────────────────────────────
  Widget _buildFeeSummary(WithdrawalViewModel vm) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: const Color(0xFFE8E4DE)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Withdrawal summary', style: TextStyle(fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,fontSize: 13.5.sp, fontWeight: FontWeight.w700, color: _titleDark)),
          SizedBox(height: 12.h),
          _Row(label: 'Requested amount', value: '₹ ${_fmt(vm.amount)}'),
          SizedBox(height: 8.h),
          _Row(label: 'Platform fee + GST (2%)', value: '-₹ ${_fmt(vm.feeAmount)}', valueColor: _errorRed),
          SizedBox(height: 8.h),
          _Row(label: 'Amount you receive', value: '₹ ${_fmt(vm.netAmount)}', valueColor: _brandGreen, bold: true),
        ],
      ),
    );
  }

  Widget _buildInfoCard(WithdrawalViewModel vm) {
    final isWallet = vm.isWalletMode;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: _infoBg,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: _infoBorder, width: 1.r),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 18.sp, color: _accentGreen),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isWallet ? 'Bank transfer with 2% fee' : 'Admin Review Required',
                  style: TextStyle(fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,fontSize: 13.5.sp, fontWeight: FontWeight.w700, color: _titleDark),
                ),
                SizedBox(height: 4.h),
                Text(
                  isWallet
                      ? 'A platform fee + GST of 2% is charged on withdrawals. Your bank receives the net amount after fees.'
                      : 'Your withdrawal request is under admin review. The final amount is calculated after a 2% platform fee + GST deduction.',
                  style: TextStyle(fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,fontSize: 12.5.sp, fontWeight: FontWeight.w400, color: _infoText, height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Error banner ──────────────────────────────────────────────────────────
  Widget _buildErrorBanner(String message) {
    return Container(
      margin: EdgeInsets.only(top: 14.h),
      width: double.infinity,
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: _errorRed.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: _errorRed.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: _errorRed, size: 20.sp),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(message, style: TextStyle(fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,fontSize: 13.sp, fontWeight: FontWeight.w500, color: _errorRed)),
          ),
        ],
      ),
    );
  }

  // ── Submit action ─────────────────────────────────────────────────────────
  /// In-flow submit action — sits naturally at the end of the scrollable
  /// content (no longer pinned to the bottom of the screen) so it moves
  /// with the page and every section above it stays reachable while
  /// scrolling, on any screen size.
  Widget _buildSubmitAction(WithdrawalViewModel vm) {
    final isSubmitting = vm.state == WithdrawalState.submitting;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(height: 1, color: const Color(0xFFEFEBE4)),
        SizedBox(height: 20.h),
        AnimatedPrimaryButton(
          label: 'Request Withdrawal',
          height: 52.h,
          borderRadius: 30.r,
          color: _brandGreen,
          disabledColor: _brandGreen.withOpacity(0.45),
          textColor: _white,
          enabled: vm.canSubmit,
          loading: isSubmitting,
          onPressed: vm.canSubmit ? () => _submit(vm) : null,
          labelWidget: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Request Withdrawal',
                  style: TextStyle(fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,fontSize: 15.5.sp, fontWeight: FontWeight.w700, color: _white)),
              SizedBox(width: 8.w),
              Icon(Icons.arrow_forward, size: 18.sp, color: _white),
            ],
          ),
        ),
      ],
    );
  }

  String _fmt(double value) {
    final parts = value.toStringAsFixed(2).split('.');
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
}

// ── Success view ──────────────────────────────────────────────────────────────
class _SuccessView extends StatelessWidget {
  final WithdrawalViewModel vm;
  final VoidCallback onDone;
  const _SuccessView({required this.vm, required this.onDone});

  @override
  Widget build(BuildContext context) {
    final isWallet = vm.isWalletMode;
    final badgeLabel = isWallet ? 'COMPLETED' : 'PENDING';
    final badgeColor = isWallet ? _accentGreen : _warningAmber;
    final badgeBg = isWallet ? _greenInfoBg : const Color(0xFFFEF3C7);

    return Theme(
      data: ThemeData(brightness: Brightness.light, scaffoldBackgroundColor: _bg),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: Scaffold(
          backgroundColor: _bg,
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(8.w, 12.h, 20.w, 8.h),
                  child: Row(
                    children: [
                      SizedBox(width: 40.w),
                      Expanded(
                        child: Text(
                          'Withdrawal Receipt',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,fontSize: 18.sp, fontWeight: FontWeight.w700, color: _brandGreen),
                        ),
                      ),
                      SizedBox(width: 40.w),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 20.h),
                    child: Column(
                      children: [
                        // Success badge — pops in with overshoot to
                        // acknowledge the just-completed action.
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: 1),
                          duration: const Duration(milliseconds: 550),
                          curve: Curves.elasticOut,
                          builder: (context, scale, child) =>
                              Transform.scale(scale: scale, child: child),
                          child: Container(
                          width: 72.w, height: 72.h,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: isWallet
                                  ? [const Color(0xFF4CAF7D), const Color(0xFF4CAF7D)]
                                  : [const Color(0xFFF59E0B), const Color(0xFFD97706)],
                              begin: Alignment.topLeft, end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: (isWallet ? _accentGreen : _warningAmber).withOpacity(0.35),
                                blurRadius: 18, offset: const Offset(0, 6),
                              )
                            ],
                          ),
                          child: Icon(
                            isWallet ? Icons.check_rounded : Icons.hourglass_top_rounded,
                            color: _white, size: 36.sp,
                          ),
                          ),
                        ),
                        SizedBox(height: 14.h),
                        StaggeredEntrance(
                          index: 0,
                          baseDelay: const Duration(milliseconds: 250),
                          child: Text(
                          isWallet ? 'Withdrawal Initiated!' : 'Request Submitted!',
                          style: TextStyle(fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,fontSize: 22.sp, fontWeight: FontWeight.w800, color: _titleDark),
                          ),
                        ),
                        SizedBox(height: 6.h),
                        Text(
                          isWallet
                              ? 'Your funds are being transferred to\nyour registered bank account.'
                              : 'Your request is pending admin approval.\nFunds will appear in your main wallet shortly.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,fontSize: 13.5.sp, fontWeight: FontWeight.w400, color: _subtitleGrey, height: 1.5),
                        ),
                        SizedBox(height: 28.h),

                        // Invoice card
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(20.w),
                          decoration: BoxDecoration(
                            color: _white,
                            borderRadius: BorderRadius.circular(20.r),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 14, offset: const Offset(0, 4))],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('TRANSACTION DETAILS',
                                  style: TextStyle(fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,fontSize: 11.sp, fontWeight: FontWeight.w700, color: _labelGrey, letterSpacing: 1.1)),
                              SizedBox(height: 16.h),
                              // Status badge
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Status', style: TextStyle(fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,fontSize: 13.5.sp, fontWeight: FontWeight.w400, color: _subtitleGrey)),
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                                    decoration: BoxDecoration(
                                      color: badgeBg,
                                      borderRadius: BorderRadius.circular(20.r),
                                    ),
                                    child: Text(badgeLabel,
                                        style: TextStyle(fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,fontSize: 12.sp, fontWeight: FontWeight.w800, color: badgeColor, letterSpacing: 0.5)),
                                  ),
                                ],
                              ),
                              _divider(),
                              _Row(label: 'Type', value: isWallet ? 'Wallet Withdrawal' : 'Capital Withdrawal'),
                              _divider(),
                              _Row(label: 'Requested amount', value: '₹ ${_fmtInv(vm.amount)}'),
                              SizedBox(height: 10.h),
                              _Row(label: 'Fee + GST (2%)', value: '-₹ ${_fmtInv(vm.feeAmount)}', valueColor: _errorRed),
                              SizedBox(height: 10.h),
                              _Row(label: 'Net amount', value: '₹ ${_fmtInv(vm.netAmount)}', bold: true, valueColor: _brandGreen),
                              if (isWallet && vm.completedReferenceId != null && vm.completedReferenceId!.isNotEmpty) ...[
                                _divider(),
                                _Row(label: 'Reference ID', value: vm.completedReferenceId!, bold: true, valueColor: _brandGreen),
                              ],
                              if (vm.completedMessage != null && vm.completedMessage!.isNotEmpty) ...[
                                _divider(),
                                _Row(label: 'Message', value: vm.completedMessage!),
                              ],
                            ],
                          ),
                        ),
                        SizedBox(height: 20.h),

                        // Note
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(14.w),
                          decoration: BoxDecoration(
                            color: _infoBg,
                            borderRadius: BorderRadius.circular(14.r),
                            border: Border.all(color: _infoBorder),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.info_outline_rounded, size: 18.sp, color: _accentGreen),
                              SizedBox(width: 10.w),
                              Expanded(
                                child: Text(
                                  isWallet
                                      ? 'Please save your Reference ID. Contact support if the amount is not credited within 2 business days.'
                                      : 'Your request has been submitted. Admin approval typically takes 1–2 business days.',
                                  style: TextStyle(fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,fontSize: 12.5.sp, fontWeight: FontWeight.w400, color: _infoText, height: 1.45),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Done button
                Container(
                  padding: EdgeInsets.fromLTRB(20.w, 14.h, 20.w, 14.h),
                  decoration: BoxDecoration(
                    color: _white,
                    borderRadius: BorderRadius.only(topLeft: Radius.circular(24.r), topRight: Radius.circular(24.r)),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, -4))],
                  ),
                  child: SafeArea(
                    top: false,
                    child: SizedBox(
                      width: double.infinity, height: 52.h,
                      child: AnimatedPrimaryButton(
                        label: 'Done',
                        onPressed: onDone,
                        color: _brandGreen,
                        textColor: _white,
                        height: 52.h,
                        borderRadius: 30.r,
                        textStyle: TextStyle(fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,fontSize: 15.5.sp, fontWeight: FontWeight.w700, color: _white),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _divider() => Padding(
    padding: EdgeInsets.symmetric(vertical: 12.h),
    child: Divider(color: Color(0xFFF3F4F6), height: 1.h),
  );

  String _fmtInv(double value) {
    final parts = value.toStringAsFixed(2).split('.');
    final intPart = parts[0];
    final buf = StringBuffer();
    final len = intPart.length;
    for (int i = 0; i < len; i++) {
      final pos = len - i;
      buf.write(intPart[i]);
      if (pos > 3 && (pos - 3) % 2 == 0) buf.write(',');
    }
    return '${buf.toString()}.${parts[1]}';
  }
}

/// Shows an active withdrawal request that is still under admin review.
class _PendingWithdrawalBlocker extends StatelessWidget {
  final WithdrawRecord record;
  final VoidCallback onRefresh;
  final bool isRefreshing;

  const _PendingWithdrawalBlocker({
    required this.record,
    required this.onRefresh,
    required this.isRefreshing,
  });

  String _fmtAmount(double value) {
    final parts = value.toStringAsFixed(2).split('.');
    final intPart = parts[0];
    final buf = StringBuffer();
    final len = intPart.length;
    for (int i = 0; i < len; i++) {
      final pos = len - i;
      buf.write(intPart[i]);
      if (pos > 3 && (pos - 3) % 2 == 0) buf.write(',');
    }
    return buf.toString();
  }

  String _fmtDate(DateTime? dt) {
    if (dt == null) return '—';
    return '${dt.day.toString().padLeft(2, '0')} '
        '${['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][dt.month - 1]} '
        '${dt.year}, ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData(brightness: Brightness.light, scaffoldBackgroundColor: _bg),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: Scaffold(
          backgroundColor: _bg,
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(8.w, 12.h, 12.w, 8.h),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Padding(
                          padding: EdgeInsets.all(8.w),
                          child: Icon(Icons.arrow_back, color: _brandGreen, size: 24.sp),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'Withdrawal Request',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,fontSize: 18.sp, fontWeight: FontWeight.w700, color: _brandGreen),
                        ),
                      ),
                      SizedBox(width: 40.w),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 24.h),
                    child: Column(
                      children: [
                        Container(
                          width: 80.w, height: 80.h,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _warningAmber.withOpacity(0.15),
                            border: Border.all(color: _warningAmber.withOpacity(0.3), width: 2.r),
                          ),
                          child: Icon(Icons.hourglass_top_rounded, color: _warningAmber, size: 38.sp),
                        ),
                        SizedBox(height: 16.h),
                        Text('Withdrawal Under Review',
                            style: TextStyle(fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,fontSize: 22.sp, fontWeight: FontWeight.w800, color: _titleDark)),
                        SizedBox(height: 8.h),
                        Text(
                          'Your withdrawal request is being reviewed by our admin team. Please wait for approval or rejection.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,fontSize: 13.5.sp, fontWeight: FontWeight.w400, color: _subtitleGrey, height: 1.55),
                        ),
                        SizedBox(height: 28.h),
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(20.w),
                          decoration: BoxDecoration(
                            color: _white,
                            borderRadius: BorderRadius.circular(20.r),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 14, offset: const Offset(0, 4))],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('REQUEST DETAILS',
                                      style: TextStyle(fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,fontSize: 11.sp, fontWeight: FontWeight.w700, color: _labelGrey, letterSpacing: 1.1)),
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                                    decoration: BoxDecoration(
                                      color: _warningAmber.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(20.r),
                                    ),
                                    child: Text('Under Review',
                                        style: TextStyle(fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,fontSize: 11.5.sp, fontWeight: FontWeight.w700, color: _warningAmber)),
                                  ),
                                ],
                              ),
                              SizedBox(height: 16.h),
                              _Row(label: 'Amount', value: '₹ ${_fmtAmount(record.amount)}', bold: true, valueColor: _titleDark),
                              SizedBox(height: 12.h),
                              _Row(label: 'Requested At', value: _fmtDate(record.createdAt)),
                              SizedBox(height: 12.h),
                              _Row(label: 'Reference ID', value: record.referenceId.isNotEmpty ? record.referenceId : '—'),
                              SizedBox(height: 12.h),
                              _Row(label: 'Admin remarks', value: record.adminRemarks.isNotEmpty ? record.adminRemarks : 'No remarks yet'),
                            ],
                          ),
                        ),
                        SizedBox(height: 20.h),
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(14.w),
                          decoration: BoxDecoration(
                            color: _infoBg,
                            borderRadius: BorderRadius.circular(14.r),
                            border: Border.all(color: _infoBorder),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.info_outline_rounded, size: 18.sp, color: _accentGreen),
                              SizedBox(width: 10.w),
                              Expanded(
                                child: Text(
                                  'Only one withdrawal request can be active at a time. Admin approval may take 1–2 business days.',
                                  style: TextStyle(fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,fontSize: 12.5.sp, fontWeight: FontWeight.w400, color: _infoText, height: 1.45),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.fromLTRB(20.w, 14.h, 20.w, 14.h),
                  decoration: BoxDecoration(
                    color: _white,
                    borderRadius: BorderRadius.only(topLeft: Radius.circular(24.r), topRight: Radius.circular(24.r)),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, -4))],
                  ),
                  child: SafeArea(
                    top: false,
                    child: SizedBox(
                      width: double.infinity, height: 52.h,
                      child: ElevatedButton.icon(
                        onPressed: isRefreshing ? null : onRefresh,
                        icon: isRefreshing
                            ? SizedBox(width: 18.w, height: 18.h, child: CircularProgressIndicator(strokeWidth: 2.2, color: _white))
                            : Icon(Icons.refresh_rounded, size: 20.sp, color: _white),
                        label: Text(
                          isRefreshing ? 'Checking…' : 'Refresh Status',
                          style: TextStyle(fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,fontSize: 15.5.sp, fontWeight: FontWeight.w700, color: _white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _brandGreen,
                          disabledBackgroundColor: _brandGreen.withOpacity(0.6),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30.r)),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label, value;
  final Color? valueColor;
  final bool bold;
  const _Row({required this.label, required this.value, this.valueColor, this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,fontSize: 13.5.sp, fontWeight: FontWeight.w400, color: _subtitleGrey)),
        SizedBox(width: 16.w),
        Flexible(
          child: Text(value, textAlign: TextAlign.right,
              style: TextStyle(fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,fontSize: 13.5.sp, fontWeight: bold ? FontWeight.w700 : FontWeight.w500, color: valueColor ?? _titleDark)),
        ),
      ],
    );
  }
}

// ── Withdrawal PIN entry sheet ─────────────────────────────────────────────
// Shown right before a withdrawal request is submitted. Pops `true` once the
// withdrawal PIN (set in Security Settings) is entered correctly, `false`/
// null if the user backs out.
class _WithdrawalPinEntrySheet extends StatefulWidget {
  const _WithdrawalPinEntrySheet();

  @override
  State<_WithdrawalPinEntrySheet> createState() =>
      _WithdrawalPinEntrySheetState();
}

class _WithdrawalPinEntrySheetState extends State<_WithdrawalPinEntrySheet> {
  static const int _pinLength = 4;
  // Own lockout scope so a withdrawal-PIN lockout never blocks the app-lock
  // login PIN (or vice versa) — see PinLockoutService.
  static const String _lockScope = 'withdrawal';

  final List<int> _pin = [];
  String? _error;
  bool _verifying = false;
  bool _locked = false;
  Duration _lockRemaining = Duration.zero;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _checkLockout();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkLockout() async {
    final until = await PinLockoutService.getLockedUntil(_lockScope);
    if (!mounted || until == null) return;
    _beginCountdown(until);
  }

  void _beginCountdown(DateTime until) {
    _countdownTimer?.cancel();
    setState(() {
      _locked = true;
      _lockRemaining = until.difference(DateTime.now());
      _error =
          'Too many attempts. Try again in ${PinLockoutService.formatCountdown(_lockRemaining)}.';
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      final remaining = until.difference(DateTime.now());
      if (!mounted) return;

      if (remaining <= Duration.zero) {
        timer.cancel();
        await PinLockoutService.reset(_lockScope);
        if (!mounted) return;
        setState(() {
          _locked = false;
          _lockRemaining = Duration.zero;
          _error = null;
        });
        return;
      }

      setState(() {
        _lockRemaining = remaining;
        _error =
            'Too many attempts. Try again in ${PinLockoutService.formatCountdown(remaining)}.';
      });
    });
  }

  void _onKey(int digit) {
    if (_verifying || _locked || _pin.length >= _pinLength) return;
    setState(() {
      _pin.add(digit);
      _error = null;
    });
    if (_pin.length == _pinLength) {
      Future.delayed(const Duration(milliseconds: 120), _verify);
    }
  }

  void _onDelete() {
    if (_verifying || _locked || _pin.isEmpty) return;
    setState(() {
      _pin.removeLast();
      _error = null;
    });
  }

  Future<void> _verify() async {
    // Safety net in case a lockout kicked in elsewhere while this sheet was
    // already open.
    final activeLockUntil = await PinLockoutService.getLockedUntil(_lockScope);
    if (activeLockUntil != null) {
      if (!mounted) return;
      setState(() => _pin.clear());
      _beginCountdown(activeLockUntil);
      return;
    }

    setState(() => _verifying = true);
    final ok = await SecurityViewModel.verifyWithdrawalPin(_pin.join());
    if (!mounted) return;

    if (ok) {
      await PinLockoutService.reset(_lockScope);
      if (!mounted) return;
      Navigator.pop(context, true);
    } else {
      final lockUntil = await PinLockoutService.registerFailedAttempt(_lockScope);
      if (!mounted) return;

      if (lockUntil != null) {
        setState(() {
          _verifying = false;
          _pin.clear();
        });
        _beginCountdown(lockUntil);
      } else {
        final attempts = await PinLockoutService.getAttempts(_lockScope);
        final remaining = PinLockoutService.remainingAttempts(attempts);
        if (!mounted) return;
        setState(() {
          _verifying = false;
          _error =
              'Incorrect PIN. $remaining attempt${remaining == 1 ? '' : 's'} left.';
          _pin.clear();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(24.r), topRight: Radius.circular(24.r)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(24.w, 12.h, 24.w, 24.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40.w, height: 4.h,
                margin: EdgeInsets.only(bottom: 20.h),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8E4DE),
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
              Container(
                width: 56.w, height: 56.h,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFE8F5EE),
                ),
                child: Icon(Icons.password_rounded, color: _brandGreen, size: 26.sp),
              ),
              SizedBox(height: 14.h),
              Text(
                'Enter Withdrawal PIN',
                style: TextStyle(fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,fontSize: 18.sp, fontWeight: FontWeight.w800, color: _titleDark),
              ),
              SizedBox(height: 6.h),
              Text(
                'Confirm your 4-digit PIN to submit this withdrawal request.',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,fontSize: 13.sp, fontWeight: FontWeight.w400, color: _subtitleGrey, height: 1.4),
              ),
              SizedBox(height: 24.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_pinLength, (i) {
                  final filled = i < _pin.length;
                  return Container(
                    margin: EdgeInsets.symmetric(horizontal: 10.w),
                    width: 16.w,
                    height: 16.h,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: filled ? _brandGreen : Colors.transparent,
                      border: Border.all(
                        color: _error != null
                            ? _errorRed
                            : (filled ? _brandGreen : const Color(0xFFD9D5CF)),
                        width: 2.r,
                      ),
                    ),
                  );
                }),
              ),
              SizedBox(height: 14.h),
              SizedBox(
                height: 20.h,
                child: AnimatedOpacity(
                  opacity: _error != null ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    _error ?? '',
                    style: TextStyle(fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,fontSize: 12.5.sp, fontWeight: FontWeight.w600, color: _errorRed),
                  ),
                ),
              ),
              SizedBox(height: 16.h),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.w),
                child: Column(
                  children: [
                    _PinKeyRow(keys: const [1, 2, 3], onKey: _onKey, enabled: !_verifying && !_locked),
                    SizedBox(height: 12.h),
                    _PinKeyRow(keys: const [4, 5, 6], onKey: _onKey, enabled: !_verifying && !_locked),
                    SizedBox(height: 12.h),
                    _PinKeyRow(keys: const [7, 8, 9], onKey: _onKey, enabled: !_verifying && !_locked),
                    SizedBox(height: 12.h),
                    Row(
                      children: [
                        const Expanded(child: SizedBox()),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: _PinKeyButton(
                            onTap: (_verifying || _locked) ? null : () => _onKey(0),
                            child: Text('0',
                                style: TextStyle(fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                                    fontSize: 22.sp, fontWeight: FontWeight.w600, color: _titleDark)),
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: _PinKeyButton(
                            onTap: (_verifying || _locked) ? null : _onDelete,
                            child: _verifying
                                ? SizedBox(
                                    width: 18.w, height: 18.h,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: _brandGreen),
                                  )
                                : Icon(Icons.backspace_outlined, size: 20.sp, color: _titleDark),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: 8.h),
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancel',
                    style: TextStyle(fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,fontSize: 13.5.sp, fontWeight: FontWeight.w600, color: _subtitleGrey)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PinKeyRow extends StatelessWidget {
  final List<int> keys;
  final ValueChanged<int> onKey;
  final bool enabled;
  const _PinKeyRow({required this.keys, required this.onKey, this.enabled = true});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: keys
          .expand((k) => [
                Expanded(
                  child: _PinKeyButton(
                    onTap: enabled ? () => onKey(k) : null,
                    child: Text('$k',
                        style: TextStyle(fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                            fontSize: 22.sp, fontWeight: FontWeight.w600, color: _titleDark)),
                  ),
                ),
                if (k != keys.last) SizedBox(width: 12.w),
              ])
          .toList(),
    );
  }
}

class _PinKeyButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  const _PinKeyButton({required this.child, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58.h,
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14.r),
        child: InkWell(
          borderRadius: BorderRadius.circular(14.r),
          onTap: onTap,
          child: Center(child: child),
        ),
      ),
    );
  }
}