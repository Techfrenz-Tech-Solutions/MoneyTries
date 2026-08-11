import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../config/app_constants.dart';
import '../../models/plan/plan_models.dart';
import '../../routes/app_routes.dart';
import '../../viewmodels/plan/plan_viewmodel.dart';
import '../../utils/responsive.dart';

const _bg = Color(0xFFF4F6F4);
const _white = Color(0xFFFFFFFF);
const _dark = Color(0xFF0D1F14);
const _green = Color(0xFF1F6B45); // banner dark green
const _greenMid = Color(0xFF9AE0BC); // banner gradient end
const _grey = Color(0xFF6B7280);
const _greyL = Color(0xFF9CA3AF);

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

  // Payment phase: null = amount entry, 'upi' = UPI phase.
  // UPI / bank transfer (with admin approval) is the only supported payment
  // method for starting an investment plan — wallet-based plan payments
  // have been removed.
  String? _paymentMethod; // always 'upi' once payment phase starts
  bool _paymentPhase = false;

  final _utrCtrl = TextEditingController();
  File? _screenshot;
  bool _uploading = false;

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
    });
  }

  @override
  void dispose() {
    _cursorCtrl.dispose();
    _utrCtrl.dispose();
    super.dispose();
  }

  Map<String, dynamic> get _args =>
      (ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?) ??
      {};

  int get _months => (_args['months'] as int?) ?? 6;
  String get _rate => (_args['rate'] as String?) ?? '0.35%';
  String get _planTitle => (_args['title'] as String?) ?? '6 Month Plan';
  PlanType get _planType => PlanTypeExt.fromMonths(_months);

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

  void _onKeyTap(String key) {
    HapticFeedback.lightImpact();
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

  Future<void> _pickScreenshot() async {
    final xfile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (xfile != null) setState(() => _screenshot = File(xfile.path));
  }

  // ── Submit via UPI ─────────────────────────────────────────────────────────
  Future<void> _submitUpiPayment() async {
    final utr = _utrCtrl.text.trim();
    if (utr.isEmpty || utr.length < 6) {
      _toast('Please enter a valid UTR / Transaction ID');
      return;
    }
    if (_screenshot == null) {
      _toast('Please upload payment screenshot');
      return;
    }
    setState(() => _uploading = true);
    final vm = context.read<PlanViewModel>();
    final bytes = await _screenshot!.readAsBytes();
    final filename = 'plan_proof_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final proofUrl = await vm.uploadProof(bytes.toList(), filename) ?? '';
    await vm.enrollPlan(
      planType: _planType,
      monthlyAmount: _amount,
      utrId: utr,
      proofImageUrl: proofUrl,
    );
    if (!mounted) return;
    setState(() => _uploading = false);
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

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: TextStyle(
            fontFamily: GoogleFonts.inter().fontFamily,
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
        body: _paymentPhase && _paymentMethod == 'upi'
            ? _buildUpiPaymentPhase(topPad, botPad)
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
                            fontFamily: GoogleFonts.inter().fontFamily,
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
                        'Configure Plan',
                        style: TextStyle(
                          fontFamily: GoogleFonts.inter().fontFamily,
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
                        fontFamily: GoogleFonts.inter().fontFamily,
                        fontSize: 22.sp,
                        fontWeight: FontWeight.w800,
                        color: _dark,
                      ),
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Center(
                    child: Text(
                      '$_rate Daily ROI · $_months Months',
                      style: TextStyle(
                        fontFamily: GoogleFonts.inter().fontFamily,
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
                              fontFamily: GoogleFonts.inter().fontFamily,
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
                  fontFamily: GoogleFonts.inter().fontFamily,
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
                      fontFamily: GoogleFonts.inter().fontFamily,
                      fontSize: 28.sp,
                      fontWeight: FontWeight.w600,
                      color: _grey,
                    ),
                  ),
                  SizedBox(width: 4.w),
                  Text(
                    _amountText.isEmpty ? '0' : _inr(_amount),
                    style: TextStyle(
                      fontFamily: GoogleFonts.inter().fontFamily,
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
                  fontFamily: GoogleFonts.inter().fontFamily,
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

  // ── Confirm Sheet → Payment Method Selection ───────────────────────────────
  void _showConfirmSheet(int amount, int total) {
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
                  fontFamily: GoogleFonts.inter().fontFamily,
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w700,
                  color: _dark,
                ),
              ),
              SizedBox(height: 6.h),
              Text(
                'This is a one-time payment — the amount is fixed.',
                style: TextStyle(
                  fontFamily: GoogleFonts.inter().fontFamily,
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
              _confirmRow('Duration', '$_months months'),
              SizedBox(height: 12.h),
              _confirmRow('Principal', 'Locked until maturity'),
              SizedBox(height: 24.h),
              GestureDetector(
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _paymentMethod = 'upi';
                    _paymentPhase = true;
                  });
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
                        fontFamily: GoogleFonts.inter().fontFamily,
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

  // ── Phase 2: UPI Payment ───────────────────────────────────────────────────
  Widget _buildUpiPaymentPhase(double topPad, double botPad) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.fromLTRB(20.w, topPad + 12.h, 20.w, 16.h),
          color: _bg,
          child: Row(
            children: [
              GestureDetector(
                onTap: () => setState(() {
                  _paymentPhase = false;
                  _paymentMethod = null;
                }),
                child: Icon(Icons.arrow_back, size: 22.sp, color: _dark),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Text(
                  'Complete Payment',
                  style: TextStyle(
                    fontFamily: GoogleFonts.inter().fontFamily,
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
            child: Column(
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
                              fontFamily: GoogleFonts.inter().fontFamily,
                              fontSize: 12.sp,
                              color: _green.withValues(alpha: 0.75),
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            '₹ ${_inr(_amount)}',
                            style: TextStyle(
                              fontFamily: GoogleFonts.inter().fontFamily,
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
                              fontFamily: GoogleFonts.inter().fontFamily,
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w600,
                              color: _green,
                            ),
                          ),
                          Text(
                            '$_rate Daily ROI',
                            style: TextStyle(
                              fontFamily: GoogleFonts.inter().fontFamily,
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
                _PaymentDetailsCard(amount: _amount, inr: _inr),
                SizedBox(height: 20.h),
                Text(
                  'Transaction Reference (UTR)',
                  style: TextStyle(
                    fontFamily: GoogleFonts.inter().fontFamily,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: _grey,
                  ),
                ),
                SizedBox(height: 8.h),
                Container(
                  decoration: BoxDecoration(
                    color: _white,
                    borderRadius: BorderRadius.circular(14.r),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _utrCtrl,
                    style: TextStyle(
                      fontFamily: GoogleFonts.inter().fontFamily,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                      color: _dark,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Enter UTR / Transaction ID',
                      hintStyle: TextStyle(
                        fontFamily: GoogleFonts.inter().fontFamily,
                        fontSize: 14.sp,
                        color: _greyL,
                      ),
                      prefixIcon: Icon(
                        Icons.tag_rounded,
                        color: _greenMid,
                        size: 20.sp,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 16.h,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 20.h),
                Text(
                  'Payment Screenshot',
                  style: TextStyle(
                    fontFamily: GoogleFonts.inter().fontFamily,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: _grey,
                  ),
                ),
                SizedBox(height: 8.h),
                GestureDetector(
                  onTap: _pickScreenshot,
                  child: Container(
                    width: double.infinity,
                    height: _screenshot != null ? 180 : 100,
                    decoration: BoxDecoration(
                      color: _white,
                      borderRadius: BorderRadius.circular(14.r),
                      border: Border.all(
                        color: _greenMid.withValues(alpha: 0.3),
                        width: 1.5.r,
                      ),
                    ),
                    child: _screenshot != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(14.r),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.file(_screenshot!, fit: BoxFit.cover),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: GestureDetector(
                                    onTap: () =>
                                        setState(() => _screenshot = null),
                                    child: Container(
                                      width: 28.w,
                                      height: 28.h,
                                      decoration: const BoxDecoration(
                                        color: Colors.black54,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.close,
                                        color: _white,
                                        size: 16.sp,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.upload_rounded,
                                size: 32.sp,
                                color: _greenMid.withValues(alpha: 0.7),
                              ),
                              SizedBox(height: 8.h),
                              Text(
                                'Tap to upload screenshot',
                                style: TextStyle(
                                  fontFamily: GoogleFonts.inter().fontFamily,
                                  fontSize: 13.sp,
                                  color: _grey,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                SizedBox(height: 32.h),
              ],
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
          child: _uploading
              ? Container(
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
                )
              : GestureDetector(
                  onTap: _submitUpiPayment,
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
                          'Confirm & Submit',
                          style: TextStyle(
                            fontFamily: GoogleFonts.inter().fontFamily,
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w700,
                            color: _green,
                          ),
                        ),
                        SizedBox(width: 10.w),
                        Icon(
                          Icons.check_circle_outline,
                          size: 20.sp,
                          color: _green,
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _confirmRow(String label, String value) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        label,
        style: TextStyle(
          fontFamily: GoogleFonts.inter().fontFamily,
          fontSize: 13.sp,
          color: _grey,
        ),
      ),
      Text(
        value,
        style: TextStyle(
          fontFamily: GoogleFonts.inter().fontFamily,
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
    if (key.isEmpty) return Expanded(child: SizedBox(height: 64.h));
    Widget content = key == 'back'
        ? Icon(Icons.backspace_outlined, size: 22.sp, color: _dark)
        : Text(
            key,
            style: TextStyle(
              fontFamily: GoogleFonts.inter().fontFamily,
              fontSize: 26.sp,
              fontWeight: FontWeight.w400,
              color: _dark,
              height: 1.0,
            ),
          );
    return Expanded(
      child: GestureDetector(
        onTap: () => _onKeyTap(key),
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 64.h,
          alignment: Alignment.center,
          child: content,
        ),
      ),
    );
  }
}

// ── Payment Details Card ──────────────────────────────────────────────────────
class _PaymentDetailsCard extends StatefulWidget {
  final int amount;
  final String Function(int) inr;
  const _PaymentDetailsCard({required this.amount, required this.inr});
  @override
  State<_PaymentDetailsCard> createState() => _PaymentDetailsCardState();
}

class _PaymentDetailsCardState extends State<_PaymentDetailsCard> {
  bool _showBank = false;
  static const _upiId = 'MONEYMINING@KVB';
  static const _acName = 'Moneytries Investments';
  static const _acNo = '1234567890';
  static const _ifsc = 'KVB0001234';

  void _copy(String val) {
    Clipboard.setData(ClipboardData(text: val));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Copied!',
          style: TextStyle(fontFamily: GoogleFonts.inter().fontFamily, fontSize: 13.sp),
        ),
        backgroundColor: const Color(0xFF4CAF7D),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(16.w),
            child: Row(
              children: [
                _tabBtn(
                  'UPI',
                  !_showBank,
                  () => setState(() => _showBank = false),
                ),
                SizedBox(width: 10.w),
                _tabBtn(
                  'Bank Transfer',
                  _showBank,
                  () => setState(() => _showBank = true),
                ),
              ],
            ),
          ),
          Divider(height: 1.h, color: Color(0xFFF0F0F0)),
          Padding(
            padding: EdgeInsets.all(20.w),
            child: _showBank ? _bankDetails() : _upiDetails(),
          ),
        ],
      ),
    );
  }

  Widget _tabBtn(String label, bool sel, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: sel ? const Color(0xFF4CAF7D) : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: GoogleFonts.inter().fontFamily,
          fontSize: 13.sp,
          fontWeight: FontWeight.w600,
          color: sel ? Colors.white : const Color(0xFF6B7280),
        ),
      ),
    ),
  );

  Widget _upiDetails() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _copyRow('UPI ID', _upiId),
      SizedBox(height: 12.h),
      _amountRow(),
    ],
  );

  Widget _bankDetails() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _copyRow('Account Name', _acName),
      SizedBox(height: 8.h),
      _copyRow('Account Number', _acNo),
      SizedBox(height: 8.h),
      _copyRow('IFSC Code', _ifsc),
      SizedBox(height: 12.h),
      _amountRow(),
    ],
  );

  Widget _copyRow(String label, String value) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: GoogleFonts.inter().fontFamily,
              fontSize: 11.sp,
              color: const Color(0xFF9CA3AF),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontFamily: GoogleFonts.inter().fontFamily,
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0D1F14),
            ),
          ),
        ],
      ),
      GestureDetector(
        onTap: () => _copy(value),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5EE),
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: Row(
            children: [
              Icon(Icons.copy_rounded, size: 14.sp, color: Color(0xFF4CAF7D)),
              SizedBox(width: 4.w),
              Text(
                'Copy',
                style: TextStyle(
                  fontFamily: GoogleFonts.inter().fontFamily,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF4CAF7D),
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );

  Widget _amountRow() => Container(
    padding: EdgeInsets.all(12.w),
    decoration: BoxDecoration(
      color: const Color(0xFFF0FAF4),
      borderRadius: BorderRadius.circular(10.r),
      border: Border.all(color: const Color(0xFF9FDAB9), width: 1.r),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Amount to Pay',
          style: TextStyle(
            fontFamily: GoogleFonts.inter().fontFamily,
            fontSize: 13.sp,
            color: const Color(0xFF4CAF7D),
          ),
        ),
        Text(
          '₹ ${widget.inr(widget.amount)}',
          style: TextStyle(
            fontFamily: GoogleFonts.inter().fontFamily,
            fontSize: 16.sp,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF4CAF7D),
          ),
        ),
      ],
    ),
  );
}