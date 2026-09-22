import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:hisscore/game/challenge_code.dart';
import 'package:hisscore/game/daily_challenge.dart';
import 'package:hisscore/game/food_types.dart';
import 'package:hisscore/game/game_session.dart';
import 'package:hisscore/game/high_score_store.dart';
import 'package:hisscore/game/online_scores.dart';
import 'package:hisscore/game/snake_engine.dart';

/// Extracting the session out of `GamePage` is what makes this file
/// possible: none of it needs a `WidgetTester`, because none of it is a
/// widget any more.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late InMemoryHighScoreStore store;
  late GameSession session;

  /// A fixed "today", so streaks and day numbers never depend on when
  /// the suite happens to run.
  DateTime today() => DateTime(2026, 9, 21, 12);

  GameSession build({
    GameMode mode = GameMode.classic,
    OnlineScoreBoard? online,
  }) {
    store = InMemoryHighScoreStore();
    return session = GameSession(
      store: store,
      onlineScores: online ?? const NoopOnlineScoreBoard(),
      engineFactory: () => SnakeEngine(mode: mode, random: Random(1)),
      now: today,
    )..selectedMode = mode;
  }

  /// Ticks until the run ends, then waits for the save it kicked off.
  /// The limit stops a broken engine hanging the suite instead of
  /// failing it.
  Future<void> runToDeath(GameSession s, {int limit = 500}) async {
    for (var i = 0; i < limit && s.engine.phase == GamePhase.running; i++) {
      s.onTicker();
    }
    expect(
      s.engine.phase,
      GamePhase.gameOver,
      reason: 'the run should have ended within $limit ticks',
    );
    await s.saveInFlight;
  }

  tearDown(() => session.dispose());

  // ═══════════════════════════════════════════════════
  // Starting and stopping
  // ═══════════════════════════════════════════════════

  test('the primary action starts a ready game', () {
    final s = build();
    expect(s.engine.phase, GamePhase.ready);

    s.primaryAction();

    expect(s.engine.phase, GamePhase.running);
    expect(s.startedAt, isNotNull);
    s.pause();
  });

  test('the tap that starts a run cannot immediately pause it', () {
    final s = build();
    s.primaryAction();

    // The same instant as the start, because `now` is fixed.
    s.primaryAction();

    expect(
      s.engine.phase,
      GamePhase.running,
      reason: 'a double-fire inside the guard window must not pause',
    );
    s.pause();
  });

  test('pausing only applies to a running game', () {
    final s = build();
    s.pause();
    expect(s.engine.phase, GamePhase.ready);

    s.primaryAction();
    s.pause();
    expect(s.engine.phase, GamePhase.paused);

    // Pausing a paused game must not toggle it back to running.
    s.pause();
    expect(s.engine.phase, GamePhase.paused);
  });

  test('returning to the menu drops the daily and challenge flags', () {
    final s = build();
    s.startDaily();
    expect(s.isDailyRun, isTrue);

    s.returnToMenu();

    expect(s.isDailyRun, isFalse);
    expect(s.challenge, isNull);
    expect(s.engine.phase, GamePhase.ready);
    expect(s.engine.score, 0);
  });

  test('the grid provider shapes a fresh engine', () {
    store = InMemoryHighScoreStore();
    session = GameSession(
      store: store,
      onlineScores: const NoopOnlineScoreBoard(),
      now: today,
    )..gridProvider = (() => (columns: 11, rows: 17));

    final engine = session.newEngine();

    expect(engine.columns, 11);
    expect(engine.rows, 17);
  });

  // ═══════════════════════════════════════════════════
  // Seeded runs
  // ═══════════════════════════════════════════════════

  test('the daily runs Classic on the fixed grid', () {
    final s = build(mode: GameMode.hardcore);
    s.startDaily();

    expect(s.engine.mode, GameMode.classic);
    expect(s.engine.columns, DailyChallenge.gridColumns);
    expect(s.engine.rows, DailyChallenge.gridRows);
    expect(s.isDailyRun, isTrue);
    s.pause();
  });

  test('the daily board is the same one twice over', () {
    final first = build()..startDaily();
    final firstFood = first.engine.food;
    first.dispose();

    final second = build()..startDaily();

    expect(second.engine.food, firstFood);
    second.pause();
  });

  test('a challenge code brings its own mode and seed', () {
    final code = ChallengeCode.random(GameMode.hardcore);
    final s = build();

    s.startChallenge(code);

    expect(s.engine.mode, GameMode.hardcore);
    expect(s.selectedMode, GameMode.hardcore);
    expect(s.challenge, code);
    expect(s.engine.columns, DailyChallenge.gridColumns);
    s.pause();
  });

  // ═══════════════════════════════════════════════════
  // The callbacks the page draws from
  // ═══════════════════════════════════════════════════

  test('eating and dying reach the page', () async {
    final s = build();
    final eaten = <FoodItem>[];
    var gameOvers = 0;
    var ticks = 0;
    s
      ..onAte = ((food, _) => eaten.add(food))
      ..onGameOver = (() => gameOvers++)
      ..onTick = (() => ticks++);

    s.primaryAction();
    await runToDeath(s);

    expect(ticks, greaterThan(0));
    expect(eaten, isNotEmpty, reason: 'the snake eats before it hits a wall');
    expect(gameOvers, 1);
  });

  test('the points a pickup paid are what the popup is given', () {
    final s = build();
    var reported = -1;
    s.onAte = ((_, gained) => reported = gained);

    s.primaryAction();
    while (s.engine.phase == GamePhase.running && reported < 0) {
      s.onTicker();
    }

    expect(reported, 10, reason: 'the first apple at x1 combo is 10 points');
    s.pause();
  });

  // ═══════════════════════════════════════════════════
  // What a finished run writes down
  // ═══════════════════════════════════════════════════

  test('a finished run saves the score, an entry and the stats', () async {
    final s = build();
    s.primaryAction();
    await runToDeath(s);

    expect(s.engine.score, greaterThan(0));
    expect(await store.load(), s.engine.score);
    expect(await store.loadTopScores(), hasLength(1));
    expect((await store.loadStats()).gamesPlayed, 1);
    expect(s.newHighScore, isTrue);
  });

  test('a worse run does not overwrite the saved best', () async {
    final s = build();
    await store.save(99999);
    await s.load();

    s.primaryAction();
    await runToDeath(s);

    expect(await store.load(), 99999);
    expect(s.newHighScore, isFalse);
  });

  test('zen is outside the high score and the leaderboard', () async {
    final s = build(mode: GameMode.zen);
    s.primaryAction();
    expect(s.countsForLeaderboard, isFalse);

    for (var i = 0; i < 40; i++) {
      s.onTicker();
    }
    final scored = s.engine.score;
    await s.persistGameEnd();

    expect(scored, greaterThan(0), reason: 'zen still scores on screen');
    expect(await store.load(), 0, reason: 'but never as the high score');
    expect(await store.loadTopScores(), isEmpty);
    s.pause();
  });

  test('a finished run pays out XP', () async {
    final s = build();
    s.primaryAction();
    await runToDeath(s);

    expect(s.outcome, isNotNull);
    expect(s.outcome!.xpGained, greaterThan(0));
    expect((await store.loadProgress()).xp, s.progress.xp);
  });

  test('a finished daily starts the streak and stamps the day', () async {
    final s = build();
    s.startDaily();
    await runToDeath(s);

    expect(s.dailyState.currentStreak, 1);
    expect(s.dailyState.bestStreak, 1);
    expect(s.dailyState.lastPlayedKey, DailyChallenge.dateKey(today()));
    expect(s.playedDailyToday, isTrue);
    expect((await store.loadDailyState()).currentStreak, 1);
  });

  test('a second daily the same day keeps the better score', () async {
    final s = build();
    s.startDaily();
    await runToDeath(s);
    final first = s.engine.score;

    // Replay the same seeded board: the same score again, so the stored
    // one must neither double up nor drop.
    s.startDaily();
    await runToDeath(s);

    expect(s.dailyState.lastScore, first);
    expect(s.dailyState.currentStreak, 1, reason: 'one day is one streak day');
  });

  test('a scoring run is submitted to the boards it belongs on', () async {
    final board = InMemoryOnlineScoreBoard();
    final s = build(online: board);
    s.primaryAction();
    await runToDeath(s);

    final allTime = await board.top(BoardId.allTime(GameMode.classic));
    expect(allTime, hasLength(1));
    expect(allTime.first.score, s.engine.score);
    expect(await board.top(BoardId.daily(s.dailyDayNumber)), isEmpty);
  });

  test('a daily run goes on the daily board and no other', () async {
    final board = InMemoryOnlineScoreBoard();
    final s = build(online: board);
    s.startDaily();
    await runToDeath(s);

    expect(await board.top(BoardId.daily(s.dailyDayNumber)), hasLength(1));
    // Every week bends the daily by some rule, so a daily score is
    // never a plain Classic score and does not belong next to them.
    expect(await board.top(BoardId.allTime(GameMode.classic)), isEmpty);
  });

  test('a save that outlives its page does not throw', () async {
    final s = build();
    s.primaryAction();
    for (var i = 0; i < 500 && s.engine.phase == GamePhase.running; i++) {
      s.onTicker();
    }
    final pending = s.saveInFlight;

    // The player left the page the instant the run ended.
    s.dispose();

    await expectLater(pending, completes);
  });

  test('the saved look is loaded but not applied here', () async {
    final s = build();
    await store.saveThemeId('amber');
    await store.saveSkinId('neon');

    await s.load();

    expect(s.savedThemeId, 'amber');
    expect(s.savedSkinId, 'neon');
  });

  test('a chosen name sticks', () async {
    final s = build();
    await s.setPlayerName('SNEK');

    expect(s.displayName, 'SNEK');
    expect(await store.loadPlayerName(), 'SNEK');
  });
}
