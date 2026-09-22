import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:hisscore/game/food_types.dart';
import 'package:hisscore/game/snake_engine.dart';

/// Pickups that ask something of the player: a star worth more the
/// longer it is left, an apple that runs, an apple that lies, and a
/// pair of holes in the floor.
void main() {
  SnakeEngine game({
    GameMode mode = GameMode.classic,
    int columns = 20,
    int rows = 20,
    int level = 1,
  }) {
    final engine = SnakeEngine(
      columns: columns,
      rows: rows,
      mode: mode,
      firstFoodDistance: 99,
      random: Random(5),
    );
    engine.level = level;
    return engine;
  }

  FoodItem star({int spawnMs = 0}) => FoodItem(
    position: const GridPoint(10, 10),
    type: FoodType.star,
    spawnMs: spawnMs,
    lifetimeMs: SnakeEngine.bonusFoodLifetimeMs,
  );

  // ═══════════════════════════════════════════════════
  // The ripening star
  // ═══════════════════════════════════════════════════

  group('a star ripens', () {
    test('it opens at the low price', () {
      expect(star().ripePoints(0), FoodItem.starPointsFresh);
    });

    test('and is worth the most in its last moment', () {
      expect(
        star().ripePoints(SnakeEngine.bonusFoodLifetimeMs),
        FoodItem.starPointsRipe,
      );
    });

    test('climbing the whole way, never falling back', () {
      var last = 0;
      for (var ms = 0; ms <= SnakeEngine.bonusFoodLifetimeMs; ms += 250) {
        final worth = star().ripePoints(ms);
        expect(worth, greaterThanOrEqualTo(last), reason: 'at ${ms}ms');
        last = worth;
      }
      expect(last, FoodItem.starPointsRipe);
    });

    test('halfway through it is worth about half the climb', () {
      final worth = star().ripePoints(SnakeEngine.bonusFoodLifetimeMs ~/ 2);
      final middle = (FoodItem.starPointsFresh + FoodItem.starPointsRipe) ~/ 2;
      expect((worth - middle).abs(), lessThanOrEqualTo(2));
    });

    test('nothing else ripens', () {
      for (final type in FoodType.values) {
        if (type == FoodType.star) continue;
        expect(type.ripens, isFalse, reason: type.name);
      }
    });

    test('a run scores the ripened price, not the opening one', () {
      final fresh = game()..start();
      fresh.foods = [star()];
      fresh.snake = [const GridPoint(9, 10), const GridPoint(8, 10)];
      fresh.tick();
      final earlyScore = fresh.score;

      final waited = game()..start();
      // Spawned long enough ago to be nearly ripe.
      waited.foods = [star(spawnMs: -SnakeEngine.bonusFoodLifetimeMs + 200)];
      waited.snake = [const GridPoint(9, 10), const GridPoint(8, 10)];
      waited.tick();

      expect(waited.score, greaterThan(earlyScore));
      expect(earlyScore, greaterThanOrEqualTo(FoodItem.starPointsFresh));
    });
  });

  // ═══════════════════════════════════════════════════
  // The golden apple that runs
  // ═══════════════════════════════════════════════════

  group('the golden apple', () {
    SnakeEngine withGolden({
      GameMode mode = GameMode.endless,
      GridPoint at = const GridPoint(10, 4),
    }) {
      final engine = game(mode: mode)..start();
      engine.foods = [
        // The engine puts a primary apple back the moment it notices
        // there is none, so the board keeps one, out of the way.
        const FoodItem(position: GridPoint(19, 19), type: FoodType.apple),
        FoodItem(
          position: at,
          type: FoodType.golden,
          spawnMs: engine.elapsedMs,
          lifetimeMs: SnakeEngine.goldenLifetimeMs,
        ),
      ];
      return engine;
    }

    GridPoint goldenIn(SnakeEngine engine) =>
        engine.foods.firstWhere((f) => f.type == FoodType.golden).position;

    test('turns up in Adventure and Endless, and nowhere else', () {
      expect(SnakeEngine.goldenModes, contains(GameMode.adventure));
      expect(SnakeEngine.goldenModes, contains(GameMode.endless));
      expect(SnakeEngine.goldenModes, isNot(contains(GameMode.classic)));
      expect(SnakeEngine.goldenModes, isNot(contains(GameMode.hardcore)));
    });

    test('it steps away from the head, not at random', () {
      final engine = withGolden(at: const GridPoint(10, 4));
      engine.snake = [const GridPoint(10, 10), const GridPoint(9, 10)];
      final before = goldenIn(engine);

      // Ticks until one lands on the flee beat.
      for (var i = 0; i < SnakeEngine.goldenFleeTicks; i++) {
        engine.tick();
      }
      final after = goldenIn(engine);

      expect(after, isNot(before));
      expect(
        (after.y - engine.head.y).abs(),
        greaterThan((before.y - engine.head.y).abs()),
        reason: 'it should have put distance between them',
      );
    });

    test('it only moves every few ticks, so it can be caught', () {
      final engine = withGolden();
      engine.snake = [const GridPoint(10, 10), const GridPoint(9, 10)];
      var moves = 0;
      var last = goldenIn(engine);
      for (var i = 0; i < SnakeEngine.goldenFleeTicks * 3; i++) {
        engine.tick();
        if (goldenIn(engine) != last) moves++;
        last = goldenIn(engine);
      }
      expect(moves, lessThanOrEqualTo(3));
      expect(moves, greaterThan(0));
    });

    test('a corner is where it gets caught', () {
      final engine = withGolden(at: const GridPoint(0, 0));
      engine.snake = [const GridPoint(5, 5), const GridPoint(4, 5)];
      for (var i = 0; i < SnakeEngine.goldenFleeTicks * 2; i++) {
        engine.tick();
      }
      expect(
        goldenIn(engine),
        const GridPoint(0, 0),
        reason: 'there is nowhere further from the head to go',
      );
    });

    test('it pays a great deal, and more on a combo', () {
      final plain = withGolden(at: const GridPoint(11, 10));
      plain.snake = [const GridPoint(10, 10), const GridPoint(9, 10)];
      plain.tick();
      expect(plain.score, SnakeEngine.goldenPoints);

      final hot = withGolden(at: const GridPoint(11, 10));
      hot.snake = [const GridPoint(10, 10), const GridPoint(9, 10)];
      hot.comboCount = 4;
      hot.lastEatMs = hot.elapsedMs;
      hot.tick();
      expect(hot.score, greaterThan(SnakeEngine.goldenPoints));
    });

    test('it does not make the snake longer', () {
      expect(FoodType.golden.growsSnake, isFalse);
      final engine = withGolden(at: const GridPoint(11, 10));
      engine.snake = [const GridPoint(10, 10), const GridPoint(9, 10)];
      final length = engine.snake.length;
      engine.tick();
      expect(engine.snake.length, length);
    });

    test('and it goes if it is left too long', () {
      final engine = withGolden();
      expect(
        engine.foods
            .firstWhere((f) => f.type == FoodType.golden)
            .isExpired(engine.elapsedMs + SnakeEngine.goldenLifetimeMs),
        isTrue,
      );
    });
  });

  // ═══════════════════════════════════════════════════
  // Poison
  // ═══════════════════════════════════════════════════

  group('poison', () {
    SnakeEngine poisoned() {
      final engine = game(mode: GameMode.hardcore)..start();
      engine.snake = [for (var i = 0; i < 8; i++) GridPoint(10 - i, 10)];
      engine.foods = [
        const FoodItem(position: GridPoint(11, 10), type: FoodType.poison),
      ];
      return engine;
    }

    test('it costs three segments', () {
      final engine = poisoned();
      final before = engine.snake.length;
      engine.tick();
      // One forward, three off the back, and no growth.
      expect(engine.snake.length, before - SnakeEngine.poisonSegments);
    });

    test('and the combo with them', () {
      final engine = poisoned();
      engine.comboCount = 5;
      engine.lastEatMs = engine.elapsedMs;
      engine.tick();
      expect(engine.comboCount, 0);
      expect(engine.comboAlive, isFalse);
    });

    test('it says so, so the screen can react', () {
      final engine = poisoned();
      expect(engine.atePoison, isFalse);
      engine.tick();
      expect(engine.atePoison, isTrue);
      engine.tick();
      expect(engine.atePoison, isFalse, reason: 'it is a moment, not a state');
    });

    test('it never eats the snake down to nothing', () {
      final engine = game(mode: GameMode.hardcore)..start();
      engine.snake = [const GridPoint(10, 10), const GridPoint(9, 10)];
      engine.foods = [
        const FoodItem(position: GridPoint(11, 10), type: FoodType.poison),
      ];
      engine.tick();
      expect(engine.snake.length, greaterThanOrEqualTo(2));
    });

    test('it is a Hardcore problem and nobody else s', () {
      for (final mode in GameMode.values) {
        final engine = game(mode: mode)..start();
        var sawPoison = false;
        for (var i = 0; i < 400 && engine.phase == GamePhase.running; i++) {
          engine.tick();
          if (engine.foods.any((f) => f.type == FoodType.poison)) {
            sawPoison = true;
          }
        }
        if (mode != GameMode.hardcore) {
          expect(
            sawPoison,
            isFalse,
            reason: 'poison turned up in ${mode.name}',
          );
        }
      }
    });
  });

  // ═══════════════════════════════════════════════════
  // Portals
  // ═══════════════════════════════════════════════════

  group('portals', () {
    test('the early levels have none', () {
      final engine = game(mode: GameMode.adventure);
      for (var level = 1; level < SnakeEngine.portalFromLevel; level++) {
        expect(engine.portalsForLevel(level), isEmpty, reason: 'level $level');
      }
      expect(engine.portals, isEmpty, reason: 'a fresh run starts at level 1');
    });

    test('and from level seven there are exactly two ends', () {
      final engine = game(mode: GameMode.adventure);
      for (
        var level = SnakeEngine.portalFromLevel;
        level < SnakeEngine.portalFromLevel + 6;
        level++
      ) {
        final pair = engine.portalsForLevel(level);
        expect(pair, hasLength(2), reason: 'level $level');
        expect(pair.first, isNot(pair.last));
      }
    });

    test('no other mode grows them', () {
      for (final mode in GameMode.values) {
        if (mode == GameMode.adventure) continue;
        expect(
          game(mode: mode).portalsForLevel(20),
          isEmpty,
          reason: mode.name,
        );
      }
    });

    test('neither end sits in the lane the snake starts in', () {
      final engine = game(mode: GameMode.adventure, rows: 20);
      for (final end in engine.portalsForLevel(SnakeEngine.portalFromLevel)) {
        expect(
          end.y,
          isNot(10),
          reason: 'a portal in the opening lane is a portal by accident',
        );
      }
    });

    test('the head comes out of the other end still going the same way', () {
      final engine = game(mode: GameMode.adventure)..start();
      engine.portals = [const GridPoint(11, 10), const GridPoint(3, 3)];
      engine.obstacles = {};
      engine.foods = [];
      engine.snake = [const GridPoint(10, 10), const GridPoint(9, 10)];
      engine.direction = Direction.right;

      engine.tick();

      expect(
        engine.head,
        const GridPoint(3, 3),
        reason: 'in one, out the other',
      );
      expect(engine.direction, Direction.right, reason: 'heading is kept');
    });

    test('it works in both directions', () {
      final engine = game(mode: GameMode.adventure)..start();
      engine.portals = [const GridPoint(3, 3), const GridPoint(11, 10)];
      engine.obstacles = {};
      engine.foods = [];
      engine.snake = [const GridPoint(2, 3), const GridPoint(1, 3)];
      engine.direction = Direction.right;

      engine.tick();

      expect(engine.head, const GridPoint(11, 10));
    });

    test('a board with no portals is untouched by any of it', () {
      final engine = game()..start();
      engine.portals = [];
      engine.obstacles = {};
      engine.foods = [];
      engine.snake = [const GridPoint(10, 10), const GridPoint(9, 10)];

      engine.tick();

      expect(engine.head, const GridPoint(11, 10));
    });
  });
}
