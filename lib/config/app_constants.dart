// lib/config/app_constants.dart
//
// App-wide constants shared across screens/viewmodels.

class AppConstants {
  /// Business rule: the maximum amount (in INR) allowed for a single
  /// deposit or a single investment plan's monthly amount. Enforced here
  /// on the client purely for immediate UX feedback — the backend
  /// (controllers/depositController.js, controllers/planController.js)
  /// is the authoritative source of truth and re-validates this on every
  /// request regardless of what the client sends.
  static const int maxTransactionAmount = 100000;

  /// Shown to the user whenever they enter (or the server rejects) an
  /// amount greater than [maxTransactionAmount].
  static const String maxTransactionAmountMessage =
      'The maximum allowed deposit or plan amount is ₹100,000.';

  // ── Minimum / maximum amount limits ────────────────────────────────────
  // These are enforced on the client for immediate UX feedback only — the
  // backend (depositController.js, planController.js, withdrawalController.js)
  // is the authoritative source of truth and re-validates every one of
  // these limits on every request regardless of what the client sends.

  /// Minimum amount (in INR) allowed for a single deposit.
  static const int minDepositAmount = 500;

  /// Minimum amount (in INR) allowed for a single investment plan.
  static const int minPlanAmount = 500;

  /// Minimum amount (in INR) allowed for a single withdrawal.
  static const int minWithdrawalAmount = 200;

  /// Maximum amount (in INR) allowed for a single withdrawal. Shares the
  /// same ₹100,000 cap as deposits/plans (see [maxTransactionAmount]).
  static const int maxWithdrawalAmount = maxTransactionAmount;

  /// Shown when the entered/submitted deposit amount is below
  /// [minDepositAmount].
  static const String minDepositAmountMessage =
      'The minimum deposit amount is ₹500.';

  /// Shown when the entered/submitted investment amount is below
  /// [minPlanAmount].
  static const String minPlanAmountMessage =
      'The minimum investment amount is ₹500.';

  /// Shown when the entered/submitted withdrawal amount is below
  /// [minWithdrawalAmount].
  static const String minWithdrawalAmountMessage =
      'The minimum withdrawal amount is ₹200.';

  /// Shown when the entered/submitted withdrawal amount is above
  /// [maxWithdrawalAmount].
  static const String maxWithdrawalAmountMessage =
      'The maximum allowed withdrawal amount is ₹100,000.';
}