import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../models/plan/plan_models.dart';
import '../../routes/app_routes.dart';
import '../../viewmodels/plan/plan_viewmodel.dart';

const _bg = Color(0xFFF4F6FB);
const _white = Color(0xFFFFFFFF);
const _dark = Color(0xFF0D1F14);
const _green = Color(0xFF3D9E6A);
const _greenMid = Color(0xFF3D9E6A);
const _grey = Color(0xFF6B7280);
const _greyL = Color(0xFF9CA3AF);

const _heroGrad = LinearGradient(
  colors: [Color(0xFF3D9E6A), Color(0xFF86C9A0)],
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

  // Payment phase: null = amount entry, 'upi' = UPI phase, 'wallet' = wallet processing
  String? _paymentMethod; // 'upi' or 'wallet'
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

    // Load wallet balance when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PlanViewModel>().loadWalletBalance();

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
  bool get _hasAmount => _amountText.isNotEmpty && _amount > 0;

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

  // ── Submit via Wallet ──────────────────────────────────────────────────────
  Future<void> _submitWalletPayment() async {
    setState(() => _uploading = true);
    final vm = context.read<PlanViewModel>();
    await vm.enrollPlanWithWallet(
      planType: _planType,
      monthlyAmount: _amount,
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
      _toast(vm.enrollError ?? 'Payment failed. Please try again.');
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
    final total = _amount * _months;
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, topPad + 12, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Icon(
                          Icons.arrow_back,
                          size: 22,
                          color: _dark,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          'Moneytries',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: _dark,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: _greenMid,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Configure Plan',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: _white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: Text(
                      _planTitle,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: _dark,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: Text(
                      '$_rate Daily ROI · $_months Months',
                      style: GoogleFonts.poppins(fontSize: 13, color: _grey),
                    ),
                  ),
                  const SizedBox(height: 28),
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
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  children: [
                    _keypadRow(['1', '2', '3']),
                    _keypadRow(['4', '5', '6']),
                    _keypadRow(['7', '8', '9']),
                    _keypadRow(['', '0', 'back']),
                  ],
                ),
              ),
              const SizedBox(height: 14),
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
                      height: 56,
                      decoration: BoxDecoration(
                        color: _green,
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Confirm & Proceed to Pay',
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
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
          decoration: BoxDecoration(
            color: _white,
            borderRadius: BorderRadius.circular(18),
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
                'Monthly Amount (Fixed)',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: _greyL,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '₹',
                    style: GoogleFonts.poppins(
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      color: _grey,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _amountText.isEmpty ? '0' : _inr(_amount),
                    style: GoogleFonts.poppins(
                      fontSize: 40,
                      fontWeight: FontWeight.w800,
                      color: _dark,
                    ),
                  ),
                  AnimatedOpacity(
                    opacity: _cursorCtrl.value,
                    duration: Duration.zero,
                    child: Container(
                      width: 2,
                      height: 40,
                      margin: const EdgeInsets.only(left: 3),
                      color: _green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'This amount is fixed for all months',
                style: GoogleFonts.poppins(fontSize: 12, color: _greyL),
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
          decoration: const BoxDecoration(
            color: _white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(24, 20, 24, 16 + bp),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0E0E0),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Confirm Investment Plan',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: _dark,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Once started, the monthly amount is fixed.',
                style: GoogleFonts.poppins(fontSize: 13, color: _grey),
              ),
              const SizedBox(height: 20),
              _confirmRow('Selected Plan', _planTitle),
              const SizedBox(height: 12),
              _confirmRow('Monthly Amount (Fixed)', '₹${_inr(amount)}'),
              const SizedBox(height: 12),
              _confirmRow('Total Commitment', '₹${_inr(total)}'),
              const SizedBox(height: 12),
              _confirmRow('Daily ROI', _rate),
              const SizedBox(height: 12),
              _confirmRow('Duration', '$_months months'),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () {
                  Navigator.pop(ctx);
                  _showPaymentMethodSheet(amount);
                },
                child: Container(
                  width: double.infinity,
                  height: 54,
                  decoration: BoxDecoration(
                    color: _green,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Center(
                    child: Text(
                      'Proceed to Pay Month 1',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _white,
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

  // ── Payment Method Sheet ───────────────────────────────────────────────────
  void _showPaymentMethodSheet(int amount) {
    final vm = context.read<PlanViewModel>();
    final walletBal = vm.walletBalance;
    final hasEnoughWallet = walletBal >= amount;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final bp = MediaQuery.of(ctx).padding.bottom;
        return Container(
          decoration: const BoxDecoration(
            color: _white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(24, 20, 24, 16 + bp),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0E0E0),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Choose Payment Method',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: _dark,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'How would you like to pay ₹${_inr(amount)}?',
                style: GoogleFonts.poppins(fontSize: 13, color: _grey),
              ),
              const SizedBox(height: 20),

              // UPI Option
              GestureDetector(
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _paymentMethod = 'upi';
                    _paymentPhase = true;
                  });
                },
                child: _paymentMethodTile(
                  icon: Icons.qr_code_rounded,
                  title: 'UPI / Bank Transfer',
                  subtitle: 'Pay via UPI or bank — requires admin approval',
                  color: const Color(0xFF3D9E6A),
                  enabled: true,
                ),
              ),
              const SizedBox(height: 12),

              // Wallet Option
              GestureDetector(
                onTap: hasEnoughWallet
                    ? () {
                        Navigator.pop(ctx);
                        _submitWalletPayment();
                      }
                    : null,
                child: _paymentMethodTile(
                  icon: Icons.account_balance_wallet_rounded,
                  title: 'Wallet Balance',
                  subtitle: hasEnoughWallet
                      ? 'Available: ₹${_inr(walletBal.toInt())} — Instant, no approval needed'
                      : 'Insufficient balance (₹${_inr(walletBal.toInt())} available)',
                  color: hasEnoughWallet
                      ? const Color(0xFF3D9E6A)
                      : const Color(0xFF9CA3AF),
                  enabled: hasEnoughWallet,
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _paymentMethodTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required bool enabled,
  }) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: enabled ? color.withValues(alpha: 0.35) : const Color(0xFFE5E7EB),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: enabled ? _dark : _grey,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: enabled ? color : _greyL,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: enabled ? color : _greyL,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  // ── Phase 2: UPI Payment ───────────────────────────────────────────────────
  Widget _buildUpiPaymentPhase(double topPad, double botPad) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.fromLTRB(20, topPad + 12, 20, 16),
          color: _bg,
          child: Row(
            children: [
              GestureDetector(
                onTap: () => setState(() {
                  _paymentPhase = false;
                  _paymentMethod = null;
                }),
                child: const Icon(Icons.arrow_back, size: 22, color: _dark),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'Month 1 Payment',
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
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                            'Month 1 — Fixed Amount',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: _white.withValues(alpha: 0.8),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '₹${_inr(_amount)}',
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
                            _planTitle,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _white,
                            ),
                          ),
                          Text(
                            '$_rate Daily ROI',
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
                _PaymentDetailsCard(amount: _amount, inr: _inr),
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
                        color: _greyL,
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
          padding: EdgeInsets.fromLTRB(20, 12, 20, botPad > 0 ? botPad : 20),
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
                  onTap: _submitUpiPayment,
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
                          'Confirm & Submit',
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

  Widget _confirmRow(String label, String value) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label, style: GoogleFonts.poppins(fontSize: 13, color: _grey)),
      Text(
        value,
        style: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: _dark,
        ),
      ),
    ],
  );

  Widget _keypadRow(List<String> keys) =>
      Row(children: keys.map(_keypadKey).toList());

  Widget _keypadKey(String key) {
    if (key.isEmpty) return const Expanded(child: SizedBox(height: 64));
    Widget content = key == 'back'
        ? const Icon(Icons.backspace_outlined, size: 22, color: _dark)
        : Text(
            key,
            style: GoogleFonts.poppins(
              fontSize: 26,
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
          height: 64,
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
        color: Colors.white,
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
                _tabBtn(
                  'UPI',
                  !_showBank,
                  () => setState(() => _showBank = false),
                ),
                const SizedBox(width: 10),
                _tabBtn(
                  'Bank Transfer',
                  _showBank,
                  () => setState(() => _showBank = true),
                ),
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

  Widget _tabBtn(String label, bool sel, VoidCallback onTap) => GestureDetector(
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
          color: sel ? Colors.white : const Color(0xFF6B7280),
        ),
      ),
    ),
  );

  Widget _upiDetails() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _copyRow('UPI ID', _upiId),
      const SizedBox(height: 12),
      _amountRow(),
    ],
  );

  Widget _bankDetails() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _copyRow('Account Name', _acName),
      const SizedBox(height: 8),
      _copyRow('Account Number', _acNo),
      const SizedBox(height: 8),
      _copyRow('IFSC Code', _ifsc),
      const SizedBox(height: 12),
      _amountRow(),
    ],
  );

  Widget _copyRow(String label, String value) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF9CA3AF))),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0D1F14),
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
              const Icon(Icons.copy_rounded, size: 14, color: Color(0xFF3D9E6A)),
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

  Widget _amountRow() => Container(
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
          style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF3D9E6A)),
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