import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisscore/game/food_types.dart';
import 'package:hisscore/game/snake_engine.dart';
import 'package:hisscore/game/weekly_modifier.dart';
import 'package:hisscore/ui/board.dart';
import 'package:hisscore/ui/backdrops.dart';
import 'package:hisscore/ui/snake_skin.dart';

import 'support/pixel_font.dart';
import 'support/tolerant_goldens.dart';

Widget _board(
  SnakeEngine engine, {
  double tickProgress = 1.0,
  List<GridPoint> ghost = const [],
  List<GridPoint> ghostPrevious = const [],
  // The size the goldens in this file have always come out at, now
  // asked for rather than inherited from the test view.
  Size size = const Size(800, 600),
}) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Center(
      child: RepaintBoundary(
        key: goldenBoundary,
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: CustomPaint(
            painter: SnakeBoardPainter(
              engine: engine,
              pulse: 0.5,
              tickProgress: tickProgress,
              ghost: ghost,
              ghostPrevious: ghostPrevious,
            ),
          ),
        ),
      ),
    ),
  );
}

SnakeEngine _engine(
  List<GridPoint> snake,
  Direction direction, {
  int columns = 14,
  int rows = 10,
  GameMode mode = GameMode.classic,
  WeeklyModifier? modifier,
  List<GridPoint>? previous,
}) {
  final engine =
      SnakeEngine(columns: columns, rows: rows, mode: mode, modifier: modifier)
        ..snake = snake
        ..direction = direction
        ..foods = [];
  engine.previousSnake = List.of(previous ?? snake);
  return engine;
}

