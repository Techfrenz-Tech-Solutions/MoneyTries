// lib/viewmodels/bank/bank_account_viewmodel.dart

import 'package:flutter/material.dart';
import '../../models/bank/bank_account_model.dart';

class BankAccountViewModel extends ChangeNotifier {
  // ── Seed data — replace with API calls in production ──────────────────────
  final List<BankAccount> _accounts = [
    const BankAccount(
      id: 'acc_1',
      bankName: 'HDFC Bank',
      accountNumber: '4821',
      ifscCode: 'HDFC0001234',
      accountType: 'Savings',
      isPrimary: true,
    ),
    const BankAccount(
      id: 'acc_2',
      bankName: 'ICICI Bank',
      accountNumber: '7303',
      ifscCode: 'ICIC0005678',
      accountType: 'Current',
      isPrimary: false,
    ),
  ];

  bool _isLoading = false;
  String? _error;

  // ── Getters ───────────────────────────────────────────────────────────────
  List<BankAccount> get accounts => List.unmodifiable(_accounts);
  bool get isLoading => _isLoading;
  String? get error => _error;
  BankAccount? get primaryAccount =>
      _accounts.where((a) => a.isPrimary).firstOrNull;

  // ── Set as primary ────────────────────────────────────────────────────────
  Future<void> setPrimary(String id) async {
    _setLoading(true);
    await Future.delayed(const Duration(milliseconds: 600)); // simulate API

    for (int i = 0; i < _accounts.length; i++) {
      _accounts[i] = _accounts[i].copyWith(isPrimary: _accounts[i].id == id);
    }
    _setLoading(false);
  }

  // ── Remove account ────────────────────────────────────────────────────────
  Future<bool> removeAccount(String id) async {
    final index = _accounts.indexWhere((a) => a.id == id);
    if (index == -1) return false;

    final wasPrimary = _accounts[index].isPrimary;
    _setLoading(true);
    await Future.delayed(const Duration(milliseconds: 600)); // simulate API

    _accounts.removeAt(index);

    // If we removed the primary and others exist, promote the first one
    if (wasPrimary && _accounts.isNotEmpty) {
      _accounts[0] = _accounts[0].copyWith(isPrimary: true);
    }

    _setLoading(false);
    return true;
  }

  // ── Add account ───────────────────────────────────────────────────────────
  Future<void> addAccount({
    required String bankName,
    required String accountNumber,
    required String ifscCode,
    required String accountType,
  }) async {
    _setLoading(true);
    await Future.delayed(const Duration(milliseconds: 800)); // simulate API

    final newId = 'acc_${DateTime.now().millisecondsSinceEpoch}';
    final isFirst = _accounts.isEmpty;

    _accounts.add(BankAccount(
      id: newId,
      bankName: bankName,
      accountNumber: accountNumber.length > 4
          ? accountNumber.substring(accountNumber.length - 4)
          : accountNumber,
      ifscCode: ifscCode.toUpperCase(),
      accountType: accountType,
      isPrimary: isFirst,
    ));

    _setLoading(false);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  void _setLoading(bool v) {
    _isLoading = v;
    _error = null;
    notifyListeners();
  }
}