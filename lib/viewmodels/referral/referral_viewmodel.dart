// lib/viewmodels/referral/referral_viewmodel.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/referral/referral_repository.dart';
import '../../models/referral/referral_model.dart';

enum ReferralLoadState { idle, loading, loaded, error }

/// Drives the "Claim ₹500" button on the Referral screen.
enum ClaimRewardState { idle, claiming, claimed, error }

class ReferralViewModel extends ChangeNotifier {
  final ReferralRepository _repo;

  ReferralViewModel({ReferralRepository? repo})
      : _repo = repo ?? ReferralRepository();

  ReferralLoadState _state = ReferralLoadState.idle;
  ReferralLoadState get state => _state;
  bool get isLoading => _state == ReferralLoadState.loading;

  String? _error;
  String? get error => _error;

  ReferralInfo? _info;
  ReferralInfo? get info => _info;

  String get myReferralCode => _info?.myReferralCode ?? '';
  double get totalEarnings => _info?.totalEarnings ?? 0;
  int get totalRefers => _info?.totalRefers ?? 0;

  int get taskProgress => _info?.taskProgress ?? 0;
  int get taskTarget => _info?.taskTarget ?? 5;
  bool get taskCompleted => _info?.taskCompleted ?? false;
  bool get rewardClaimed => _info?.rewardClaimed ?? false;
  double get taskProgressFraction =>
      taskTarget == 0 ? 0 : (taskProgress / taskTarget).clamp(0.0, 1.0);

  /// True only when the task is done, the reward hasn't been claimed yet,
  /// and no claim request is currently in flight.
  bool get canClaimReward =>
      taskCompleted && !rewardClaimed && _claimState != ClaimRewardState.claiming;

  ClaimRewardState _claimState = ClaimRewardState.idle;
  ClaimRewardState get claimState => _claimState;
  String? _claimError;
  String? get claimError => _claimError;

  // ── Referral Candidates tab ────────────────────────────────────────────
  ReferralLoadState _candidatesState = ReferralLoadState.idle;
  ReferralLoadState get candidatesState => _candidatesState;
  bool get isLoadingCandidates =>
      _candidatesState == ReferralLoadState.loading;

  String? _candidatesError;
  String? get candidatesError => _candidatesError;

  List<ReferralCandidate> _candidates = const [];
  List<ReferralCandidate> get candidates => _candidates;

  /// Fetches EVERY referred user who signed up with this user's referral
  /// code — including ones who haven't started a plan yet, shown with a
  /// Pending Plan status rather than being hidden. Newest-registered first.
  ///
  /// Call again any time the tab is revisited, pulled-to-refresh, or on the
  /// periodic auto-refresh timer (see [startCandidatesAutoRefresh]) so a
  /// candidate's status — Pending Plan, Under Review, First Payment
  /// Completed, Reward Credited, Rejected — keeps moving forward
  /// automatically as their plan progresses, without needing to leave and
  /// re-enter the screen.
  ///
  /// [silent] skips flipping [candidatesState] back to loading (and thus
  /// avoids a skeleton-list flash) — used by the background auto-refresh
  /// timer so a periodic poll doesn't visibly reset an already-loaded list.
  Future<void> loadReferralCandidates({bool silent = false}) async {
    if (!silent) {
      _candidatesState = ReferralLoadState.loading;
      _candidatesError = null;
      notifyListeners();
    }

    try {
      final fresh = await _repo.fetchReferralCandidates();
      _candidates = fresh;
      _candidatesError = null;
      _candidatesState = ReferralLoadState.loaded;
    } catch (e) {
      if (!silent) {
        _candidatesError = e.toString().replaceFirst('Exception: ', '');
        _candidatesState = ReferralLoadState.error;
      }
      // A failed silent background refresh leaves the existing list intact
      // rather than surfacing an error over content the user already has.
    }

    notifyListeners();
  }

  Timer? _candidatesAutoRefreshTimer;

  /// Starts a periodic background refresh of [candidates] so a candidate's
  /// status keeps updating live while the Referral Candidates tab is open
  /// (e.g. a friend's plan gets approved while this screen is on-screen),
  /// without needing to leave and re-enter the tab or pull-to-refresh.
  void startCandidatesAutoRefresh(
      {Duration interval = const Duration(seconds: 15)}) {
    _candidatesAutoRefreshTimer?.cancel();
    _candidatesAutoRefreshTimer = Timer.periodic(interval, (_) {
      loadReferralCandidates(silent: true);
    });
  }

  /// Stops the periodic background refresh started by
  /// [startCandidatesAutoRefresh]. Call when the Referral Candidates tab is
  /// no longer visible so the app isn't polling in the background.
  void stopCandidatesAutoRefresh() {
    _candidatesAutoRefreshTimer?.cancel();
    _candidatesAutoRefreshTimer = null;
  }

  Future<void> loadReferralInfo() async {
    _state = ReferralLoadState.loading;
    _error = null;
    notifyListeners();

    try {
      _info = await _repo.fetchReferralInfo();
      _state = ReferralLoadState.loaded;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _state = ReferralLoadState.error;
    }

    notifyListeners();
  }

  /// Claims the one-time ₹500 "Invite 5 Users" reward and credits it to
  /// the user's main Wallet Balance. Refreshes referral info afterwards so
  /// [rewardClaimed] flips and the button locks immediately.
  Future<void> claimReward() async {
    if (!canClaimReward) return;

    _claimState = ClaimRewardState.claiming;
    _claimError = null;
    notifyListeners();

    try {
      await _repo.claimTaskReward();
      _claimState = ClaimRewardState.claimed;
      await loadReferralInfo(); // refresh so rewardClaimed = true, UI locks
    } catch (e) {
      _claimError = e.toString().replaceFirst('Exception: ', '');
      _claimState = ClaimRewardState.error;
    }

    notifyListeners();
  }

  @override
  void dispose() {
    _candidatesAutoRefreshTimer?.cancel();
    super.dispose();
  }
}