// lib/services/audio/app_sound_event.dart
//
// Every distinct "premium" audio cue the app can play, mapped to its
// asset. Kept as a single enum (rather than raw string paths scattered
// through viewmodels/views) so every call site is type-safe and every
// available cue is discoverable in one place.
//
// Add new .wav assets under assets/sounds/ and register them in
// pubspec.yaml's flutter -> assets list, then add one line here.
enum AppSoundEvent {
  /// Wallet balance revealed (eye-icon tap on Home).
  walletBalance('assets/sounds/wallet_reveal.wav'),

  /// Login completed successfully (password or 2FA OTP).
  loginSuccess('assets/sounds/login_success.wav'),

  /// Deposit request submitted successfully.
  depositSuccess('assets/sounds/deposit_success.wav'),

  /// Withdrawal request submitted successfully.
  withdrawalSuccess('assets/sounds/withdrawal_success.wav'),

  /// KYC approved by admin (status transitions to "approved").
  kycApproved('assets/sounds/kyc_approved.wav'),

  /// Investment plan enrolled / instalment paid / ROI or principal
  /// withdrawal confirmed.
  planActivated('assets/sounds/plan_activated.wav'),

  /// Referral reward successfully claimed.
  referralSuccess('assets/sounds/referral_success.wav'),

  /// Generic "it worked" cue — KYC submitted, other confirmations that
  /// don't have a bespoke cue of their own.
  transactionSuccess('assets/sounds/success_chime.wav'),

  /// Light tactile confirmation for primary-action button taps.
  buttonTap('assets/sounds/tap_tick.wav'),

  /// Soft, non-alarming cue for failures — used sparingly.
  error('assets/sounds/error_soft.wav');

  final String assetPath;
  const AppSoundEvent(this.assetPath);
}