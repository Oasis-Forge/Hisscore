import 'dart:async';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'food_types.dart';

/// The platform calls, behind an interface.
///
/// Vibration is the one thing in the game that cannot be checked on an
/// emulator, in a widget test or in a screenshot — there is nothing to
/// look at and nothing to hear. Putting the four calls behind this seam
/// at least makes *which* buzz fires at *which* moment testable, and
/// leaves only "does the phone actually shake" for a human with a phone.
abstract class HapticImpl {
  void light();
  void medium();
  void heavy();
  void selection();
}

class SystemHaptics implements HapticImpl {
  const SystemHaptics();

  @override
  void light() => unawaited(HapticFeedback.lightImpact());

  @override
  void medium() => unawaited(HapticFeedback.mediumImpact());

  @override
  void heavy() => unawaited(HapticFeedback.heavyImpact());

  @override
  void selection() => unawaited(HapticFeedback.selectionClick());
}

/// What the game feels like in the hand, and the switch to turn it off.
///
/// A static [instance] rather than an injected one, for the same reason
/// the palette and the skin are: the buttons that buzz are leaf widgets
/// several layers from anything that could hand them a service, and a
/// player who turns vibration off means everywhere, not in the parts of
/// the app that happen to have it plumbed through.
class Haptics {
  Haptics({this.impl = const SystemHaptics()});

  /// Swapped out by tests; the app leaves it alone.
  static Haptics instance = Haptics();

  static const _enabledKey = 'hisscore.haptics_enabled';

  /// The gap between the two pulses of a level-up, long enough to read
  /// as two and short enough to read as one event.
  static const doublePulseGap = Duration(milliseconds: 90);

  /// The platform underneath. Swapped for a recorder in tests.
  final HapticImpl impl;

  bool _enabled = true;
  bool get enabled => _enabled;

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _enabled = prefs.getBool(_enabledKey) ?? true;
    } catch (_) {
      // Local storage unavailable — default to on, just don't persist.
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

  // ─── The moments ──────────────────────────────────

  /// A button, anywhere in the app.
  void tap() => _fire(impl.light);

  /// A menu choice — a mode, a theme, a tab.
  void select() => _fire(impl.selection);

  /// Something was eaten. An apple is the quiet common case; a pickup
  /// is rarer and gets the sharper click; a bank is the largest single
  /// thing that happens in a run and is felt accordingly.
  void ate(FoodType type) => _fire(switch (type) {
    FoodType.apple => impl.light,
    FoodType.bank => impl.medium,
    _ => impl.selection,
  });

  /// The combo went up a step.
  void combo() => _fire(impl.medium);

  /// A scrape steered out of.
  void closeCall() => _fire(impl.selection);

  /// The run ended.
  void death() => _fire(impl.heavy);

  /// Adventure advanced a level: two pulses, so it is not mistaken for
  /// a combo step.
  void levelUp() {
    if (!_enabled) return;
    impl.medium();
    Timer(doublePulseGap, () {
      // Re-checked on the way out: the player may have switched
      // vibration off between the two halves of the pulse.
      if (_enabled) impl.medium();
    });
  }

  void _fire(VoidCallback call) {
    if (!_enabled) return;
    call();
  }
}
