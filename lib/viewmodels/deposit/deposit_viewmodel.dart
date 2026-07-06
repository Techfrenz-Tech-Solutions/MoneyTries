import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../data/deposit/deposit_repository.dart';
import '../../models/deposit/deposit_models.dart';

enum DepositState { idle, loading, success, error, checkingPending }

enum PaymentMethod { upi, bank }

class DepositViewModel extends ChangeNotifier {
  final DepositRepository _repo;

  DepositViewModel({DepositRepository? repository})
      : _repo = repository ?? DepositRepository() {
    _checkPendingDeposit();
  }

  // ── Form state ─────────────────────────────────────────────────────────────
  PaymentMethod paymentMethod = PaymentMethod.upi;
  int amount = 0;
  String utrId = '';
  File? screenshot;

  // ── Async state ────────────────────────────────────────────────────────────
  DepositState state = DepositState.checkingPending;
  String? errorMessage;
  ManualOrderModel? completedOrder;

  // ── Pending deposit state ──────────────────────────────────────────────────
  /// A pending deposit found on load — blocks the user from submitting again.
  DepositRecord? pendingDeposit;

  /// Whether the app is currently checking for a pending deposit on load.
  bool get isCheckingPending => state == DepositState.checkingPending;

  /// True when there's an active pending deposit blocking new submissions.
  bool get hasPendingDeposit => pendingDeposit != null;

  // ── UPI / Bank details shown to user ──────────────────────────────────────
  static const String upiId = 'MONEYMINING@KVB';
  static const String bankAccountName = 'MoneyMining Pvt Ltd';
  static const String bankAccountNumber = '1234567890';
  static const String bankIfsc = 'KVB0001234';
  static const String bankAccountType = 'Current';

  // ── On-load pending check ──────────────────────────────────────────────────
  Future<void> _checkPendingDeposit() async {
    state = DepositState.checkingPending;
    notifyListeners();
    try {
      pendingDeposit = await _repo.fetchPendingDeposit();
    } catch (_) {
      // Network error on check — don't block the user, just allow submission
      pendingDeposit = null;
    }
    state = DepositState.idle;
    notifyListeners();
  }

  /// Called by the UI "Refresh Status" button to re-check if admin acted.
  Future<void> refreshPendingStatus() async {
    state = DepositState.checkingPending;
    notifyListeners();
    try {
      pendingDeposit = await _repo.fetchPendingDeposit();
    } catch (_) {
      // keep existing pendingDeposit if network fails
    }
    state = DepositState.idle;
    notifyListeners();
  }

  // ── Setters ───────────────────────────────────────────────────────────────
  void setPaymentMethod(PaymentMethod method) {
    paymentMethod = method;
    notifyListeners();
  }

  void setAmount(int value) {
    amount = value;
    _clearErrorIfResolved();
    notifyListeners();
  }

  void setUtrId(String value) {
    utrId = value.trim();
    _clearErrorIfResolved();
    notifyListeners();
  }

  void setScreenshot(File file) {
    screenshot = file;
    if (state == DepositState.error) {
      state = DepositState.idle;
      errorMessage = null;
    }
    notifyListeners();
  }

  void clearScreenshot() {
    screenshot = null;
    notifyListeners();
  }

  void reset() {
    amount = 0;
    utrId = '';
    screenshot = null;
    state = DepositState.idle;
    errorMessage = null;
    completedOrder = null;
    pendingDeposit = null;
    notifyListeners();
  }

  // ── Clears the error banner once the field that caused it is now valid ─────
  void _clearErrorIfResolved() {
    if (state == DepositState.error) {
      final stillInvalid = validate() != null;
      if (!stillInvalid) {
        state = DepositState.idle;
        errorMessage = null;
      }
    }
  }

  // ── Validation ─────────────────────────────────────────────────────────────
  String? validate() {
    if (amount <= 0) return 'Please enter a valid amount.';
    if (utrId.isEmpty) return 'Please enter your UTR / Transaction ID.';
    if (utrId.length < 6) return 'UTR ID seems too short. Please verify.';
    if (screenshot == null) return 'Please upload a payment screenshot.';
    return null; // valid
  }

  // ── Submit ─────────────────────────────────────────────────────────────────
  Future<void> submitDeposit() async {
    // Guard: block if already pending
    if (hasPendingDeposit) return;

    final validationError = validate();
    if (validationError != null) {
      errorMessage = validationError;
      state = DepositState.error;
      notifyListeners();
      return;
    }

    state = DepositState.loading;
    errorMessage = null;
    notifyListeners();

    try {
      final order = await _repo.createManualDeposit(
        amount: amount,
        utrId: utrId,
        screenshot: screenshot!,
      );
      completedOrder = order;
      state = DepositState.success;
    } catch (e) {
      errorMessage = e.toString().replaceFirst('Exception: ', '');
      state = DepositState.error;
    }

    notifyListeners();
  }
}