// lib/views/profile/linked_bank_accounts_view.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/bank/bank_account_model.dart';
import '../../viewmodels/bank/bank_account_viewmodel.dart';
import '../../utils/responsive.dart';

// ── Palette (matches profile_screen.dart) ─────────────────────────────────────
const _bgColor = Color(0xFFF7F5F2);
const _white = Color(0xFFFFFFFF);
const _titleDark = Color(0xFF111827);
const _subtitleGrey = Color(0xFF6B7280);
const _brandGreen = Color(0xFF1F6B45); // banner dark green
const _iconBg = Color(0xFFDCF3E5); // banner gradient start
const _iconGreen = Color(0xFF1F6B45); // banner dark green
const _divider = Color(0xFFE8E4DE);
const _errorRed = Color(0xFFDC4444);
const _errorBg = Color(0xFFFBE0E0);

class LinkedBankAccountsView extends StatelessWidget {
  const LinkedBankAccountsView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => BankAccountViewModel(),
      child: const _LinkedBankAccountsContent(),
    );
  }
}

class _LinkedBankAccountsContent extends StatelessWidget {
  const _LinkedBankAccountsContent();

  @override
  Widget build(BuildContext context) {
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
              'Linked Bank Accounts',
              style: TextStyle(
                fontFamily: GoogleFonts.inter().fontFamily,
                fontSize: 17.sp,
                fontWeight: FontWeight.w700,
                color: _titleDark,
              ),
            ),
            centerTitle: true,
          ),
          body: Consumer<BankAccountViewModel>(
            builder: (context, vm, _) {
              return Stack(
                children: [
                  SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.symmetric(
                      horizontal: 20.w,
                      vertical: 8.h,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Info banner ──────────────────────────────────
                        _InfoBanner(),
                        SizedBox(height: 20.h),

                        // ── Account list ─────────────────────────────────
                        if (vm.accounts.isNotEmpty) ...[
                          Text(
                            'Your Accounts (${vm.accounts.length})',
                            style: TextStyle(
                              fontFamily: GoogleFonts.inter().fontFamily,
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                              color: _subtitleGrey,
                            ),
                          ),
                          SizedBox(height: 12.h),
                          ...vm.accounts.map(
                            (acc) => Padding(
                              padding: EdgeInsets.only(bottom: 12.h),
                              child: _AccountTile(account: acc),
                            ),
                          ),
                        ] else ...[
                          _EmptyState(),
                        ],

                        SizedBox(height: 16.h),

                        // ── Add account button ───────────────────────────
                        _AddAccountButton(
                          onTap: () => _showAddAccountSheet(context),
                        ),
                        SizedBox(height: 32.h),
                      ],
                    ),
                  ),

                  // ── Loading overlay ──────────────────────────────────────
                  if (vm.isLoading)
                    Container(
                      color: Colors.white.withOpacity(0.6),
                      child: const Center(
                        child: CircularProgressIndicator(color: _brandGreen),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // ── Add account bottom sheet ──────────────────────────────────────────────
  void _showAddAccountSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<BankAccountViewModel>(),
        child: const _AddAccountSheet(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Info Banner
// ─────────────────────────────────────────────────────────────────────────────
class _InfoBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: _iconBg,
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: _brandGreen, size: 20.sp),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              'Your bank accounts are securely linked for withdrawals and auto-deposits. '
              'Only the Primary account receives payouts.',
              style: TextStyle(
                fontFamily: GoogleFonts.inter().fontFamily,
                fontSize: 12.5.sp,
                fontWeight: FontWeight.w400,
                color: _brandGreen,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Account Tile
// ─────────────────────────────────────────────────────────────────────────────
class _AccountTile extends StatelessWidget {
  final BankAccount account;
  const _AccountTile({required this.account});

  @override
  Widget build(BuildContext context) {
    final vm = context.read<BankAccountViewModel>();

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(16.r),
        border: account.isPrimary
            ? Border.all(color: _brandGreen, width: 1.5.r)
            : Border.all(color: Colors.transparent),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // ── Bank icon ──────────────────────────────────────────────────
          Container(
            width: 48.w,
            height: 48.h,
            decoration: BoxDecoration(
              color: _iconBg,
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(
              Icons.account_balance_outlined,
              color: _iconGreen,
              size: 24.sp,
            ),
          ),
          SizedBox(width: 14.w),

          // ── Bank info ──────────────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      account.bankName,
                      style: TextStyle(
                        fontFamily: GoogleFonts.inter().fontFamily,
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w600,
                        color: _titleDark,
                      ),
                    ),
                    if (account.isPrimary) ...[
                      SizedBox(width: 8.w),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8.w,
                          vertical: 3.h,
                        ),
                        decoration: BoxDecoration(
                          color: _iconBg,
                          borderRadius: BorderRadius.circular(20.r),
                        ),
                        child: Text(
                          'Primary',
                          style: TextStyle(
                            fontFamily: GoogleFonts.inter().fontFamily,
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w600,
                            color: _brandGreen,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: 3.h),
                Text(
                  '${account.accountType}  ·  •••• ${account.accountNumber}',
                  style: TextStyle(
                    fontFamily: GoogleFonts.inter().fontFamily,
                    fontSize: 12.5.sp,
                    fontWeight: FontWeight.w400,
                    color: _subtitleGrey,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  'IFSC: ${account.ifscCode}',
                  style: TextStyle(
                    fontFamily: GoogleFonts.inter().fontFamily,
                    fontSize: 11.5.sp,
                    fontWeight: FontWeight.w400,
                    color: _subtitleGrey,
                  ),
                ),
              ],
            ),
          ),

          // ── Popup menu ─────────────────────────────────────────────────
          PopupMenuButton<String>(
            icon: Icon(
              Icons.more_vert_rounded,
              color: _subtitleGrey,
              size: 22.sp,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.r),
            ),
            onSelected: (value) async {
              if (value == 'primary') {
                if (!account.isPrimary) {
                  await vm.setPrimary(account.id);
                  if (context.mounted) {
                    _showSnack(
                      context,
                      '${account.bankName} set as primary account',
                    );
                  }
                }
              } else if (value == 'remove') {
                final confirmed = await _showRemoveDialog(context, account);
                if (confirmed == true && context.mounted) {
                  final success = await vm.removeAccount(account.id);
                  if (success && context.mounted) {
                    _showSnack(
                      context,
                      '${account.bankName} removed successfully',
                    );
                  }
                }
              }
            },
            itemBuilder: (_) => [
              if (!account.isPrimary)
                PopupMenuItem(
                  value: 'primary',
                  child: Row(
                    children: [
                      Icon(
                        Icons.star_outline_rounded,
                        color: _brandGreen,
                        size: 18.sp,
                      ),
                      SizedBox(width: 10.w),
                      Text(
                        'Set as Primary',
                        style: TextStyle(
                          fontFamily: GoogleFonts.inter().fontFamily,
                          fontSize: 14.sp,
                          color: _titleDark,
                        ),
                      ),
                    ],
                  ),
                ),
              PopupMenuItem(
                value: 'remove',
                child: Row(
                  children: [
                    Icon(
                      Icons.delete_outline_rounded,
                      color: _errorRed,
                      size: 18.sp,
                    ),
                    SizedBox(width: 10.w),
                    Text(
                      'Remove Account',
                      style: TextStyle(
                        fontFamily: GoogleFonts.inter().fontFamily,
                        fontSize: 14.sp,
                        color: _errorRed,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<bool?> _showRemoveDialog(BuildContext context, BankAccount acc) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.r),
        ),
        backgroundColor: _white,
        title: Text(
          'Remove Account?',
          style: TextStyle(
            fontFamily: GoogleFonts.inter().fontFamily,
            fontSize: 17.sp,
            fontWeight: FontWeight.w700,
            color: _titleDark,
          ),
        ),
        content: Text(
          'Are you sure you want to remove ${acc.bankName} (•••• ${acc.accountNumber})? '
          'This action cannot be undone.',
          style: TextStyle(
            fontFamily: GoogleFonts.inter().fontFamily,
            fontSize: 13.5.sp,
            color: _subtitleGrey,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: TextStyle(
                fontFamily: GoogleFonts.inter().fontFamily,
                fontWeight: FontWeight.w600,
                color: _subtitleGrey,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Remove',
              style: TextStyle(
                fontFamily: GoogleFonts.inter().fontFamily,
                fontWeight: FontWeight.w700,
                color: _errorRed,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSnack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: TextStyle(
            fontFamily: GoogleFonts.inter().fontFamily,
            fontSize: 13.5.sp,
            color: _white,
          ),
        ),
        backgroundColor: _brandGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
        ),
        margin: EdgeInsets.all(16.w),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty State
// ─────────────────────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 40.h, horizontal: 24.w),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 72.w,
            height: 72.h,
            decoration: BoxDecoration(
              color: _iconBg,
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: Icon(
              Icons.account_balance_outlined,
              color: _iconGreen,
              size: 36.sp,
            ),
          ),
          SizedBox(height: 16.h),
          Text(
            'No Bank Accounts Linked',
            style: TextStyle(
              fontFamily: GoogleFonts.inter().fontFamily,
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
              color: _titleDark,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'Add a bank account to enable\nwithdrawals and auto-deposits.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: GoogleFonts.inter().fontFamily,
              fontSize: 13.5.sp,
              color: _subtitleGrey,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Add Account Button
// ─────────────────────────────────────────────────────────────────────────────
class _AddAccountButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AddAccountButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 16.h),
        decoration: BoxDecoration(
          color: _white,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: _brandGreen, width: 1.5.r),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_rounded, color: _brandGreen, size: 22.sp),
            SizedBox(width: 8.w),
            Text(
              'Add New Bank Account',
              style: TextStyle(
                fontFamily: GoogleFonts.inter().fontFamily,
                fontSize: 15.sp,
                fontWeight: FontWeight.w600,
                color: _brandGreen,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Add Account Bottom Sheet
// ─────────────────────────────────────────────────────────────────────────────
class _AddAccountSheet extends StatefulWidget {
  const _AddAccountSheet();

  @override
  State<_AddAccountSheet> createState() => _AddAccountSheetState();
}

class _AddAccountSheetState extends State<_AddAccountSheet> {
  final _formKey = GlobalKey<FormState>();
  final _bankNameCtrl = TextEditingController();
  final _accountNumCtrl = TextEditingController();
  final _confirmNumCtrl = TextEditingController();
  final _ifscCtrl = TextEditingController();
  String _accountType = 'Savings';
  bool _submitting = false;

  static const _accountTypes = ['Savings', 'Current'];

  @override
  void dispose() {
    _bankNameCtrl.dispose();
    _accountNumCtrl.dispose();
    _confirmNumCtrl.dispose();
    _ifscCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _submitting = true);
    final vm = context.read<BankAccountViewModel>();

    await vm.addAccount(
      bankName: _bankNameCtrl.text.trim(),
      accountNumber: _accountNumCtrl.text.trim(),
      ifscCode: _ifscCtrl.text.trim(),
      accountType: _accountType,
    );

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Bank account added successfully!',
            style: TextStyle(
              fontFamily: GoogleFonts.inter().fontFamily,
              fontSize: 13.5.sp,
              color: _white,
            ),
          ),
          backgroundColor: _brandGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
          margin: EdgeInsets.all(16.w),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
      ),
      padding: EdgeInsets.fromLTRB(24.w, 0, 24.w, 24.h + bottomPad),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Drag handle ─────────────────────────────────────────────
            Center(
              child: Container(
                margin: EdgeInsets.symmetric(vertical: 14.h),
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8E4DE),
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
            ),
            Text(
              'Add Bank Account',
              style: TextStyle(
                fontFamily: GoogleFonts.inter().fontFamily,
                fontSize: 18.sp,
                fontWeight: FontWeight.w700,
                color: _titleDark,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              'Your details are encrypted and secure.',
              style: TextStyle(
                fontFamily: GoogleFonts.inter().fontFamily,
                fontSize: 13.sp,
                color: _subtitleGrey,
              ),
            ),
            SizedBox(height: 24.h),

            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Bank Name
                  _label('Bank Name'),
                  _field(
                    controller: _bankNameCtrl,
                    hint: 'e.g. HDFC Bank',
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Enter bank name'
                        : null,
                  ),
                  SizedBox(height: 16.h),

                  // Account Number
                  _label('Account Number'),
                  _field(
                    controller: _accountNumCtrl,
                    hint: 'Enter account number',
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    obscureText: true,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty)
                        return 'Enter account number';
                      if (v.trim().length < 9)
                        return 'Account number too short';
                      return null;
                    },
                  ),
                  SizedBox(height: 16.h),

                  // Confirm Account Number
                  _label('Confirm Account Number'),
                  _field(
                    controller: _confirmNumCtrl,
                    hint: 'Re-enter account number',
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) {
                      if (v == null || v.trim().isEmpty)
                        return 'Confirm account number';
                      if (v.trim() != _accountNumCtrl.text.trim()) {
                        return 'Account numbers do not match';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16.h),

                  // IFSC Code
                  _label('IFSC Code'),
                  _field(
                    controller: _ifscCtrl,
                    hint: 'e.g. HDFC0001234',
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                      LengthLimitingTextInputFormatter(11),
                    ],
                    validator: (v) {
                      if (v == null || v.trim().isEmpty)
                        return 'Enter IFSC code';
                      final ifscRegex = RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$');
                      if (!ifscRegex.hasMatch(v.trim().toUpperCase())) {
                        return 'Enter a valid IFSC code (e.g. HDFC0001234)';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16.h),

                  // Account Type
                  _label('Account Type'),
                  SizedBox(height: 8.h),
                  Row(
                    children: _accountTypes.map((type) {
                      final selected = _accountType == type;
                      return Padding(
                        padding: EdgeInsets.only(right: 12.w),
                        child: GestureDetector(
                          onTap: () => setState(() => _accountType = type),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: EdgeInsets.symmetric(
                              horizontal: 20.w,
                              vertical: 10.h,
                            ),
                            decoration: BoxDecoration(
                              color: selected ? _iconBg : _bgColor,
                              borderRadius: BorderRadius.circular(12.r),
                              border: Border.all(
                                color: selected ? _brandGreen : _divider,
                                width: selected ? 1.5 : 1,
                              ),
                            ),
                            child: Text(
                              type,
                              style: TextStyle(
                                fontFamily: GoogleFonts.inter().fontFamily,
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w600,
                                color: selected ? _brandGreen : _subtitleGrey,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  SizedBox(height: 28.h),

                  // Submit button
                  SizedBox(
                    width: double.infinity,
                    height: 54.h,
                    child: ElevatedButton(
                      onPressed: _submitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        disabledBackgroundColor: const Color(
                          0xFF9AE0BC,
                        ).withOpacity(0.5),
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16.r),
                        ),
                        elevation: 0,
                        padding: EdgeInsets.zero,
                      ),
                      child: Ink(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFDCF3E5), Color(0xFF9AE0BC)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16.r),
                        ),
                        child: Container(
                          alignment: Alignment.center,
                          child: _submitting
                              ? SizedBox(
                                  width: 22.w,
                                  height: 22.h,
                                  child: CircularProgressIndicator(
                                    color: const Color(0xFF1F6B45),
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : Text(
                                  'Add Account',
                                  style: TextStyle(
                                    fontFamily: GoogleFonts.inter().fontFamily,
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
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: GoogleFonts.inter().fontFamily,
          fontSize: 13.5.sp,
          fontWeight: FontWeight.w600,
          color: _titleDark,
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    bool obscureText = false,
    TextCapitalization textCapitalization = TextCapitalization.none,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      obscureText: obscureText,
      textCapitalization: textCapitalization,
      validator: validator,
      style: TextStyle(
        fontFamily: GoogleFonts.inter().fontFamily,
        fontSize: 14.sp,
        color: _titleDark,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          fontFamily: GoogleFonts.inter().fontFamily,
          fontSize: 14.sp,
          color: _subtitleGrey,
        ),
        filled: true,
        fillColor: _bgColor,
        contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14.r),
          borderSide: BorderSide(color: _divider, width: 1.r),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14.r),
          borderSide: BorderSide(color: _divider, width: 1.r),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14.r),
          borderSide: BorderSide(color: _brandGreen, width: 1.5.r),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14.r),
          borderSide: BorderSide(color: _errorRed, width: 1.r),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14.r),
          borderSide: BorderSide(color: _errorRed, width: 1.5.r),
        ),
      ),
    );
  }
}
