import 'package:flutter/foundation.dart';
import '../../config/app_constants.dart';
import '../../data/plan/plan_repository.dart';
import '../../models/plan/plan_models.dart';
import '../../services/audio/interaction_feedback.dart';

enum PlanVmState { idle, loading, success, error }

class PlanViewModel extends ChangeNotifier {
  final PlanRepository _repo;

  PlanViewModel({PlanRepository? repository})
    : _repo = repository ?? PlanRepository();

  // ── Plans list ─────────────────────────────────────────────────────────────
  List<ActivePlan> plans = [];
  PlanVmState listState = PlanVmState.idle;
  String? listError;

  // ── Wallet balance (plans are funded exclusively from this) ───────────────
  double walletBalance = 0;
  bool walletBalanceLoading = false;

  // ── Enroll / first payment ─────────────────────────────────────────────────
  PlanVmState enrollState = PlanVmState.idle;
  String? enrollError;
  ActivePlan? enrolledPlan;
  // True specifically when the last enroll attempt failed because the
  // wallet balance was too low, so the UI can show a persistent
  // "Insufficient wallet balance" state instead of a one-off toast.
  bool insufficientBalance = false;

  // ── ROI withdrawal ─────────────────────────────────────────────────────────
  PlanVmState roiState = PlanVmState.idle;
  String? roiError;
  RoiWithdrawalResponse? roiResult;

  // ── Principal withdrawal ───────────────────────────────────────────────────
  PlanVmState principalState = PlanVmState.idle;
  String? principalError;
  PrincipalWithdrawalResponse? principalResult;

  // ── Profile plan amount ────────────────────────────────────────────────────
  double planAmount = 0;

  // ── Load plans ─────────────────────────────────────────────────────────────
  Future<void> loadPlans() async {
    listState = PlanVmState.loading;
    listError = null;
    notifyListeners();

    try {
      plans = await _repo.fetchMyPlans();
      // Instant, best-effort figure from the plans list that was just
      // fetched (which already carries each plan's up-to-date status and
      // principal_credited_at from the server) — shown immediately while
      // the authoritative sum below is still in flight.
      _recomputePlanAmountLocally();
      listState = PlanVmState.success;
    } catch (e) {
      listError = e.toString().replaceFirst('Exception: ', '');
      listState = PlanVmState.error;
    }
    notifyListeners();

    // Reconcile against the server's own SUM(plan_amount) — the true
    // source of truth, since it reads plan_amount directly (zeroed the
    // instant maturePlanIfDue() runs) rather than the client's derived
    // totalPrincipal figure. Runs after the list above so a freshly loaded
    // Profile page — or any other screen calling loadPlans() — never keeps
    // showing a matured plan's principal past this refresh.
    if (listState == PlanVmState.success) {
      await loadPlanAmount();
    }
  }

  // ── Wallet balance ─────────────────────────────────────────────────────────
  Future<void> loadWalletBalance() async {
    walletBalanceLoading = true;
    notifyListeners();
    try {
      walletBalance = await _repo.fetchWalletBalance();
    } catch (_) {
      // Leave the last known value in place on failure.
    }
    walletBalanceLoading = false;
    notifyListeners();
  }

  /// Whether the current wallet balance covers the given plan amount.
  bool hasSufficientBalance(int amount) => walletBalance >= amount;

  // ── Profile plan amount ────────────────────────────────────────────────────
  Future<void> loadPlanAmount() async {
    try {
      planAmount = await _repo.fetchPlanAmount();
    } catch (_) {
      _recomputePlanAmountLocally();
    }
    notifyListeners();
  }

  // ── Profile plan amount ────────────────────────────────────────────────────
  // "Plan Balance" = principal still locked in a currently active/not-yet-
  // matured plan. The moment a plan matures, maturePlanIfDue() on the server
  // auto-credits its principal to the wallet and marks the plan 'completed'
  // — from that instant its principal must stop counting here. Both signals
  // (status == completed, and isPrincipalCredited — set the moment the
  // credit actually lands) are checked so this stays correct even in the
  // brief edge case where one has updated but the other hasn't yet.
  void _recomputePlanAmountLocally() {
    double total = 0;
    for (final p in plans) {
      final isMatured = p.status == PlanStatus.completed || p.isPrincipalCredited;
      if (isMatured) continue; // matured — principal already left this pool
      if (p.status == PlanStatus.active || p.status == PlanStatus.approved) {
        total += p.totalPrincipal;
      }
    }
    planAmount = total;
  }

