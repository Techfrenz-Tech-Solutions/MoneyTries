import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../models/plan/plan_models.dart';
import '../../viewmodels/plan/plan_viewmodel.dart';
import '../../utils/responsive.dart';
import '../../widgets/animations/animations.dart';

const _bg = Color(0xFFF4F6F4);
const _white = Color(0xFFFFFFFF);
const _dark = Color(0xFF0D1F14);
const _green = Color(0xFF1F6B45); // banner dark green
const _greenMid = Color(0xFF9AE0BC); // banner gradient end
const _grey = Color(0xFF6B7280);
const _greyLight = Color(0xFF9CA3AF);

const _heroGrad = LinearGradient(
  colors: [Color(0xFFDCF3E5), Color(0xFF9AE0BC)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

class PlanPaymentScreen extends StatefulWidget {
  const PlanPaymentScreen({super.key});
  @override
  State<PlanPaymentScreen> createState() => _PlanPaymentScreenState();
}

class _PlanPaymentScreenState extends State<PlanPaymentScreen> {
  final _utrCtrl = TextEditingController();
  File? _screenshot;
  bool _uploading = false;
  bool _initialized = false;

  // 'upi' phase is the inline UPI form. UPI / bank transfer (with admin
  // approval) is the only supported payment method for investment plan
  // instalments — wallet-based plan payments have been removed.
  bool _upiPhase = false;

  late ActivePlan _plan;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      _plan =
          args?['plan'] as ActivePlan? ??
          ActivePlan(
            id: '',
            planType: PlanType.sixMonth,
            monthlyAmount: 0,
            monthsPaid: 0,
            startDate: DateTime.now(),
            maturityDate: DateTime.now().add(const Duration(days: 180)),
            accruedRoi: 0,
            withdrawnRoi: 0,
            status: PlanStatus.active,
          );
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _utrCtrl.dispose();
    super.dispose();
  }

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

  Future<void> _pickScreenshot() async {
    final xfile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (xfile != null) setState(() => _screenshot = File(xfile.path));
  }

  // ── Submit via UPI ─────────────────────────────────────────────────────────
  Future<void> _submitUpi() async {
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
    final filename = 'payment_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final proofUrl = await vm.uploadProof(bytes.toList(), filename) ?? '';
    await vm.payMonthlyInstalment(
      planId: _plan.id,
      utrId: utr,
      proofImageUrl: proofUrl,
    );
    if (!mounted) return;
    setState(() => _uploading = false);
    if (vm.payState == PlanVmState.success) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Payment submitted — pending review.',
            style: TextStyle(fontFamily: GoogleFonts.inter().fontFamily, fontSize: 13.sp),
          ),
          backgroundColor: const Color(0xFF4CAF7D),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      _toast(vm.payError ?? 'Payment failed. Please try again.');
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
    final nextMonth = _plan.monthsPaid + 1;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _bg,
        body: Column(
          children: [
            // Header
            Container(
              padding: EdgeInsets.fromLTRB(20.w, topPad + 12.h, 20.w, 16.h),
              color: _bg,
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      if (_upiPhase) {
                        setState(() => _upiPhase = false);
                      } else {
                        Navigator.pop(context);
                      }
                    },
                    child: Icon(Icons.arrow_back, size: 22.sp, color: _dark),
                  ),
                  SizedBox(width: 14.w),
                  Expanded(
                    child: Text(
                      _upiPhase ? 'Complete Payment — UPI' : 'Complete Payment',
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
              child: _upiPhase
                  ? _buildUpiForm(botPad, nextMonth)
                  : _buildMethodSelection(botPad, nextMonth),
            ),
          ],
        ),
      ),
    );
  }

  // ── Default view: hero card + "Pay Now" button → shows method sheet ────────
  Widget _buildMethodSelection(double botPad, int nextMonth) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Hero summary
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
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Investment Payment',
                                style: TextStyle(
                                  fontFamily: GoogleFonts.inter().fontFamily,
                                  fontSize: 12.sp,
                                  color: _green.withValues(alpha: 0.75),
                                ),
                              ),
                              SizedBox(height: 4.h),
                              Text(
                                '₹ ${_inr(_plan.monthlyAmount)}',
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
                                _plan.planType.displayName,
                                style: TextStyle(
                                  fontFamily: GoogleFonts.inter().fontFamily,
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w600,
                                  color: _green,
                                ),
                              ),
                              Text(
                                '${_plan.monthsPaid}/${_plan.totalMonths} months paid',
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
                      SizedBox(height: 14.h),
                      Container(
                        padding: EdgeInsets.all(10.w),
                        decoration: BoxDecoration(
                          color: _green.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.lock_outline,
                              size: 14.sp,
                              color: _green,
                            ),
                            SizedBox(width: 8.w),
                            Expanded(
                              child: Text(
                                'Monthly amount is fixed — ₹ ${_inr(_plan.monthlyAmount)} for all months',
                                style: TextStyle(
                                  fontFamily: GoogleFonts.inter().fontFamily,
                                  fontSize: 11.sp,
                                  color: _green.withValues(alpha: 0.85),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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
          child: GestureDetector(
            onTap: () => setState(() => _upiPhase = true),
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
                    'Pay Now',
                    style: TextStyle(
                      fontFamily: GoogleFonts.inter().fontFamily,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w700,
                      color: _green,
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Icon(Icons.arrow_forward, size: 18.sp, color: _green),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── UPI form ───────────────────────────────────────────────────────────────
  Widget _buildUpiForm(double botPad, int nextMonth) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Hero
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
                            'Investment Payment',
                            style: TextStyle(
                              fontFamily: GoogleFonts.inter().fontFamily,
                              fontSize: 12.sp,
                              color: _green.withValues(alpha: 0.75),
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            '₹ ${_inr(_plan.monthlyAmount)}',
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
                            _plan.planType.displayName,
                            style: TextStyle(
                              fontFamily: GoogleFonts.inter().fontFamily,
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w600,
                              color: _green,
                            ),
                          ),
                          Text(
                            '${_plan.monthsPaid}/${_plan.totalMonths} months paid',
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
                _PaymentDetailsBlock(amount: _plan.monthlyAmount, inr: _inr),
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
                        color: _greyLight,
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
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            transitionBuilder: (child, anim) =>
                FadeTransition(opacity: anim, child: child),
            child: _uploading
              ? Container(
                  key: const ValueKey('loading'),
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
              : AnimatedTapScale(
                  key: const ValueKey('button'),
                  onTap: _submitUpi,
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
                          'Submit Payment',
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
        ),
      ],
    );
  }
}

// ── Payment Details Block ─────────────────────────────────────────────────────
class _PaymentDetailsBlock extends StatefulWidget {
  final int amount;
  final String Function(int) inr;
  const _PaymentDetailsBlock({required this.amount, required this.inr});
  @override
  State<_PaymentDetailsBlock> createState() => _PaymentDetailsBlockState();
}

class _PaymentDetailsBlockState extends State<_PaymentDetailsBlock> {
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
        color: _white,
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
                _tab(
                  'UPI',
                  !_showBank,
                  () => setState(() => _showBank = false),
                ),
                SizedBox(width: 10.w),
                _tab('Bank', _showBank, () => setState(() => _showBank = true)),
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

  Widget _tab(String label, bool sel, VoidCallback onTap) => GestureDetector(
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
          color: sel ? _white : _grey,
        ),
      ),
    ),
  );

  Widget _upiDetails() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _copyRow('UPI ID', _upiId),
      SizedBox(height: 12.h),
      _amountChip(),
    ],
  );

  Widget _bankDetails() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _copyRow('Account Name', _acName),
      SizedBox(height: 10.h),
      _copyRow('Account Number', _acNo),
      SizedBox(height: 10.h),
      _copyRow('IFSC Code', _ifsc),
      SizedBox(height: 12.h),
      _amountChip(),
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
              color: _greyLight,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontFamily: GoogleFonts.inter().fontFamily,
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
              color: _dark,
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

  Widget _amountChip() => Container(
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