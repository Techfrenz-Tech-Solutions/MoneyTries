import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/deposit/deposit_viewmodel.dart';
import '../../models/deposit/deposit_models.dart';
import '../../routes/app_routes.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _bg            = Color(0xFFECEFF5);
const _white         = Color(0xFFFFFFFF);
const _titleDark     = Color(0xFF111827);
const _subtitleGrey  = Color(0xFF6B7280);
const _labelGrey     = Color(0xFF9CA3AF);
const _brandGreen    = Color(0xFF3D9E6A);
const _accentGreen   = Color(0xFF3D9E6A);
const _accentGreenEnd= Color(0xFF86C9A0);
const _infoBg        = Color(0xFFE9F3EE);
const _infoBorder    = Color(0xFFD4EDE0);
const _infoText      = Color(0xFF4B5563);
const _errorRed      = Color(0xFFDC2626);
const _amber         = Color(0xFFD97706);
const _amberBg       = Color(0xFFFFFBEB);
const _amberBorder   = Color(0xFFFDE68A);

class _QuickAmount {
  final String label;
  final int amount;
  const _QuickAmount(this.label, this.amount);
}

// ── Entry point ───────────────────────────────────────────────────────────────
class DepositScreen extends StatelessWidget {
  const DepositScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => DepositViewModel(),
      child: const _DepositScreenContent(),
    );
  }
}

// ── Main screen ───────────────────────────────────────────────────────────────
class _DepositScreenContent extends StatefulWidget {
  const _DepositScreenContent();
  @override
  State<_DepositScreenContent> createState() => _DepositScreenContentState();
}

class _DepositScreenContentState extends State<_DepositScreenContent> {
  final TextEditingController _amountController =
      TextEditingController(text: '0');
  final TextEditingController _utrController = TextEditingController();
  final _imagePicker = ImagePicker();

  static const _quickAmounts = [
    _QuickAmount('Basic', 1000),
    _QuickAmount('Growth', 5000),
    _QuickAmount('Vault', 10000),
  ];

  @override
  void dispose() {
    _amountController.dispose();
    _utrController.dispose();
    super.dispose();
  }

  void _selectQuickAmount(int value, DepositViewModel vm) {
    vm.setAmount(value);
    _amountController.text = value.toString();
  }

