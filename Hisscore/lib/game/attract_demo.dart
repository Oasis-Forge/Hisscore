import 'dart:async';

import 'package:flutter/foundation.dart';

import 'auto_player.dart';
import 'snake_engine.dart';

/// The snake that plays itself behind the menu, so the intro shows the
/// game instead of describing it.
///
/// It is deliberately its own engine: the menu must never disturb the
/// run the player is in the middle of, and a demo that cornered itself
/// simply starts over rather than sitting on a dead board.
class AttractDemo extends ChangeNotifier {
  AttractDemo({this.now = DateTime.now});

  /// Wall clock, injectable for tests.
  final DateTime Function() now;

  static const tickInterval = Duration(milliseconds: 170);

  SnakeEngine? _engine;
  Timer? _ticker;
  late DateTime _tickAt = now();

  SnakeEngine? get engine => _engine;

  bool get running => _ticker != null;

  void start() {
    _ticker?.cancel();
    final demo = SnakeEngine(
      columns: 20,
      rows: 20,
      mode: GameMode.endless, // wraps, so the demo rarely stalls
    );
    demo.start();
    _engine = demo;
    _tickAt = now();
    _ticker = Timer.periodic(tickInterval, (_) => _tick(demo));
    notifyListeners();
  }

  void _tick(SnakeEngine demo) {
    _tickAt = now();
    final next = AutoPlayer.chooseDirection(demo);
    if (next != null) demo.queueTurn(next);
    demo.tick();
    // Cornered itself — start over rather than sit on a dead board.
    if (demo.phase != GamePhase.running) {
      demo.reset();
      demo.start();
    }
    notifyListeners();
  }

  void stop() {
    _ticker?.cancel();
    _ticker = null;
    _engine = null;
    notifyListeners();
  }

  /// How far through the current tick the demo is, for the board's
  /// movement interpolation.
  double get tickProgress {
    final demo = _engine;
    if (demo == null) return 1;
    final tickMs = demo.tickInterval.inMilliseconds;
    if (tickMs <= 0) return 1;
    final elapsed = now().difference(_tickAt).inMicroseconds;
    return (elapsed / (tickMs * 1000)).clamp(0.0, 1.0);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
