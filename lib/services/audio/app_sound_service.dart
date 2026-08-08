// lib/services/audio/app_sound_service.dart
//
// Central manager for every short UI sound effect in the app (wallet
// reveal, deposit/withdrawal/KYC/plan/referral/login success, button
// taps). Mirrors the pattern used by GPay/PhonePe/Paytm/Navi:
//
//   - Every clip is preloaded once at startup so playback has no
//     first-play delay.
//   - Only one clip plays at a time — a new request while a clip is
//     already playing is dropped rather than layered on top, so cues
//     never overlap or stack up from rapid taps/refreshes.
//   - The same event is debounced for a short window so a rebuilding
//     widget or a duplicate notifyListeners() can't fire the same cue
//     twice in a row.
//   - Routed through the "sonification"/"ambient" system audio
//     category, so it automatically respects the device's silent /
//     vibrate switch (iOS) and ringer mode (Android) instead of always
//     playing at full volume regardless of the user's settings, and
//     never steals audio focus from music/calls already playing.
//   - Persisted on/off toggle (default: on) via SharedPreferences, so
//     a future "Sound effects" row in Settings can flip it with zero
//     extra wiring.
//
// Call AppSoundService.instance.init() once, early in main(), before
// runApp(). After that, call AppSoundService.instance.play(event)
// from anywhere (viewmodels, widgets) — it is always safe to call,
// even before init() finishes, since play() is a no-op until ready.
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_sound_event.dart';

class AppSoundService {
  AppSoundService._();
  static final AppSoundService instance = AppSoundService._();

  static const String _prefsKey = 'sound_effects_enabled';

  /// Minimum gap before the *same* event is allowed to fire again —
  /// guards against duplicate notifyListeners()/rebuild triggers
  /// firing one logical event twice.
  static const Duration _sameEventDebounce = Duration(milliseconds: 600);

  final AudioPlayer _player = AudioPlayer(playerId: 'app_sound_service');

  bool _ready = false;
  bool _enabled = true;
  bool _playing = false;
  AppSoundEvent? _lastEvent;
  DateTime? _lastPlayedAt;

  bool get isEnabled => _enabled;

  /// Preloads every clip and configures the low-latency, silent-mode
  /// respecting audio context. Safe to call once; subsequent calls are
  /// ignored.
  Future<void> init() async {
    if (_ready) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      _enabled = prefs.getBool(_prefsKey) ?? true;
    } catch (_) {
      _enabled = true;
    }

    try {
      await _player.setReleaseMode(ReleaseMode.stop);
      // PlayerMode.lowLatency keeps clips resident (SoundPool on
      // Android / minimal-buffer AVAudioPlayer on iOS) for
      // effectively-instant playback with no per-call decode delay.
      await _player.setPlayerMode(PlayerMode.lowLatency);
      await _player.setAudioContext(
        AudioContext(
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.ambient,
            options: const {
              AVAudioSessionOptions.mixWithOthers,
            },
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

      // Warm every clip into the low-latency cache so the very first
      // real playback has zero delay.
      for (final event in AppSoundEvent.values) {
        try {
          await AudioCache.instance
              .load(event.assetPath.replaceFirst('assets/', ''));
        } catch (e) {
          debugPrint('AppSoundService: failed to preload ${event.name}: $e');
        }
      }

      _ready = true;
    } catch (e) {
      // Sound is a nice-to-have — never let audio setup failure affect
      // the rest of the app.
      debugPrint('AppSoundService: init failed, sounds disabled: $e');
      _ready = false;
    }
  }

  /// Plays [event] once, unless sounds are disabled, setup hasn't
  /// finished, another clip is already playing, or this exact event
  /// just played a moment ago.
  Future<void> play(AppSoundEvent event) async {
    if (!_ready || !_enabled) return;
    if (_playing) return; // never overlap

    final now = DateTime.now();
    if (_lastEvent == event &&
        _lastPlayedAt != null &&
        now.difference(_lastPlayedAt!) < _sameEventDebounce) {
      return; // never repeat the same cue in quick succession
    }

    _playing = true;
    _lastEvent = event;
    _lastPlayedAt = now;
    try {
      await _player.stop();
      await _player.play(
        AssetSource(event.assetPath.replaceFirst('assets/', '')),
        mode: PlayerMode.lowLatency,
      );
    } catch (e) {
      debugPrint('AppSoundService: playback failed for ${event.name}: $e');
    } finally {
      // Release the "in-flight" guard slightly ahead of the actual
      // clip end (all clips are well under 1s) so a fast follow-up
      // success screen isn't starved of its own cue.
      Future.delayed(const Duration(milliseconds: 850), () {
        _playing = false;
      });
    }
  }

  /// Persists the sound on/off preference (e.g. from a Settings screen).
  Future<void> setEnabled(bool value) async {
    _enabled = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKey, value);
    } catch (_) {
      // Non-fatal — the in-memory toggle still applies for this session.
    }
  }
}