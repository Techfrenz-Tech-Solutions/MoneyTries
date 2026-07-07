// lib/viewmodels/history/history_viewmodel.dart
import 'package:flutter/foundation.dart';
import '../../data/deposit/deposit_repository.dart';
import '../../data/withdrawal/withdrawal_repository.dart';
import '../../data/plan/plan_repository.dart';
import '../../data/referral/referral_repository.dart';
import '../../models/deposit/deposit_models.dart';
import '../../models/withdrawal/withdrawal_models.dart';
import '../../models/plan/plan_models.dart';
import '../../models/referral/referral_model.dart';

// ── Unified transaction item ──────────────────────────────────────────────────
enum TxnType { deposit, withdrawal, roi, referral, wallet }

class HistoryTxn {
  final String id;
  final TxnType type;
  final String title;
  final String subtitle;
  final double amount;
  final bool isCredit;
  final String status; // pending | approved | rejected
  final DateTime? date;

  const HistoryTxn({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.isCredit,
    required this.status,
    this.date,
  });
}

// ── ViewModel ─────────────────────────────────────────────────────────────────
class HistoryViewModel extends ChangeNotifier {
  final DepositRepository    _depositRepo;
  final WithdrawalRepository _withdrawalRepo;
  final PlanRepository       _planRepo;
  final ReferralRepository   _referralRepo;

  HistoryViewModel({
    DepositRepository?    depositRepo,
    WithdrawalRepository? withdrawalRepo,
    PlanRepository?       planRepo,
    ReferralRepository?   referralRepo,
  })  : _depositRepo    = depositRepo    ?? DepositRepository(),
        _withdrawalRepo = withdrawalRepo ?? WithdrawalRepository(),
        _planRepo       = planRepo       ?? PlanRepository(),
        _referralRepo   = referralRepo   ?? ReferralRepository();

  // ── State ─────────────────────────────────────────────────────────────────
  bool _loading = false;
  String? _error;

  // Per-section errors. A tab whose fetch actually failed (expired session,
  // no network, server error, unexpected response shape, etc.) must show
  // that failure — not silently render the same "No history yet" empty
  // state as a tab that genuinely has zero records. Null means "loaded
  // successfully" (even if the resulting list is empty).
  String? _depositsError;
  String? _withdrawalsError;
  String? _roiError;
  String? _referralError;

  List<HistoryTxn> _deposits     = [];
  List<HistoryTxn> _withdrawals  = [];
  List<HistoryTxn> _roiTxns      = [];
  List<HistoryTxn> _referralTxns = [];
  List<HistoryTxn> _walletTxns   = [];

  // Summary for the earnings card
  double _totalDeposited   = 0;
  double _totalWithdrawn   = 0;
  double _totalRoiAccrued  = 0;
  double _totalRoiWithdrawn = 0;
  int    _roiWithdrawalCount = 0;
  double _totalReferralEarnings = 0;

  bool   get isLoading       => _loading;
  String? get error          => _error;

  String? get depositsError    => _depositsError;
  String? get withdrawalsError => _withdrawalsError;
  String? get roiError         => _roiError;
  String? get referralError    => _referralError;

  List<HistoryTxn> get deposits    => _deposits;
  List<HistoryTxn> get withdrawals => _withdrawals;
  List<HistoryTxn> get roiTxns     => _roiTxns;
  List<HistoryTxn> get referralTxns => _referralTxns;
  List<HistoryTxn> get walletTxns  => _walletTxns;

  double get totalDeposited    => _totalDeposited;
  double get totalWithdrawn    => _totalWithdrawn;
  double get totalRoiAccrued   => _totalRoiAccrued;
  double get totalRoiWithdrawn => _totalRoiWithdrawn;
  int    get roiWithdrawalCount => _roiWithdrawalCount;
  double get totalReferralEarnings => _totalReferralEarnings;

