import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisscore/game/game_session.dart';
import 'package:hisscore/game/high_score_store.dart';
import 'package:hisscore/game/online_scores.dart';
import 'package:hisscore/game/snake_engine.dart';
import 'package:hisscore/ui/game_overlay.dart';
import 'package:hisscore/ui/theme.dart';

/// A scrape the grace tick saved is worth noticing: it pays a few
/// points, it is counted, and the player is told at the moment it
/// happens rather than at game over.
void main() {
  SnakeEngine engine({GameMode mode = GameMode.classic}) => SnakeEngine(
    columns: 6,
    rows: 6,
    firstFoodDistance: 99,
    mode: mode,
    random: Random(7),
  );

  void tickToTheBrink(SnakeEngine game, {int limit = 50}) {
    for (var i = 0; i < limit; i++) {
      game.tick();
      if (game.graceHeld) return;
    }
    fail('the snake never reached the brink');
  }

  group('counting', () {
    test('steering out of a scrape counts one and pays for it', () {
      final game = engine()..start();
      tickToTheBrink(game);
      final before = game.score;
      expect(game.closeCalls, 0);

      game.queueTurn(Direction.up);
      game.tick();

      expect(game.closeCalls, 1);
      expect(game.justSurvivedCloseCall, isTrue);
      expect(game.score, before + SnakeEngine.closeCallPoints);
    });

    test('dying on the brink is not a close call', () {
      final game = engine()..start();
      tickToTheBrink(game);
      final before = game.score;

      game.tick();

      expect(game.phase, GamePhase.gameOver);
      expect(game.closeCalls, 0);
      expect(game.score, before, reason: 'no points for dying');
    });

    test('the flag lives for exactly one tick', () {
      final game = engine()..start();
      tickToTheBrink(game);
      game.queueTurn(Direction.up);
      game.tick();
      expect(game.justSurvivedCloseCall, isTrue);

      game.tick();

      expect(game.justSurvivedCloseCall, isFalse);
      expect(game.closeCalls, 1, reason: 'the count is not reset by a tick');
    });

    test('two scrapes count twice', () {
      final game = engine()..start();
      tickToTheBrink(game);
      game.queueTurn(Direction.up);
      game.tick();
      tickToTheBrink(game);
      game.queueTurn(Direction.left);
      game.tick();

      expect(game.closeCalls, 2);
    });

    test('hardcore can never have one', () {
      final game = engine(mode: GameMode.hardcore)..start();

      for (var i = 0; i < 30 && game.phase == GamePhase.running; i++) {
        game.tick();
      }

      expect(game.phase, GamePhase.gameOver);
      expect(game.closeCalls, 0);
    });

    test('a reset run starts at none', () {
      final game = engine()..start();
      tickToTheBrink(game);
      game.queueTurn(Direction.up);
      game.tick();
      expect(game.closeCalls, 1);

      game.reset();

      expect(game.closeCalls, 0);
      expect(game.justSurvivedCloseCall, isFalse);
    });
  });

  group('telling the player', () {
    late InMemoryHighScoreStore store;

    /// [scoring] swaps the cramped, food-free board for a normal one
    /// where the snake actually reaches an apple.
    GameSession session({
      GameMode mode = GameMode.classic,
      bool scoring = false,
    }) {
      store = InMemoryHighScoreStore();
      return GameSession(
        store: store,
        onlineScores: const NoopOnlineScoreBoard(),
        engineFactory: () => scoring
            ? SnakeEngine(mode: mode, random: Random(1))
            : engine(mode: mode),
        now: () => DateTime(2026, 9, 21),
      )..selectedMode = mode;
    }

    test('a close call reaches the page', () {
      var calls = 0;
      final s = session()..onCloseCall = (() => calls++);
      s.primaryAction();

      while (s.engine.phase == GamePhase.running && !s.engine.graceHeld) {
        s.onTicker();
      }
      s.turn(Direction.up);
      s.onTicker();

      expect(calls, 1);
      expect(s.engine.closeCalls, 1);
      s.dispose();
    });

    test('beating a saved best is announced mid-run, once', () async {
      var bests = 0;
      final s = session(scoring: true)..onNewBest = (() => bests++);
      await store.save(5);
      await s.load();
      s.primaryAction();

      // The first apple alone clears a best of 5.
      for (var i = 0; i < 30 && s.engine.phase == GamePhase.running; i++) {
        s.onTicker();
      }

      expect(s.engine.score, greaterThan(5));
      expect(bests, 1, reason: 'announced once, not on every tick after');
      s.dispose();
    });

    test('a first-ever run is not announced as beating anything', () async {
      var bests = 0;
      final s = session(scoring: true)..onNewBest = (() => bests++);
      await s.load();
      expect(s.highScore, 0);
      s.primaryAction();

      for (var i = 0; i < 30 && s.engine.phase == GamePhase.running; i++) {
        s.onTicker();
      }

      expect(s.engine.score, greaterThan(0));
      expect(bests, 0);
      expect(s.newHighScore, isTrue, reason: 'still a new best to save');
      s.dispose();
    });

    test('zen never announces a best', () async {
      var bests = 0;
      final s = session(mode: GameMode.zen, scoring: true)
        ..onNewBest = (() => bests++);
      await store.save(5);
      await s.load();
      s.primaryAction();

      for (var i = 0; i < 40; i++) {
        s.onTicker();
      }

      expect(bests, 0);
      s.dispose();
    });

    test('the close calls reach the quest summary', () async {
      final s = session();
      s.primaryAction();
      while (s.engine.phase == GamePhase.running && !s.engine.graceHeld) {
        s.onTicker();
      }
      s.turn(Direction.up);
      s.onTicker();
      final saved = s.engine.closeCalls;
      while (s.engine.phase == GamePhase.running) {
        s.onTicker();
      }
      await s.saveInFlight;

      expect(saved, 1);
      expect(s.outcome, isNotNull);
      s.dispose();
    });
  });

  group('the end screen', () {
    Future<void> pumpBreakdown(WidgetTester tester, SnakeEngine game) {
      return tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: RetroColors.voidBg,
            body: ScoreBreakdown(engine: game),
          ),
        ),
      );
    }

    testWidgets('shows the count when there were any', (tester) async {
      final game = engine()
        ..start()
        ..closeCalls = 3;

      await pumpBreakdown(tester, game);

      expect(find.text('CLOSE CALLS'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('stays out of the way when there were none', (tester) async {
      await pumpBreakdown(tester, engine()..start());

      expect(find.text('CLOSE CALLS'), findsNothing);
    });
  });
}
