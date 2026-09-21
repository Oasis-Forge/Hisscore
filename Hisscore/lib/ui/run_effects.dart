import 'dart:async';

import 'package:flutter/material.dart';

import '../game/food_types.dart';
import '../game/snake_engine.dart';
import 'floating_label.dart';
import 'particles.dart';
import 'screen_shake.dart';
import 'theme.dart';

/// The noise a run makes on screen: eat bursts, floating score popups,
/// the level-up edge glow, the screen shake and the death flash.
///
/// None of this is game state — the run plays out identically with all
/// of it switched off — so it is kept away from both the engine and the
/// session. The page feeds it the board geometry and the moments; it
/// owns the timers and hands back what to draw.
class RunEffects extends ChangeNotifier {
  RunEffects({this.now = DateTime.now});

  /// Wall clock, injectable for tests.
  final DateTime Function() now;

  static const levelFlashDuration = Duration(milliseconds: 420);
  static const deathFlashDuration = Duration(milliseconds: 500);
  static const labelLifetime = Duration(milliseconds: 700);

  /// How long the board is left on screen, in slow motion, before the
  /// game-over card covers it. The card used to appear on the same
  /// frame as the death, which threw away the one moment the player
  /// wants to look at: how they died.
  static const deathPause = Duration(milliseconds: 400);

  /// How fast the world runs during that pause.
  static const slowMotionScale = 0.3;

  final particles = ParticleSystem();
  final shake = ScreenShakeController();
  final List<FloatingLabel> labels = [];

  final List<Timer> _labelTimers = [];
  int _labelSeq = 0;

  DateTime? _levelFlashAt;
  DateTime? _deathAt;
  Timer? _deathPauseTimer;

  /// The slow-motion beat between the death and the card. The page
  /// holds the game-over overlay back while this is true.
  bool get dying => _deathAt != null && _deathPauseTimer != null;

  // ─── Geometry ─────────────────────────────────────

  /// Measured board geometry, so particles and popups land on the cell
  /// they belong to instead of an assumed board size. The page sets
  /// these every layout, because only the page has measured itself.
  Size boardSize = Size.zero;
  Offset boardOffset = Offset.zero;
  int columns = 1;
  int rows = 1;

  void measure({
    required Size size,
    required Offset offset,
    required int columns,
    required int rows,
  }) {
    boardSize = size;
    boardOffset = offset;
    this.columns = columns;
    this.rows = rows;
  }

  /// Centre of a grid cell in the board's own pixel space — the same
  /// space the painter (and therefore the particle system) draws in.
  Offset cellCentre(GridPoint point) {
    final cellW = boardSize.width / columns;
    final cellH = boardSize.height / rows;
    return Offset(point.x * cellW + cellW / 2, point.y * cellH + cellH / 2);
  }

  // ─── Moments ──────────────────────────────────────

  /// Something was eaten at [food]'s cell, worth [gained] points, with
  /// the combo now at [comboCount].
  void ate(
    FoodItem food,
    int gained, {
    required int comboCount,
    required double multiplier,
  }) {
    final pos = food.position;
    final cell = cellCentre(pos);
    particles.emitEat(cell.dx, cell.dy, _colorFor(food.type));
    if (comboCount > 1) {
      particles.emitComboSparkle(cell.dx, cell.dy - 10);
    }
    if (gained > 0) {
      spawnLabel('+$gained', pos, RetroColors.phosphorHot);
    }
    if (comboCount > 1) {
      spawnLabel(
        'COMBO x${multiplier.toStringAsFixed(1)}',
        GridPoint(pos.x, pos.y - 1),
        RetroColors.combo,
        big: true,
      );
    }
  }

  void levelUp(int level) {
    spawnLabel(
      'LEVEL $level!',
      GridPoint(columns ~/ 2, rows ~/ 2),
      RetroColors.amber,
      big: true,
    );
    shake.shake(intensity: 3);
    _levelFlashAt = now();
  }

  void died(GridPoint head) {
    final cell = cellCentre(head);
    particles.emitDeath(cell.dx, cell.dy, RetroColors.cherry);
    shake.shake(intensity: 8);
    _deathAt = now();
    _deathPauseTimer?.cancel();
    particles.timeScale = slowMotionScale;
    _deathPauseTimer = Timer(deathPause, _endDeathPause);
  }

  void _endDeathPause() {
    _deathPauseTimer = null;
    particles.timeScale = 1.0;
    notifyListeners();
  }

  /// Spawns a floating text popup at a grid position; it rises and
  /// fades, then removes itself.
  void spawnLabel(
    String text,
    GridPoint gridPos,
    Color color, {
    bool big = false,
  }) {
    final cell = cellCentre(gridPos);
    final id = _labelSeq++;
    labels.add(
      FloatingLabel(
        id: id,
        text: text,
        // Labels sit in the board *area*, so shift by where the board
        // itself is within it.
        x: cell.dx + boardOffset.dx,
        y: cell.dy + boardOffset.dy,
        color: color,
        big: big,
      ),
    );
    late final Timer timer;
    timer = Timer(labelLifetime, () {
      _labelTimers.remove(timer);
      labels.removeWhere((l) => l.id == id);
      notifyListeners();
    });
    _labelTimers.add(timer);
  }

  /// A fresh run starts on a clean screen, at full speed.
  void clear() {
    particles.clear();
    particles.timeScale = 1.0;
    _cancelLabelTimers();
    labels.clear();
    _deathPauseTimer?.cancel();
    _deathPauseTimer = null;
    _levelFlashAt = null;
    _deathAt = null;
  }

  // ─── Fades ────────────────────────────────────────

  double get levelFlashOpacity => _fade(_levelFlashAt, levelFlashDuration);

  /// The red flash runs on death time rather than wall time, so it
  /// crawls through the slow-motion beat and then finishes at normal
  /// speed once the card is on its way in.
  double get deathFlashOpacity {
    if (_deathAt == null) return 0;
    final elapsed = deathElapsed.inMilliseconds;
    final span = deathFlashDuration.inMilliseconds;
    if (elapsed >= span) return 0;
    return 1.0 - elapsed / span;
  }

  /// Time since the death as the effects experience it: slowed for the
  /// length of [deathPause], normal speed after. Continuous at the
  /// hand-over, so nothing jumps when the world speeds back up.
  Duration get deathElapsed {
    final at = _deathAt;
    if (at == null) return Duration.zero;
    final real = now().difference(at);
    if (real <= deathPause) return real * slowMotionScale;
    return deathPause * slowMotionScale + (real - deathPause);
  }

  double _fade(DateTime? at, Duration total) {
    if (at == null) return 0;
    final elapsed = now().difference(at).inMilliseconds;
    final span = total.inMilliseconds;
    if (elapsed >= span) return 0;
    return 1.0 - elapsed / span;
  }

  static Color _colorFor(FoodType type) => switch (type) {
    FoodType.apple => RetroColors.food,
    FoodType.star => RetroColors.starGold,
    FoodType.shield => RetroColors.shieldCyan,
    FoodType.speedBurst => RetroColors.speedYellow,
    FoodType.shrink => RetroColors.shrinkPurple,
    FoodType.magnet => RetroColors.magnetPink,
  };

  void _cancelLabelTimers() {
    for (final t in _labelTimers) {
      t.cancel();
    }
    _labelTimers.clear();
  }

  @override
  void dispose() {
    _cancelLabelTimers();
    _deathPauseTimer?.cancel();
    shake.dispose();
    super.dispose();
  }
}
