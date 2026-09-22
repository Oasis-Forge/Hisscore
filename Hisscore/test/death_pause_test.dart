import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisscore/game/high_score_store.dart';
import 'package:hisscore/game/snake_engine.dart';
import 'package:hisscore/main.dart';
import 'package:hisscore/ui/run_effects.dart';

/// The slow-motion beat between dying and the game-over card.
/// The red flash has to fade on its own clock.
///
/// It used to be handed to the board as a number, captured whenever the
/// page last rebuilt — and after a run ends, nothing rebuilds it. A
/// player with no network therefore read the whole game-over card
/// through a red wash, because a leaderboard answering was the only
/// thing that happened to rebuild the page afterwards.
void _flashFades() {
  test('the death flash fades on time alone', () {
    var clock = DateTime(2026, 9, 22, 12);
    final effects = RunEffects(now: () => clock)
      ..measure(
        size: const Size(200, 300),
        offset: Offset.zero,
        columns: 10,
        rows: 15,
      )
      ..died(const GridPoint(5, 5));

    expect(effects.deathFlashOpacity, greaterThan(0));

    // Well past the flash, with nobody notifying anybody: no ticker,
    // no listener, no leaderboard answering. Just time.
    clock = clock.add(const Duration(seconds: 5));

    expect(
      effects.deathFlashOpacity,
      0,
      reason: 'a run that ends offline must not leave the card washed red',
    );
    effects.dispose();
  });
}

void main() {
  _flashFades();

  /// A board small enough that the snake runs out of room quickly.
  SnakeEngine cramped() => SnakeEngine(
    columns: 6,
    rows: 6,
    firstFoodDistance: 99,
    random: Random(1),
  );

  Future<void> playUntilDead(WidgetTester tester) async {
    await tester.pumpWidget(
      HisscoreApp(
        highScoreStore: InMemoryHighScoreStore(),
        engineFactory: cramped,
      ),
    );
    await tester.pump();
    await tester.tap(find.text('PLAY'));
    await tester.pump();
    // Four ticks to the wall, one held by the grace tick, one to die.
    await tester.pump(const Duration(milliseconds: 1300));
  }

  testWidgets('the card waits for the beat to finish', (tester) async {
    await playUntilDead(tester);

    expect(
      find.text('GAME OVER'),
      findsNothing,
      reason: 'the board should still be visible right after the death',
    );

    await tester.pump(RunEffects.deathPause);
    await tester.pump();

    expect(find.text('GAME OVER'), findsOneWidget);
  });
  test('death time is slowed, then continuous at the hand-over', () {
    var clock = DateTime(2026, 9, 21);
    final effects = RunEffects(now: () => clock);
    effects.measure(
      size: const Size(100, 100),
      offset: Offset.zero,
      columns: 10,
      rows: 10,
    );

    effects.died(const GridPoint(1, 1));
    expect(effects.particles.timeScale, RunEffects.slowMotionScale);

    // Half way through the pause, only a tenth of the flash has played.
    clock = clock.add(const Duration(milliseconds: 200));
    expect(effects.deathElapsed, const Duration(milliseconds: 60));

    // Exactly at the hand-over, both branches agree.
    clock = clock.add(const Duration(milliseconds: 200));
    expect(effects.deathElapsed, const Duration(milliseconds: 120));

    // And a real second past the pause runs at full speed again.
    clock = clock.add(const Duration(milliseconds: 100));
    expect(effects.deathElapsed, const Duration(milliseconds: 220));

    effects.dispose();
  });

  test('the red flash outlasts the pause', () {
    var clock = DateTime(2026, 9, 21);
    final effects = RunEffects(now: () => clock);
    effects.measure(
      size: const Size(100, 100),
      offset: Offset.zero,
      columns: 10,
      rows: 10,
    );

    effects.died(const GridPoint(1, 1));
    expect(effects.deathFlashOpacity, 1.0);

    clock = clock.add(RunEffects.deathPause);
    expect(
      effects.deathFlashOpacity,
      greaterThan(0.5),
      reason: 'still going strong when the card arrives',
    );

    clock = clock.add(const Duration(seconds: 1));
    expect(effects.deathFlashOpacity, 0);

    effects.dispose();
  });

  test('a new run clears the slow motion', () {
    final effects = RunEffects();
    effects.measure(
      size: const Size(100, 100),
      offset: Offset.zero,
      columns: 10,
      rows: 10,
    );

    effects.died(const GridPoint(1, 1));
    expect(effects.dying, isTrue);
    expect(effects.particles.timeScale, lessThan(1.0));

    effects.clear();

    expect(effects.dying, isFalse);
    expect(effects.particles.timeScale, 1.0);
    expect(effects.deathFlashOpacity, 0);

    effects.dispose();
  });
}