  Future<void> _pickImage(DepositViewModel vm) async {
    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (picked != null) {
        vm.setScreenshot(File(picked.path));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open gallery. Check permissions.')),
        );
      }
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard'),
        duration: const Duration(seconds: 2),
        backgroundColor: _brandGreen,
      ),
    );
  }

  Future<void> _submit(DepositViewModel vm) async {
    FocusScope.of(context).unfocus();
    await vm.submitDeposit();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DepositViewModel>(
      builder: (context, vm, _) {

        // ── 1. Loading: checking for existing pending deposit ────────────────
        if (vm.isCheckingPending) {
          return _buildLoadingScaffold();
        }

        // ── 2. Success: just submitted, show receipt ─────────────────────────
        if (vm.state == DepositState.success && vm.completedOrder != null) {
          return _UnderReviewReceipt(
            orderId: vm.completedOrder!.orderId,
            amount: vm.amount,
            utrId: vm.utrId,
            paymentMethod: vm.paymentMethod,
            submittedAt: DateTime.now(),
            onDone: () {
              vm.reset();
              _amountController.text = '0';
              _utrController.clear();
              Navigator.pop(context);
            },
          );
        }

        // ── 3. Pending exists: show blocker screen ───────────────────────────
        if (vm.hasPendingDeposit) {
          return _PendingDepositBlocker(
            record: vm.pendingDeposit!,
            onRefresh: vm.refreshPendingStatus,
            isRefreshing: vm.isCheckingPending,
          );
        }

        // ── 4. Normal deposit form ───────────────────────────────────────────
        return Theme(
          data: ThemeData(brightness: Brightness.light, scaffoldBackgroundColor: _bg),
          child: AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle.dark,
            child: Scaffold(
              backgroundColor: _bg,
              body: SafeArea(
                child: Column(
                  children: [
                    _buildTopBar(context),
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            _buildAmountInput(vm),
                            const SizedBox(height: 28),
                            _buildQuickSelect(vm),
                            const SizedBox(height: 24),
                            _buildPaymentMethodSelector(vm),
                            const SizedBox(height: 20),
                            _buildPaymentDetails(vm),
                            const SizedBox(height: 20),
                            _buildUtrField(vm),
                            const SizedBox(height: 20),
                            _buildScreenshotPicker(vm),
                            const SizedBox(height: 24),
                            _buildSummaryCard(vm),
                            if (vm.state == DepositState.error && vm.errorMessage != null)
                              _buildErrorBanner(vm.errorMessage!),
                          ],
                        ),
                      ),
                    ),
                    _buildBottomBar(vm),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoadingScaffold() {
    return Theme(
      data: ThemeData(brightness: Brightness.light, scaffoldBackgroundColor: _bg),
      child: Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: Column(
            children: [
              _buildTopBar(context),
              const Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: _accentGreen, strokeWidth: 2.5),
                      SizedBox(height: 16),
                      Text('Checking deposit status…',
                          style: TextStyle(fontSize: 14, color: _subtitleGrey)),
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

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 20, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Icon(Icons.arrow_back, color: _brandGreen, size: 24),
            ),
          ),
          const SizedBox(width: 4),
          Text('Deposit Funds',
              style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: _brandGreen)),
          const Spacer(),
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, AppRoutes.profile),
            child: Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _white, width: 2),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6, offset: const Offset(0, 2))],
              ),
              child: ClipOval(
                child: Container(
                  color: const Color(0xFFB7CDB8),
                  child: const Icon(Icons.person, color: _white, size: 22),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountInput(DepositViewModel vm) {
    return Column(
      children: [
        Text('ENTER AMOUNT',
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: _labelGrey, letterSpacing: 1.0)),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final maxW = constraints.maxWidth.isInfinite ? 280.0 : constraints.maxWidth - 40;
            return ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxW),
              child: IntrinsicWidth(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 6, top: 6),
                      child: Text('₹', style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w600, color: _titleDark)),
                    ),
                    Flexible(
                      child: TextField(
                        controller: _amountController,
                        onChanged: (v) => vm.setAmount(int.tryParse(v) ?? 0),
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        cursorColor: _accentGreen,
                        style: GoogleFonts.inter(fontSize: 40, fontWeight: FontWeight.w800, color: _titleDark),
                        decoration: const InputDecoration(isDense: true, border: InputBorder.none, contentPadding: EdgeInsets.zero),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 6),
        Container(height: 2, width: 140,
            decoration: BoxDecoration(color: _accentGreen.withOpacity(0.4), borderRadius: BorderRadius.circular(2))),
      ],
    );
  }

  Widget _buildQuickSelect(DepositViewModel vm) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('QUICK SELECT',
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: _labelGrey, letterSpacing: 1.0)),
        const SizedBox(height: 12),
        Row(
          children: _quickAmounts.map((q) {
            final selected = vm.amount == q.amount;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: q == _quickAmounts.last ? 0 : 10),
                child: GestureDetector(
                  onTap: () => _selectQuickAmount(q.amount, vm),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: _white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: selected ? _accentGreen : const Color(0xFFE5E7EB), width: selected ? 2 : 1),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
                    ),
                    child: Column(
                      children: [
                        Text(q.label, style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w500, color: _subtitleGrey)),
                        const SizedBox(height: 4),
                        Text('₹${_fmt(q.amount)}', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: _titleDark)),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildPaymentMethodSelector(DepositViewModel vm) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('PAYMENT METHOD',
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: _labelGrey, letterSpacing: 1.0)),
        const SizedBox(height: 12),
        Row(
          children: [
            _MethodChip(
              label: 'UPI Transfer', icon: Icons.qr_code_scanner_rounded,
              selected: vm.paymentMethod == PaymentMethod.upi,
              onTap: () => vm.setPaymentMethod(PaymentMethod.upi),
            ),
            const SizedBox(width: 12),
            _MethodChip(
              label: 'Bank Transfer\n(IMPS)', icon: Icons.account_balance_rounded,
              selected: vm.paymentMethod == PaymentMethod.bank,
              onTap: () => vm.setPaymentMethod(PaymentMethod.bank),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPaymentDetails(DepositViewModel vm) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _infoBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _infoBorder),
      ),
      child: vm.paymentMethod == PaymentMethod.upi ? _buildUpiDetails() : _buildBankDetails(),
    );
  }

  Widget _buildUpiDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Send payment to this UPI ID:',
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: _infoText)),
        const SizedBox(height: 10),
        _CopyRow(label: 'UPI ID', value: DepositViewModel.upiId,
            onCopy: () => _copyToClipboard(DepositViewModel.upiId, 'UPI ID')),
      ],
    );
  }

  Widget _buildBankDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Transfer via IMPS / NEFT to:',
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: _infoText)),
        const SizedBox(height: 10),
        _CopyRow(label: 'Account Name', value: DepositViewModel.bankAccountName,
            onCopy: () => _copyToClipboard(DepositViewModel.bankAccountName, 'Account Name')),
        const SizedBox(height: 8),
        _CopyRow(label: 'Account No.', value: DepositViewModel.bankAccountNumber,
            onCopy: () => _copyToClipboard(DepositViewModel.bankAccountNumber, 'Account Number')),
        const SizedBox(height: 8),
        _CopyRow(label: 'IFSC', value: DepositViewModel.bankIfsc,
            onCopy: () => _copyToClipboard(DepositViewModel.bankIfsc, 'IFSC Code')),
        const SizedBox(height: 8),
        _CopyRow(label: 'Account Type', value: DepositViewModel.bankAccountType, onCopy: null),
      ],
    );
  }

  Widget _buildUtrField(DepositViewModel vm) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('UTR / TRANSACTION ID',
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: _labelGrey, letterSpacing: 1.0)),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: _white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: TextField(
            controller: _utrController,
            onChanged: vm.setUtrId,
            keyboardType: TextInputType.text,
            textCapitalization: TextCapitalization.characters,
            cursorColor: _accentGreen,
            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: _titleDark),
            decoration: InputDecoration(
              hintText: 'Enter UTR / Ref. No.',
              hintStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w400, color: _labelGrey),
              prefixIcon: const Icon(Icons.tag_rounded, color: _accentGreen, size: 20),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScreenshotPicker(DepositViewModel vm) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('PAYMENT SCREENSHOT',
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: _labelGrey, letterSpacing: 1.0)),
        const SizedBox(height: 10),
        if (vm.screenshot == null)
          GestureDetector(
            onTap: () => _pickImage(vm),
            child: Container(
              width: double.infinity, height: 110,
              decoration: BoxDecoration(
                color: _white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _accentGreen.withOpacity(0.35), width: 1.5),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(color: _infoBg, shape: BoxShape.circle),
                    child: const Icon(Icons.upload_rounded, color: _accentGreen, size: 26),
                  ),
                  const SizedBox(height: 8),
                  Text('Tap to upload screenshot',
                      style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w600, color: _accentGreen)),
                  const SizedBox(height: 2),
                  Text('JPG or PNG from your gallery',
                      style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w400, color: _labelGrey)),
                ],
              ),
            ),
          )
        else
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(vm.screenshot!, width: double.infinity, height: 180, fit: BoxFit.cover),
              ),
              Positioned(
                top: 8, right: 8,
                child: GestureDetector(
                  onTap: vm.clearScreenshot,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                    child: const Icon(Icons.close, color: _white, size: 16),
                  ),
                ),
              ),
              Positioned(
                bottom: 8, left: 8,
                child: GestureDetector(
                  onTap: () => _pickImage(vm),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                    child: Text('Change', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: _white)),
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildSummaryCard(DepositViewModel vm) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Gateway Charges', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: _subtitleGrey)),
            Text('₹0', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: _accentGreen)),
          ]),
          const SizedBox(height: 14),
          const Divider(color: Color(0xFFE5E7EB), height: 1),
          const SizedBox(height: 14),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Total to Pay', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: _titleDark)),
            Text('₹${_fmt(vm.amount)}', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: _titleDark)),
          ]),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: _infoBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: _infoBorder, width: 1)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.info_outline_rounded, size: 18, color: _accentGreen),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Complete the payment, then enter your UTR/Ref. ID and upload the screenshot before submitting.',
                  style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w400, color: _infoText, height: 1.45),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      margin: const EdgeInsets.only(top: 14),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _errorRed.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _errorRed.withOpacity(0.3)),
      ),
      child: Row(children: [
        const Icon(Icons.error_outline_rounded, color: _errorRed, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(message, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: _errorRed))),
      ]),
    );
  }

  Widget _buildBottomBar(DepositViewModel vm) {
    final enabled = vm.amount > 0 && vm.utrId.isNotEmpty && vm.screenshot != null && vm.state != DepositState.loading;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, -4))],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity, height: 52,
          child: ElevatedButton(
            onPressed: enabled ? () => _submit(vm) : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentGreenEnd,
              disabledBackgroundColor: _accentGreenEnd.withOpacity(0.5),
              foregroundColor: _white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
            child: vm.state == DepositState.loading
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: _white))
                : Text('Submit Deposit Request',
                    style: GoogleFonts.inter(fontSize: 15.5, fontWeight: FontWeight.w700, color: _white)),
          ),
        ),
      ),
    );
  }

  String _fmt(int value) {
    final str = value.toString();
    final buf = StringBuffer();
    final len = str.length;
    for (int i = 0; i < len; i++) {
      final pos = len - i;
      buf.write(str[i]);
      if (pos > 3 && (pos - 3) % 2 == 0) buf.write(',');
    }
    return buf.toString();
  }
}

