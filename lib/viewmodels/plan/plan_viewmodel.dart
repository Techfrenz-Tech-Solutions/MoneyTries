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

  // ── Enroll / first payment ─────────────────────────────────────────────────
  PlanVmState enrollState = PlanVmState.idle;
  String? enrollError;
  ActivePlan? enrolledPlan;

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
      _recomputePlanAmountLocally();
      listState = PlanVmState.success;
    } catch (e) {
      listError = e.toString().replaceFirst('Exception: ', '');
      listState = PlanVmState.error;
    }
    notifyListeners();
  }

  // ── Profile plan amount ────────────────────────────────────────────────────
  Future<void> loadPlanAmount() async {
    try {
      planAmount = await _repo.fetchPlanAmount();
    } catch (_) {
      _recomputePlanAmountLocally();
    }
    notifyListeners();
  }

  void _recomputePlanAmountLocally() {
    double total = 0;
    for (final p in plans) {
      if (p.status == PlanStatus.active ||
          p.status == PlanStatus.approved ||
          p.status == PlanStatus.completed) {
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

  // ── Enroll via UPI (first payment, requires admin approval) ───────────────
  Future<void> enrollPlan({
    required PlanType planType,
    required int monthlyAmount,
    required String utrId,
    required String proofImageUrl,
    int? durationDays,
  }) async {
    if (monthlyAmount < AppConstants.minPlanAmount) {
      enrollError = AppConstants.minPlanAmountMessage;
      enrollState = PlanVmState.error;
      notifyListeners();
      return;
    }
    if (monthlyAmount > AppConstants.maxTransactionAmount) {
      enrollError = AppConstants.maxTransactionAmountMessage;
      enrollState = PlanVmState.error;
      notifyListeners();
      return;
    }

    enrollState = PlanVmState.loading;
    enrollError = null;
    enrolledPlan = null;
    notifyListeners();

    try {
      enrolledPlan = await _repo.enrollPlan(
        planType: planType,
        monthlyAmount: monthlyAmount,
        utrId: utrId,
        proofImageUrl: proofImageUrl,
        durationDays: durationDays,
      );
      plans.add(enrolledPlan!);
      _recomputePlanAmountLocally();
      enrollState = PlanVmState.success;
      InteractionFeedback.planActivated();
    } catch (e) {
      enrollError = e.toString().replaceFirst('Exception: ', '');
      enrollState = PlanVmState.error;
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

  // ── Upload proof ───────────────────────────────────────────────────────────
  Future<String?> uploadProof(List<int> bytes, String filename) async {
    try {
      return await _repo.uploadProof(bytes, filename);
    } catch (_) {
      return null;
    }
  }

  // ── Resets ─────────────────────────────────────────────────────────────────
  void resetEnroll() {
    enrollState = PlanVmState.idle;
    enrollError = null;
    enrolledPlan = null;
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