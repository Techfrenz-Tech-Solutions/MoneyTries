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
}