// ── Pending Deposit Blocker ───────────────────────────────────────────────────
/// Shown when the user already has a pending deposit awaiting admin review.
/// They cannot submit a new one until this is approved or rejected.
class _PendingDepositBlocker extends StatelessWidget {
  final DepositRecord record;
  final VoidCallback onRefresh;
  final bool isRefreshing;

  const _PendingDepositBlocker({
    required this.record,
    required this.onRefresh,
    required this.isRefreshing,
  });

  String _fmtAmount(double v) {
    final str = v.toStringAsFixed(0);
    final buf = StringBuffer();
    final len = str.length;
    for (int i = 0; i < len; i++) {
      final pos = len - i;
      buf.write(str[i]);
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
                // Top bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 12, 20, 8),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(Icons.arrow_back, color: _brandGreen, size: 24),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text('Deposit Funds',
                          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: _brandGreen)),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                    child: Column(
                      children: [
                        // Pulsing clock icon
                        Container(
                          width: 80, height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _amberBg,
                            border: Border.all(color: _amberBorder, width: 2),
                            boxShadow: [BoxShadow(color: _amber.withOpacity(0.15), blurRadius: 18, offset: const Offset(0, 6))],
                          ),
                          child: const Icon(Icons.hourglass_top_rounded, color: _amber, size: 38),
                        ),
                        const SizedBox(height: 16),
                        Text('Deposit Under Review',
                            style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: _titleDark)),
                        const SizedBox(height: 8),
                        Text(
                          'Your deposit request is being reviewed\nby our team. Please wait for approval.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w400, color: _subtitleGrey, height: 1.55),
                        ),
                        const SizedBox(height: 28),

