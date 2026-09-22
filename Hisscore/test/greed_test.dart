import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:hisscore/game/food_types.dart';
import 'package:hisscore/game/snake_engine.dart';

/// The greed pot: apples pay twice, once into the score and once into a
/// pot that is only ever kept by reaching a bank.
///
/// The invariant every test here is really guarding is the one in
/// `SnakeEngine.pot`'s doc: greed is winnings *on top*. A run that never
/// sees a bank must still score exactly what the same run would have
/// scored with greed switched off, or the mode is a trap rather than a
/// bet.
void main() {
  SnakeEngine game({
    GameMode mode = GameMode.endless,
    int columns = 20,
    int rows = 20,
  }) {
    return SnakeEngine(
      columns: columns,
      rows: rows,
      mode: mode,
      // Far enough that nothing is eaten by accident: every test here
      // puts the food where it wants it.
      firstFoodDistance: 99,
      random: Random(5),
    );
  }

  /// Puts [type] directly in front of the head and ticks onto it.
  void eat(SnakeEngine engine, FoodType type) {
    final ahead = engine.head + engine.direction.delta;
    engine.foods = [FoodItem(position: ahead, type: type)];
    engine.tick();
  }

  group('which modes play it', () {
    test('Endless does', () {
      expect(game().greedEnabled, isTrue);
    });

    test('and nothing else does', () {
      for (final mode in GameMode.values) {
        if (mode == GameMode.endless) continue;
        expect(
          game(mode: mode).greedEnabled,
          isFalse,
          reason: '${mode.name} should not have a pot',
        );
      }
    });

    test('a mode without it never accrues one', () {
      final engine = game(mode: GameMode.classic)..start();
      for (var i = 0; i < 5; i++) {
        eat(engine, FoodType.apple);
      }
      expect(engine.pot, 0);
      expect(engine.greed, 1.0);
    });
  });

  group('the pot', () {
    test('starts empty at ×1', () {
      final engine = game()..start();
      expect(engine.pot, 0);
      expect(engine.greed, 1.0);
    });

    test('an apple pays the score exactly what it always did', () {
      final greedy = game()..start();
      final plain = game(mode: GameMode.classic)..start();
      eat(greedy, FoodType.apple);
      eat(plain, FoodType.apple);
      expect(greedy.score, plain.score);
    });

    test('and drops a copy of those points in the pot', () {
      final engine = game()..start();
      eat(engine, FoodType.apple);
      expect(engine.pot, engine.score);
    });

    test('each apple raises greed by a step', () {
      final engine = game()..start();
      eat(engine, FoodType.apple);
      expect(engine.greed, 1.0 + SnakeEngine.greedStep);
      eat(engine, FoodType.apple);
      expect(engine.greed, 1.0 + SnakeEngine.greedStep * 2);
    });

    test('greed stops climbing at the cap', () {
      final engine = game()..start();
      for (var i = 0; i < 40; i++) {
        eat(engine, FoodType.apple);
      }
      expect(engine.greed, SnakeEngine.greedMax);
    });

    test('the pot inherits the combo the apple was scored with', () {
      // The combo only starts paying on the third apple, because the
      // multiplier is read before the count goes up. That is where the
      // pot has to show it agrees — and since every point in this run
      // came from an apple, the pot should equal the score outright.
      final engine = game()..start();
      eat(engine, FoodType.apple);
      eat(engine, FoodType.apple);
      final beforeThird = engine.score;
      eat(engine, FoodType.apple);
      expect(engine.score - beforeThird, greaterThan(engine.pointsPerFood));
      expect(engine.pot, engine.score);
    });

    test('only apples feed it', () {
      final engine = game()..start();
      eat(engine, FoodType.star);
      expect(engine.score, greaterThan(0));
      expect(engine.pot, 0);
    });
  });

  group('banking', () {
    test('pays the pot times greed and empties it', () {
      final engine = game()..start();
      for (var i = 0; i < 4; i++) {
        eat(engine, FoodType.apple);
      }
      final pot = engine.pot;
      final greed = engine.greed;
      final before = engine.score;

      eat(engine, FoodType.bank);

      expect(engine.score - before, (pot * greed).round());
      expect(engine.pot, 0);
      expect(engine.greed, 1.0);
    });

    test('counts towards the run total and this tick only', () {
      final engine = game()..start();
      eat(engine, FoodType.apple);
      eat(engine, FoodType.bank);
      final paid = engine.justBanked;
      expect(paid, greaterThan(0));
      expect(engine.greedBanked, paid);

      // justBanked is a one-tick flag like justAte.
      engine.tick();
      expect(engine.justBanked, 0);
      expect(engine.greedBanked, paid);
    });

    test('an empty pot banks nothing rather than something', () {
      final engine = game()..start();
      final before = engine.score;
      eat(engine, FoodType.bank);
      expect(engine.score, before);
      expect(engine.justBanked, 0);
    });

    test('waiting a turn longer is worth more than banking now', () {
      // The whole bet, in one assertion: the same apples banked one
      // apple later pay more.
      var sooner = 0;
      var later = 0;
      {
        final engine = game()..start();
        for (var i = 0; i < 3; i++) {
          eat(engine, FoodType.apple);
        }
        final before = engine.score;
        eat(engine, FoodType.bank);
        sooner = engine.score - before;
      }
      {
        final engine = game()..start();
        for (var i = 0; i < 4; i++) {
          eat(engine, FoodType.apple);
        }
        final before = engine.score;
        eat(engine, FoodType.bank);
        later = engine.score - before;
      }
      expect(later, greaterThan(sooner));
    });
  });

  group('what greed costs', () {
    test('dying keeps the score and loses the pot', () {
      final engine = game()..start();
      for (var i = 0; i < 3; i++) {
        eat(engine, FoodType.apple);
      }
      final scored = engine.score;
      expect(engine.pot, greaterThan(0));

      // Straight into its own middle. Endless wraps, so a wall is not
      // available; and grace holds a doomed snake for a tick, so this
      // takes more than one.
      engine.snake = [
        const GridPoint(5, 5),
        const GridPoint(5, 6),
        const GridPoint(6, 6),
        const GridPoint(6, 5),
        const GridPoint(7, 5),
      ];
      engine.previousSnake = List.of(engine.snake);
      engine.foods = [];
      engine.direction = Direction.up;
      engine.queueTurn(Direction.right);
      for (var i = 0; i < 6 && engine.phase == GamePhase.running; i++) {
        engine.tick();
      }

      expect(engine.phase, GamePhase.gameOver);
      // The score is untouched by the loss: the pot was never in it.
      expect(engine.score, scored);
    });

    test('a second chance takes the pot with the segments', () {
      final engine = game()..start();
      for (var i = 0; i < 3; i++) {
        eat(engine, FoodType.apple);
      }
      final scored = engine.score;
      expect(engine.pot, greaterThan(0));

      engine.phase = GamePhase.gameOver;
      engine.revive();

      expect(engine.revived, isTrue);
      expect(engine.score, scored);
      expect(engine.pot, 0);
      expect(engine.greed, 1.0);
    });

    test('a new run starts with nothing in hand', () {
      final engine = game()..start();
      for (var i = 0; i < 3; i++) {
        eat(engine, FoodType.apple);
      }
      eat(engine, FoodType.bank);
      engine.reset();
      expect(engine.pot, 0);
      expect(engine.greed, 1.0);
      expect(engine.greedBanked, 0);
      expect(engine.justBanked, 0);
    });
  });

  group('where banks come from', () {
    /// Eats [count] apples the ordinary way, letting the engine spawn
    /// whatever it wants around them.
    SnakeEngine runApples(int count, {GameMode mode = GameMode.endless}) {
      final engine = SnakeEngine(
        columns: 30,
        rows: 20,
        mode: mode,
        firstFoodDistance: 3,
        random: Random(7),
      )..start();
      while (engine.totalApplesEaten < count &&
          engine.phase == GamePhase.running) {
        final apple = engine.foods.firstWhere((f) => f.type == FoodType.apple);
        // Walk the head onto the apple rather than teleporting it, so
        // the spawn logic sees a real run.
        final target = apple.position;
        if (engine.head.x != target.x) {
          engine.queueTurn(
            engine.head.x < target.x ? Direction.right : Direction.left,
          );
        } else if (engine.head.y != target.y) {
          engine.queueTurn(
            engine.head.y < target.y ? Direction.down : Direction.up,
          );
        }
        engine.tick();
      }
      return engine;
    }

    test('one turns up once there is a pot to bank', () {
      final engine = runApples(SnakeEngine.bankEveryApples);
      expect(engine.foods.any((f) => f.type == FoodType.bank), isTrue);
    });

    test('never in a mode without greed', () {
      final engine = runApples(
        SnakeEngine.bankEveryApples * 2,
        mode: GameMode.classic,
      );
      expect(engine.foods.any((f) => f.type == FoodType.bank), isFalse);
    });

    test('and never over an empty pot', () {
      // Nothing has been eaten, so there is nothing to put in a bank —
      // spawning one here would teach the player it is worth nothing.
      final engine = game()..start();
      expect(engine.pot, 0);
      for (var i = 0; i < 20; i++) {
        engine.tick();
      }
      expect(engine.foods.any((f) => f.type == FoodType.bank), isFalse);
    });

    test('a bank expires like any other timed pickup', () {
      final engine = runApples(SnakeEngine.bankEveryApples);
      final bank = engine.foods.firstWhere((f) => f.type == FoodType.bank);
      expect(bank.lifetimeMs, SnakeEngine.bankLifetimeMs);
      expect(bank.isExpired(bank.spawnMs + SnakeEngine.bankLifetimeMs), isTrue);
    });
  });
}
