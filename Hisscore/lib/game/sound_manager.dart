import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'food_types.dart';

/// Plays the game's short retro sound effects (see tool/generate_sfx.dart)
/// and persists a mute toggle. Every call is best-effort: a missing audio
/// backend (e.g. a platform without one, or a test harness) never crashes
/// the game — it just plays silently.
class SoundManager {
  SoundManager();

  static const _enabledKey = 'hisscore.sound_enabled';
  static const _musicKey = 'hisscore.music_enabled';
  static const _musicLayers = ['bass', 'arp', 'lead'];
  static const _musicVolume = 0.4;

  /// Sound effects and music both mix with whatever else is playing instead
  /// of taking audio focus. A Snake game has no business permanently
  /// stopping the podcast someone had on: on Android that means asking for
  /// no focus at all, on iOS the ambient category.
  @visibleForTesting
  static final AudioContext mixWithOthers = AudioContext(
    android: const AudioContextAndroid(audioFocus: AndroidAudioFocus.none),
    iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
  );

  bool _enabled = true;
  bool get enabled => _enabled;

  final Map<String, AudioPool> _pools = {};

  bool _musicEnabled = true;
  bool get musicEnabled => _musicEnabled;

  // Music state: what the game wants, and what has been applied.
  final List<AudioPlayer> _layers = [];
  bool _wantPlaying = false;
  int _wantLayers = 1;
  bool _musicPlaying = false;
  int _appliedLayers = 0;
  bool _applying = false;
  bool _musicUnavailable = false;

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _enabled = prefs.getBool(_enabledKey) ?? true;
      _musicEnabled = prefs.getBool(_musicKey) ?? true;
    } catch (_) {
      // Local storage unavailable — default to enabled, just don't persist.
    }
  }

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_enabledKey, value);
    } catch (_) {
      // Best-effort; the in-memory toggle still applies this session.
    }
  }

  Future<void> setMusicEnabled(bool value) async {
    _musicEnabled = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_musicKey, value);
    } catch (_) {
      // Best-effort, as with the sound toggle.
    }
  }

  /// How many music layers play at [combo]: the bass always, the arpeggio
  /// from a x2 combo, the lead from x4.
  static int musicLayersForCombo(int combo) =>
      combo >= 4 ? 3 : (combo >= 2 ? 2 : 1);

  /// The sound file (without extension) for eating [type].
  static String pickupSound(FoodType type) => switch (type) {
    FoodType.apple => 'eat',
    FoodType.star => 'star',
    FoodType.shield => 'shield',
    FoodType.speedBurst => 'speed',
    FoodType.shrink => 'shrink',
    FoodType.magnet => 'magnet',
    FoodType.golden => 'golden',
    FoodType.poison => 'poison',
    FoodType.bank => 'bank',
  };

  Future<void> playPickup(FoodType type) => _play(pickupSound(type));

  Future<void> playEat() => _play('eat');
  Future<void> playBonus() => _play('bonus');
  Future<void> playLevelUp() => _play('levelup');
  Future<void> playCloseCall() => _play('closecall');
  Future<void> playNewBest() => _play('newbest');
  Future<void> playGameOver() => _play('gameover');

  Future<void> _play(String name) async {
    if (!_enabled) return;
    try {
      final pool = await _poolFor(name);
      await pool.start();
    } catch (e) {
      // No audio backend on this platform/harness — ignore.
      debugPrint('SoundManager: could not play $name ($e)');
    }
  }

  Future<AudioPool> _poolFor(String name) async {
    final existing = _pools[name];
    if (existing != null) return existing;
    // AudioPool.createFromAsset takes no audio context and does not forward
    // one, so its players fall back to the global default and ask for
    // AUDIOFOCUS_GAIN on every blip, stopping the player's own music. Build
    // the pool the long way so the effects mix, like the layers below.
    final pool = await AudioPool.create(
      source: AssetSource('sfx/$name.wav'),
      audioContext: mixWithOthers,
      maxPlayers: 3,
      playerMode: PlayerMode.lowLatency,
    );
    _pools[name] = pool;
    return pool;
  }

  /// Tells the music what the game is doing. Cheap and idempotent, so it
  /// can be called on every rebuild: it only acts when [playing] or the
  /// layer count for [combo] actually changes.
  void syncMusic({required bool playing, required int combo}) {
    final on = playing && _enabled && _musicEnabled && !_musicUnavailable;
    final layers = musicLayersForCombo(combo);
    if (on == _wantPlaying && layers == _wantLayers) return;
    _wantPlaying = on;
    _wantLayers = layers;
    _applyMusic();
  }

  Future<void> _applyMusic() async {
    if (_applying) return;
    _applying = true;
    try {
      while (_wantPlaying != _musicPlaying ||
          (_wantPlaying && _wantLayers != _appliedLayers)) {
        final on = _wantPlaying;
        final layers = _wantLayers;
        if (on) {
          await _ensureLayers();
          for (var i = 0; i < _layers.length; i++) {
            await _layers[i].setVolume(i < layers ? _musicVolume : 0);
          }
          if (!_musicPlaying) {
            // Start every layer together; they are all the same length, so
            // they stay in step.
            await Future.wait(_layers.map((p) => p.resume()));
          }
          _appliedLayers = layers;
        } else {
          await Future.wait(_layers.map((p) => p.pause()));
        }
        _musicPlaying = on;
      }
    } catch (e) {
      // No audio backend here: give up on music for the session.
      debugPrint('SoundManager: music unavailable ($e)');
      _musicUnavailable = true;
      _wantPlaying = false;
      _musicPlaying = false;
    } finally {
      _applying = false;
    }
  }

  Future<void> _ensureLayers() async {
    if (_layers.isNotEmpty) return;
    for (final name in _musicLayers) {
      final player = AudioPlayer();
      // Three players share one soundtrack. If each asked for audio focus
      // (the default), Android would hand it to the last one and pause the
      // others, leaving only a single layer. Don't take focus, and mix with
      // whatever else is playing.
      try {
        await player.setAudioContext(mixWithOthers);
      } catch (e) {
        debugPrint('SoundManager: could not set audio context ($e)');
      }
      await player.setReleaseMode(ReleaseMode.loop);
      await player.setSource(AssetSource('music/$name.wav'));
      _layers.add(player);
    }
  }

  Future<void> dispose() async {
    for (final pool in _pools.values) {
      try {
        await pool.dispose();
      } catch (_) {}
    }
    _pools.clear();
    for (final player in _layers) {
      try {
        await player.dispose();
      } catch (_) {}
    }
    _layers.clear();
  }
}
