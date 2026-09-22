import 'dart:math';

import 'snake_engine.dart';
import 'weekly_modifier.dart';

/// Everything needed to play a run back exactly as it happened: the
/// board it was dealt, the seed behind that deal, and every turn that
/// actually took effect.
///
/// The engine is already deterministic — its clock is counted in ticks
/// rather than read from the wall — so a seed and a list of turns is
/// the whole run. Nothing about the score is stored to be trusted: a
/// replay recomputes it, which is what makes this the thing a server
/// would need to check a score rather than take the client's word.
class RunLog {
  const RunLog({
    required this.seed,
    required this.columns,
    required this.rows,
    required this.mode,
    required this.ticks,
    required this.score,
    this.modifier,
    this.dayNumber,
    this.steers = const [],
  });

  final int seed;
  final int columns;
  final int rows;
  final GameMode mode;

  /// The weekly rule the run was played under, if it was a daily.
  final WeeklyModifier? modifier;

  /// Which daily this was, so a ghost from yesterday is not raced
  /// against today's board.
  final int? dayNumber;

  /// How many ticks the run lasted.
  final int ticks;

  /// What the run scored. Kept for showing, never for trusting — the
  /// replay is the authority.
  final int score;

  final List<Steer> steers;

  /// The log of a run, ready to be replayed.
  ///
  /// [seed] has to be passed in because the engine holds a [Random],
  /// not the number behind it; only the caller that dealt the board
  /// knows that.
  factory RunLog.of(SnakeEngine engine, {required int seed, int? dayNumber}) =>
      RunLog(
        seed: seed,
        columns: engine.columns,
        rows: engine.rows,
        mode: engine.mode,
        modifier: engine.modifier,
        dayNumber: dayNumber,
        ticks: engine.totalTicks,
        score: engine.score,
        steers: List.of(engine.steers),
      );

  /// Plays the run back on a fresh engine and hands it back at the
  /// moment the original ended.
  ///
  /// Turns are put straight onto the engine rather than queued, because
  /// what was recorded is the direction the snake actually took — a
  /// mirrored week would otherwise bend each one a second time.
  SnakeEngine replay({int? untilTick}) {
    final engine = engineForReplay()..start();
    final stop = untilTick ?? ticks;
    var next = 0;
    for (var tick = 1; tick <= stop; tick++) {
      while (next < steers.length && steers[next].tick <= tick) {
        engine.direction = steers[next].direction;
        next++;
      }
      engine.tick();
    }
    return engine;
  }

  /// A fresh engine dealt exactly the board this run was dealt.
  SnakeEngine engineForReplay() => SnakeEngine(
    columns: columns,
    rows: rows,
    mode: mode,
    modifier: modifier,
    fixedGrid: true,
    random: Random(seed),
  );

  /// The steer that lands on [tick], if any.
  Direction? steerAt(int tick) {
    for (final steer in steers) {
      if (steer.tick == tick) return steer.direction;
    }
    return null;
  }

  // ─── Storage ──────────────────────────────────────

  /// Direction letters, fixed forever: they are in saved logs.
  static const _letters = {
    Direction.up: 'U',
    Direction.down: 'D',
    Direction.left: 'L',
    Direction.right: 'R',
  };

  /// One line, and short enough to sit in `SharedPreferences` without
  /// thinking about it.
  ///
  /// The turns are a run of `<tick><letter>` with no separator, which
  /// needs none: a letter ends a number. A few hundred characters for a
  /// full daily.
  String encode() {
    final steerText = [
      for (final steer in steers) '${steer.tick}${_letters[steer.direction]}',
    ].join();
    return [
      '1', // format version, so an old log can be dropped rather than misread
      seed,
      columns,
      rows,
      mode.name,
      modifier?.name ?? '',
      dayNumber ?? '',
      ticks,
      score,
      steerText,
    ].join('|');
  }

  /// The reverse, and forgiving: anything it cannot read is a log that
  /// is simply not there, never an exception into a game that was
  /// about to start.
  static RunLog? decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final parts = raw.split('|');
      if (parts.length != 10 || parts[0] != '1') return null;
      final mode = GameMode.values.asNameMap()[parts[4]];
      if (mode == null) return null;
      return RunLog(
        seed: int.parse(parts[1]),
        columns: int.parse(parts[2]),
        rows: int.parse(parts[3]),
        mode: mode,
        modifier: parts[5].isEmpty
            ? null
            : WeeklyModifier.values.asNameMap()[parts[5]],
        dayNumber: parts[6].isEmpty ? null : int.parse(parts[6]),
        ticks: int.parse(parts[7]),
        score: int.parse(parts[8]),
        steers: _decodeSteers(parts[9]),
      );
    } catch (_) {
      return null;
    }
  }

  static List<Steer> _decodeSteers(String raw) {
    final steers = <Steer>[];
    final digits = StringBuffer();
    for (final rune in raw.runes) {
      final char = String.fromCharCode(rune);
      final direction = _letters.entries
          .where((e) => e.value == char)
          .firstOrNull
          ?.key;
      if (direction == null) {
        digits.write(char);
        continue;
      }
      steers.add((tick: int.parse(digits.toString()), direction: direction));
      digits.clear();
    }
    return steers;
  }
}
