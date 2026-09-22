import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisscore/game/challenge_code.dart';
import 'package:hisscore/game/game_session.dart';
import 'package:hisscore/game/high_score_store.dart';
import 'package:hisscore/game/online_scores.dart';
import 'package:hisscore/game/snake_engine.dart';
import 'package:hisscore/main.dart';
import 'package:hisscore/ui/game_overlay.dart';
import 'package:hisscore/ui/run_effects.dart';
import 'package:hisscore/ui/second_chance.dart';

/// One second chance per run, in the two modes it belongs in, and
/// nothing written down until the offer is settled.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // `SoundManager` catches its own failures, but audioplayers kicks off
  // an unawaited init of its own inside `AudioPool.create`, and that
  // one throws into the zone and lands on whichever test happens to be
  // running. Answering the channel with nothing keeps the failure
  // reports about this file's subject.
  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('xyz.luan/audioplayers.global'),
          (call) async => null,
        );
  });

  /// A cramped board with the food out of reach, so a run is nothing
  /// but the snake and the wall it is heading for.
  SnakeEngine cramped({GameMode mode = GameMode.adventure}) => SnakeEngine(
    columns: 6,
    rows: 6,
    firstFoodDistance: 99,
    mode: mode,
    random: Random(7),
  );

  void runToDeath(SnakeEngine game, {int limit = 60}) {
    for (var i = 0; i < limit && game.phase != GamePhase.gameOver; i++) {
      game.tick();
    }
    expect(game.phase, GamePhase.gameOver, reason: 'the run should have ended');
  }

  /// Endless wraps, so a snake walking in a straight line never dies.
  /// This one is steered into its own body instead.
  SnakeEngine endlessDeath() {
    final game = SnakeEngine(
      columns: 8,
      rows: 8,
      initialLength: 6,
      firstFoodDistance: 99,
      mode: GameMode.endless,
      random: Random(3),
    )..start();
    for (final turn in [Direction.down, Direction.left, Direction.up]) {
      game.queueTurn(turn);
      game.tick();
    }
    runToDeath(game, limit: 10);
    return game;
  }

  // ═══════════════════════════════════════════════════
  // The engine
  // ═══════════════════════════════════════════════════

  group('who can be brought back', () {
    test('only after actually dying', () {
      final game = cramped()..start();
      expect(game.canRevive, isFalse, reason: 'still running');
    });

    test('adventure gets it', () {
      final game = cramped()..start();
      runToDeath(game);
      expect(game.canRevive, isTrue);
    });

    test('endless gets it', () {
      expect(endlessDeath().canRevive, isTrue);
    });

    test('classic and hardcore do not', () {
      for (final mode in [GameMode.classic, GameMode.hardcore]) {
        final game = cramped(mode: mode)..start();
        runToDeath(game, limit: 200);
        expect(game.canRevive, isFalse, reason: mode.name);
      }
    });

    test('zen never dies, so the question never comes up', () {
      final game = cramped(mode: GameMode.zen)..start();
      for (var i = 0; i < 60; i++) {
        game.tick();
      }
      expect(game.phase, GamePhase.running);
      expect(game.canRevive, isFalse);
    });

    test('a win is not a death', () {
      final game = cramped()..start();
      runToDeath(game);
      game.won = true;
      expect(game.canRevive, isFalse);
    });
  });

  group('what a revive costs and keeps', () {
    test('the score, apples and level survive; the snake is halved', () {
      final game = SnakeEngine(
        columns: 14,
        rows: 14,
        initialLength: 9,
        firstFoodDistance: 99,
        mode: GameMode.endless,
        random: Random(3),
      )..start();
      game.score = 420;
      game.totalApplesEaten = 12;
      game.level = 4;
      // Endless wraps, so it has to be walked into itself to die.
      game.snake = [
        for (var i = 0; i < 9; i++) GridPoint(5 + (i % 3), 5 + (i ~/ 3)),
      ];
      final lengthBefore = game.snake.length;
      game.phase = GamePhase.gameOver;

      game.revive();

      expect(game.revived, isTrue);
      expect(game.score, 420, reason: 'earned, so kept');
      expect(game.totalApplesEaten, 12);
      expect(game.level, 4);
      expect(game.snake.length, max(3, lengthBefore ~/ 2));
      expect(game.phase, GamePhase.paused, reason: 'counted back in, not run');
    });

    test('a short snake is never cut below three', () {
      final game = cramped()..start();
      runToDeath(game);

      game.revive();

      expect(game.snake.length, greaterThanOrEqualTo(3));
    });

    test('the combo is dropped', () {
      final game = cramped()..start();
      runToDeath(game);
      game.comboCount = 5;

      game.revive();

      expect(game.comboCount, 0);
      expect(game.comboAlive, isFalse);
    });

    test('the obstacles crowding the head are swept', () {
      final game = cramped()..start();
      runToDeath(game);
      final head = game.head;
      game.obstacles = {
        GridPoint(head.x, head.y - 1),
        GridPoint(head.x - 2, head.y),
        // Far enough away to be left alone.
        GridPoint(head.x - 5, head.y),
      };

      game.revive();

      for (final o in game.obstacles) {
        final dx = (o.x - head.x).abs();
        final dy = (o.y - head.y).abs();
        expect(
          dx > dy ? dx : dy,
          greaterThan(SnakeEngine.reviveClearRadius),
          reason: '$o was left next to the head',
        );
      }
    });

    test('it comes back facing somewhere it can actually go', () {
      final game = cramped()..start();
      runToDeath(game);

      game.revive();
      game.start();
      game.tick();

      expect(
        game.phase,
        GamePhase.running,
        reason: 'the first tick after a revive must not kill it again',
      );
    });

    test('only once', () {
      final game = cramped()..start();
      runToDeath(game);
      game.revive();
      expect(game.canRevive, isFalse);

      game.start();
      runToDeath(game);

      expect(game.revived, isTrue);
      expect(game.canRevive, isFalse, reason: 'one per run, for good');
    });

    test('a new run gets its chance back', () {
      final game = cramped()..start();
      runToDeath(game);
      game.revive();
      expect(game.revived, isTrue);

      game.reset();

      expect(game.revived, isFalse);
    });

    test('calling it when it is not on offer does nothing', () {
      final game = cramped(mode: GameMode.classic)..start();
      runToDeath(game);
      final snake = List.of(game.snake);

      game.revive();

      expect(game.revived, isFalse);
      expect(game.snake, snake);
      expect(game.phase, GamePhase.gameOver);
    });
  });

  // ═══════════════════════════════════════════════════
  // The session
  // ═══════════════════════════════════════════════════

  group('when it is offered', () {
    GameSession session({GameMode mode = GameMode.adventure}) => GameSession(
      store: InMemoryHighScoreStore(),
      onlineScores: const NoopOnlineScoreBoard(),
      engineFactory: () => cramped(mode: mode),
      now: () => DateTime(2026, 9, 21),
    )..selectedMode = mode;

    void play(GameSession s) {
      s.primaryAction();
      for (var i = 0; i < 60 && s.engine.phase == GamePhase.running; i++) {
        s.onTicker();
      }
    }

    test('an ordinary adventure run is offered one', () {
      final s = session();
      play(s);

      expect(s.offerSecondChance, isTrue);
      s.dispose();
    });

    test('the daily is not, however it ended', () {
      final s = session();
      s.startDaily();
      for (var i = 0; i < 400 && s.engine.phase == GamePhase.running; i++) {
        s.onTicker();
      }

      expect(s.offerSecondChance, isFalse);
      s.dispose();
    });

    test("a friend's code is not either", () {
      final s = session();
      s.startChallenge(ChallengeCode.random(GameMode.adventure));
      for (var i = 0; i < 400 && s.engine.phase == GamePhase.running; i++) {
        s.onTicker();
      }

      expect(s.offerSecondChance, isFalse);
      s.dispose();
    });

    test('refusing takes it off the table', () {
      final s = session();
      play(s);

      s.refuseSecondChance();

      expect(s.offerSecondChance, isFalse);
      s.dispose();
    });
  });

  group('what gets written down', () {
    late InMemoryHighScoreStore store;

    GameSession session({GameMode mode = GameMode.adventure}) {
      store = InMemoryHighScoreStore();
      return GameSession(
        store: store,
        onlineScores: const NoopOnlineScoreBoard(),
        engineFactory: () => cramped(mode: mode),
        now: () => DateTime(2026, 9, 21),
      )..selectedMode = mode;
    }

    void play(GameSession s) {
      s.primaryAction();
      for (var i = 0; i < 60 && s.engine.phase == GamePhase.running; i++) {
        s.onTicker();
      }
    }

    test('nothing, while the run could still come back', () async {
      final s = session();
      play(s);
      await s.saveInFlight;

      expect(
        (await store.loadStats()).gamesPlayed,
        0,
        reason: 'the run has not finished yet',
      );
      s.dispose();
    });

    test('once, when the offer lapses', () async {
      final s = session();
      play(s);
      s.refuseSecondChance();
      await s.saveInFlight;

      expect((await store.loadStats()).gamesPlayed, 1);
      s.dispose();
    });

    test('once, for a revived run that then really ends', () async {
      final s = session();
      play(s);
      s.acceptSecondChance();
      s.engine.start();
      for (var i = 0; i < 60 && s.engine.phase == GamePhase.running; i++) {
        s.onTicker();
      }
      await s.saveInFlight;

      expect(s.engine.phase, GamePhase.gameOver);
      expect(s.engine.revived, isTrue);
      expect(
        (await store.loadStats()).gamesPlayed,
        1,
        reason: 'one run, not two, however many lives it had',
      );
      s.dispose();
    });

    test('once, for a run walked away from without answering', () async {
      final s = session();
      play(s);

      s.returnToMenu();
      await s.saveInFlight;

      expect((await store.loadStats()).gamesPlayed, 1);
      s.dispose();
    });

    test('a mode that never offers saves on the death, as before', () async {
      final s = session(mode: GameMode.classic);
      play(s);
      await s.saveInFlight;

      expect((await store.loadStats()).gamesPlayed, 1);
      s.dispose();
    });
  });

  // ═══════════════════════════════════════════════════
  // The card
  // ═══════════════════════════════════════════════════

  group('the offer on screen', () {
    Future<void> playUntilDead(WidgetTester tester) async {
      await tester.pumpWidget(
        HisscoreApp(
          highScoreStore: InMemoryHighScoreStore(),
          engineFactory: () => cramped(),
        ),
      );
      await tester.pump();
      // The injected engine's mode is overwritten by whatever the menu
      // has selected, so the mode has to be chosen the way a player
      // would choose it.
      await tester.tap(find.text('ADVENTURE'));
      await tester.pump();
      await tester.tap(find.text('PLAY'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pump(RunEffects.deathPause);
      await tester.pump();
    }

    testWidgets('appears on the card, counting down', (tester) async {
      await playUntilDead(tester);

      expect(find.text('SECOND CHANCE'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 1100));

      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('lapses on its own and leaves the plain card', (tester) async {
      await playUntilDead(tester);
      expect(find.text('SECOND CHANCE'), findsOneWidget);

      await tester.pump(secondChanceWindow);
      await tester.pump();

      expect(find.text('SECOND CHANCE'), findsNothing);
      expect(find.text('GAME OVER'), findsOneWidget);
      expect(find.text('PLAY AGAIN'), findsOneWidget);
    });

    testWidgets('taking it counts the player back in', (tester) async {
      await playUntilDead(tester);

      await tester.tap(find.text('SECOND CHANCE'));
      await tester.pump();

      expect(find.text('GAME OVER'), findsNothing);
      expect(find.byType(ResumeCountdown), findsOneWidget);

      // A revive parks the engine in `paused`, but the player did not
      // ask for a pause: the card and its live buttons must not be
      // sitting under the see-through countdown, where a stray tap
      // would bank the run and skip the count.
      expect(find.byType(GameOverlay), findsNothing);
      expect(find.text('RESUME'), findsNothing);
      expect(find.text('MENU'), findsNothing);

      // 3, 2, 1, and away.
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();

      expect(find.byType(ResumeCountdown), findsNothing);
    });

    testWidgets('a revived run is marked as one', (tester) async {
      await playUntilDead(tester);
      await tester.tap(find.text('SECOND CHANCE'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));

      // Die again; there is no second second chance.
      await tester.pump(const Duration(milliseconds: 2000));
      await tester.pump(RunEffects.deathPause);
      await tester.pump();

      expect(find.text('GAME OVER'), findsOneWidget);
      expect(find.text('REVIVED'), findsOneWidget);
      expect(find.text('SECOND CHANCE'), findsNothing);
    });
  });
}
