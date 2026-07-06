// lib/views/profile/linked_bank_accounts_view.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/bank/bank_account_model.dart';
import '../../viewmodels/bank/bank_account_viewmodel.dart';

// ── Palette (matches profile_screen.dart) ─────────────────────────────────────
const _bgColor      = Color(0xFFECEFF5);
const _white        = Color(0xFFFFFFFF);
const _titleDark    = Color(0xFF111827);
const _subtitleGrey = Color(0xFF6B7280);
const _brandGreen   = Color(0xFF3D9E6A);
const _iconBg       = Color(0xFFD0EDDC);
const _iconGreen    = Color(0xFF3D9E6A);
const _divider      = Color(0xFFE5E7EB);
const _errorRed     = Color(0xFFDC4444);
const _errorBg      = Color(0xFFFBE0E0);

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
      data: ThemeData(brightness: Brightness.light, scaffoldBackgroundColor: _bgColor),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: Scaffold(
          backgroundColor: _bgColor,
          appBar: AppBar(
            backgroundColor: _bgColor,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _titleDark, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              'Linked Bank Accounts',
              style: GoogleFonts.poppins(
                  fontSize: 17, fontWeight: FontWeight.w700, color: _titleDark),
            ),
            centerTitle: true,
          ),
          body: Consumer<BankAccountViewModel>(
            builder: (context, vm, _) {
              return Stack(
                children: [
                  SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Info banner ──────────────────────────────────
                        _InfoBanner(),
                        const SizedBox(height: 20),

                        // ── Account list ─────────────────────────────────
                        if (vm.accounts.isNotEmpty) ...[
                          Text(
                            'Your Accounts (${vm.accounts.length})',
                            style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: _subtitleGrey),
                          ),
                          const SizedBox(height: 12),
                          ...vm.accounts.map((acc) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _AccountTile(account: acc),
                              )),
                        ] else ...[
                          _EmptyState(),
                        ],

                        const SizedBox(height: 16),

                        // ── Add account button ───────────────────────────
                        _AddAccountButton(
                          onTap: () => _showAddAccountSheet(context),
                        ),
                        const SizedBox(height: 32),
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _iconBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: _brandGreen, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Your bank accounts are securely linked for withdrawals and auto-deposits. '
              'Only the Primary account receives payouts.',
              style: GoogleFonts.poppins(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w400,
                  color: _brandGreen,
                  height: 1.5),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(16),
        border: account.isPrimary
            ? Border.all(color: _brandGreen, width: 1.5)
            : Border.all(color: Colors.transparent),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          // ── Bank icon ──────────────────────────────────────────────────
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
                color: _iconBg, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.account_balance_outlined,
                color: _iconGreen, size: 24),
          ),
          const SizedBox(width: 14),

          // ── Bank info ──────────────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      account.bankName,
                      style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: _titleDark),
                    ),
                    if (account.isPrimary) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _iconBg,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Primary',
                          style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _brandGreen),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${account.accountType}  ·  •••• ${account.accountNumber}',
                  style: GoogleFonts.poppins(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w400,
                      color: _subtitleGrey),
                ),
                const SizedBox(height: 2),
                Text(
                  'IFSC: ${account.ifscCode}',
                  style: GoogleFonts.poppins(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w400,
                      color: _subtitleGrey),
                ),
              ],
            ),
          ),

          // ── Popup menu ─────────────────────────────────────────────────
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded,
                color: _subtitleGrey, size: 22),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (value) async {
              if (value == 'primary') {
                if (!account.isPrimary) {
                  await vm.setPrimary(account.id);
                  if (context.mounted) {
                    _showSnack(context, '${account.bankName} set as primary account');
                  }
                }
              } else if (value == 'remove') {
                final confirmed = await _showRemoveDialog(context, account);
                if (confirmed == true && context.mounted) {
                  final success = await vm.removeAccount(account.id);
                  if (success && context.mounted) {
                    _showSnack(context, '${account.bankName} removed successfully');
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
                      const Icon(Icons.star_outline_rounded,
                          color: _brandGreen, size: 18),
                      const SizedBox(width: 10),
                      Text('Set as Primary',
                          style: GoogleFonts.poppins(
                              fontSize: 14, color: _titleDark)),
                    ],
                  ),
                ),
              PopupMenuItem(
                value: 'remove',
                child: Row(
                  children: [
                    const Icon(Icons.delete_outline_rounded,
                        color: _errorRed, size: 18),
                    const SizedBox(width: 10),
                    Text('Remove Account',
                        style: GoogleFonts.poppins(
                            fontSize: 14, color: _errorRed)),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: _white,
        title: Text(
          'Remove Account?',
          style: GoogleFonts.poppins(
              fontSize: 17, fontWeight: FontWeight.w700, color: _titleDark),
        ),
        content: Text(
          'Are you sure you want to remove ${acc.bankName} (•••• ${acc.accountNumber})? '
          'This action cannot be undone.',
          style: GoogleFonts.poppins(
              fontSize: 13.5, color: _subtitleGrey, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600, color: _subtitleGrey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Remove',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700, color: _errorRed)),
          ),
        ],
      ),
    );
  }

  void _showSnack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: GoogleFonts.poppins(fontSize: 13.5, color: _white)),
      backgroundColor: _brandGreen,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 2),
    ));
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
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
                color: _iconBg, borderRadius: BorderRadius.circular(20)),
            child: const Icon(Icons.account_balance_outlined,
                color: _iconGreen, size: 36),
          ),
          const SizedBox(height: 16),
          Text(
            'No Bank Accounts Linked',
            style: GoogleFonts.poppins(
                fontSize: 16, fontWeight: FontWeight.w700, color: _titleDark),
          ),
          const SizedBox(height: 8),
          Text(
            'Add a bank account to enable\nwithdrawals and auto-deposits.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
                fontSize: 13.5, color: _subtitleGrey, height: 1.5),
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
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: _white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _brandGreen, width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_rounded, color: _brandGreen, size: 22),
            const SizedBox(width: 8),
            Text(
              'Add New Bank Account',
              style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: _brandGreen),
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
  final _bankNameCtrl    = TextEditingController();
  final _accountNumCtrl  = TextEditingController();
  final _confirmNumCtrl  = TextEditingController();
  final _ifscCtrl        = TextEditingController();
  String _accountType    = 'Savings';
  bool _submitting       = false;

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
      bankName:      _bankNameCtrl.text.trim(),
      accountNumber: _accountNumCtrl.text.trim(),
      ifscCode:      _ifscCtrl.text.trim(),
      accountType:   _accountType,
    );

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Bank account added successfully!',
            style: GoogleFonts.poppins(fontSize: 13.5, color: _white)),
        backgroundColor: _brandGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + bottomPad),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Drag handle ─────────────────────────────────────────────
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 14),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Text(
              'Add Bank Account',
              style: GoogleFonts.poppins(
                  fontSize: 18, fontWeight: FontWeight.w700, color: _titleDark),
            ),
            const SizedBox(height: 4),
            Text(
              'Your details are encrypted and secure.',
              style: GoogleFonts.poppins(
                  fontSize: 13, color: _subtitleGrey),
            ),
            const SizedBox(height: 24),

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
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Enter bank name' : null,
                  ),
                  const SizedBox(height: 16),

                  // Account Number
                  _label('Account Number'),
                  _field(
                    controller: _accountNumCtrl,
                    hint: 'Enter account number',
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    obscureText: true,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Enter account number';
                      if (v.trim().length < 9) return 'Account number too short';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Confirm Account Number
                  _label('Confirm Account Number'),
                  _field(
                    controller: _confirmNumCtrl,
                    hint: 'Re-enter account number',
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Confirm account number';
                      if (v.trim() != _accountNumCtrl.text.trim()) {
                        return 'Account numbers do not match';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

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
                      if (v == null || v.trim().isEmpty) return 'Enter IFSC code';
                      final ifscRegex = RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$');
                      if (!ifscRegex.hasMatch(v.trim().toUpperCase())) {
                        return 'Enter a valid IFSC code (e.g. HDFC0001234)';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Account Type
                  _label('Account Type'),
                  const SizedBox(height: 8),
                  Row(
                    children: _accountTypes.map((type) {
                      final selected = _accountType == type;
                      return Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: GestureDetector(
                          onTap: () => setState(() => _accountType = type),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 10),
                            decoration: BoxDecoration(
                              color: selected ? _iconBg : _bgColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color:
                                    selected ? _brandGreen : _divider,
                                width: selected ? 1.5 : 1,
                              ),
                            ),
                            child: Text(
                              type,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color:
                                    selected ? _brandGreen : _subtitleGrey,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 28),

                  // Submit button
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _submitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _brandGreen,
                        disabledBackgroundColor: _brandGreen.withOpacity(0.6),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: _submitting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  color: _white, strokeWidth: 2.5),
                            )
                          : Text(
                              'Add Account',
                              style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: _white),
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
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: GoogleFonts.poppins(
            fontSize: 13.5, fontWeight: FontWeight.w600, color: _titleDark),
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
      style: GoogleFonts.poppins(fontSize: 14, color: _titleDark),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.poppins(fontSize: 14, color: _subtitleGrey),
        filled: true,
        fillColor: _bgColor,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _divider, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _divider, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _brandGreen, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _errorRed, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _errorRed, width: 1.5),
        ),
      ),
    );
  }
}