// lib/services/audio/keypad_sound_player.dart
//
// Plays the short "tick"/"tock" cues for on-screen amount-entry
// keypads (Investment Amount screen, Configure Investment screen).
//
// Deliberately separate from AppSoundService: that service is tuned
// for one-off success chimes (long same-event debounce, ~850ms
// "don't overlap" window) which would silence most keys during fast
// digit entry. A keypad needs a much shorter guard — just long enough
// to stop true overlap on a double-fire, short enough to keep up with
// normal typing speed.
//
// Respects the same "sound effects enabled" preference as the rest of
// the app (reads AppSoundService.instance.isEnabled, so there's a
// single Settings toggle for both) and routes through the same
// ambient/sonification audio category, so it honours the device's
// silent switch / ringer mode automatically and never steals audio
// focus.
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'app_haptic_service.dart';
import 'app_sound_event.dart';
import 'app_sound_service.dart';

class KeypadSoundPlayer {
  KeypadSoundPlayer._();
  static final KeypadSoundPlayer instance = KeypadSoundPlayer._();

  /// Both clips are well under 100ms; this just needs to be a hair
  /// longer than that so a genuine double-fire (e.g. a stray extra
  /// pointer event) doesn't layer two clips, while normal fast typing
  /// (~120ms+ between keys) never gets dropped.
  static const Duration _overlapGuard = Duration(milliseconds: 90);

  final AudioPlayer _player = AudioPlayer(playerId: 'keypad_sound_player');

  bool _ready = false;
  bool _playing = false;

  Future<void> init() async {
    if (_ready) return;
    try {
      await _player.setReleaseMode(ReleaseMode.stop);
      await _player.setPlayerMode(PlayerMode.lowLatency);
      await _player.setAudioContext(
        AudioContext(
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.ambient,
            options: const {AVAudioSessionOptions.mixWithOthers},
          ),
          android: const AudioContextAndroid(
            isSpeakerphoneOn: false,
            stayAwake: false,
            contentType: AndroidContentType.sonification,
            usageType: AndroidUsageType.assistanceSonification,
            audioFocus: AndroidAudioFocus.none,
          ),
        ),
      );
      for (final event in [
        AppSoundEvent.keypadTap,
        AppSoundEvent.keypadBackspace,
      ]) {
        try {
          await AudioCache.instance
              .load(event.assetPath.replaceFirst('assets/', ''));
        } catch (e) {
          debugPrint('KeypadSoundPlayer: failed to preload ${event.name}: $e');
        }
      }
      _ready = true;
    } catch (e) {
      debugPrint('KeypadSoundPlayer: init failed, keypad sounds disabled: $e');
      _ready = false;
    }
  }

  /// Digit key tapped.
  void tap() => _play(AppSoundEvent.keypadTap);

  /// Backspace key tapped.
  void backspace() => _play(AppSoundEvent.keypadBackspace);

  void _play(AppSoundEvent event) {
    if (!_ready || !AppSoundService.instance.isEnabled) return;
    if (_playing) return; // never overlap
    _playing = true;
    _player
        .play(
      AssetSource(event.assetPath.replaceFirst('assets/', '')),
      mode: PlayerMode.lowLatency,
    )
        .catchError((e) {
      debugPrint('KeypadSoundPlayer: playback failed for ${event.name}: $e');
    });
    Future.delayed(_overlapGuard, () => _playing = false);
  }
}

/// Convenience call site used by every amount-entry keypad: fires the
/// right sound and a light haptic tick together, in one line.
class KeypadFeedback {
  KeypadFeedback._();

  static void digit() {
    KeypadSoundPlayer.instance.tap();
    AppHapticService.instance.lightTap();
  }

  static void backspace() {
    KeypadSoundPlayer.instance.backspace();
    AppHapticService.instance.lightTap();
  }
}