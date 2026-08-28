import 'package:flutter/material.dart';
import 'package:moneytries/config/app_fonts.dart';
import 'package:flutter/services.dart';
import '../../config/app_constants.dart';
import '../../routes/app_routes.dart';
import '../../utils/responsive.dart';
import '../../widgets/premium/premium_keypad_key.dart';

// ── Palette (matches ConfigureInvestmentScreen for visual consistency) ────────
const _bg = Color(0xFFF4F6F4);
const _white = Color(0xFFFFFFFF);
const _dark = Color(0xFF0D1F14);
const _green = Color(0xFF1F6B45); // banner dark green
const _greenMid = Color(0xFF9AE0BC); // banner gradient end
const _grey = Color(0xFF6B7280);
const _greyL = Color(0xFF9CA3AF);

/// Step 1 of the redesigned Investment Plan flow:
///   Enter Investment Amount → Show Plan Comparison → Select Plan → T&C →
///   Submit Request → Admin Approval → First Payment → Active Plan.
///
/// This screen only collects the one-time investment amount the user wants to
/// compare plans against. No plan is chosen here — that happens on the next
/// screen (PlanComparisonScreen), once the user can see how each plan
/// performs against the amount they entered.
///
/// Optionally receives `excludeTypes` (a `List<String>` of `PlanType.name`
/// values) via route arguments when the user already holds one or more
/// active plans and tapped "Continue Another Plan" — those plan types are
/// simply forwarded to the comparison screen so they're excluded there.
class InvestmentAmountScreen extends StatefulWidget {
  const InvestmentAmountScreen({super.key});
  @override
  State<InvestmentAmountScreen> createState() => _InvestmentAmountScreenState();
}

class _InvestmentAmountScreenState extends State<InvestmentAmountScreen>
    with SingleTickerProviderStateMixin {
  String _amountText = '';
  static const _maxDigits = 8;
  List<String> _excludeTypes = const [];
  bool _argsRead = false;

  late final AnimationController _cursorCtrl;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_argsRead) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      final raw = args?['excludeTypes'];
      if (raw is List) {
        _excludeTypes = raw.map((e) => e.toString()).toList();
      }
      _argsRead = true;
    }
  }

  @override
  void initState() {
    super.initState();
    _cursorCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 530),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _cursorCtrl.dispose();
    super.dispose();
  }

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

  void _continue() {
    if (!_hasAmount) return;
    Navigator.pushNamed(
      context,
      AppRoutes.planComparison,
      arguments: {
        'amount': _amount,
        if (_excludeTypes.isNotEmpty) 'excludeTypes': _excludeTypes,
      },
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
        body: Column(
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
                              'MoneyTries',
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
                            'Step 1 of 3',
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
                          'How much do you want\nto invest?',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                            fontSize: 22.sp,
                            fontWeight: FontWeight.w800,
                            color: _dark,
                            height: 1.25,
                          ),
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Center(
                        child: Text(
                          _excludeTypes.isEmpty
                              ? 'We\'ll compare all available plans against this amount'
                              : 'We\'ll compare your remaining available plans against this amount',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                            fontSize: 13.sp,
                            color: _grey,
                          ),
                        ),
                      ),
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
                        onTap: _hasAmount ? _continue : null,
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
                                'Compare Plans',
                                style: TextStyle(
                                  fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w700,
                                  color: _green,
                                ),
                              ),
                              SizedBox(width: 10.w),
                              Icon(
                                Icons.arrow_forward,
                                size: 18.sp,
                                color: _green,
                              ),
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
        ),
      ),
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
                'Investment Amount',
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
                        : 'Enter the amount you\'ll invest every month',
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

  Widget _keypadRow(List<String> keys) {
    return Row(
      children: keys.map((k) {
        if (k.isEmpty) {
          return const PremiumKeypadKey(onTap: null, child: SizedBox());
        }
        final isBack = k == 'back';
        return PremiumKeypadKey(
          onTap: () => _onKeyTap(k),
          isBackspace: isBack,
          height: 64.h,
          child: isBack
              ? Icon(Icons.backspace_outlined, size: 22.sp, color: _dark)
              : Text(
                  k,
                  style: TextStyle(
                    fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                    fontSize: 26.sp,
                    fontWeight: FontWeight.w600,
                    color: _dark,
                  ),
                ),
        );
      }).toList(),
    );
  }
}