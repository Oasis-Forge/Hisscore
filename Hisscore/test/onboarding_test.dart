import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisscore/game/food_types.dart';
import 'package:hisscore/game/high_score_store.dart';
import 'package:hisscore/game/snake_engine.dart';
import 'package:hisscore/main.dart';
import 'package:hisscore/ui/swipe_hint.dart';

/// A first-time player is told what the one control is and what the
/// pickups do, without having to go looking for either.
void main() {
  /// A store that looks like somebody has played before.
  Future<InMemoryHighScoreStore> playedBefore() async {
    final store = InMemoryHighScoreStore();
    await store.updateStats(SnakeEngine(random: Random(1)));
    return store;
  }

  group('pickup effects', () {
    test('every pickup says what it does', () {
      for (final type in FoodType.values) {
        expect(
          type.effect,
          isNotEmpty,
          reason: '${type.name} has no effect text for the legend',
        );
        expect(type.effect, equals(type.effect.toUpperCase()));
      }
    });

    test('no two pickups describe themselves the same way', () {
      final effects = FoodType.values.map((t) => t.effect).toSet();
      expect(effects, hasLength(FoodType.values.length));
    });
  });

  group('swipe hint', () {
    testWidgets('shows over the menu before the first run', (tester) async {
      await tester.pumpWidget(
        HisscoreApp(highScoreStore: InMemoryHighScoreStore()),
      );
      await tester.pump();

      expect(find.byType(SwipeHint), findsOneWidget);
      expect(find.text('SWIPE TO STEER'), findsOneWidget);
    });

    testWidgets('is gone once a run has been finished', (tester) async {
      await tester.pumpWidget(
        HisscoreApp(highScoreStore: await playedBefore()),
      );
      await tester.pump();

      expect(find.byType(SwipeHint), findsNothing);
    });

    testWidgets('never shows during a run', (tester) async {
      await tester.pumpWidget(
        HisscoreApp(highScoreStore: InMemoryHighScoreStore()),
      );
      await tester.pump();
      expect(find.byType(SwipeHint), findsOneWidget);

      await tester.tap(find.text('PLAY'));
      await tester.pump();

      expect(find.byType(SwipeHint), findsNothing);
    });
  });

  group('pause legend', () {
    testWidgets('pausing explains every pickup', (tester) async {
      await tester.pumpWidget(
        HisscoreApp(
          highScoreStore: InMemoryHighScoreStore(),
          engineFactory: () => SnakeEngine(random: Random(1)),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('PLAY'));
      await tester.pump();

      // Past the guard that stops the starting tap pausing the run.
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.byIcon(Icons.pause));
      await tester.pump();

      expect(find.text('PAUSED'), findsOneWidget);
      expect(find.text('PICKUPS'), findsOneWidget);
      for (final type in FoodType.values) {
        expect(
          find.text(type.effect),
          findsOneWidget,
          reason: '${type.name} is missing from the pause legend',
        );
      }
    });

    testWidgets('the game-over card stays free of it', (tester) async {
      await tester.pumpWidget(
        HisscoreApp(
          highScoreStore: InMemoryHighScoreStore(),
          engineFactory: () =>
              SnakeEngine(columns: 6, rows: 6, random: Random(1)),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('PLAY'));
      await tester.pump();
      // Long enough for a 6-wide board to run out of room.
      await tester.pump(const Duration(seconds: 3));

      expect(find.text('GAME OVER'), findsOneWidget);
      expect(find.text('PICKUPS'), findsNothing);
    });
  });
}
