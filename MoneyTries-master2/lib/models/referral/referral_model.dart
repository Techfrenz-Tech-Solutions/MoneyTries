// lib/models/referral/referral_model.dart

/// Core referral dashboard info shown on the Referral screen.
class ReferralInfo {
  final String myReferralCode;

  /// Lifetime referral earnings (sum of all referral bonuses + the ₹500
  /// task reward). This is a display-only figure — there is no separate
  /// Referral Wallet; every rupee here has already been credited directly
  /// to the user's Main Wallet Balance at the moment it was earned/claimed.
  final double totalEarnings;

  /// Total number of users who signed up using this user's referral code.
  final int totalRefers;

  /// How many of the referred users have completed their first plan
  /// payment (i.e. "activated"). Drives the 0/5 ... 5/5 task progress.
  final int taskProgress;

  /// Target number of activated referrals required to unlock the reward.
  final int taskTarget;

  /// True once [taskProgress] >= [taskTarget].
  final bool taskCompleted;

  /// True once the ₹500 "Invite 5 Users" reward has already been claimed.
  final bool rewardClaimed;

  const ReferralInfo({
    required this.myReferralCode,
    required this.totalEarnings,
    required this.totalRefers,
    required this.taskProgress,
    required this.taskTarget,
    required this.taskCompleted,
    required this.rewardClaimed,
  });

  factory ReferralInfo.fromJson(Map<String, dynamic> j) {
    final target = int.tryParse(j['task_target']?.toString() ?? '5') ?? 5;
    final progress =
        int.tryParse(j['task_progress']?.toString() ?? '0') ?? 0;
    return ReferralInfo(
      myReferralCode: j['my_referral_code']?.toString() ?? '',
      totalEarnings:
          double.tryParse(j['total_earnings']?.toString() ?? '0') ?? 0,
      totalRefers: int.tryParse(j['total_refers']?.toString() ?? '0') ?? 0,
      taskProgress: progress.clamp(0, target),
      taskTarget: target,
      taskCompleted: (j['task_completed'] == true ||
              j['task_completed'] == 1) ||
          progress >= target,
      rewardClaimed:
          j['reward_claimed'] == true || j['reward_claimed'] == 1,
    );
  }
}

/// A single row in the Referral tab of Transaction History.
///
/// [kind] distinguishes a per-referral bonus credit from the one-time
/// ₹500 "Invite 5 Users" task reward, since the two carry different
/// display fields.
enum ReferralTxnKind { bonus, taskReward }

class ReferralTransaction {
  final String id;
  final ReferralTxnKind kind;

  /// Populated only for [ReferralTxnKind.bonus].
  final String? referredUserName;
  final String? selectedPlan; // e.g. "3 Month Plan"
  final double? firstPaymentAmount;

  /// The credited amount — the referral bonus for [ReferralTxnKind.bonus],
  /// or ₹500 for [ReferralTxnKind.taskReward].
  final double amount;

  final DateTime? date;

  const ReferralTransaction({
    required this.id,
    required this.kind,
    this.referredUserName,
    this.selectedPlan,
    this.firstPaymentAmount,
    required this.amount,
    this.date,
  });

  factory ReferralTransaction.fromJson(Map<String, dynamic> j) {
    final kindStr = j['type']?.toString() ?? j['kind']?.toString() ?? '';
    final kind = kindStr == 'task_reward'
        ? ReferralTxnKind.taskReward
        : ReferralTxnKind.bonus;

    // NOTE: the backend already returns the correct wall-clock time (see
    // referralController.js — created_at is written via MySQL NOW(), the
    // same convention every other transaction type in this app relies on).
    // Deposit/Withdrawal/ROI models all parse this raw value with
    // DateTime.tryParse() and nothing else — calling .toLocal() on top of
    // it re-applies the device's UTC offset a second time, which is what
    // was pushing this specific timestamp several hours into the future.
    // (Same class of bug already fixed once on the Home screen's Recent
    // Transactions card — see the note in home_screen.dart.)
    DateTime? parsedDate;
    final rawDate = j['created_at'] ?? j['date'];
    if (rawDate != null) {
      parsedDate = DateTime.tryParse(rawDate.toString());
    }

    return ReferralTransaction(
      id: j['id']?.toString() ?? '',
      kind: kind,
      referredUserName: j['referred_user_name']?.toString(),
      selectedPlan: j['selected_plan']?.toString(),
      firstPaymentAmount: j['first_payment_amount'] != null
          ? double.tryParse(j['first_payment_amount'].toString())
          : null,
      amount: double.tryParse(j['amount']?.toString() ?? '0') ?? 0,
      date: parsedDate,
    );
  }
}