                        // Deposit details card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: _white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 14, offset: const Offset(0, 4))],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('DEPOSIT DETAILS',
                                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: _labelGrey, letterSpacing: 1.1)),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _amberBg,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: _amberBorder),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(width: 6, height: 6,
                                            decoration: const BoxDecoration(color: _amber, shape: BoxShape.circle)),
                                        const SizedBox(width: 5),
                                        Text('Under Review',
                                            style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: _amber)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              _DetailRow(label: 'Order ID', value: '#${record.id}', valueColor: _brandGreen, bold: true),
                              _detailDivider(),
                              _DetailRow(label: 'Amount', value: '₹${_fmtAmount(record.amount)}', bold: true, valueColor: _titleDark),
                              _detailDivider(),
                              _DetailRow(label: 'UTR / Ref. ID', value: record.utrId),
                              _detailDivider(),
                              _DetailRow(label: 'Submitted On', value: _fmtDate(record.createdAt)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Info note
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: _amberBg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: _amberBorder),
                          ),
                          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Icon(Icons.lock_clock_outlined, size: 18, color: _amber),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'You can only have one active deposit request at a time. Once this request is approved or rejected by our admin team, you will be able to submit a new one.',
                                style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w400, color: const Color(0xFF92400E), height: 1.5),
                              ),
                            ),
                          ]),
                        ),
                        const SizedBox(height: 20),

                        // Steps timeline
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: _white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3))],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('APPROVAL PROGRESS',
                                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: _labelGrey, letterSpacing: 1.1)),
                              const SizedBox(height: 16),
                              _TimelineStep(
                                icon: Icons.check_circle_rounded,
                                label: 'Deposit Submitted',
                                sublabel: _fmtDate(record.createdAt),
                                color: _accentGreen,
                                isDone: true,
                              ),
                              _TimelineConnector(done: true),
                              _TimelineStep(
                                icon: Icons.manage_search_rounded,
                                label: 'Admin Review',
                                sublabel: 'In progress…',
                                color: _amber,
                                isDone: false,
                                isActive: true,
                              ),
                              _TimelineConnector(done: false),
                              _TimelineStep(
                                icon: Icons.account_balance_wallet_rounded,
                                label: 'Funds Credited',
                                sublabel: 'Pending admin decision',
                                color: _labelGrey,
                                isDone: false,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Bottom refresh button
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                  decoration: BoxDecoration(
                    color: _white,
                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, -4))],
                  ),
                  child: SafeArea(
                    top: false,
                    child: SizedBox(
                      width: double.infinity, height: 52,
                      child: ElevatedButton.icon(
                        onPressed: isRefreshing ? null : onRefresh,
                        icon: isRefreshing
                            ? const SizedBox(
                                width: 18, height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2.2, color: _white))
                            : const Icon(Icons.refresh_rounded, size: 20, color: _white),
                        label: Text(
                          isRefreshing ? 'Checking…' : 'Refresh Status',
                          style: GoogleFonts.inter(fontSize: 15.5, fontWeight: FontWeight.w700, color: _white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _brandGreen,
                          disabledBackgroundColor: _brandGreen.withOpacity(0.6),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
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

  Widget _detailDivider() => const Padding(
    padding: EdgeInsets.symmetric(vertical: 12),
    child: Divider(color: Color(0xFFF3F4F6), height: 1),
  );
}

// ── Under Review Receipt (shown immediately after submit) ─────────────────────
class _UnderReviewReceipt extends StatelessWidget {
  final String orderId;
  final int amount;
  final String utrId;
  final PaymentMethod paymentMethod;
  final DateTime submittedAt;
  final VoidCallback onDone;

  const _UnderReviewReceipt({
    required this.orderId,
    required this.amount,
    required this.utrId,
    required this.paymentMethod,
    required this.submittedAt,
    required this.onDone,
  });

  String _fmtAmount(int v) {
    final str = v.toString();
    final buf = StringBuffer();
    final len = str.length;
    for (int i = 0; i < len; i++) {
      final pos = len - i;
      buf.write(str[i]);
      if (pos > 3 && (pos - 3) % 2 == 0) buf.write(',');
    }
    return buf.toString();
  }

  String _fmtDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')} '
        '${['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][dt.month - 1]} '
        '${dt.year}, ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final method = paymentMethod == PaymentMethod.upi ? 'UPI Transfer' : 'Bank Transfer (IMPS)';

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
                  padding: const EdgeInsets.fromLTRB(8, 12, 20, 8),
                  child: Row(children: [
                    const SizedBox(width: 40),
                    Expanded(
                      child: Text('Deposit Receipt', textAlign: TextAlign.center,
                          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: _brandGreen)),
                    ),
                    const SizedBox(width: 40),
                  ]),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                    child: Column(
                      children: [
                        // Animated check → amber clock combo icon
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 80, height: 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _amberBg,
                                border: Border.all(color: _amberBorder, width: 2.5),
                                boxShadow: [BoxShadow(color: _amber.withOpacity(0.2), blurRadius: 18, offset: const Offset(0, 6))],
                              ),
                              child: const Icon(Icons.hourglass_top_rounded, color: _amber, size: 38),
                            ),
                            Positioned(
                              bottom: 0, right: 0,
                              child: Container(
                                width: 26, height: 26,
                                decoration: BoxDecoration(
                                  color: _accentGreen,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: _white, width: 2),
                                ),
                                child: const Icon(Icons.check, color: _white, size: 14),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text('Request Submitted!',
                            style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: _titleDark)),
                        const SizedBox(height: 6),
                        Text(
                          'Your deposit is now under admin review.\nFunds will be credited once approved.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w400, color: _subtitleGrey, height: 1.5),
                        ),
                        const SizedBox(height: 28),

                        // Transaction details card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: _white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 14, offset: const Offset(0, 4))],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('TRANSACTION DETAILS',
                                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: _labelGrey, letterSpacing: 1.1)),
                              const SizedBox(height: 16),
                              _InvoiceRow(label: 'Order ID', value: '#$orderId', valueColor: _brandGreen, bold: true),
                              _invoiceDivider(),
                              _InvoiceRow(label: 'UTR / Ref. ID', value: utrId),
                              _invoiceDivider(),
                              _InvoiceRow(label: 'Payment Method', value: method),
                              _invoiceDivider(),
                              _InvoiceRow(label: 'Amount', value: '₹${_fmtAmount(amount)}', bold: true, valueColor: _titleDark),
                              _invoiceDivider(),
                              _InvoiceRow(label: 'Submitted On', value: _fmtDate(submittedAt)),
                              _invoiceDivider(),
                              _InvoiceRow(label: 'Status', value: 'Awaiting Admin Approval', valueColor: _amber, bold: true),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Info note
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: _amberBg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: _amberBorder),
                          ),
                          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Icon(Icons.info_outline_rounded, size: 18, color: _amber),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Admin will review your payment and approve or reject it. You will not be able to submit another deposit until this one is resolved. Save your Order ID for reference.',
                                style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w400, color: const Color(0xFF92400E), height: 1.45),
                              ),
                            ),
                          ]),
                        ),
                      ],
                    ),
                  ),
                ),

                Container(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                  decoration: BoxDecoration(
                    color: _white,
                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, -4))],
                  ),
                  child: SafeArea(
                    top: false,
                    child: SizedBox(
                      width: double.infinity, height: 52,
                      child: ElevatedButton(
                        onPressed: onDone,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _brandGreen, foregroundColor: _white, elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        ),
                        child: Text('Done', style: GoogleFonts.inter(fontSize: 15.5, fontWeight: FontWeight.w700, color: _white)),
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

  Widget _invoiceDivider() => const Padding(
    padding: EdgeInsets.symmetric(vertical: 12),
    child: Divider(color: Color(0xFFF3F4F6), height: 1),
  );
}

// ── Timeline step widget ───────────────────────────────────────────────────────
class _TimelineStep extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final Color color;
  final bool isDone;
  final bool isActive;

  const _TimelineStep({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.color,
    required this.isDone,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(isDone || isActive ? 0.12 : 0.06),
            border: Border.all(
              color: isDone || isActive ? color : _labelGrey.withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: Icon(icon, color: isDone || isActive ? color : _labelGrey, size: 18),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: GoogleFonts.inter(
                      fontSize: 13.5,
                      fontWeight: isDone || isActive ? FontWeight.w700 : FontWeight.w500,
                      color: isDone || isActive ? _titleDark : _labelGrey)),
              const SizedBox(height: 2),
              Text(sublabel,
                  style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w400, color: _subtitleGrey)),
            ],
          ),
        ),
        if (isDone)
          const Icon(Icons.check_circle_rounded, color: _accentGreen, size: 18),
        if (isActive && !isDone)
          Container(
            width: 10, height: 10,
            decoration: const BoxDecoration(color: _amber, shape: BoxShape.circle),
          ),
      ],
    );
  }
}

