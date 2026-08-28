import 'package:flutter/material.dart';
import 'package:moneytries/config/app_fonts.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../config/app_constants.dart';
import '../../models/plan/plan_models.dart';
import '../../routes/app_routes.dart';
import '../../viewmodels/plan/plan_viewmodel.dart';
import '../../utils/responsive.dart';
import '../../widgets/premium/premium_keypad_key.dart';

const _bg = Color(0xFFF4F6F4);
const _white = Color(0xFFFFFFFF);
const _dark = Color(0xFF0D1F14);
const _green = Color(0xFF1F6B45); // banner dark green
const _greenMid = Color(0xFF9AE0BC); // banner gradient end
const _grey = Color(0xFF6B7280);
const _greyL = Color(0xFF9CA3AF);
const _red = Color(0xFFDC2626);

const _heroGrad = LinearGradient(
  colors: [Color(0xFFDCF3E5), Color(0xFF9AE0BC)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

class ConfigureInvestmentScreen extends StatefulWidget {
  const ConfigureInvestmentScreen({super.key});
  @override
  State<ConfigureInvestmentScreen> createState() =>
      _ConfigureInvestmentScreenState();
}

class _ConfigureInvestmentScreenState extends State<ConfigureInvestmentScreen>
    with SingleTickerProviderStateMixin {
  String _amountText = '';
  static const _maxDigits = 8;

  // Payment phase: false = amount entry, true = wallet confirm-and-pay
  // phase. Investment plans are now funded ONLY from the user's wallet
  // balance — UPI / bank-transfer + payment-screenshot + UTR has been
  // removed entirely.
  bool _paymentPhase = false;
  bool _submitting = false;

  late final AnimationController _cursorCtrl;

  @override
  void initState() {
    super.initState();
    _cursorCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 530),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Redesigned flow: the amount is now chosen earlier, on the Plan
      // Comparison screen, and passed through Terms into this screen's
      // route arguments. Prefill it here so the user doesn't have to
      // re-type it — the keypad below still works exactly as before if
      // they want to adjust it, and every downstream submit/enroll call
      // continues to read from `_amount` as it always has.
      final presetAmount = _args['amount'] as int?;
      if (mounted &&
          presetAmount != null &&
          presetAmount > 0 &&
          _amountText.isEmpty) {
        setState(() => _amountText = presetAmount.toString());
      }
      // Fetch the real wallet balance up front so the confirm sheet /
      // wallet phase can show an accurate figure and gate submission
      // without waiting on a round trip once the user taps through.
      if (mounted) {
        context.read<PlanViewModel>().loadWalletBalance();
      }
    });
  }

  @override
  void dispose() {
    _cursorCtrl.dispose();
    super.dispose();
  }

  Map<String, dynamic> get _args =>
      (ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?) ??
      {};

  int get _months => (_args['months'] as int?) ?? 6;
  String get _rate => (_args['rate'] as String?) ?? '0.40%';
  String get _planTitle => (_args['title'] as String?) ?? '6 Month Plan';

  /// Prefers the explicit `planType` name passed from the comparison
  /// screen (robust for Pre Plan, which has no month count) and falls back
  /// to the original months-based resolution for backward compatibility.
  PlanType get _planType {
    final rawName = _args['planType'] as String?;
    if (rawName != null) {
      return PlanType.values.firstWhere(
        (t) => t.name == rawName,
        orElse: () => PlanTypeExt.fromMonths(_months),
      );
    }
    return PlanTypeExt.fromMonths(_months);
  }

  bool get _isPrePlan => _planType == PlanType.prePlan;
  /// Pre Plan's duration in days, as chosen by the user on the comparison
  /// screen's +/- day selector and carried through via route arguments.
  /// Only meaningful when [_isPrePlan] is true.
  int get _days => (_args['days'] as int?) ?? PlanType.prePlan.durationDays;

  int get _amount => int.tryParse(_amountText.isEmpty ? '0' : _amountText) ?? 0;
  bool get _underMin => _amount > 0 && _amount < AppConstants.minPlanAmount;
  bool get _overMax => _amount > AppConstants.maxTransactionAmount;
  bool get _hasAmount =>
      _amountText.isNotEmpty && _amount >= AppConstants.minPlanAmount && !_overMax;

  String _inr(int n) {
    if (n <= 0) return '0';
    final s = n.toString();
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

  String _inrDouble(double n) => _inr(n.round());

  // Sound + haptic feedback for each tap now lives in PremiumKeypadKey
  // (fired before this handler runs), so this only mutates the amount.
  void _onKeyTap(String key) {
    setState(() {
      if (key == 'back') {
        if (_amountText.isNotEmpty) {
          _amountText = _amountText.substring(0, _amountText.length - 1);
        }
      } else {
        if (_amountText.length >= _maxDigits) return;
        if (_amountText == '0') {
          _amountText = key;
        } else {
          _amountText += key;
        }
      }
    });
  }

  // ── Submit: locks the amount from the wallet balance and submits the
  // plan through the existing admin approval flow. ──────────────────────────
  Future<void> _submitWalletPayment() async {
    final vm = context.read<PlanViewModel>();
    if (!vm.hasSufficientBalance(_amount)) {
      _toast('Insufficient wallet balance');
      return;
    }
    setState(() => _submitting = true);
    await vm.enrollPlan(
      planType: _planType,
      monthlyAmount: _amount,
      durationDays: _isPrePlan ? _days : null,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (vm.enrollState == PlanVmState.success) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.activePlan,
        (r) => r.settings.name == AppRoutes.plan || r.isFirst,
        arguments: {'plan': vm.enrolledPlan},
      );
    } else {
      _toast(vm.enrollError ?? 'Submission failed. Please try again.');
    }
  }

  // Handles the "Add Money" tap from the insufficient-wallet-balance dialog.
  // Deposit no longer requires KYC approval — open it directly, no gate,
  // no "Complete KYC" prompt. (Plan viewing/purchase itself never required
  // KYC either.)
  Future<void> _onAddMoneyFromInsufficientDialog() async {
    if (!mounted) return;
    Navigator.pushNamed(context, AppRoutes.deposit);
  }

  // Blocking warning dialog shown when the entered amount is higher than
  // the user's available wallet balance at the moment they tap
  // "Proceed to Pay". Keeps the user on the amount/confirm step instead of
  // silently letting them fall through to the payment phase.
  void _showInsufficientBalanceWarning(int amount, double walletBalance) {
    final shortfall = (amount - walletBalance).clamp(0, double.infinity);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18.r),
        ),
        title: Row(
          children: [
            Icon(Icons.error_outline, size: 22.sp, color: _red),
            SizedBox(width: 8.w),
            Expanded(
              child: Text(
                'Insufficient Wallet Balance',
                style: TextStyle(
                  fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w700,
                  color: _dark,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'The amount you entered (₹ ${_inr(amount)}) is higher than your '
          'available wallet balance (₹ ${_inrDouble(walletBalance)}). '
          'You need ₹ ${_inrDouble(shortfall.toDouble())} more to proceed '
          'with this payment.',
          style: TextStyle(
            fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
            fontSize: 13.5.sp,
            color: _grey,
            height: 1.4,
          ),
        ),
        actionsPadding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 12.h),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Edit Amount',
              style: TextStyle(
                fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                fontSize: 13.5.sp,
                fontWeight: FontWeight.w600,
                color: _grey,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _onAddMoneyFromInsufficientDialog();
            },
            child: Text(
              'Add Money',
              style: TextStyle(
                fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                fontSize: 13.5.sp,
                fontWeight: FontWeight.w700,
                color: _green,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: TextStyle(
            fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
            fontSize: 13.sp,
            color: const Color(0xFF111827),
          ),
        ),
        backgroundColor: Colors.white,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
        ),
        elevation: 6,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    final botPad = MediaQuery.of(context).padding.bottom;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _bg,
        body: _paymentPhase
            ? _buildWalletPaymentPhase(topPad, botPad)
            : _buildAmountPhase(topPad, botPad),
      ),
    );
  }

  // ── Phase 1: Amount Entry ─────────────────────────────────────────────────
  Widget _buildAmountPhase(double topPad, double botPad) {
    final total = _amount;
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: EdgeInsets.fromLTRB(20.w, topPad + 12.h, 20.w, 24.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Icon(
                          Icons.arrow_back,
                          size: 22.sp,
                          color: _dark,
                        ),
                      ),
                      SizedBox(width: 14.w),
                      Expanded(
                        child: Text(
                          'Moneytries',
                          style: TextStyle(
                            fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w700,
                            color: _dark,
                          ),
                        ),
                      ),
                      _walletRefreshButton(),
                    ],
                  ),
                  SizedBox(height: 24.h),
                  Center(
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 14.w,
                        vertical: 5.h,
                      ),
                      decoration: BoxDecoration(
                        color: _greenMid,
                        borderRadius: BorderRadius.circular(20.r),
                      ),
                      child: Text(
                        'Configure Plan',
                        style: TextStyle(
                          fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w500,
                          color: _green,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 10.h),
                  Center(
                    child: Text(
                      _planTitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                        fontSize: 22.sp,
                        fontWeight: FontWeight.w800,
                        color: _dark,
                      ),
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Center(
                    child: Text(
                      _isPrePlan
                          ? '$_rate Daily ROI · $_days Days'
                          : '$_rate Daily ROI · $_months Months',
                      style: TextStyle(
                        fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                        fontSize: 13.sp,
                        color: _grey,
                      ),
                    ),
                  ),
                  SizedBox(height: 16.h),
                  Center(child: _walletBalancePill()),
                  SizedBox(height: 28.h),
                  _buildAmountDisplay(),
                ],
              ),
            ),
          ),
        ),
        Container(
          color: _bg,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.w),
                child: Column(
                  children: [
                    _keypadRow(['1', '2', '3']),
                    _keypadRow(['4', '5', '6']),
                    _keypadRow(['7', '8', '9']),
                    _keypadRow(['', '0', 'back']),
                  ],
                ),
              ),
              SizedBox(height: 14.h),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  0,
                  20,
                  botPad > 0 ? botPad : 20,
                ),
                child: AnimatedOpacity(
                  opacity: _hasAmount ? 1.0 : 0.45,
                  duration: const Duration(milliseconds: 200),
                  child: GestureDetector(
                    onTap: _hasAmount
                        ? () => _showConfirmSheet(_amount, total)
                        : null,
                    child: Container(
                      width: double.infinity,
                      height: 56.h,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFDCF3E5), Color(0xFF9AE0BC)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(28.r),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF9AE0BC,
                            ).withValues(alpha: 0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Confirm & Proceed to Pay',
                            style: TextStyle(
                              fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w700,
                              color: _green,
                            ),
                          ),
                          SizedBox(width: 10.w),
                          Icon(Icons.arrow_forward, size: 18.sp, color: _white),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Wallet balance refresh button (top-right of header) ───────────────────
  // Re-fetches the real wallet balance from the backend on tap, so the user
  // can confirm the figure is current right before confirming the plan
  // (e.g. after just adding money via Deposit).
  Widget _walletRefreshButton() {
    return Consumer<PlanViewModel>(
      builder: (context, vm, _) {
        return GestureDetector(
          onTap: vm.walletBalanceLoading
              ? null
              : () async {
                  await vm.loadWalletBalance();
                  if (!mounted) return;
                  _toast('Wallet balance updated');
                },
          child: Container(
            width: 36.w,
            height: 36.h,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: vm.walletBalanceLoading
                ? SizedBox(
                    width: 16.w,
                    height: 16.h,
                    child: CircularProgressIndicator(
                      color: _green,
                      strokeWidth: 2,
                    ),
                  )
                : Icon(Icons.refresh_rounded, size: 18.sp, color: _green),
          ),
        );
      },
    );
  }

  // Small pill showing the live wallet balance underneath the plan title,
  // so the user knows upfront whether they can afford this plan.
  Widget _walletBalancePill() {
    return Consumer<PlanViewModel>(
      builder: (context, vm, _) {
        final insufficient = _amount > 0 && !vm.hasSufficientBalance(_amount);
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
          decoration: BoxDecoration(
            color: insufficient ? const Color(0xFFFDECEC) : const Color(0xFFF0FAF4),
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(
              color: insufficient ? _red.withValues(alpha: 0.3) : const Color(0xFF9FDAB9),
              width: 1.r,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.account_balance_wallet_outlined,
                size: 14.sp,
                color: insufficient ? _red : _green,
              ),
              SizedBox(width: 6.w),
              Text(
                vm.walletBalanceLoading
                    ? 'Loading wallet balance…'
                    : 'Wallet Balance: ₹${_inrDouble(vm.walletBalance)}',
                style: TextStyle(
                  fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: insufficient ? _red : _green,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAmountDisplay() {
    return AnimatedBuilder(
      animation: _cursorCtrl,
      builder: (_, __) {
        return Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: 28.h, horizontal: 20.w),
          decoration: BoxDecoration(
            color: _white,
            borderRadius: BorderRadius.circular(18.r),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            children: [
              Text(
                'Investment Amount (One-Time)',
                style: TextStyle(
                  fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                  fontSize: 12.sp,
                  color: _greyL,
                  letterSpacing: 0.3,
                ),
              ),
              SizedBox(height: 12.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '₹',
                    style: TextStyle(
                      fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                      fontSize: 28.sp,
                      fontWeight: FontWeight.w600,
                      color: _grey,
                    ),
                  ),
                  SizedBox(width: 4.w),
                  Text(
                    _amountText.isEmpty ? '0' : _inr(_amount),
                    style: TextStyle(
                      fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                      fontSize: 40.sp,
                      fontWeight: FontWeight.w800,
                      color: _dark,
                    ),
                  ),
                  AnimatedOpacity(
                    opacity: _cursorCtrl.value,
                    duration: Duration.zero,
                    child: Container(
                      width: 2.w,
                      height: 40.h,
                      margin: EdgeInsets.only(left: 3.w),
                      color: _green,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 6.h),
              Text(
                _underMin
                    ? AppConstants.minPlanAmountMessage
                    : _overMax
                        ? AppConstants.maxTransactionAmountMessage
                        : 'Paid once — principal is locked until maturity',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                  fontSize: 12.sp,
                  fontWeight: (_underMin || _overMax) ? FontWeight.w600 : FontWeight.normal,
                  color: (_underMin || _overMax) ? const Color(0xFFDC2626) : _greyL,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Confirm Sheet → Wallet Payment ─────────────────────────────────────────
  void _showConfirmSheet(int amount, int total) {
    final vm = context.read<PlanViewModel>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final bp = MediaQuery.of(ctx).padding.bottom;
        return Container(
          decoration: BoxDecoration(
            color: _white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
          ),
          padding: EdgeInsets.fromLTRB(24.w, 20.h, 24.w, 16.h + bp),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0E0E0),
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                ),
              ),
              SizedBox(height: 20.h),
              Text(
                'Confirm Investment Plan',
                style: TextStyle(
                  fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w700,
                  color: _dark,
                ),
              ),
              SizedBox(height: 6.h),
              Text(
                'This is a one-time payment — the amount is fixed.',
                style: TextStyle(
                  fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                  fontSize: 13.sp,
                  color: _grey,
                ),
              ),
              SizedBox(height: 20.h),
              _confirmRow('Selected Plan', _planTitle),
              SizedBox(height: 12.h),
              _confirmRow('Investment Amount', '₹ ${_inr(amount)}'),
              SizedBox(height: 12.h),
              _confirmRow('Daily ROI', _rate),
              SizedBox(height: 12.h),
              _confirmRow(
                'Duration',
                _isPrePlan ? '$_days days' : '$_months months',
              ),
              SizedBox(height: 12.h),
              _confirmRow('Principal', 'Locked until maturity'),
              SizedBox(height: 12.h),
              _confirmRow('Pay From', 'Wallet Balance'),
              SizedBox(height: 24.h),
              GestureDetector(
                onTap: () {
                  if (!vm.hasSufficientBalance(amount)) {
                    Navigator.pop(ctx);
                    _showInsufficientBalanceWarning(amount, vm.walletBalance);
                    return;
                  }
                  Navigator.pop(ctx);
                  setState(() => _paymentPhase = true);
                },
                child: Container(
                  width: double.infinity,
                  height: 54.h,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFDCF3E5), Color(0xFF9AE0BC)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(28.r),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF9AE0BC).withValues(alpha: 0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      'Proceed to Pay',
                      style: TextStyle(
                        fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w700,
                        color: _green,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Phase 2: Wallet Payment (confirm & pay from wallet balance) ───────────
  Widget _buildWalletPaymentPhase(double topPad, double botPad) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.fromLTRB(20.w, topPad + 12.h, 20.w, 16.h),
          color: _bg,
          child: Row(
            children: [
              GestureDetector(
                onTap: () => setState(() => _paymentPhase = false),
                child: Icon(Icons.arrow_back, size: 22.sp, color: _dark),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Text(
                  'Confirm Payment',
                  style: TextStyle(
                    fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w700,
                    color: _dark,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: Consumer<PlanViewModel>(
              builder: (context, vm, _) {
                final insufficient = !vm.hasSufficientBalance(_amount);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(20.w),
                      decoration: BoxDecoration(
                        gradient: _heroGrad,
                        borderRadius: BorderRadius.circular(18.r),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF9AE0BC).withValues(alpha: 0.4),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'One-Time Investment',
                                style: TextStyle(
                                  fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                                  fontSize: 12.sp,
                                  color: _green.withValues(alpha: 0.75),
                                ),
                              ),
                              SizedBox(height: 4.h),
                              Text(
                                '₹ ${_inr(_amount)}',
                                style: TextStyle(
                                  fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                                  fontSize: 28.sp,
                                  fontWeight: FontWeight.w800,
                                  color: _dark,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                _planTitle,
                                style: TextStyle(
                                  fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w600,
                                  color: _green,
                                ),
                              ),
                              Text(
                                '$_rate Daily ROI',
                                style: TextStyle(
                                  fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                                  fontSize: 12.sp,
                                  color: _green.withValues(alpha: 0.75),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 20.h),
                    _WalletPaymentCard(
                      amount: _amount,
                      walletBalance: vm.walletBalance,
                      loading: vm.walletBalanceLoading,
                      insufficient: insufficient,
                      inr: _inr,
                      inrDouble: _inrDouble,
                    ),
                    if (insufficient) ...[
                      SizedBox(height: 16.h),
                      _insufficientBalanceBanner(),
                    ],
                    SizedBox(height: 32.h),
                  ],
                );
              },
            ),
          ),
        ),
        Container(
          color: _bg,
          padding: EdgeInsets.fromLTRB(
            20.w,
            12.h,
            20.w,
            botPad > 0 ? botPad : 20.h,
          ),
          child: Consumer<PlanViewModel>(
            builder: (context, vm, _) {
              final insufficient = !vm.hasSufficientBalance(_amount);
              final disabled = insufficient || _submitting;
              if (_submitting) {
                return Container(
                  width: double.infinity,
                  height: 56.h,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFFDCF3E5).withValues(alpha: 0.6),
                        const Color(0xFF9AE0BC).withValues(alpha: 0.6),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(28.r),
                  ),
                  child: Center(
                    child: SizedBox(
                      width: 22.w,
                      height: 22.h,
                      child: CircularProgressIndicator(
                        color: _green,
                        strokeWidth: 2.5,
                      ),
                    ),
                  ),
                );
              }
              return AnimatedOpacity(
                opacity: disabled ? 0.5 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: GestureDetector(
                  onTap: disabled ? null : _submitWalletPayment,
                  child: Container(
                    width: double.infinity,
                    height: 56.h,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFDCF3E5), Color(0xFF9AE0BC)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(28.r),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF9AE0BC).withValues(alpha: 0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          insufficient
                              ? 'Insufficient Wallet Balance'
                              : 'Confirm & Pay from Wallet',
                          style: TextStyle(
                            fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w700,
                            color: _green,
                          ),
                        ),
                        SizedBox(width: 10.w),
                        Icon(
                          insufficient
                              ? Icons.error_outline
                              : Icons.check_circle_outline,
                          size: 20.sp,
                          color: _green,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _insufficientBalanceBanner() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: const Color(0xFFFDECEC),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: _red.withValues(alpha: 0.3), width: 1.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline, size: 18.sp, color: _red),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  'Insufficient wallet balance',
                  style: TextStyle(
                    fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    color: _red,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          Text(
            'Your wallet balance is lower than this plan\'s investment amount. Add funds to your wallet to continue.',
            style: TextStyle(
              fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
              fontSize: 12.5.sp,
              color: _red.withValues(alpha: 0.85),
            ),
          ),
          SizedBox(height: 12.h),
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, AppRoutes.deposit),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
              decoration: BoxDecoration(
                color: _red,
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_circle_outline, size: 15.sp, color: _white),
                  SizedBox(width: 6.w),
                  Text(
                    'Add Money to Wallet',
                    style: TextStyle(
                      fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                      color: _white,
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

  Widget _confirmRow(String label, String value) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        label,
        style: TextStyle(
          fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
          fontSize: 13.sp,
          color: _grey,
        ),
      ),
      Text(
        value,
        style: TextStyle(
          fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
          fontSize: 14.sp,
          fontWeight: FontWeight.w600,
          color: _dark,
        ),
      ),
    ],
  );

  Widget _keypadRow(List<String> keys) =>
      Row(children: keys.map(_keypadKey).toList());

  Widget _keypadKey(String key) {
    if (key.isEmpty) {
      return const PremiumKeypadKey(onTap: null, child: SizedBox());
    }
    final isBack = key == 'back';
    Widget content = isBack
        ? Icon(Icons.backspace_outlined, size: 22.sp, color: _dark)
        : Text(
            key,
            style: TextStyle(
              fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
              fontSize: 26.sp,
              fontWeight: FontWeight.w400,
              color: _dark,
              height: 1.0,
            ),
          );
    return PremiumKeypadKey(
      onTap: () => _onKeyTap(key),
      isBackspace: isBack,
      height: 64.h,
      child: content,
    );
  }
}

// ── Wallet Payment Card ────────────────────────────────────────────────────
// Replaces the old UPI/Bank-Transfer details card. Shows the investment
// amount, the user's current wallet balance, and the balance remaining
// after this plan is paid for (only when sufficient).
class _WalletPaymentCard extends StatelessWidget {
  final int amount;
  final double walletBalance;
  final bool loading;
  final bool insufficient;
  final String Function(int) inr;
  final String Function(double) inrDouble;

  const _WalletPaymentCard({
    required this.amount,
    required this.walletBalance,
    required this.loading,
    required this.insufficient,
    required this.inr,
    required this.inrDouble,
  });

  @override
  Widget build(BuildContext context) {
    final remaining = (walletBalance - amount).clamp(0, double.infinity);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(20.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.account_balance_wallet_rounded,
                  size: 18.sp,
                  color: _green,
                ),
                SizedBox(width: 8.w),
                Text(
                  'Pay from Wallet Balance',
                  style: TextStyle(
                    fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    color: _dark,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16.h),
            _row('Available Wallet Balance', loading ? '…' : '₹ ${inrDouble(walletBalance)}'),
            SizedBox(height: 10.h),
            _row('Investment Amount', '₹ ${inr(amount)}'),
            Divider(height: 24.h, color: const Color(0xFFF0F0F0)),
            _row(
              insufficient ? 'Shortfall' : 'Balance After Payment',
              insufficient
                  ? '₹ ${inrDouble(amount - walletBalance)}'
                  : '₹ ${inrDouble(remaining.toDouble())}',
              valueColor: insufficient ? _red : _green,
              bold: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, {Color? valueColor, bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
            fontSize: 13.sp,
            color: _grey,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
            fontSize: bold ? 16.sp : 14.sp,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w700,
            color: valueColor ?? _dark,
          ),
        ),
      ],
    );
  }
}