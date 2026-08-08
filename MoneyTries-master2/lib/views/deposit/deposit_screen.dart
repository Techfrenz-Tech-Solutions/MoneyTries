import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/app_constants.dart';
import '../../core/api/api_config.dart';
import '../../viewmodels/deposit/deposit_viewmodel.dart';
import '../../models/deposit/deposit_models.dart';
import '../../routes/app_routes.dart';
import '../../utils/responsive.dart';
import '../../widgets/animations/animations.dart';

// Same host used by deposit_repository.dart / home_screen.dart for API calls.
const String _kBaseUrl = ApiConfig.baseUrl;

// ── Palette ───────────────────────────────────────────────────────────────────
const _bg            = Color(0xFFF7F5F2);
const _white         = Color(0xFFFFFFFF);
const _titleDark     = Color(0xFF111827);
const _subtitleGrey  = Color(0xFF6B7280);
const _labelGrey     = Color(0xFF9CA3AF);
const _brandGreen    = Color(0xFF4CAF7D);
const _accentGreen   = Color(0xFF4CAF7D);
const _accentGreenEnd= Color(0xFF7DCB9E);
const _infoBg        = Color(0xFFE8F5EE);
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
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _loadAvatar();
  }

  Future<void> _loadAvatar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null) return;
      final res = await http
          .get(
            Uri.parse('$_kBaseUrl/api/profile'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final data = body['data'] as Map<String, dynamic>?;
        if (data != null && mounted) {
          final img = data['profile_image']?.toString();
          // profile_image is a full https:// URL when stored on Cloudinary,
          // and a bare relative path when stored on local disk — only the
          // latter needs the base URL prefixed.
          setState(() {
            _avatarUrl = (img != null && img.isNotEmpty)
                ? (img.startsWith('http') ? img : '$_kBaseUrl/uploads/$img')
                : null;
          });
        }
      }
    } catch (_) {}
  }

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
                        padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 20.h),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            _buildAmountInput(vm),
                            SizedBox(height: 28.h),
                            _buildQuickSelect(vm),
                            SizedBox(height: 24.h),
                            _buildPaymentMethodSelector(vm),
                            SizedBox(height: 20.h),
                            _buildPaymentDetails(vm),
                            SizedBox(height: 20.h),
                            _buildUtrField(vm),
                            SizedBox(height: 20.h),
                            _buildScreenshotPicker(vm),
                            SizedBox(height: 24.h),
                            _buildSummaryCard(vm),
                            if (vm.state == DepositState.error && vm.errorMessage != null)
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

  Widget _buildLoadingScaffold() {
    return Theme(
      data: ThemeData(brightness: Brightness.light, scaffoldBackgroundColor: _bg),
      child: Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: Column(
            children: [
              _buildTopBar(context),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: _accentGreen, strokeWidth: 2.5),
                      SizedBox(height: 16.h),
                      Text('Checking deposit status…',
                          style: TextStyle(fontSize: 14.sp, color: _subtitleGrey)),
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
      padding: EdgeInsets.fromLTRB(8.w, 12.h, 20.w, 8.h),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Padding(
              padding: EdgeInsets.all(8.w),
              child: Icon(Icons.arrow_back, color: _brandGreen, size: 24.sp),
            ),
          ),
          SizedBox(width: 4.w),
          Text('Deposit Funds',
              style: TextStyle(fontFamily: 'Times New Roman',fontSize: 18.sp, fontWeight: FontWeight.w700, color: _brandGreen)),
          const Spacer(),
          AnimatedTapScale(
            scaleDown: 0.9,
            onTap: () => Navigator.pushNamed(context, AppRoutes.profile)
                .then((_) => _loadAvatar()),
            child: Hero(
              tag: kAppTopbarAvatarHeroTag,
              child: Container(
                width: 38.w, height: 38.h,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _white, width: 2.r),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6, offset: const Offset(0, 2))],
                ),
                child: ClipOval(
                  child: Container(
                    color: const Color(0xFFB2DFC5),
                    child: _avatarUrl != null
                        ? ShimmerNetworkImage(
                            url: _avatarUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                Icon(Icons.person, color: _white, size: 22.sp),
                          )
                        : Icon(Icons.person, color: _white, size: 22.sp),
                  ),
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
            style: TextStyle(fontFamily: 'Times New Roman',fontSize: 12.sp, fontWeight: FontWeight.w600, color: _labelGrey, letterSpacing: 1.0)),
        SizedBox(height: 14.h),
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
                      padding: EdgeInsets.only(right: 6.w, top: 6.h),
                      child: Text('₹', style: TextStyle(fontFamily: 'Times New Roman',fontSize: 28.sp, fontWeight: FontWeight.w600, color: _titleDark)),
                    ),
                    Flexible(
                      child: TextField(
                        controller: _amountController,
                        onChanged: (v) => vm.setAmount(int.tryParse(v) ?? 0),
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        cursorColor: _accentGreen,
                        style: TextStyle(fontFamily: 'Times New Roman',fontSize: 40.sp, fontWeight: FontWeight.w800, color: _titleDark),
                        decoration: const InputDecoration(isDense: true, border: InputBorder.none, contentPadding: EdgeInsets.zero),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        SizedBox(height: 6.h),
        Container(height: 2.h, width: 140.w,
            decoration: BoxDecoration(color: _accentGreen.withOpacity(0.4), borderRadius: BorderRadius.circular(2.r))),
        if (vm.amount > AppConstants.maxTransactionAmount) ...[
          SizedBox(height: 10.h),
          Text(
            AppConstants.maxTransactionAmountMessage,
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Times New Roman', fontSize: 12.5.sp, fontWeight: FontWeight.w600, color: _errorRed),
          ),
        ],
      ],
    );
  }

  Widget _buildQuickSelect(DepositViewModel vm) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('QUICK SELECT',
            style: TextStyle(fontFamily: 'Times New Roman',fontSize: 12.sp, fontWeight: FontWeight.w600, color: _labelGrey, letterSpacing: 1.0)),
        SizedBox(height: 12.h),
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
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                    decoration: BoxDecoration(
                      color: _white,
                      borderRadius: BorderRadius.circular(14.r),
                      border: Border.all(color: selected ? _accentGreen : const Color(0xFFE8E4DE), width: selected ? 2 : 1),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
                    ),
                    child: Column(
                      children: [
                        Text(q.label, style: TextStyle(fontFamily: 'Times New Roman',fontSize: 12.5.sp, fontWeight: FontWeight.w500, color: _subtitleGrey)),
                        SizedBox(height: 4.h),
                        Text('₹${_fmt(q.amount)}', style: TextStyle(fontFamily: 'Times New Roman',fontSize: 15.sp, fontWeight: FontWeight.w800, color: _titleDark)),
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
            style: TextStyle(fontFamily: 'Times New Roman',fontSize: 12.sp, fontWeight: FontWeight.w600, color: _labelGrey, letterSpacing: 1.0)),
        SizedBox(height: 12.h),
        Row(
          children: [
            _MethodChip(
              label: 'UPI Transfer', icon: Icons.qr_code_scanner_rounded,
              selected: vm.paymentMethod == PaymentMethod.upi,
              onTap: () => vm.setPaymentMethod(PaymentMethod.upi),
            ),
            SizedBox(width: 12.w),
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
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: _infoBg,
        borderRadius: BorderRadius.circular(16.r),
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
            style: TextStyle(fontFamily: 'Times New Roman',fontSize: 13.sp, fontWeight: FontWeight.w500, color: _infoText)),
        SizedBox(height: 10.h),
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
            style: TextStyle(fontFamily: 'Times New Roman',fontSize: 13.sp, fontWeight: FontWeight.w500, color: _infoText)),
        SizedBox(height: 10.h),
        _CopyRow(label: 'Account Name', value: DepositViewModel.bankAccountName,
            onCopy: () => _copyToClipboard(DepositViewModel.bankAccountName, 'Account Name')),
        SizedBox(height: 8.h),
        _CopyRow(label: 'Account No.', value: DepositViewModel.bankAccountNumber,
            onCopy: () => _copyToClipboard(DepositViewModel.bankAccountNumber, 'Account Number')),
        SizedBox(height: 8.h),
        _CopyRow(label: 'IFSC', value: DepositViewModel.bankIfsc,
            onCopy: () => _copyToClipboard(DepositViewModel.bankIfsc, 'IFSC Code')),
        SizedBox(height: 8.h),
        _CopyRow(label: 'Account Type', value: DepositViewModel.bankAccountType, onCopy: null),
      ],
    );
  }

  Widget _buildUtrField(DepositViewModel vm) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('UTR / TRANSACTION ID',
            style: TextStyle(fontFamily: 'Times New Roman',fontSize: 12.sp, fontWeight: FontWeight.w600, color: _labelGrey, letterSpacing: 1.0)),
        SizedBox(height: 10.h),
        Container(
          decoration: BoxDecoration(
            color: _white,
            borderRadius: BorderRadius.circular(14.r),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: TextField(
            controller: _utrController,
            onChanged: vm.setUtrId,
            keyboardType: TextInputType.text,
            textCapitalization: TextCapitalization.characters,
            cursorColor: _accentGreen,
            style: TextStyle(fontFamily: 'Times New Roman',fontSize: 15.sp, fontWeight: FontWeight.w600, color: _titleDark),
            decoration: InputDecoration(
              hintText: 'Enter UTR / Ref. No.',
              hintStyle: TextStyle(fontFamily: 'Times New Roman',fontSize: 14.sp, fontWeight: FontWeight.w400, color: _labelGrey),
              prefixIcon: Icon(Icons.tag_rounded, color: _accentGreen, size: 20.sp),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
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
            style: TextStyle(fontFamily: 'Times New Roman',fontSize: 12.sp, fontWeight: FontWeight.w600, color: _labelGrey, letterSpacing: 1.0)),
        SizedBox(height: 10.h),
        if (vm.screenshot == null)
          GestureDetector(
            onTap: () => _pickImage(vm),
            child: Container(
              width: double.infinity, height: 110.h,
              decoration: BoxDecoration(
                color: _white,
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(color: _accentGreen.withOpacity(0.35), width: 1.5.r),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: EdgeInsets.all(12.w),
                    decoration: const BoxDecoration(color: _infoBg, shape: BoxShape.circle),
                    child: Icon(Icons.upload_rounded, color: _accentGreen, size: 26.sp),
                  ),
                  SizedBox(height: 8.h),
                  Text('Tap to upload screenshot',
                      style: TextStyle(fontFamily: 'Times New Roman',fontSize: 13.5.sp, fontWeight: FontWeight.w600, color: _accentGreen)),
                  SizedBox(height: 2.h),
                  Text('JPG or PNG from your gallery',
                      style: TextStyle(fontFamily: 'Times New Roman',fontSize: 11.5.sp, fontWeight: FontWeight.w400, color: _labelGrey)),
                ],
              ),
            ),
          )
        else
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16.r),
                child: Image.file(vm.screenshot!, width: double.infinity, height: 180.h, fit: BoxFit.cover),
              ),
              Positioned(
                top: 8, right: 8,
                child: GestureDetector(
                  onTap: vm.clearScreenshot,
                  child: Container(
                    padding: EdgeInsets.all(6.w),
                    decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                    child: Icon(Icons.close, color: _white, size: 16.sp),
                  ),
                ),
              ),
              Positioned(
                bottom: 8, left: 8,
                child: GestureDetector(
                  onTap: () => _pickImage(vm),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                    decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20.r)),
                    child: Text('Change', style: TextStyle(fontFamily: 'Times New Roman',fontSize: 12.sp, fontWeight: FontWeight.w600, color: _white)),
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
      padding: EdgeInsets.fromLTRB(18.w, 18.h, 18.w, 18.h),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(18.r),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Gateway Charges', style: TextStyle(fontFamily: 'Times New Roman',fontSize: 14.sp, fontWeight: FontWeight.w500, color: _subtitleGrey)),
            Text('₹0', style: TextStyle(fontFamily: 'Times New Roman',fontSize: 14.sp, fontWeight: FontWeight.w700, color: _accentGreen)),
          ]),
          SizedBox(height: 14.h),
          Divider(color: Color(0xFFE8E4DE), height: 1.h),
          SizedBox(height: 14.h),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Total to Pay', style: TextStyle(fontFamily: 'Times New Roman',fontSize: 16.sp, fontWeight: FontWeight.w800, color: _titleDark)),
            Text('₹${_fmt(vm.amount)}', style: TextStyle(fontFamily: 'Times New Roman',fontSize: 18.sp, fontWeight: FontWeight.w800, color: _titleDark)),
          ]),
          SizedBox(height: 16.h),
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(color: _infoBg, borderRadius: BorderRadius.circular(12.r), border: Border.all(color: _infoBorder, width: 1.r)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.info_outline_rounded, size: 18.sp, color: _accentGreen),
              SizedBox(width: 10.w),
              Expanded(
                child: Text(
                  'Complete the payment, then enter your UTR/Ref. ID and upload the screenshot before submitting.',
                  style: TextStyle(fontFamily: 'Times New Roman',fontSize: 12.5.sp, fontWeight: FontWeight.w400, color: _infoText, height: 1.45),
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
      margin: EdgeInsets.only(top: 14.h),
      width: double.infinity,
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: _errorRed.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: _errorRed.withOpacity(0.3)),
      ),
      child: Row(children: [
        Icon(Icons.error_outline_rounded, color: _errorRed, size: 20.sp),
        SizedBox(width: 10.w),
        Expanded(child: Text(message, style: TextStyle(fontFamily: 'Times New Roman',fontSize: 13.sp, fontWeight: FontWeight.w500, color: _errorRed))),
      ]),
    );
  }

  /// In-flow submit action — sits naturally at the end of the scrollable
  /// content (no longer pinned to the bottom of the screen) so it moves
  /// with the page and every section above it stays reachable while
  /// scrolling, on any screen size.
  Widget _buildSubmitAction(DepositViewModel vm) {
    final isLoading = vm.state == DepositState.loading;
    // Form-validity only (excludes the loading state) so the button keeps
    // its full brand color while the spinner is showing, matching the
    // in-flight look used by CRED/GPay-style submit buttons, rather than
    // dimming to the disabled color during a request that will succeed.
    final formValid = vm.amount > 0 &&
        vm.amount <= AppConstants.maxTransactionAmount &&
        vm.utrId.isNotEmpty &&
        vm.screenshot != null;
    final enabled = formValid && !isLoading;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(height: 1, color: const Color(0xFFEFEBE4)),
        SizedBox(height: 20.h),
        AnimatedPrimaryButton(
          label: 'Submit Deposit Request',
          height: 52.h,
          borderRadius: 30.r,
          color: _accentGreenEnd,
          disabledColor: _accentGreenEnd.withOpacity(0.5),
          textColor: _white,
          enabled: formValid,
          loading: isLoading,
          onPressed: enabled ? () => _submit(vm) : null,
          textStyle: TextStyle(
            fontFamily: 'Times New Roman',
            fontSize: 15.5.sp,
            fontWeight: FontWeight.w700,
            color: _white,
          ),
        ),
      ],
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
                  padding: EdgeInsets.fromLTRB(8.w, 12.h, 20.w, 8.h),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Padding(
                          padding: EdgeInsets.all(8.w),
                          child: Icon(Icons.arrow_back, color: _brandGreen, size: 24.sp),
                        ),
                      ),
                      SizedBox(width: 4.w),
                      Text('Deposit Funds',
                          style: TextStyle(fontFamily: 'Times New Roman',fontSize: 18.sp, fontWeight: FontWeight.w700, color: _brandGreen)),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 24.h),
                    child: Column(
                      children: [
                        // Pulsing clock icon
                        Container(
                          width: 80.w, height: 80.h,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _amberBg,
                            border: Border.all(color: _amberBorder, width: 2.r),
                            boxShadow: [BoxShadow(color: _amber.withOpacity(0.15), blurRadius: 18, offset: const Offset(0, 6))],
                          ),
                          child: Icon(Icons.hourglass_top_rounded, color: _amber, size: 38.sp),
                        ),
                        SizedBox(height: 16.h),
                        Text('Deposit Under Review',
                            style: TextStyle(fontFamily: 'Times New Roman',fontSize: 22.sp, fontWeight: FontWeight.w800, color: _titleDark)),
                        SizedBox(height: 8.h),
                        Text(
                          'Your deposit request is being reviewed\nby our team. Please wait for approval.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontFamily: 'Times New Roman',fontSize: 13.5.sp, fontWeight: FontWeight.w400, color: _subtitleGrey, height: 1.55),
                        ),
                        SizedBox(height: 28.h),

                        // Deposit details card
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
                                  Text('DEPOSIT DETAILS',
                                      style: TextStyle(fontFamily: 'Times New Roman',fontSize: 11.sp, fontWeight: FontWeight.w700, color: _labelGrey, letterSpacing: 1.1)),
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                                    decoration: BoxDecoration(
                                      color: _amberBg,
                                      borderRadius: BorderRadius.circular(20.r),
                                      border: Border.all(color: _amberBorder),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(width: 6.w, height: 6.h,
                                            decoration: const BoxDecoration(color: _amber, shape: BoxShape.circle)),
                                        SizedBox(width: 5.w),
                                        Text('Under Review',
                                            style: TextStyle(fontFamily: 'Times New Roman',fontSize: 11.5.sp, fontWeight: FontWeight.w700, color: _amber)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 16.h),
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
                        SizedBox(height: 20.h),

                        // Info note
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(14.w),
                          decoration: BoxDecoration(
                            color: _amberBg,
                            borderRadius: BorderRadius.circular(14.r),
                            border: Border.all(color: _amberBorder),
                          ),
                          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Icon(Icons.lock_clock_outlined, size: 18.sp, color: _amber),
                            SizedBox(width: 10.w),
                            Expanded(
                              child: Text(
                                'You can only have one active deposit request at a time. Once this request is approved or rejected by our admin team, you will be able to submit a new one.',
                                style: TextStyle(fontFamily: 'Times New Roman',fontSize: 12.5.sp, fontWeight: FontWeight.w400, color: const Color(0xFF92400E), height: 1.5),
                              ),
                            ),
                          ]),
                        ),
                        SizedBox(height: 20.h),

                        // Steps timeline
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(18.w),
                          decoration: BoxDecoration(
                            color: _white,
                            borderRadius: BorderRadius.circular(16.r),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3))],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('APPROVAL PROGRESS',
                                  style: TextStyle(fontFamily: 'Times New Roman',fontSize: 11.sp, fontWeight: FontWeight.w700, color: _labelGrey, letterSpacing: 1.1)),
                              SizedBox(height: 16.h),
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
                            ? SizedBox(
                                width: 18.w, height: 18.h,
                                child: CircularProgressIndicator(strokeWidth: 2.2, color: _white))
                            : Icon(Icons.refresh_rounded, size: 20.sp, color: _white),
                        label: Text(
                          isRefreshing ? 'Checking…' : 'Refresh Status',
                          style: TextStyle(fontFamily: 'Times New Roman',fontSize: 15.5.sp, fontWeight: FontWeight.w700, color: _white),
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

  Widget _detailDivider() => Padding(
    padding: EdgeInsets.symmetric(vertical: 12.h),
    child: Divider(color: Color(0xFFF3F4F6), height: 1.h),
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
                  padding: EdgeInsets.fromLTRB(8.w, 12.h, 20.w, 8.h),
                  child: Row(children: [
                    SizedBox(width: 40.w),
                    Expanded(
                      child: Text('Deposit Receipt', textAlign: TextAlign.center,
                          style: TextStyle(fontFamily: 'Times New Roman',fontSize: 18.sp, fontWeight: FontWeight.w700, color: _brandGreen)),
                    ),
                    SizedBox(width: 40.w),
                  ]),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 20.h),
                    child: Column(
                      children: [
                        // Animated check → amber clock combo icon. Pops in
                        // with a slight overshoot so the moment of
                        // submission feels acknowledged, not just displayed.
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: 1),
                          duration: const Duration(milliseconds: 550),
                          curve: Curves.elasticOut,
                          builder: (context, scale, child) =>
                              Transform.scale(scale: scale, child: child),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 80.w, height: 80.h,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _amberBg,
                                  border: Border.all(color: _amberBorder, width: 2.5.r),
                                  boxShadow: [BoxShadow(color: _amber.withOpacity(0.2), blurRadius: 18, offset: const Offset(0, 6))],
                                ),
                                child: Icon(Icons.hourglass_top_rounded, color: _amber, size: 38.sp),
                              ),
                              Positioned(
                                bottom: 0, right: 0,
                                child: Container(
                                  width: 26.w, height: 26.h,
                                  decoration: BoxDecoration(
                                    color: _accentGreen,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: _white, width: 2.r),
                                  ),
                                  child: Icon(Icons.check, color: _white, size: 14.sp),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 14.h),
                        StaggeredEntrance(
                          index: 0,
                          baseDelay: const Duration(milliseconds: 250),
                          child: Text('Request Submitted!',
                              style: TextStyle(fontFamily: 'Times New Roman',fontSize: 22.sp, fontWeight: FontWeight.w800, color: _titleDark)),
                        ),
                        SizedBox(height: 6.h),
                        Text(
                          'Your deposit is now under admin review.\nFunds will be credited once approved.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontFamily: 'Times New Roman',fontSize: 13.5.sp, fontWeight: FontWeight.w400, color: _subtitleGrey, height: 1.5),
                        ),
                        SizedBox(height: 28.h),

                        // Transaction details card
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
                                  style: TextStyle(fontFamily: 'Times New Roman',fontSize: 11.sp, fontWeight: FontWeight.w700, color: _labelGrey, letterSpacing: 1.1)),
                              SizedBox(height: 16.h),
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
                        SizedBox(height: 20.h),

                        // Info note
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(14.w),
                          decoration: BoxDecoration(
                            color: _amberBg,
                            borderRadius: BorderRadius.circular(14.r),
                            border: Border.all(color: _amberBorder),
                          ),
                          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Icon(Icons.info_outline_rounded, size: 18.sp, color: _amber),
                            SizedBox(width: 10.w),
                            Expanded(
                              child: Text(
                                'Admin will review your payment and approve or reject it. You will not be able to submit another deposit until this one is resolved. Save your Order ID for reference.',
                                style: TextStyle(fontFamily: 'Times New Roman',fontSize: 12.5.sp, fontWeight: FontWeight.w400, color: const Color(0xFF92400E), height: 1.45),
                              ),
                            ),
                          ]),
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
                      child: ElevatedButton(
                        onPressed: onDone,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _brandGreen, foregroundColor: _white, elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30.r)),
                        ),
                        child: Text('Done', style: TextStyle(fontFamily: 'Times New Roman',fontSize: 15.5.sp, fontWeight: FontWeight.w700, color: _white)),
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

  Widget _invoiceDivider() => Padding(
    padding: EdgeInsets.symmetric(vertical: 12.h),
    child: Divider(color: Color(0xFFF3F4F6), height: 1.h),
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
          width: 36.w, height: 36.h,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(isDone || isActive ? 0.12 : 0.06),
            border: Border.all(
              color: isDone || isActive ? color : _labelGrey.withOpacity(0.3),
              width: 1.5.r,
            ),
          ),
          child: Icon(icon, color: isDone || isActive ? color : _labelGrey, size: 18.sp),
        ),
        SizedBox(width: 14.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(fontFamily: 'Times New Roman',
                      fontSize: 13.5.sp,
                      fontWeight: isDone || isActive ? FontWeight.w700 : FontWeight.w500,
                      color: isDone || isActive ? _titleDark : _labelGrey)),
              SizedBox(height: 2.h),
              Text(sublabel,
                  style: TextStyle(fontFamily: 'Times New Roman',fontSize: 11.5.sp, fontWeight: FontWeight.w400, color: _subtitleGrey)),
            ],
          ),
        ),
        if (isDone)
          Icon(Icons.check_circle_rounded, color: _accentGreen, size: 18.sp),
        if (isActive && !isDone)
          Container(
            width: 10.w, height: 10.h,
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
      padding: EdgeInsets.only(left: 17.w),
      child: Container(
        width: 2.w, height: 22.h,
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
      Text(label, style: TextStyle(fontFamily: 'Times New Roman',fontSize: 13.5.sp, fontWeight: FontWeight.w400, color: _subtitleGrey)),
      SizedBox(width: 16.w),
      Flexible(
        child: Text(value, textAlign: TextAlign.right,
            style: TextStyle(fontFamily: 'Times New Roman',fontSize: 13.5.sp,
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
      Text(label, style: TextStyle(fontFamily: 'Times New Roman',fontSize: 13.5.sp, fontWeight: FontWeight.w400, color: _subtitleGrey)),
      SizedBox(width: 16.w),
      Flexible(
        child: Text(value, textAlign: TextAlign.right,
            style: TextStyle(fontFamily: 'Times New Roman',fontSize: 13.5.sp,
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
          padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 10.w),
          decoration: BoxDecoration(
            color: selected ? _infoBg : _white,
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(color: selected ? _accentGreen : const Color(0xFFE8E4DE), width: selected ? 2 : 1),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Column(children: [
            Icon(icon, color: selected ? _accentGreen : _labelGrey, size: 24.sp),
            SizedBox(height: 6.h),
            Text(label, textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Times New Roman',fontSize: 12.5.sp, fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
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
          Text(label, style: TextStyle(fontFamily: 'Times New Roman',fontSize: 11.sp, fontWeight: FontWeight.w500, color: _labelGrey)),
          SizedBox(height: 2.h),
          Text(value, style: TextStyle(fontFamily: 'Times New Roman',fontSize: 14.sp, fontWeight: FontWeight.w700, color: _titleDark)),
        ]),
      ),
      if (onCopy != null)
        GestureDetector(
          onTap: onCopy,
          child: Container(
            padding: EdgeInsets.all(6.w),
            decoration: BoxDecoration(color: _accentGreen.withOpacity(0.12), borderRadius: BorderRadius.circular(8.r)),
            child: Icon(Icons.copy_rounded, size: 16.sp, color: _accentGreen),
          ),
        ),
    ]);
  }
}