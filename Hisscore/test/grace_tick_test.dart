import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:hisscore/game/daily_challenge.dart';
import 'package:hisscore/game/snake_engine.dart';

/// The grace tick: a snake one move from dying is held where it is for
/// one tick, so a turn that landed a frame late still saves it.
void main() {
  /// A board with the food pushed out of the way, so a run is nothing
  /// but the snake and the wall it is heading for.
  SnakeEngine engine({
    GameMode mode = GameMode.classic,
    int columns = 6,
    int rows = 6,
  }) => SnakeEngine(
    columns: columns,
    rows: rows,
    firstFoodDistance: 99,
    mode: mode,
    random: Random(7),
  );

  /// Ticks until the snake is held on the brink, and says where it is.
  int tickToTheBrink(SnakeEngine game, {int limit = 50}) {
    for (var i = 1; i <= limit; i++) {
      game.tick();
      if (game.graceHeld) return i;
    }
    fail('the snake never reached the brink in $limit ticks');
  }

  group('being held', () {
    test('a wall holds the snake for a tick instead of killing it', () {
      final game = engine()..start();

      // Head starts at (2,3) heading right on a 6-wide board: (3,3),
      // (4,3), (5,3), then the wall.
      game.tick();
      game.tick();
      game.tick();
      expect(game.head, const GridPoint(5, 3));
      expect(game.phase, GamePhase.running);

      game.tick();

      expect(game.phase, GamePhase.running, reason: 'the grace tick');
      expect(game.graceHeld, isTrue);
      expect(game.onTheBrink, isTrue);
      expect(game.head, const GridPoint(5, 3), reason: 'it did not move');
    });

    test('nothing on the board moves during the held tick', () {
      final game = engine()..start();
      tickToTheBrink(game);
      final snake = List.of(game.snake);
      final foods = [for (final f in game.foods) f.position];
      final score = game.score;

      expect(game.snake, snake);
      expect([for (final f in game.foods) f.position], foods);
      expect(game.score, score);
      expect(game.justAte, isFalse);
    });

    test('a held snake that is not steered dies on the next tick', () {
      final game = engine()..start();
      tickToTheBrink(game);

      game.tick();

      expect(game.phase, GamePhase.gameOver);
    });

    test('the flag only lives for the tick that held', () {
      final game = engine()..start();
      tickToTheBrink(game);
      expect(game.graceHeld, isTrue);

      game.queueTurn(Direction.up);
      game.tick();

      expect(game.graceHeld, isFalse);
      expect(game.phase, GamePhase.running);
    });
  });

  group('being saved', () {
    test('a turn during the held tick saves the snake', () {
      final game = engine()..start();
      tickToTheBrink(game);

      // The late turn the whole mechanic exists for.
      game.queueTurn(Direction.up);
      game.tick();

      expect(game.phase, GamePhase.running);
      expect(game.head, const GridPoint(5, 2));
    });

    test('a saved snake can be saved again at the next scrape', () {
      final game = engine()..start();
      tickToTheBrink(game);
      game.queueTurn(Direction.up);
      game.tick();
      expect(game.graceSpent, isFalse, reason: 'a safe move restores it');

      // Up the right-hand wall to the top, and into it.
      final second = tickToTheBrink(game);

      expect(second, greaterThan(0));
      expect(game.phase, GamePhase.running);
      expect(game.graceHeld, isTrue);
    });

    test('grace is not offered when a turn is already queued', () {
      final game = engine()..start();
      game.tick();
      game.tick();
      expect(game.head, const GridPoint(4, 3));

      // Two turns banked: the first is spent on this tick, the second
      // is still waiting, so the player is steering rather than
      // scraping and gets no hold.
      game.queueTurn(Direction.up);
      game.queueTurn(Direction.left);
      game.tick();

      expect(game.graceHeld, isFalse);
      expect(game.phase, GamePhase.running);
    });

    test('self-collision is forgiven once too', () {
      final game = SnakeEngine(
        columns: 8,
        rows: 8,
        initialLength: 5,
        firstFoodDistance: 99,
        random: Random(1),
      )..start();
      game.queueTurn(Direction.up);
      game.tick();
      game.queueTurn(Direction.left);
      game.tick();
      game.queueTurn(Direction.down);
      game.tick();

      expect(game.graceHeld, isTrue);
      expect(game.phase, GamePhase.running);
    });
  });

  group('who gets it', () {
    test('hardcore gets none', () {
      final game = engine(mode: GameMode.hardcore);
      expect(game.graceTicks, 0);
      game.start();

      for (var i = 0; i < 20 && game.phase == GamePhase.running; i++) {
        game.tick();
        expect(game.graceHeld, isFalse, reason: 'hardcore never holds');
      }

      expect(game.phase, GamePhase.gameOver);
    });

    test('every other mode gets exactly one tick', () {
      for (final mode in GameMode.values) {
        final expected = mode == GameMode.hardcore ? 0 : 1;
        expect(
          engine(mode: mode).graceTicks,
          expected,
          reason: '${mode.name} should get $expected grace ticks',
        );
      }
    });

    test('the mode is read live, so switching it switches the rule', () {
      final game = engine()..start();
      expect(game.graceTicks, 1);

      game.mode = GameMode.hardcore;

      expect(game.graceTicks, 0);
      for (var i = 0; i < 20 && game.phase == GamePhase.running; i++) {
        game.tick();
      }
      expect(game.phase, GamePhase.gameOver);
    });

    test('zen is untouched — it cannot die in the first place', () {
      final game = engine(mode: GameMode.zen)..start();

      for (var i = 0; i < 40; i++) {
        game.tick();
      }

      expect(game.phase, GamePhase.running);
      expect(game.graceHeld, isFalse);
    });
  });

  group('determinism', () {
    test('a reset run starts with its grace intact', () {
      final game = engine()..start();
      tickToTheBrink(game);
      expect(game.graceSpent, isTrue);

      game.reset();

      expect(game.graceSpent, isFalse);
      expect(game.graceHeld, isFalse);
    });

    test('the daily plays out identically on two engines', () {
      SnakeEngine daily() => SnakeEngine(
        columns: DailyChallenge.gridColumns,
        rows: DailyChallenge.gridRows,
        random: Random(DailyChallenge.seedForDay(262)),
      )..start();

      // The same inputs at the same ticks on both.
      const script = {3: Direction.down, 9: Direction.left, 14: Direction.up};
      final a = daily();
      final b = daily();
      for (var i = 0; i < 60; i++) {
        final turn = script[i];
        if (turn != null) {
          a.queueTurn(turn);
          b.queueTurn(turn);
        }
        a.tick();
        b.tick();
      }

      expect(a.snake, b.snake);
      expect(a.score, b.score);
      expect(a.phase, b.phase);
      expect(a.graceSpent, b.graceSpent);
      expect(
        [for (final f in a.foods) f.position],
        [for (final f in b.foods) f.position],
      );
    });
  });
}
