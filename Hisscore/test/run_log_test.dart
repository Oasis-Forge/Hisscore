import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisscore/game/daily_challenge.dart';
import 'package:hisscore/game/game_session.dart';
import 'package:hisscore/game/haptics.dart';
import 'package:hisscore/game/high_score_store.dart';
import 'package:hisscore/game/online_scores.dart';
import 'package:hisscore/game/run_log.dart';
import 'package:hisscore/game/snake_engine.dart';
import 'package:hisscore/game/weekly_modifier.dart';

/// A run written down as a seed and a list of turns, and played back
/// from it: the thing a server would need to check a score rather than
/// take the client's word, and the thing a ghost is raced from.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A ghost run eats, and eating reaches for the speaker. audioplayers
  // starts an unawaited init of its own that throws into the zone and
  // lands on whichever test is running; answering the channel with
  // nothing keeps the failures here about this file's subject.
  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('xyz.luan/audioplayers.global'),
          (call) async => null,
        );
  });

  /// A run driven by a fixed list of turns, so the same script always
  /// produces the same game.
  SnakeEngine played({
    int seed = 77,
    GameMode mode = GameMode.classic,
    WeeklyModifier? modifier,
    int columns = 16,
    int rows = 16,
    List<(int, Direction)> script = const [
      (3, Direction.down),
      (6, Direction.right),
      (9, Direction.up),
      (12, Direction.right),
      (16, Direction.down),
      (20, Direction.left),
    ],
    int ticks = 40,
  }) {
    final engine = SnakeEngine(
      columns: columns,
      rows: rows,
      mode: mode,
      modifier: modifier,
      fixedGrid: true,
      random: Random(seed),
    )..start();
    for (var tick = 1; tick <= ticks; tick++) {
      for (final (at, direction) in script) {
        if (at == tick) engine.queueTurn(direction);
      }
      if (engine.phase != GamePhase.running) break;
      engine.tick();
    }
    return engine;
  }

  // ═══════════════════════════════════════════════════
  // Recording
  // ═══════════════════════════════════════════════════

  group('what the engine writes down', () {
    test('a run that never turns records nothing', () {
      final engine = played(script: const [], ticks: 5);
      expect(engine.steers, isEmpty);
    });

    test('a turn is recorded with the tick it landed on', () {
      final engine = played(script: const [(3, Direction.down)], ticks: 6);
      expect(engine.steers, hasLength(1));
      expect(engine.steers.single.direction, Direction.down);
      expect(engine.steers.single.tick, greaterThan(0));
    });

    test('a turn that was refused is not recorded', () {
      final engine = SnakeEngine(random: Random(1))..start();
      // The snake starts facing right; a reversal never happens, so it
      // never happened.
      engine.queueTurn(Direction.left);
      engine.tick();
      expect(engine.steers, isEmpty);
      expect(engine.direction, Direction.right);
    });

    test('a mirrored week records the turn the snake actually took', () {
      final engine = SnakeEngine(
        modifier: WeeklyModifier.mirrored,
        random: Random(1),
      )..start();
      engine.queueTurn(Direction.down);
      engine.tick();
      engine.queueTurn(Direction.left);
      engine.tick();
      expect(
        engine.steers.last.direction,
        Direction.right,
        reason: 'the player asked for left and the snake went right',
      );
    });

    test('a fresh run starts with a clean sheet', () {
      final engine = played(ticks: 20);
      expect(engine.steers, isNotEmpty);
      engine.reset();
      expect(engine.steers, isEmpty);
    });
  });

  // ═══════════════════════════════════════════════════
  // Replaying
  // ═══════════════════════════════════════════════════

  group('a replay reproduces the run', () {
    void expectSameRun(SnakeEngine a, SnakeEngine b) {
      expect(b.score, a.score, reason: 'score');
      expect(b.totalTicks, a.totalTicks, reason: 'ticks');
      expect(b.snake, a.snake, reason: 'the snake ended somewhere else');
      expect(b.totalApplesEaten, a.totalApplesEaten, reason: 'apples');
      expect(b.phase, a.phase, reason: 'phase');
      expect(
        b.foods.map((f) => (f.position, f.type)),
        a.foods.map((f) => (f.position, f.type)),
        reason: 'the board is not the same board',
      );
    }

    test('exactly: the score and the final board', () {
      final run = played();
      final log = RunLog.of(run, seed: 77);

      expectSameRun(run, log.replay());
    });

    test('and again, and again', () {
      final log = RunLog.of(played(), seed: 77);
      expectSameRun(log.replay(), log.replay());
    });

    test('a run that ended in a wall ends in the same wall', () {
      // No turns at all: straight into the right-hand side.
      final run = played(script: const [], ticks: 200);
      expect(run.phase, GamePhase.gameOver);

      final replay = RunLog.of(run, seed: 77).replay();

      expectSameRun(run, replay);
    });

    test('through a weekly rule as well', () {
      for (final modifier in WeeklyModifier.values) {
        final run = played(modifier: modifier, columns: 20, rows: 30);
        final replay = RunLog.of(run, seed: 77).replay();
        expect(replay.score, run.score, reason: modifier.name);
        expect(replay.snake, run.snake, reason: modifier.name);
      }
    });

    test('and part of the way through, for a race', () {
      final run = played();
      final log = RunLog.of(run, seed: 77);

      final halfway = log.replay(untilTick: 12);

      expect(halfway.totalTicks, 12);
      expect(
        halfway.snake,
        isNot(run.snake),
        reason: 'it should be mid-run, not at the end',
      );
    });

    test('the seed is carried, not assumed', () {
      final run = played(seed: 77);
      final log = RunLog.of(run, seed: 77);
      expect(log.seed, 77);
      // The board a replay is dealt comes from the log, not from
      // whatever a fresh engine would roll.
      expect(log.engineForReplay().columns, run.columns);
      expect(log.engineForReplay().mode, run.mode);
    });
  });

  // ═══════════════════════════════════════════════════
  // Storage
  // ═══════════════════════════════════════════════════

  group('written down and read back', () {
    test('a log survives the round trip', () {
      final log = RunLog.of(
        played(modifier: WeeklyModifier.fog, columns: 20, rows: 30),
        seed: 77,
        dayNumber: 265,
      );

      final back = RunLog.decode(log.encode())!;

      expect(back.seed, log.seed);
      expect(back.columns, log.columns);
      expect(back.rows, log.rows);
      expect(back.mode, log.mode);
      expect(back.modifier, WeeklyModifier.fog);
      expect(back.dayNumber, 265);
      expect(back.ticks, log.ticks);
      expect(back.score, log.score);
      expect(back.steers, log.steers);
    });

    test('and replays the same from the written form', () {
      final run = played();
      final back = RunLog.decode(RunLog.of(run, seed: 77).encode())!;
      expect(back.replay().score, run.score);
      expect(back.replay().snake, run.snake);
    });

    test('it stays short enough to keep', () {
      final log = RunLog.of(played(ticks: 300), seed: 77);
      expect(
        log.encode().length,
        lessThan(2000),
        reason: 'a full run has to sit in preferences without a thought',
      );
    });

    test('a log with no turns still reads back', () {
      final log = RunLog.of(played(script: const [], ticks: 4), seed: 77);
      final back = RunLog.decode(log.encode());
      expect(back, isNotNull);
      expect(back!.steers, isEmpty);
    });

    test('nonsense is no log at all, not an exception', () {
      for (final raw in [
        null,
        '',
        'not a log',
        '1|only|three',
        '2|77|16|16|classic|||40|0|', // a version this build cannot read
        '1|77|16|16|nosuchmode|||40|0|',
        '1|x|16|16|classic|||40|0|',
      ]) {
        expect(RunLog.decode(raw), isNull, reason: raw ?? 'null');
      }
    });

    test('both stores keep one', () async {
      final log = RunLog.of(played(), seed: 77, dayNumber: 3);

      final memory = InMemoryHighScoreStore();
      expect(await memory.loadDailyGhost(), isNull);
      await memory.saveDailyGhost(log);
      expect((await memory.loadDailyGhost())!.score, log.score);
    });
  });

  // ═══════════════════════════════════════════════════
  // The race
  // ═══════════════════════════════════════════════════

  group('the ghost', () {
    GameSession sessionOn(int day, {HighScoreStore? store}) => GameSession(
      store: store ?? InMemoryHighScoreStore(),
      onlineScores: const NoopOnlineScoreBoard(),
      // A run that eats reaches for the phone's vibration motor, and
      // there is no phone here.
      haptics: Haptics(impl: const _SilentHaptics()),
      now: () => DailyChallenge.dateForDay(day),
    );

    test('there is none until a daily has been played', () async {
      final session = sessionOn(265);
      await session.load();
      expect(session.ghostScore, isNull);
      session.startDaily();
      expect(session.ghostSnake, isEmpty);
      session.dispose();
    });

    test('a finished daily leaves one behind', () async {
      final store = InMemoryHighScoreStore();
      final session = sessionOn(265, store: store);
      await session.load();
      session.startDaily();
      for (var i = 0; i < 6; i++) {
        session.onTicker();
      }
      session.engine.phase = GamePhase.gameOver;
      await session.persistGameEnd();

      final kept = await store.loadDailyGhost();
      expect(kept, isNotNull);
      expect(kept!.dayNumber, 265);
      expect(kept.score, session.engine.score);
      session.dispose();
    });

    test('and a worse run does not replace it', () async {
      final store = InMemoryHighScoreStore();
      final first = sessionOn(265, store: store);
      await first.load();
      first.startDaily();
      first.engine.score = 900;
      first.engine.phase = GamePhase.gameOver;
      await first.persistGameEnd();
      first.dispose();

      final second = sessionOn(265, store: store);
      await second.load();
      second.startDaily();
      second.engine.score = 100;
      second.engine.phase = GamePhase.gameOver;
      await second.persistGameEnd();

      expect((await store.loadDailyGhost())!.score, 900);
      second.dispose();
    });

    test('a better one does', () async {
      final store = InMemoryHighScoreStore();
      final first = sessionOn(265, store: store);
      await first.load();
      first.startDaily();
      first.engine.score = 100;
      first.engine.phase = GamePhase.gameOver;
      await first.persistGameEnd();
      first.dispose();

      final second = sessionOn(265, store: store);
      await second.load();
      second.startDaily();
      second.engine.score = 900;
      second.engine.phase = GamePhase.gameOver;
      await second.persistGameEnd();

      expect((await store.loadDailyGhost())!.score, 900);
      second.dispose();
    });

    test("yesterday's ghost is not raced against today's board", () async {
      final store = InMemoryHighScoreStore();
      final yesterday = sessionOn(264, store: store);
      await yesterday.load();
      yesterday.startDaily();
      yesterday.engine.score = 500;
      yesterday.engine.phase = GamePhase.gameOver;
      await yesterday.persistGameEnd();
      yesterday.dispose();

      final today = sessionOn(265, store: store);
      await today.load();

      expect(today.savedGhost, isNotNull, reason: 'it is still on disk');
      expect(today.ghostScore, isNull, reason: 'but not for this board');
      today.startDaily();
      expect(today.ghostSnake, isEmpty);
      today.dispose();
    });

    test('it runs alongside the live run, tick for tick', () async {
      final store = InMemoryHighScoreStore();
      final first = sessionOn(265, store: store);
      await first.load();
      first.startDaily();
      for (var i = 0; i < 12; i++) {
        first.onTicker();
      }
      first.engine.phase = GamePhase.gameOver;
      await first.persistGameEnd();
      final ticksRun = first.engine.totalTicks;
      first.dispose();

      final rematch = sessionOn(265, store: store);
      await rematch.load();
      rematch.startDaily();

      expect(rematch.ghostSnake, isNotEmpty, reason: 'the race is on');
      for (var i = 0; i < 5; i++) {
        rematch.onTicker();
      }
      expect(rematch.ghost!.totalTicks, rematch.engine.totalTicks);

      // And it stops where the run it came from stopped.
      for (var i = 0; i < ticksRun + 5; i++) {
        rematch.onTicker();
      }
      expect(rematch.ghostSnake, isEmpty);
      rematch.dispose();
    });

    test('no race outside the daily', () async {
      final store = InMemoryHighScoreStore();
      final daily = sessionOn(265, store: store);
      await daily.load();
      daily.startDaily();
      daily.engine.phase = GamePhase.gameOver;
      await daily.persistGameEnd();
      daily.dispose();

      final plain = sessionOn(265, store: store);
      await plain.load();
      plain.primaryAction();

      expect(plain.ghostSnake, isEmpty);
      plain.dispose();
    });
  });
}

class _SilentHaptics implements HapticImpl {
  const _SilentHaptics();

  @override
  void light() {}

  @override
  void medium() {}

  @override
  void heavy() {}

  @override
  void selection() {}
}
