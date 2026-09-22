import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisscore/game/daily_challenge.dart';
import 'package:hisscore/game/food_types.dart';
import 'package:hisscore/game/game_session.dart';
import 'package:hisscore/game/high_score_store.dart';
import 'package:hisscore/game/online_scores.dart';
import 'package:hisscore/game/snake_engine.dart';
import 'package:hisscore/game/weekly_modifier.dart';
import 'package:hisscore/ui/game_overlay.dart';
import 'package:hisscore/ui/ready_tabs.dart';

/// One rule bending the daily for a week: the same rule for everyone
/// all week, a different one next week, and each rule actually doing
/// what its name says.
void main() {
  /// The first day number whose week runs under [modifier]. Found
  /// rather than written down, so reordering the list does not quietly
  /// turn these tests into tests of something else.
  int dayWith(WeeklyModifier modifier) => List.generate(
    500,
    (i) => i + 1,
  ).firstWhere((day) => DailyChallenge.modifierForDay(day) == modifier);

  SnakeEngine engineWith(
    WeeklyModifier? modifier, {
    GameMode mode = GameMode.classic,
    int columns = 20,
    int rows = 20,
    int firstFoodDistance = 4,
  }) => SnakeEngine(
    columns: columns,
    rows: rows,
    mode: mode,
    modifier: modifier,
    firstFoodDistance: firstFoodDistance,
    random: Random(11),
  );

  // ═══════════════════════════════════════════════════
  // Which rule, and when it changes
  // ═══════════════════════════════════════════════════

  group('ISO weeks', () {
    test('week 1 is the one holding the first Thursday', () {
      // 2026 opens on a Thursday, so 1 January is already week 1 and
      // the week runs back into December.
      expect(DailyChallenge.isoWeek(DateTime.utc(2026, 1, 1)), 1);
      expect(DailyChallenge.isoWeek(DateTime.utc(2025, 12, 29)), 1);
      expect(DailyChallenge.isoWeek(DateTime.utc(2026, 1, 4)), 1);
      expect(DailyChallenge.isoWeek(DateTime.utc(2026, 1, 5)), 2);
    });

    test('a week is never split between two years', () {
      // 1 January 2027 is a Friday, so it belongs to the last week of
      // 2026 rather than starting a week 1 that is three days long.
      expect(DailyChallenge.isoWeek(DateTime.utc(2027, 1, 1)), 53);
      expect(DailyChallenge.isoWeek(DateTime.utc(2027, 1, 4)), 1);
    });

    test('the day number and the date agree', () {
      for (final day in [1, 2, 100, 265, 400]) {
        expect(
          DailyChallenge.dayNumber(DailyChallenge.dateForDay(day)),
          day,
          reason: 'day $day should survive the round trip',
        );
      }
    });
  });

  group('picking the week rule', () {
    test('every day of a week gets the same one', () {
      // Day 5 is the Monday of week 2; the six days after it are the
      // rest of that week.
      final monday = DailyChallenge.dateForDay(5);
      expect(monday.weekday, DateTime.monday, reason: 'week starts here');
      final rule = DailyChallenge.modifierForDay(5);
      for (var i = 0; i < 7; i++) {
        expect(
          DailyChallenge.modifierForDay(5 + i),
          rule,
          reason: 'day ${5 + i}',
        );
      }
    });

    test('the next week gets a different one', () {
      expect(
        DailyChallenge.modifierForDay(12),
        isNot(DailyChallenge.modifierForDay(5)),
      );
    });

    test('the same day always gives the same answer', () {
      for (final day in [1, 33, 265]) {
        expect(
          DailyChallenge.modifierForDay(day),
          DailyChallenge.modifierForDay(day),
        );
      }
    });

    test('all of them come round', () {
      final seen = {
        for (var day = 1; day <= 400; day++) DailyChallenge.modifierForDay(day),
      };
      expect(seen, WeeklyModifier.values.toSet());
    });
  });

  // ═══════════════════════════════════════════════════
  // What each rule does
  // ═══════════════════════════════════════════════════

  group('double speed', () {
    test('the clock runs at half the interval', () {
      final plain = engineWith(null);
      final fast = engineWith(WeeklyModifier.doubleSpeed);
      expect(fast.tickInterval, plain.tickInterval ~/ 2);
    });

    test('and stays halved as the run speeds up', () {
      final plain = engineWith(null)..start();
      final fast = engineWith(WeeklyModifier.doubleSpeed)..start();
      for (var i = 0; i < 40; i++) {
        plain.tick();
        fast.tick();
      }
      expect(
        fast.tickInterval.inMilliseconds,
        lessThan(plain.tickInterval.inMilliseconds),
      );
    });
  });

  group('no walls', () {
    test('a classic run wraps instead of ending', () {
      final game = engineWith(
        WeeklyModifier.noWalls,
        columns: 8,
        rows: 8,
        firstFoodDistance: 99,
      )..start();
      expect(game.wrapEnabled, isTrue);

      // Straight at the right-hand wall and out the other side.
      for (var i = 0; i < 20; i++) {
        game.tick();
      }

      expect(game.phase, GamePhase.running);
    });

    test('without it the same run ends at the wall', () {
      final game = engineWith(null, columns: 8, rows: 8, firstFoodDistance: 99)
        ..start();
      for (var i = 0; i < 20; i++) {
        game.tick();
      }
      expect(game.phase, GamePhase.gameOver);
    });
  });

  group('mirrored', () {
    test('left steers right', () {
      final game = engineWith(WeeklyModifier.mirrored)..start();
      // The snake starts facing right, so a mirrored "right" is a
      // reversal and is refused; down is untouched and gets through.
      game.queueTurn(Direction.down);
      game.tick();
      expect(game.direction, Direction.down);

      game.queueTurn(Direction.left);
      game.tick();
      expect(game.direction, Direction.right, reason: 'left came out right');
    });

    test('up and down are left alone', () {
      final game = engineWith(WeeklyModifier.mirrored)..start();
      game.queueTurn(Direction.up);
      game.tick();
      expect(game.direction, Direction.up);
    });

    test('without it left is left', () {
      final game = engineWith(null)..start();
      game.queueTurn(Direction.down);
      game.tick();
      game.queueTurn(Direction.left);
      game.tick();
      expect(game.direction, Direction.left);
    });
  });

  group('fog', () {
    test('only the ground near the head is lit', () {
      final game = engineWith(WeeklyModifier.fog, columns: 30, rows: 30);
      final head = game.head;
      expect(game.lit(head), isTrue);
      expect(
        game.lit(GridPoint(head.x, head.y + WeeklyModifier.fogRadius)),
        isTrue,
        reason: 'the edge of the light counts as lit',
      );
      expect(
        game.lit(GridPoint(head.x, head.y + WeeklyModifier.fogRadius + 1)),
        isFalse,
      );
    });

    test('the light is round, not square', () {
      final game = engineWith(WeeklyModifier.fog, columns: 30, rows: 30);
      final head = game.head;
      // The corner of the square that a Chebyshev rule would light.
      const r = WeeklyModifier.fogRadius;
      expect(game.lit(GridPoint(head.x + r, head.y + r)), isFalse);
    });

    test('without it everything is lit', () {
      final game = engineWith(null, columns: 30, rows: 30);
      expect(game.lit(const GridPoint(29, 29)), isTrue);
    });
  });

  group('tiny board', () {
    test('the daily grid shrinks, and only for this rule', () {
      expect(
        DailyChallenge.columnsFor(WeeklyModifier.tinyBoard),
        WeeklyModifier.tinyColumns,
      );
      expect(
        DailyChallenge.rowsFor(WeeklyModifier.tinyBoard),
        WeeklyModifier.tinyRows,
      );
      for (final other in WeeklyModifier.values) {
        if (other == WeeklyModifier.tinyBoard) continue;
        expect(DailyChallenge.columnsFor(other), DailyChallenge.gridColumns);
        expect(DailyChallenge.rowsFor(other), DailyChallenge.gridRows);
      }
      expect(DailyChallenge.columnsFor(null), DailyChallenge.gridColumns);
    });
  });

  group('magnet madness', () {
    test('the pull is on from the first tick', () {
      final game = engineWith(WeeklyModifier.magnetMadness);
      expect(game.magnetActive, isTrue);
      expect(engineWith(null).magnetActive, isFalse);
    });

    test('food closes in on the snake by itself', () {
      final game = engineWith(
        WeeklyModifier.magnetMadness,
        columns: 20,
        rows: 20,
        firstFoodDistance: 99,
      )..start();
      // Somewhere off the snake's line, so the only thing that can
      // move it is the pull.
      game.foods = [
        FoodItem(
          position: GridPoint(game.head.x + 6, game.head.y + 6),
          type: FoodType.apple,
        ),
      ];
      final before = game.foods.first.position;

      game.tick();

      final after = game.foods.first.position;
      expect(after, isNot(before));
      expect(
        (after.y - game.head.y).abs(),
        lessThan((before.y - game.head.y).abs()),
        reason: 'it should have come closer, not drifted',
      );
    });
  });

  // ═══════════════════════════════════════════════════
  // The daily itself
  // ═══════════════════════════════════════════════════

  group('the daily run', () {
    GameSession sessionOn(int day) => GameSession(
      store: InMemoryHighScoreStore(),
      onlineScores: const NoopOnlineScoreBoard(),
      now: () => DailyChallenge.dateForDay(day),
    );

    test('starts under this week rule, on a fixed grid', () {
      final day = dayWith(WeeklyModifier.fog);
      final session = sessionOn(day)..startDaily();

      expect(session.dailyModifier, WeeklyModifier.fog);
      expect(session.engine.modifier, WeeklyModifier.fog);
      expect(session.engine.fixedGrid, isTrue);
      expect(session.engine.columns, DailyChallenge.gridColumns);
      session.dispose();
    });

    test('a tiny-board week really is played on a smaller board', () {
      final day = dayWith(WeeklyModifier.tinyBoard);
      final session = sessionOn(day)..startDaily();

      expect(session.engine.columns, WeeklyModifier.tinyColumns);
      expect(session.engine.rows, WeeklyModifier.tinyRows);
      expect(
        session.engine.fixedGrid,
        isTrue,
        reason: 'still the same board for everyone, just a smaller one',
      );
      session.dispose();
    });

    test('stays off the mode all-time board', () async {
      final online = InMemoryOnlineScoreBoard();
      final session = GameSession(
        store: InMemoryHighScoreStore(),
        onlineScores: online,
        now: () => DailyChallenge.dateForDay(dayWith(WeeklyModifier.noWalls)),
      );
      await session.load();
      session.leaderboardOptIn = true;
      session.startDaily();
      session.engine.score = 500;
      session.engine.phase = GamePhase.gameOver;
      await session.persistGameEnd();

      expect(
        (await online.top(BoardId.daily(session.dailyDayNumber))),
        isNotEmpty,
        reason: 'the daily is its own board, and everyone played this',
      );
      expect(
        await online.top(BoardId.allTime(GameMode.classic)),
        isEmpty,
        reason: 'a run with no walls is not a Classic run',
      );
      session.dispose();
    });

    test('an ordinary run is not bent by anything', () {
      final session = sessionOn(dayWith(WeeklyModifier.noWalls))
        ..primaryAction();
      expect(session.engine.modifier, isNull);
      expect(session.engine.fixedGrid, isFalse);
      session.dispose();
    });

    test('the shared result names the rule', () {
      final text = DailyChallenge.resultText(
        dayNumber: 12,
        score: 340,
        apples: 9,
        bestCombo: 3,
        streak: 2,
        modifier: WeeklyModifier.mirrored,
      );
      expect(text, contains(WeeklyModifier.mirrored.label));
    });

    test('and says nothing when there is no rule', () {
      final text = DailyChallenge.resultText(
        dayNumber: 12,
        score: 340,
        apples: 9,
        bestCombo: 3,
        streak: 2,
      );
      expect(text, contains('Daily #12 🐍\n'));
    });
  });

  // ═══════════════════════════════════════════════════
  // Saying so
  // ═══════════════════════════════════════════════════

  group('on screen', () {
    Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: Center(child: child)),
      ),
    );

    testWidgets('the card names the rule before the run', (tester) async {
      final day = dayWith(WeeklyModifier.mirrored);
      await pump(
        tester,
        DailyChallengeCard(
          dayNumber: day,
          dailyState: const DailyState(),
          playedToday: false,
          onStart: () {},
        ),
      );

      expect(
        find.text('THIS WEEK: ${WeeklyModifier.mirrored.label}'),
        findsOneWidget,
      );
      expect(
        find.text(WeeklyModifier.mirrored.blurb.toUpperCase()),
        findsOneWidget,
        reason: 'a name alone does not say what it does',
      );
    });

    testWidgets('and the end card names it again', (tester) async {
      final game = engineWith(WeeklyModifier.fog)..start();
      game.phase = GamePhase.gameOver;
      await pump(
        tester,
        GameOverlay(
          phase: GamePhase.gameOver,
          engine: game,
          won: false,
          newHighScore: false,
          isDailyRun: true,
          dailyDayNumber: 12,
          dailyState: const DailyState(),
          onShare: () {},
          onResume: () {},
          onExitToMenu: () {},
        ),
      );

      expect(find.text(WeeklyModifier.fog.label), findsOneWidget);
    });

    testWidgets('an ordinary run says nothing about rules', (tester) async {
      final game = engineWith(null)..start();
      game.phase = GamePhase.gameOver;
      await pump(
        tester,
        GameOverlay(
          phase: GamePhase.gameOver,
          engine: game,
          won: false,
          newHighScore: false,
          isDailyRun: false,
          dailyDayNumber: 12,
          dailyState: const DailyState(),
          onShare: () {},
          onResume: () {},
          onExitToMenu: () {},
        ),
      );

      for (final modifier in WeeklyModifier.values) {
        expect(find.text(modifier.label), findsNothing);
      }
    });
  });
}
