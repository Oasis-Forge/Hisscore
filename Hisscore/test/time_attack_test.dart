import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:hisscore/game/challenge_code.dart';
import 'package:hisscore/game/daily_challenge.dart';
import 'package:hisscore/game/food_types.dart';
import 'package:hisscore/game/game_session.dart';
import 'package:hisscore/game/high_score_store.dart';
import 'package:hisscore/game/online_scores.dart';
import 'package:hisscore/game/snake_engine.dart';

/// Sixty seconds on one board: the clock, the hurry bonus, and the fact
/// that every phone plays the same shape of game.
void main() {
  SnakeEngine timed({int columns = 20, int rows = 20}) => SnakeEngine(
    columns: columns,
    rows: rows,
    mode: GameMode.timeAttack,
    firstFoodDistance: 99,
    random: Random(4),
  );

  group('the clock', () {
    test('a timed mode says so, and the others do not', () {
      expect(GameMode.timeAttack.isTimed, isTrue);
      for (final mode in GameMode.values) {
        if (mode == GameMode.timeAttack) continue;
        expect(mode.isTimed, isFalse, reason: mode.name);
      }
    });

    test('it starts full', () {
      final game = timed();
      expect(game.timeLeftMs, SnakeEngine.timeAttackMs);
      expect(game.timeFraction, 1.0);
    });

    test('and drains as the run goes', () {
      final game = timed()..start();
      for (var i = 0; i < 20; i++) {
        game.tick();
      }
      expect(game.timeLeftMs, lessThan(SnakeEngine.timeAttackMs));
      expect(game.timeFraction, lessThan(1.0));
      expect(game.timeFraction, greaterThan(0.0));
    });

    test('the run ends when the clock does, wherever the snake is', () {
      final game = timed(columns: 60, rows: 60)..start();
      game.tick();
      expect(game.phase, GamePhase.running, reason: 'plenty of time left');

      game.elapsedMs = SnakeEngine.timeAttackMs;
      game.tick();

      expect(game.phase, GamePhase.gameOver);
      expect(game.timeLeftMs, 0);
    });

    test('and not a tick before it', () {
      final game = timed(columns: 60, rows: 60)..start();
      game.elapsedMs = SnakeEngine.timeAttackMs - 1;
      game.tick();
      expect(game.phase, GamePhase.running);
    });

    test('it never reads below zero', () {
      final game = timed()..start();
      game.elapsedMs = SnakeEngine.timeAttackMs + 5000;
      expect(game.timeLeftMs, 0);
      expect(game.timeFraction, 0.0);
    });

    test('an untimed run has no clock at all', () {
      final classic = SnakeEngine(random: Random(4));
      expect(classic.timeLeftMs, isNull);
      expect(classic.timeFraction, 1.0);
    });
  });

  group('eating in a hurry', () {
    /// A timed run with an apple one step to the right of the head.
    SnakeEngine about({required int sinceLastEat}) {
      final game = timed()..start();
      game.snake = [const GridPoint(10, 10), const GridPoint(9, 10)];
      game.elapsedMs = 20000;
      game.lastEatMs = 20000 - sinceLastEat;
      game.foods = [
        const FoodItem(position: GridPoint(11, 10), type: FoodType.apple),
      ];
      return game;
    }

    test('an apple taken quickly is worth double', () {
      final quick = about(sinceLastEat: SnakeEngine.quickEatMs - 500)..tick();
      expect(quick.ateQuickly, isTrue);
      expect(quick.score, greaterThanOrEqualTo(quick.pointsPerFood * 2));
    });

    test('and one taken slowly is worth what it always was', () {
      final slow = about(sinceLastEat: SnakeEngine.quickEatMs + 1000)..tick();
      expect(slow.ateQuickly, isFalse);
      expect(slow.score, slow.pointsPerFood);
    });

    test('the first apple of a run is never a hurry', () {
      final game = timed()..start();
      game.snake = [const GridPoint(10, 10), const GridPoint(9, 10)];
      game.foods = [
        const FoodItem(position: GridPoint(11, 10), type: FoodType.apple),
      ];
      game.tick();
      expect(
        game.ateQuickly,
        isFalse,
        reason: 'there was no last apple to be quick after',
      );
    });

    test('no other mode pays it', () {
      final classic = SnakeEngine(firstFoodDistance: 99, random: Random(4))
        ..start();
      classic.snake = [const GridPoint(10, 10), const GridPoint(9, 10)];
      classic.elapsedMs = 20000;
      classic.lastEatMs = 19500;
      classic.foods = [
        const FoodItem(position: GridPoint(11, 10), type: FoodType.apple),
      ];
      classic.tick();
      expect(classic.ateQuickly, isFalse);
      expect(classic.score, classic.pointsPerFood);
    });

    test('it is a moment, not a state', () {
      final game = about(sinceLastEat: 500)..tick();
      expect(game.ateQuickly, isTrue);
      game.tick();
      expect(game.ateQuickly, isFalse);
    });
  });

  group('the same board everywhere', () {
    test('a Time Attack run is played on the fixed grid', () async {
      final session = GameSession(
        store: InMemoryHighScoreStore(),
        onlineScores: const NoopOnlineScoreBoard(),
      )..gridProvider = (() => (columns: 11, rows: 13));
      await session.load();
      session.selectedMode = GameMode.timeAttack;

      session.primaryAction();

      expect(session.engine.mode, GameMode.timeAttack);
      expect(session.engine.fixedGrid, isTrue);
      expect(session.engine.columns, DailyChallenge.gridColumns);
      expect(session.engine.rows, DailyChallenge.gridRows);
      session.dispose();
    });

    test('an ordinary run is still shaped to the screen', () async {
      final session = GameSession(
        store: InMemoryHighScoreStore(),
        onlineScores: const NoopOnlineScoreBoard(),
      )..gridProvider = (() => (columns: 11, rows: 13));
      await session.load();
      session.selectedMode = GameMode.classic;

      session.primaryAction();

      expect(session.engine.fixedGrid, isFalse);
      expect(session.engine.columns, 11);
      session.dispose();
    });

    test('it gets a board of its own', () {
      final board = BoardId.allTime(GameMode.timeAttack);
      expect(board.value, 'alltime-timeattack');
      expect(board, isNot(BoardId.allTime(GameMode.classic)));
    });

    test('a finished run reaches that board and no other', () async {
      final online = InMemoryOnlineScoreBoard();
      final session = GameSession(
        store: InMemoryHighScoreStore(),
        onlineScores: online,
      );
      await session.load();
      session.selectedMode = GameMode.timeAttack;
      session.primaryAction();
      session.engine.score = 640;
      session.engine.phase = GamePhase.gameOver;
      await session.persistGameEnd();

      expect(
        await online.top(BoardId.allTime(GameMode.timeAttack)),
        isNotEmpty,
      );
      expect(await online.top(BoardId.allTime(GameMode.classic)), isEmpty);
      session.dispose();
    });
  });

  group('fitting in with the rest', () {
    test('a challenge code can carry it', () {
      final code = ChallengeCode.random(GameMode.timeAttack, Random(2));
      expect(ChallengeCode.parse(code.text)?.mode, GameMode.timeAttack);
    });

    test('the mode chips still split into two full rows', () {
      expect(
        GameMode.values.length,
        6,
        reason: 'the selector lays out three and the rest',
      );
    });

    test('it has a look of its own', () {
      final labels = {for (final m in GameMode.values) m.label};
      expect(labels.length, GameMode.values.length);
      expect(GameMode.timeAttack.label, 'TIME ATTACK');
      expect(GameMode.timeAttack.description, isNotEmpty);
    });
  });
}
