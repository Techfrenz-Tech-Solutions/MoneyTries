import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../models/plan/plan_models.dart';
import '../../viewmodels/plan/plan_viewmodel.dart';

const _bg = Color(0xFFF4F6FB);
const _white = Color(0xFFFFFFFF);
const _dark = Color(0xFF0D1F14);
const _green = Color(0xFF3D9E6A);
const _greenMid = Color(0xFF3D9E6A);
const _grey = Color(0xFF6B7280);
const _greyLight = Color(0xFF9CA3AF);

const _heroGrad = LinearGradient(
  colors: [Color(0xFF3D9E6A), Color(0xFF86C9A0)],
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
            'Month ${_plan.monthsPaid + 1} payment submitted — pending review.',
            style: GoogleFonts.poppins(fontSize: 13),
          ),
          backgroundColor: const Color(0xFF3D9E6A),
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
          style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF111827)),
        ),
        backgroundColor: Colors.white,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
              padding: EdgeInsets.fromLTRB(20, topPad + 12, 20, 16),
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
                    child: const Icon(Icons.arrow_back, size: 22, color: _dark),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      _upiPhase
                          ? 'Month $nextMonth — UPI Payment'
                          : 'Month $nextMonth Payment',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
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
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Hero summary
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: _heroGrad,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(
                          0xFF3D9E6A,
                        ).withValues(alpha: 0.28),
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
                                'Month $nextMonth — Fixed Amount',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: _white.withValues(alpha: 0.8),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '₹${_inr(_plan.monthlyAmount)}',
                                style: GoogleFonts.poppins(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  color: _white,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                _plan.planType.displayName,
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _white,
                                ),
                              ),
                              Text(
                                '${_plan.monthsPaid}/${_plan.totalMonths} months paid',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: _white.withValues(alpha: 0.8),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.lock_outline,
                              size: 14,
                              color: _white,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Monthly amount is fixed — ₹${_inr(_plan.monthlyAmount)} for all months',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: _white.withValues(alpha: 0.9),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
        Container(
          color: _bg,
          padding: EdgeInsets.fromLTRB(20, 12, 20, botPad > 0 ? botPad : 20),
          child: GestureDetector(
            onTap: () => setState(() => _upiPhase = true),
            child: Container(
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                color: _green,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Pay Now',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _white,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Icon(
                    Icons.arrow_forward,
                    size: 18,
                    color: _white,
                  ),
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
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Hero
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: _heroGrad,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF3D9E6A).withValues(alpha: 0.28),
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
                            'Month $nextMonth — Fixed Amount',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: _white.withValues(alpha: 0.8),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '₹${_inr(_plan.monthlyAmount)}',
                            style: GoogleFonts.poppins(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: _white,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _plan.planType.displayName,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _white,
                            ),
                          ),
                          Text(
                            '${_plan.monthsPaid}/${_plan.totalMonths} months paid',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: _white.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _PaymentDetailsBlock(
                  amount: _plan.monthlyAmount,
                  inr: _inr,
                ),
                const SizedBox(height: 20),
                Text(
                  'Transaction Reference (UTR)',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _grey,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: _white,
                    borderRadius: BorderRadius.circular(14),
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
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _dark,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Enter UTR / Transaction ID',
                      hintStyle: GoogleFonts.poppins(
                        fontSize: 14,
                        color: _greyLight,
                      ),
                      prefixIcon: const Icon(
                        Icons.tag_rounded,
                        color: _greenMid,
                        size: 20,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Payment Screenshot',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _grey,
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _pickScreenshot,
                  child: Container(
                    width: double.infinity,
                    height: _screenshot != null ? 180 : 100,
                    decoration: BoxDecoration(
                      color: _white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _greenMid.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                    ),
                    child: _screenshot != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(14),
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
                                      width: 28,
                                      height: 28,
                                      decoration: const BoxDecoration(
                                        color: Colors.black54,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        color: _white,
                                        size: 16,
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
                                size: 32,
                                color: _greenMid.withValues(alpha: 0.7),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Tap to upload screenshot',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: _grey,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
        Container(
          color: _bg,
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            botPad > 0 ? botPad : 20,
          ),
          child: _uploading
              ? Container(
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    color: _green.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: _white,
                        strokeWidth: 2.5,
                      ),
                    ),
                  ),
                )
              : GestureDetector(
                  onTap: _submitUpi,
                  child: Container(
                    width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      color: _green,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Submit Payment',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: _white,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Icon(
                          Icons.check_circle_outline,
                          size: 20,
                          color: _white,
                        ),
                      ],
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
        content: Text('Copied!', style: GoogleFonts.poppins(fontSize: 13)),
        backgroundColor: const Color(0xFF3D9E6A),
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
        borderRadius: BorderRadius.circular(18),
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
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _tab(
                  'UPI',
                  !_showBank,
                  () => setState(() => _showBank = false),
                ),
                const SizedBox(width: 10),
                _tab('Bank', _showBank, () => setState(() => _showBank = true)),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF0F0F0)),
          Padding(
            padding: const EdgeInsets.all(20),
            child: _showBank ? _bankDetails() : _upiDetails(),
          ),
        ],
      ),
    );
  }

  Widget _tab(String label, bool sel, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: sel ? const Color(0xFF3D9E6A) : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 13,
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
      const SizedBox(height: 12),
      _amountChip(),
    ],
  );

  Widget _bankDetails() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _copyRow('Account Name', _acName),
      const SizedBox(height: 10),
      _copyRow('Account Number', _acNo),
      const SizedBox(height: 10),
      _copyRow('IFSC Code', _ifsc),
      const SizedBox(height: 12),
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
            style: GoogleFonts.poppins(fontSize: 11, color: _greyLight),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _dark,
            ),
          ),
        ],
      ),
      GestureDetector(
        onTap: () => _copy(value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFECFDF5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.copy_rounded,
                size: 14,
                color: Color(0xFF3D9E6A),
              ),
              const SizedBox(width: 4),
              Text(
                'Copy',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF3D9E6A),
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );

  Widget _amountChip() => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFF0FDF4),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFF86EFAC), width: 1),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Amount to Pay',
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: const Color(0xFF3D9E6A),
          ),
        ),
        Text(
          '₹${widget.inr(widget.amount)}',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF3D9E6A),
          ),
        ),
      ],
    ),
  );
}