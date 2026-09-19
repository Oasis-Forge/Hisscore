import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisscore/game/food_types.dart';
import 'package:hisscore/game/snake_engine.dart';
import 'package:hisscore/ui/board.dart';
import 'package:hisscore/ui/backdrops.dart';
import 'package:hisscore/ui/snake_skin.dart';

/// Goldens are rendered on a developer's machine and checked on CI's, so
/// allow a hair of anti-aliasing drift between platforms while still
/// catching a malformed shape (two earlier painter bugs were caught by
/// eye: the lightning bolt and the star).
class _TolerantComparator extends LocalFileComparator {
  _TolerantComparator(super.testFile, {required this.tolerance});

  final double tolerance;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    if (result.passed || result.diffPercent <= tolerance) return true;
    final error = await generateFailureOutput(result, golden, basedir);
    throw FlutterError(error);
  }
}

Widget _board(SnakeEngine engine, {double tickProgress = 1.0}) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: RepaintBoundary(
      child: SizedBox(
        width: 420,
        height: 300,
        child: CustomPaint(
          painter: SnakeBoardPainter(
            engine: engine,
            pulse: 0.5,
            tickProgress: tickProgress,
          ),
        ),
      ),
    ),
  );
}

SnakeEngine _engine(List<GridPoint> snake, Direction direction) {
  final engine = SnakeEngine(columns: 14, rows: 10)
    ..snake = snake
    ..direction = direction
    ..foods = [];
  engine.previousSnake = List.of(snake);
  return engine;
}

void main() {
  setUp(() {
    final base = goldenFileComparator as LocalFileComparator;
    goldenFileComparator = _TolerantComparator(
      Uri.parse('${base.basedir}board_golden_test.dart'),
      tolerance: 0.005,
    );
  });

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
      find.byType(RepaintBoundary).first,
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
        find.byType(RepaintBoundary).first,
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
      find.byType(RepaintBoundary).first,
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
      find.byType(RepaintBoundary).first,
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
      find.byType(RepaintBoundary).first,
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
        find.byType(RepaintBoundary).first,
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
      find.byType(RepaintBoundary).first,
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
      find.byType(RepaintBoundary).first,
      matchesGoldenFile('goldens/board_obstacles.png'),
    );
  });
}