void main() {
  // The board writes a number on a ripening pickup. Without the real
  // face that is a row of the test font's boxes, which says nothing
  // about what a player would read.
  setUpAll(loadPixelFont);

  setUp(() => useTolerantGoldens('board_golden_test.dart'));

  testWidgets('snake with an apple', (tester) async {
    final engine = _engine([
      const GridPoint(6, 5),
      const GridPoint(5, 5),
      const GridPoint(4, 5),
      const GridPoint(4, 4),
      const GridPoint(3, 4),
    ], Direction.right);
    engine.foods = [
      const FoodItem(position: GridPoint(10, 5), type: FoodType.apple),
    ];
    await tester.pumpWidget(_board(engine));
    await expectLater(
      find.byKey(goldenBoundary),
      matchesGoldenFile('goldens/board_snake_apple.png'),
    );
  });

  for (final skin in [SnakeSkin.pixel, SnakeSkin.neon, SnakeSkin.rainbow]) {
    testWidgets('${skin.id} skin', (tester) async {
      SnakeSkin.current = skin;
      addTearDown(() => SnakeSkin.current = SnakeSkin.classic);
      final engine = _engine([
        const GridPoint(7, 5),
        const GridPoint(6, 5),
        const GridPoint(5, 5),
        const GridPoint(5, 4),
        const GridPoint(4, 4),
        const GridPoint(3, 4),
      ], Direction.right);
      await tester.pumpWidget(_board(engine));
      await expectLater(
        find.byKey(goldenBoundary),
        matchesGoldenFile('goldens/board_skin_${skin.id}.png'),
      );
    });
  }

  testWidgets('head bulges right after eating', (tester) async {
    final engine = _engine([
      const GridPoint(6, 5),
      const GridPoint(5, 5),
      const GridPoint(4, 5),
    ], Direction.right)..justAte = true;
    // tickProgress 0 is the moment of eating, when the bulge is biggest.
    await tester.pumpWidget(_board(engine, tickProgress: 0));
    await expectLater(
      find.byKey(goldenBoundary),
      matchesGoldenFile('goldens/board_head_bulge.png'),
    );
  });

  testWidgets('a hot combo swells the glow', (tester) async {
    final engine = _engine([
      const GridPoint(6, 5),
      const GridPoint(5, 5),
      const GridPoint(4, 5),
      const GridPoint(3, 5),
    ], Direction.right)..comboCount = 6;
    await tester.pumpWidget(_board(engine));
    await expectLater(
      find.byKey(goldenBoundary),
      matchesGoldenFile('goldens/board_combo_glow.png'),
    );
  });

  testWidgets('speed burst trails streaks', (tester) async {
    final engine = _engine([
      const GridPoint(8, 5),
      const GridPoint(7, 5),
      const GridPoint(6, 5),
    ], Direction.right)..speedBurstUntilMs = 5000;
    await tester.pumpWidget(_board(engine));
    await expectLater(
      find.byKey(goldenBoundary),
      matchesGoldenFile('goldens/board_speed_streaks.png'),
    );
  });

  for (final level in [4, 7, 10]) {
    final zone = BoardBackdrop.forLevel(level);
    testWidgets('${zone.name} backdrop', (tester) async {
      final engine = _engine([
        const GridPoint(6, 5),
        const GridPoint(5, 5),
        const GridPoint(4, 5),
      ], Direction.right)..mode = GameMode.adventure;
      engine.level = level;
      await tester.pumpWidget(_board(engine));
      await expectLater(
        find.byKey(goldenBoundary),
        matchesGoldenFile('goldens/board_backdrop_${zone.name}.png'),
      );
    });
  }

  testWidgets('every pickup type', (tester) async {
    final engine = _engine([
      const GridPoint(3, 8),
      const GridPoint(2, 8),
      const GridPoint(1, 8),
    ], Direction.right);
    engine.foods = [
      const FoodItem(position: GridPoint(1, 2), type: FoodType.apple),
      const FoodItem(position: GridPoint(3, 2), type: FoodType.star),
      const FoodItem(position: GridPoint(5, 2), type: FoodType.shield),
      const FoodItem(position: GridPoint(7, 2), type: FoodType.speedBurst),
      const FoodItem(position: GridPoint(9, 2), type: FoodType.shrink),
      const FoodItem(position: GridPoint(11, 2), type: FoodType.magnet),
    ];
    await tester.pumpWidget(_board(engine));
    await expectLater(
      find.byKey(goldenBoundary),
      matchesGoldenFile('goldens/board_all_pickups.png'),
    );
  });

  testWidgets('obstacles', (tester) async {
    final engine = _engine([
      const GridPoint(3, 5),
      const GridPoint(2, 5),
    ], Direction.right);
    engine.obstacles = {
      for (var x = 6; x < 9; x++) GridPoint(x, 3),
      for (var y = 5; y < 8; y++) GridPoint(10, y),
    };
    await tester.pumpWidget(_board(engine));
    await expectLater(
      find.byKey(goldenBoundary),
      matchesGoldenFile('goldens/board_obstacles.png'),
    );
  });

  // ─── Everything the fun track put on the board ──────────────────
  //
  // None of it had a golden, and six of the seven visual bugs this
  // project has shipped were found by looking at a phone rather than by
  // a test failing.

  testWidgets('fog lights only the ground near the head', (tester) async {
    // A bigger grid than the rest of this file: the lit disc is five
    // cells across whatever the board is, so on 14x10 it would light
    // nearly all of it and the golden would show no fog at all.
    final engine = _engine(
      const [
        GridPoint(10, 9),
        GridPoint(9, 9),
        GridPoint(8, 9),
        GridPoint(7, 9),
      ],
      Direction.right,
      columns: 28,
      rows: 20,
      modifier: WeeklyModifier.fog,
    );
    engine.foods = [
      // One inside the light, one the fog is there to hide.
      const FoodItem(position: GridPoint(13, 7), type: FoodType.apple),
      const FoodItem(position: GridPoint(24, 3), type: FoodType.apple),
    ];
    engine.obstacles = {for (var y = 2; y < 18; y++) GridPoint(20, y)};
    await tester.pumpWidget(_board(engine));
    await expectLater(
      find.byKey(goldenBoundary),
      // The rim around the edge is the point of half this golden: the
      // walls stay drawn through the dark, because dying into an edge
      // that was never painted is a missing picture, not a difficulty.
      matchesGoldenFile('goldens/board_fog.png'),
    );
  });

  testWidgets('portals read as a way through', (tester) async {
    final engine = _engine(
      const [GridPoint(5, 5), GridPoint(4, 5), GridPoint(3, 5)],
      Direction.right,
      mode: GameMode.adventure,
    );
    engine.level = 7;
    engine.portals = [const GridPoint(10, 3), const GridPoint(2, 8)];
    await tester.pumpWidget(_board(engine));
    await expectLater(
      find.byKey(goldenBoundary),
      matchesGoldenFile('goldens/board_portals.png'),
    );
  });

  testWidgets('the ghost runs the board alongside', (tester) async {
    final engine = _engine(
      const [
        GridPoint(8, 4),
        GridPoint(7, 4),
        GridPoint(6, 4),
        GridPoint(5, 4),
      ],
      Direction.right,
      previous: const [
        GridPoint(7, 4),
        GridPoint(6, 4),
        GridPoint(5, 4),
        GridPoint(4, 4),
      ],
    );
    await tester.pumpWidget(
      _board(
        engine,
        tickProgress: 0.25,
        ghost: const [
          GridPoint(9, 7),
          GridPoint(8, 7),
          GridPoint(7, 7),
          GridPoint(6, 7),
          GridPoint(5, 7),
        ],
        ghostPrevious: const [
          GridPoint(8, 7),
          GridPoint(7, 7),
          GridPoint(6, 7),
          GridPoint(5, 7),
          GridPoint(4, 7),
        ],
      ),
    );
    await expectLater(
      find.byKey(goldenBoundary),
      matchesGoldenFile('goldens/board_ghost.png'),
    );
  });

  testWidgets('a ghost level with the player sits under them', (tester) async {
    // This one guards a bug that shipped: the ghost was drawn on its
    // grid cell while the live snake was slid between cells, so a
    // player exactly level with their own best run saw it a cell ahead.
    // In a race that is a lie.
    //
    // Same cells, same previous cells, a quarter of the way through the
    // tick. The ghost is longer, so the picture shows what a ghost
    // looks like as well — and the only part of it that should be
    // visible is the tail trailing out behind the snake. Anything
    // poking out in front of the head is the bug, back again.
    const cells = [
      GridPoint(9, 5),
      GridPoint(8, 5),
      GridPoint(7, 5),
      GridPoint(6, 5),
      GridPoint(5, 5),
      GridPoint(4, 5),
      GridPoint(3, 5),
    ];
    const previous = [
      GridPoint(8, 5),
      GridPoint(7, 5),
      GridPoint(6, 5),
      GridPoint(5, 5),
      GridPoint(4, 5),
      GridPoint(3, 5),
      GridPoint(2, 5),
    ];
    final engine = _engine(
      cells.take(3).toList(),
      Direction.right,
      previous: previous.take(3).toList(),
    );
    await tester.pumpWidget(
      _board(engine, tickProgress: 0.25, ghost: cells, ghostPrevious: previous),
    );
    await expectLater(
      find.byKey(goldenBoundary),
      matchesGoldenFile('goldens/board_ghost_level.png'),
    );
  });

  testWidgets('a golden apple and a poison one, beside a real apple', (
    tester,
  ) async {
    // Side by side on purpose. Poison is meant to look exactly like an
    // apple in the wrong colour — near enough to be missed in a hurry,
    // far enough to be seen when looked at. That is a judgement only a
    // picture can hold.
    final engine = _engine(const [
      GridPoint(3, 8),
      GridPoint(2, 8),
      GridPoint(1, 8),
    ], Direction.right)..elapsedMs = 2000;
    engine.foods = [
      const FoodItem(position: GridPoint(3, 3), type: FoodType.apple),
      const FoodItem(position: GridPoint(7, 3), type: FoodType.poison),
      const FoodItem(
        position: GridPoint(11, 3),
        type: FoodType.golden,
        lifetimeMs: 8000,
      ),
    ];
    await tester.pumpWidget(_board(engine));
    await expectLater(
      find.byKey(goldenBoundary),
      matchesGoldenFile('goldens/board_golden_and_poison.png'),
    );
  });

  // A star is worth more the longer it is left, and the number under it
  // is the only way a player can price that choice. On a small board so
  // the 6px face is legible when the file is opened.
  //
  // Be clear about what these two do and do not catch: two digits at
  // 6px are well under the comparator's tolerance whatever size the
  // canvas is, so a wrong *number* would slip through. The arithmetic
  // is pinned in risk_reward_test.dart. What these pin is the picture —
  // that a price is drawn at all, in the game's own face, under the
  // star rather than over it, and that the last-second blink is there.
  for (final (name, atMs, worth) in [
    ('ripening', 1000, 70),
    ('ripe', 4500, 140),
  ]) {
    testWidgets('a $name star is priced on the board ($worth)', (tester) async {
      final engine = _engine(
        const [GridPoint(1, 4), GridPoint(0, 4)],
        Direction.right,
        columns: 5,
        rows: 5,
      )..elapsedMs = atMs;
      engine.foods = [
        const FoodItem(
          position: GridPoint(3, 2),
          type: FoodType.star,
          lifetimeMs: 5000,
        ),
      ];
      await tester.pumpWidget(_board(engine, size: const Size(200, 200)));
      await expectLater(
        find.byKey(goldenBoundary),
        matchesGoldenFile('goldens/board_star_$name.png'),
      );
    });
  }
}