/// Current status of a referred user, shown as a badge on their Referral
/// Candidate card. Mirrors the `status` value computed server-side in
/// referralController.js#getReferralCandidates, which is re-derived on
/// every fetch from the referred user's live investment_plans /
/// referral_transactions rows — so as a referred user's plan progresses
/// (submits a plan, gets approved, gets rejected, earns the referrer their
/// bonus) the next fetch of this list reflects it automatically.
enum ReferralCandidateStatus {
  /// Registered with this user's referral code but hasn't started any
  /// investment plan yet. Shown instead of hiding the user entirely.
  pendingPlan,

  /// Submitted a plan; awaiting admin review.
  underReview,

  /// The referred user's first instalment has been approved (plan status
  /// is approved/active/completed) but the referrer's bonus for this user
  /// hasn't been credited yet.
  firstPaymentCompleted,

  /// The referrer's one-time bonus for this referred user has been
  /// credited to the Main Wallet Balance. The steady-state end status for
  /// any referred user who has made their first plan payment.
  rewardCredited,

  /// The referred user's plan was rejected by an admin.
  rejected,
}

ReferralCandidateStatus _candidateStatusFromString(String? raw) {
  switch (raw) {
    case 'under_review':
      return ReferralCandidateStatus.underReview;
    case 'first_payment_completed':
      return ReferralCandidateStatus.firstPaymentCompleted;
    case 'reward_credited':
      return ReferralCandidateStatus.rewardCredited;
    case 'rejected':
      return ReferralCandidateStatus.rejected;
    case 'pending_plan':
    default:
      return ReferralCandidateStatus.pendingPlan;
  }
}

/// A single row in the "Referral Candidates" tab of the Referral screen —
/// EVERY user who signed up with the current user's referral code,
/// regardless of whether they've started an investment plan yet. Users who
/// haven't started a plan are shown with [ReferralCandidateStatus.pendingPlan]
/// rather than being hidden from the list.
class ReferralCandidate {
  final String id;
  final int? referredUserId;
  final String userName;

  /// Short plan code for display — "3M", "6M", or "12M". Null until the
  /// referred user has actually started a plan.
  final String? selectedPlan;

  final double? firstPaymentAmount;
  final DateTime? firstPaymentDate;

  /// When the referred user registered using this user's referral code.
  final DateTime? registeredAt;

  /// Last 4 digits of the referred user's registered mobile number.
  final String? mobileLast4;

  final double bonusEarned;
  final ReferralCandidateStatus status;

  const ReferralCandidate({
    required this.id,
    this.referredUserId,
    required this.userName,
    this.selectedPlan,
    this.firstPaymentAmount,
    this.firstPaymentDate,
    this.registeredAt,
    this.mobileLast4,
    required this.bonusEarned,
    required this.status,
  });

  factory ReferralCandidate.fromJson(Map<String, dynamic> j) {
    // Same UTC-vs-local timestamp convention as ReferralTransaction above —
    // parse the raw backend value with tryParse() only, no .toLocal().
    DateTime? parsedPaymentDate;
    final rawPaymentDate = j['first_payment_date'];
    if (rawPaymentDate != null) {
      parsedPaymentDate = DateTime.tryParse(rawPaymentDate.toString());
    }

    DateTime? parsedRegisteredAt;
    final rawRegisteredAt = j['registered_at'];
    if (rawRegisteredAt != null) {
      parsedRegisteredAt = DateTime.tryParse(rawRegisteredAt.toString());
    }

    return ReferralCandidate(
      id: j['id']?.toString() ?? '',
      referredUserId: int.tryParse(j['referred_user_id']?.toString() ?? ''),
      userName: (j['user_name']?.toString().trim().isNotEmpty ?? false)
          ? j['user_name'].toString()
          : 'Moneytries User',
      selectedPlan: j['selected_plan']?.toString(),
      firstPaymentAmount: j['first_payment_amount'] != null
          ? double.tryParse(j['first_payment_amount'].toString())
          : null,
      firstPaymentDate: parsedPaymentDate,
      registeredAt: parsedRegisteredAt,
      mobileLast4: j['mobile_last4']?.toString(),
      bonusEarned: double.tryParse(j['bonus_earned']?.toString() ?? '0') ?? 0,
      status: _candidateStatusFromString(j['status']?.toString()),
    );
  }
}