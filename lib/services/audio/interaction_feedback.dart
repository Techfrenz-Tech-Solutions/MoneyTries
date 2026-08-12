// lib/services/audio/interaction_feedback.dart
//
// Single entry point every viewmodel/view should use to signal a
// completed action. Pairs the right sound with the right haptic pulse
// so call sites stay a one-liner:
//
//   InteractionFeedback.depositSuccess();
//
// IMPORTANT: only ever call these AFTER an action has actually
// succeeded (e.g. inside a try block's success branch, never before
// an await, never in a "submitting" state) — every call site wired up
// in this app follows that rule.
import 'app_haptic_service.dart';
import 'app_sound_event.dart';
import 'app_sound_service.dart';
import 'keypad_sound_player.dart';

class InteractionFeedback {
  InteractionFeedback._();

  static Future<void> init() async {
    await Future.wait([
      AppSoundService.instance.init(),
      AppHapticService.instance.init(),
    ]);
    // Depends on AppSoundService's enabled-flag being loaded above, and
    // AppSoundService.instance.init() must run first so KeypadSoundPlayer
    // can read AppSoundService.instance.isEnabled.
    await KeypadSoundPlayer.instance.init();
  }

  /// Wallet balance revealed via the eye-icon toggle on Home.
  static void walletBalanceRevealed() {
    AppSoundService.instance.play(AppSoundEvent.walletBalance);
    AppHapticService.instance.lightTap();
  }

  /// Login (password flow or 2FA OTP) completed successfully.
  static void loginSuccess() {
    AppSoundService.instance.play(AppSoundEvent.loginSuccess);
    AppHapticService.instance.success();
  }

  /// Deposit request submitted successfully.
  static void depositSuccess() {
    AppSoundService.instance.play(AppSoundEvent.depositSuccess);
    AppHapticService.instance.success();
  }

  /// Withdrawal request submitted successfully.
  static void withdrawalSuccess() {
    AppSoundService.instance.play(AppSoundEvent.withdrawalSuccess);
    AppHapticService.instance.success();
  }

  /// KYC approved by admin (status transitioned to "approved").
  static void kycApproved() {
    AppSoundService.instance.play(AppSoundEvent.kycApproved);
    AppHapticService.instance.success();
  }

  /// Plan enrolled, instalment paid, or ROI/principal withdrawal confirmed.
  static void planActivated() {
    AppSoundService.instance.play(AppSoundEvent.planActivated);
    AppHapticService.instance.success();
  }

  /// Referral reward successfully claimed.
  static void referralSuccess() {
    AppSoundService.instance.play(AppSoundEvent.referralSuccess);
    AppHapticService.instance.success();
  }

  /// Generic success cue (e.g. KYC documents submitted, awaiting review).
  static void transactionSuccess() {
    AppSoundService.instance.play(AppSoundEvent.transactionSuccess);
    AppHapticService.instance.success();
  }

  /// Light tactile confirmation for a primary-action button press.
  static void buttonTap() {
    AppSoundService.instance.play(AppSoundEvent.buttonTap);
    AppHapticService.instance.lightTap();
  }

  /// Soft, non-alarming cue for a failed action.
  static void error() {
    AppSoundService.instance.play(AppSoundEvent.error);
    AppHapticService.instance.error();
  }
}