class _TimelineConnector extends StatelessWidget {
  final bool done;
  const _TimelineConnector({required this.done});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 17),
      child: Container(
        width: 2, height: 22,
        color: done ? _accentGreen.withOpacity(0.4) : _labelGrey.withOpacity(0.2),
      ),
    );
  }
}

// ── Detail row ────────────────────────────────────────────────────────────────
class _DetailRow extends StatelessWidget {
  final String label, value;
  final Color? valueColor;
  final bool bold;
  const _DetailRow({required this.label, required this.value, this.valueColor, this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w400, color: _subtitleGrey)),
      const SizedBox(width: 16),
      Flexible(
        child: Text(value, textAlign: TextAlign.right,
            style: GoogleFonts.inter(fontSize: 13.5,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                color: valueColor ?? _titleDark)),
      ),
    ]);
  }
}

// ── Invoice row ───────────────────────────────────────────────────────────────
class _InvoiceRow extends StatelessWidget {
  final String label, value;
  final Color? valueColor;
  final bool bold;
  const _InvoiceRow({required this.label, required this.value, this.valueColor, this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w400, color: _subtitleGrey)),
      const SizedBox(width: 16),
      Flexible(
        child: Text(value, textAlign: TextAlign.right,
            style: GoogleFonts.inter(fontSize: 13.5,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                color: valueColor ?? _titleDark)),
      ),
    ]);
  }
}

// ── Payment method chip ────────────────────────────────────────────────────────
class _MethodChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _MethodChip({required this.label, required this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          decoration: BoxDecoration(
            color: selected ? _infoBg : _white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? _accentGreen : const Color(0xFFE5E7EB), width: selected ? 2 : 1),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Column(children: [
            Icon(icon, color: selected ? _accentGreen : _labelGrey, size: 24),
            const SizedBox(height: 6),
            Text(label, textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 12.5, fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? _brandGreen : _subtitleGrey)),
          ]),
        ),
      ),
    );
  }
}

// ── Copy row widget ────────────────────────────────────────────────────────────
class _CopyRow extends StatelessWidget {
  final String label, value;
  final VoidCallback? onCopy;
  const _CopyRow({required this.label, required this.value, required this.onCopy});

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: _labelGrey)),
          const SizedBox(height: 2),
          Text(value, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: _titleDark)),
        ]),
      ),
      if (onCopy != null)
        GestureDetector(
          onTap: onCopy,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: _accentGreen.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.copy_rounded, size: 16, color: _accentGreen),
          ),
        ),
    ]);
  }
}