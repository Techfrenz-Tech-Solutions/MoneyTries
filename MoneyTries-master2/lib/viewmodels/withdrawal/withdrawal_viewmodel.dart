import 'package:flutter/foundation.dart';
import '../../data/withdrawal/withdrawal_repository.dart';
import '../../models/withdrawal/withdrawal_models.dart';
import '../../services/audio/interaction_feedback.dart';

enum WithdrawalMode { wallet, deposit }

enum WithdrawalState { idle, loadingKyc, checkingPending, submitting, success, error }

class WithdrawalViewModel extends ChangeNotifier {
  final WithdrawalRepository _repo;

  static const double _platformFeeRate = 0.02;

  WithdrawalViewModel({
    WithdrawalRepository? repository,
    required this.mode,
  }) : _repo = repository ?? WithdrawalRepository();

  // ── Mode ───────────────────────────────────────────────────────────────────
  final WithdrawalMode mode;

  bool get isWalletMode => mode == WithdrawalMode.wallet;

  // ── KYC / bank ─────────────────────────────────────────────────────────────
  KycStatus? kycStatus;

  KycBankDetail? get bankDetail => kycStatus?.bankDetail;

  bool get kycVerified => kycStatus?.isVerified ?? false;

  // ── Form state ─────────────────────────────────────────────────────────────
  double amount = 0;

  // Balances — populated from the backend via fetchBalances().
  // setBalances() is kept for backward compatibility / manual overrides.
  double walletBalance = 0;
  double vaultBalance = 0;

  double get availableBalance =>
      isWalletMode ? walletBalance : vaultBalance;

  bool get amountExceedsBalance => amount > availableBalance && amount > 0;

  double get feeAmount => amount * _platformFeeRate;
  double get netAmount => (amount - feeAmount).clamp(0.0, double.infinity);

  bool get canSubmit =>
      amount > 0 &&
      amount <= availableBalance &&
      kycVerified &&
      !hasPendingWithdrawal &&
      state != WithdrawalState.submitting &&
      state != WithdrawalState.loadingKyc &&
      state != WithdrawalState.checkingPending;

  // ── Async state ─────────────────────────────────────────────────────────────
  WithdrawalState state = WithdrawalState.idle;
  String? errorMessage;

  // ── Pending withdrawal state ─────────────────────────────────────────────────
  WithdrawRecord? pendingWithdrawal;
  bool get isCheckingPending => state == WithdrawalState.checkingPending;
  bool get hasPendingWithdrawal => pendingWithdrawal != null;

  // ── Success payloads ───────────────────────────────────────────────────────
  String? completedReferenceId; // wallet mode
  String? completedMessage;     // both modes

  // ── Init ───────────────────────────────────────────────────────────────────
  void setAmount(double value) {
    amount = value;
    notifyListeners();
  }

  void setBalances({required double wallet, required double vault}) {
    walletBalance = wallet;
    vaultBalance = vault;
    notifyListeners();
  }

  // ── Fetch real balances from the backend ─────────────────────────────────
  Future<void> fetchBalances() async {
    try {
      final result = await _repo.fetchBalances();
      walletBalance = result.wallet;
      vaultBalance = result.vault;
      notifyListeners();
    } catch (e) {
      // Non-fatal — leave previous/default balances in place, but surface
      // the error so the UI can show a banner if it wants to.
      errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
    }
  }

  // ── Fetch KYC ──────────────────────────────────────────────────────────────
  Future<void> fetchKycStatus() async {
    state = WithdrawalState.loadingKyc;
    errorMessage = null;
    notifyListeners();

    try {
      kycStatus = await _repo.fetchKycStatus();
      state = WithdrawalState.idle;
    } catch (e) {
      errorMessage = e.toString().replaceFirst('Exception: ', '');
      state = WithdrawalState.error;
    }

    notifyListeners();
  }

  Future<void> checkPendingWithdrawal() async {
    state = WithdrawalState.checkingPending;
    errorMessage = null;
    notifyListeners();

    try {
      pendingWithdrawal = await _repo.fetchPendingWithdrawal();
      state = WithdrawalState.idle;
    } catch (_) {
      pendingWithdrawal = null;
      state = WithdrawalState.idle;
    }

    notifyListeners();
  }

  /// Called by the UI "Refresh Status" button to re-check if admin acted.
  Future<void> refreshPendingStatus() async {
    await checkPendingWithdrawal();
  }

  // ── Submit ─────────────────────────────────────────────────────────────────
  Future<void> submitWithdrawal() async {
    if (!canSubmit) return;

    state = WithdrawalState.submitting;
    errorMessage = null;
    notifyListeners();

    try {
      if (isWalletMode) {
        final resp = await _repo.walletWithdrawRequest(amount: amount);
        completedReferenceId = resp.referenceId;
        completedMessage = resp.message;
      } else {
        final resp = await _repo.requestMoveWalletAmount(amount: amount);
        completedMessage = resp.message;
      }
      state = WithdrawalState.success;
      InteractionFeedback.withdrawalSuccess();
    } catch (e) {
      errorMessage = e.toString().replaceFirst('Exception: ', '');
      state = WithdrawalState.error;
    }

    notifyListeners();
  }

  // ── Reset ──────────────────────────────────────────────────────────────────
  void reset() {
    amount = 0;
    state = WithdrawalState.idle;
    errorMessage = null;
    pendingWithdrawal = null;
    completedReferenceId = null;
    completedMessage = null;
    notifyListeners();
  }

  // ── Validation ─────────────────────────────────────────────────────────────
  String? validate() {
    if (amount <= 0) return 'Please enter a valid amount.';
    if (amount > availableBalance) return 'Amount exceeds your available balance.';
    if (!kycVerified) return 'KYC verification is required to withdraw.';
    return null;
  }
}