  // ── Queries ────────────────────────────────────────────────────────────────
  bool hasActivePlan(PlanType type) {
    return plans.any(
      (p) =>
          p.planType == type &&
          (p.status == PlanStatus.active ||
              p.status == PlanStatus.approved ||
              p.status == PlanStatus.underReview),
    );
  }

  ActivePlan? getActivePlan(PlanType type) {
    try {
      return plans.firstWhere(
        (p) =>
            p.planType == type &&
            (p.status == PlanStatus.active ||
                p.status == PlanStatus.approved ||
                p.status == PlanStatus.underReview),
      );
    } catch (_) {
      return null;
    }
  }

  List<ActivePlan> getPlansForType(PlanType type) =>
      plans.where((p) => p.planType == type).toList();

  // ── Enroll, paid from wallet balance (requires admin approval) ────────────
  Future<void> enrollPlan({
    required PlanType planType,
    required int monthlyAmount,
    int? durationDays,
  }) async {
    if (monthlyAmount < AppConstants.minPlanAmount) {
      enrollError = AppConstants.minPlanAmountMessage;
      enrollState = PlanVmState.error;
      insufficientBalance = false;
      notifyListeners();
      return;
    }
    if (monthlyAmount > AppConstants.maxTransactionAmount) {
      enrollError = AppConstants.maxTransactionAmountMessage;
      enrollState = PlanVmState.error;
      insufficientBalance = false;
      notifyListeners();
      return;
    }
    // Client-side pre-check for a snappy "Insufficient wallet balance"
    // message — the backend re-checks the up-to-the-millisecond balance
    // and is the authoritative guard, this just avoids a round trip when
    // it's obviously not going to work.
    if (!hasSufficientBalance(monthlyAmount)) {
      enrollError = 'Insufficient wallet balance';
      enrollState = PlanVmState.error;
      insufficientBalance = true;
      notifyListeners();
      return;
    }

    enrollState = PlanVmState.loading;
    enrollError = null;
    insufficientBalance = false;
    enrolledPlan = null;
    notifyListeners();

    try {
      enrolledPlan = await _repo.enrollPlan(
        planType: planType,
        monthlyAmount: monthlyAmount,
        durationDays: durationDays,
      );
      plans.add(enrolledPlan!);
      _recomputePlanAmountLocally();
      // The amount was just locked from the wallet — refresh the balance
      // so any screen reading it (this one included) shows the new figure.
      walletBalance = (walletBalance - monthlyAmount).clamp(0, double.infinity);
      enrollState = PlanVmState.success;
      InteractionFeedback.planActivated();
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      enrollError = msg;
      insufficientBalance = msg.toLowerCase().contains('insufficient wallet balance');
      enrollState = PlanVmState.error;
      // The backend is the source of truth on balance — resync in case our
      // local optimistic figure had drifted (e.g. another device spent
      // from the wallet in the meantime).
      if (insufficientBalance) {
        await loadWalletBalance();
      }
    }
    notifyListeners();
  }

  // ── ROI withdrawal ─────────────────────────────────────────────────────────
  Future<void> withdrawRoi({
    required String planId,
    required double amount,
  }) async {
    roiState = PlanVmState.loading;
    roiError = null;
    roiResult = null;
    notifyListeners();

    try {
      roiResult = await _repo.withdrawRoi(planId: planId, amount: amount);
      roiState = PlanVmState.success;
      InteractionFeedback.transactionSuccess();
      await loadPlans();
    } catch (e) {
      roiError = e.toString().replaceFirst('Exception: ', '');
      roiState = PlanVmState.error;
    }
    notifyListeners();
  }

  // ── Principal withdrawal ───────────────────────────────────────────────────
  Future<void> withdrawPrincipal({required String planId}) async {
    principalState = PlanVmState.loading;
    principalError = null;
    principalResult = null;
    notifyListeners();

    try {
      principalResult = await _repo.withdrawPrincipal(planId: planId);
      principalState = PlanVmState.success;
      InteractionFeedback.transactionSuccess();
      await loadPlans();
    } catch (e) {
      principalError = e.toString().replaceFirst('Exception: ', '');
      principalState = PlanVmState.error;
    }
    notifyListeners();
  }

  // ── Resets ─────────────────────────────────────────────────────────────────
  void resetEnroll() {
    enrollState = PlanVmState.idle;
    enrollError = null;
    enrolledPlan = null;
    insufficientBalance = false;
    notifyListeners();
  }

  void resetRoi() {
    roiState = PlanVmState.idle;
    roiError = null;
    roiResult = null;
    notifyListeners();
  }

  void resetPrincipal() {
    principalState = PlanVmState.idle;
    principalError = null;
    principalResult = null;
    notifyListeners();
  }
}