  // ── Load all ─────────────────────────────────────────────────────────────
  Future<void> loadAll() async {
    _loading = true;
    _error   = null;
    notifyListeners();

    try {
      await Future.wait([
        _loadDeposits(),
        _loadWithdrawals(),
        _loadRoi(),
        _loadReferrals(),
      ]);
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // ── Deposits ─────────────────────────────────────────────────────────────
  Future<void> _loadDeposits() async {
    try {
      final resp = await _depositRepo.fetchDepositList(pageNo: 1, pageSize: 50);
      _deposits = resp.data.map(_depositToTxn).toList();
      _totalDeposited = resp.data
          .where((d) => d.isApproved)
          .fold(0.0, (sum, d) => sum + d.amount);
      _depositsError = null;
    } catch (e) {
      debugPrint('[history] deposit fetch failed: $e');
      _deposits = [];
      _depositsError = e.toString().replaceFirst('Exception: ', '');
    }
  }

  HistoryTxn _depositToTxn(DepositRecord d) => HistoryTxn(
        id:       'dep_${d.id}',
        type:     TxnType.deposit,
        title:    'Bank Deposit',
        subtitle: 'UTR: ${d.utrId.isNotEmpty ? d.utrId : "—"}',
        amount:   d.amount,
        isCredit: true,
        status:   _mapDepositStatus(d.orderStatus),
        date:     d.createdAt,
      );

  String _mapDepositStatus(String s) {
    switch (s.toLowerCase()) {
      case 'approved': return 'approved';
      case 'rejected': return 'rejected';
      default:         return 'pending';
    }
  }

  // ── Withdrawals ──────────────────────────────────────────────────────────
  Future<void> _loadWithdrawals() async {
    try {
      final resp = await _withdrawalRepo.fetchWithdrawList(
          pageNo: 1, pageSize: 50);
      _withdrawals = resp.data.map(_withdrawToTxn).toList();
      _walletTxns  = _withdrawals; // wallet tab mirrors withdrawals for now
      _totalWithdrawn = resp.data
          .where((w) => w.status == 'approved')
          .fold(0.0, (sum, w) => sum + w.amount);
      _withdrawalsError = null;
    } catch (e) {
      debugPrint('[history] withdrawal fetch failed: $e');
      _withdrawals = [];
      _walletTxns  = [];
      _withdrawalsError = e.toString().replaceFirst('Exception: ', '');
    }
  }

  HistoryTxn _withdrawToTxn(WithdrawRecord w) => HistoryTxn(
        id:       'wd_${w.id}',
        type:     TxnType.withdrawal,
        title:    'Withdrawal',
        subtitle: w.referenceId.isNotEmpty
            ? 'Ref: ${w.referenceId}'
            : 'Bank Transfer',
        amount:   w.amount,
        isCredit: false,
        status:   w.status,
        date:     w.createdAt,
      );

  // ── ROI (from daily ROI credit transactions) ──────────────────────────────
  Future<void> _loadRoi() async {
    try {
      final plans = await _planRepo.fetchMyPlans();
      final List<HistoryTxn> roiList = [];
      double totalRoi = 0;
      double totalWithdrawn = 0;
      int withdrawalCount = 0;

      for (final plan in plans) {
        // Use the same client-computed accrued figure the Plan screen shows,
        // now correctly tiered by paid instalment date (ROI on each
        // instalment only starts from the day it was actually paid — see
        // ActivePlan.tieredExpectedAccruedRoi). The server's accrued_roi
        // field can lag behind or use a stale start date, so — exactly like
        // the Plan Detail screen — the client-side calculation is treated as
        // authoritative here too, so the two screens always agree.
        totalRoi += plan.tieredExpectedAccruedRoi;

        // Each credited calendar day = its own "Daily ROI Credit"
        // transaction. Sourced from the server's roi_daily_credits table,
        // which guarantees exactly one row per (plan, date) — so even if
        // the user was offline for several days, every missed day still
        // shows up here as its own separate, non-duplicated entry.
        for (final credit in plan.dailyRoiCredits) {
          roiList.add(HistoryTxn(
            id:       'roi_daily_${credit.id}',
            type:     TxnType.roi,
            title:    'Daily ROI Credit',
            subtitle: credit.creditDate != null
                ? '${plan.planType.months}M Plan • '
                    '${credit.creditDate!.day.toString().padLeft(2, '0')}/'
                    '${credit.creditDate!.month.toString().padLeft(2, '0')}/'
                    '${credit.creditDate!.year}'
                : '${plan.planType.months}M Plan',
            amount:   credit.amount,
            isCredit: true,
            status:   'approved',
            date:     credit.creditedAt ?? credit.creditDate,
          ));
        }

        // Each "withdraw ROI to wallet" action is its own, separate debit
        // transaction — never collapsed into a running counter. Every click
        // of "Withdraw to Wallet" inserts its own row in roi_withdrawals on
        // the backend (see withdrawRoi in planController.js), so here we
        // simply list every one of those rows as its own card, in full: its
        // own amount, its own date/time, its own plan name, its own status.
        // Two ₹9.00 withdrawals made today show up as two separate ₹9.00
        // cards under "TODAY" — they are never merged into one entry.
        final seenWithdrawalIds = <String>{};
        for (final wd in plan.roiWithdrawals) {
          final id = 'roi_wd_${wd.id}';
          if (!seenWithdrawalIds.add(id)) continue; // guard against an exact duplicate row id
          roiList.add(HistoryTxn(
            id:       id,
            type:     TxnType.roi,
            title:    'ROI Withdrawn',
            subtitle: '${plan.planType.months}M Plan • To Wallet',
            amount:   wd.amount,
            isCredit: false,
            status:   'approved',
            date:     wd.createdAt,
          ));
          totalWithdrawn += wd.amount;
          withdrawalCount++;
        }
      }

      // Sort newest first
      roiList.sort((a, b) => (b.date ?? DateTime(0)).compareTo(a.date ?? DateTime(0)));
      _roiTxns           = roiList;
      _totalRoiWithdrawn  = totalWithdrawn;
      _roiWithdrawalCount = withdrawalCount;
      _totalRoiAccrued    = totalRoi;
      _roiError           = null;
    } catch (e) {
      debugPrint('[history] ROI fetch failed: $e');
      _roiTxns = [];
      _roiError = e.toString().replaceFirst('Exception: ', '');
    }
  }

  // ── Referral (bonus credits + task reward claims) ──────────────────────────
  Future<void> _loadReferrals() async {
    try {
      final txns = await _referralRepo.fetchReferralTransactions();
      final list = txns.map(_referralToTxn).toList();
      list.sort((a, b) => (b.date ?? DateTime(0)).compareTo(a.date ?? DateTime(0)));
      _referralTxns = list;
      _totalReferralEarnings =
          txns.fold(0.0, (sum, t) => sum + t.amount);
      _referralError = null;
    } catch (e) {
      debugPrint('[history] referral fetch failed: $e');
      _referralTxns = [];
      _referralError = e.toString().replaceFirst('Exception: ', '');
    }
  }

  HistoryTxn _referralToTxn(ReferralTransaction t) {
    if (t.kind == ReferralTxnKind.taskReward) {
      return HistoryTxn(
        id:       'ref_reward_${t.id}',
        type:     TxnType.referral,
        title:    'Invite 5 Users Reward',
        subtitle: 'Referral task completed • Added to Wallet',
        amount:   t.amount,
        isCredit: true,
        status:   'approved',
        date:     t.date,
      );
    }

    final name = t.referredUserName?.isNotEmpty == true
        ? t.referredUserName!
        : 'New user';
    final plan = t.selectedPlan?.isNotEmpty == true ? t.selectedPlan! : '—';
    final firstPayment = t.firstPaymentAmount != null
        ? '₹${t.firstPaymentAmount!.toStringAsFixed(2)}'
        : '—';

    return HistoryTxn(
      id:       'ref_bonus_${t.id}',
      type:     TxnType.referral,
      title:    'Referral Bonus — $name',
      subtitle: '$plan • First Payment $firstPayment',
      amount:   t.amount,
      isCredit: true,
      status:   'approved',
      date:     t.date,
    );
  }

  String? errorFor(TxnType type) {
    switch (type) {
      case TxnType.deposit:    return _depositsError;
      case TxnType.withdrawal: return _withdrawalsError;
      case TxnType.roi:        return _roiError;
      case TxnType.referral:   return _referralError;
      case TxnType.wallet:     return _withdrawalsError; // wallet tab mirrors withdrawals
    }
  }

  // ── Filtered by search ────────────────────────────────────────────────────
  List<HistoryTxn> filtered(List<HistoryTxn> list, String query) {
    if (query.trim().isEmpty) return list;
    final q = query.toLowerCase();
    return list.where((t) =>
      t.title.toLowerCase().contains(q) ||
      t.subtitle.toLowerCase().contains(q) ||
      t.amount.toStringAsFixed(2).contains(q)
    ).toList();
  }
}