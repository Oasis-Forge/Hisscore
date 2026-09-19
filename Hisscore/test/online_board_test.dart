import 'package:flutter/material.dart';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:hisscore/game/daily_challenge.dart';
import 'package:hisscore/game/high_score_store.dart';
import 'package:hisscore/game/online_scores.dart';
import 'package:hisscore/game/snake_engine.dart';
import 'package:hisscore/main.dart';

Future<void> _openStats(WidgetTester tester) async {
  await tester.tap(find.text('STATS'));
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  final today = DailyChallenge.dayNumber(DateTime.now());

  testWidgets('with no backend the stats tab has no board switch', (
    tester,
  ) async {
    await tester.pumpWidget(
      HisscoreApp(highScoreStore: InMemoryHighScoreStore()),
    );
    await tester.pump();
    await _openStats(tester);
    expect(find.text('TODAY'), findsNothing);
    expect(find.text('ALL-TIME'), findsNothing);
    expect(find.textContaining('[EDIT]'), findsNothing);
  });

  testWidgets('TODAY and ALL-TIME show the boards, highest first', (
    tester,
  ) async {
    final board = InMemoryOnlineScoreBoard()
      ..seed(BoardId.daily(today), 'a', 'ANN', 120)
      ..seed(BoardId.daily(today), 'b', 'BOB', 340)
      ..seed(BoardId.allTime(GameMode.classic), 'c', 'CAT', 900);
    await tester.pumpWidget(
      HisscoreApp(
        highScoreStore: InMemoryHighScoreStore(),
        onlineScores: board,
      ),
    );
    await tester.pump();
    await _openStats(tester);

    await tester.tap(find.text('TODAY'));
    await tester.pump();
    await tester.pump();
    expect(find.text('BOB'), findsOneWidget);
    expect(find.text('00340'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('BOB')).dy,
      lessThan(tester.getTopLeft(find.text('ANN')).dy),
    );

    await tester.tap(find.text('ALL-TIME'));
    await tester.pump();
    await tester.pump();
    expect(find.text('CAT'), findsOneWidget);
    expect(find.text('BOB'), findsNothing);
  });

  testWidgets('an empty board says so', (tester) async {
    await tester.pumpWidget(
      HisscoreApp(
        highScoreStore: InMemoryHighScoreStore(),
        onlineScores: InMemoryOnlineScoreBoard(),
      ),
    );
    await tester.pump();
    await _openStats(tester);
    await tester.tap(find.text('TODAY'));
    await tester.pump();
    await tester.pump();
    expect(find.text('NO SCORES YET'), findsOneWidget);
  });

  testWidgets('the name can be edited, cleaned, saved and shown', (
    tester,
  ) async {
    final store = InMemoryHighScoreStore();
    final board = InMemoryOnlineScoreBoard(playerId: 'abc123');
    await tester.pumpWidget(
      HisscoreApp(highScoreStore: store, onlineScores: board),
    );
    await tester.pump();
    await _openStats(tester);
    expect(find.text('YOU: PLAYER-ABC1  [EDIT]'), findsOneWidget);

    await tester.tap(find.textContaining('[EDIT]'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(find.byType(TextField), 'ace pilot!');
    await tester.tap(find.text('SAVE'));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('YOU: ACE PILOT  [EDIT]'), findsOneWidget);
    expect(await store.loadPlayerName(), 'ACE PILOT');
  });

  testWidgets('a too-short name is refused', (tester) async {
    final store = InMemoryHighScoreStore();
    await tester.pumpWidget(
      HisscoreApp(
        highScoreStore: store,
        onlineScores: InMemoryOnlineScoreBoard(),
      ),
    );
    await tester.pump();
    await _openStats(tester);
    await tester.tap(find.textContaining('[EDIT]'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(find.byType(TextField), 'x');
    await tester.tap(find.text('SAVE'));
    await tester.pump();

    expect(find.textContaining('LETTERS OR DIGITS'), findsOneWidget);
    expect(await store.loadPlayerName(), isNull);
  });

  testWidgets('finishing a run posts it to the all-time board', (tester) async {
    final board = InMemoryOnlineScoreBoard(playerId: 'me');
    await tester.pumpWidget(
      HisscoreApp(
        highScoreStore: InMemoryHighScoreStore(),
        onlineScores: board,
        engineFactory: () => SnakeEngine(
          columns: 6,
          rows: 6,
          firstFoodDistance: 1,
          random: Random(1),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('PLAY'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1300));
    expect(find.text('GAME OVER'), findsOneWidget);

    final top = await tester.runAsync(
      () => board.top(BoardId.allTime(GameMode.classic)),
    );
    expect(top, hasLength(1));
    expect(top!.single.name, 'PLAYER-ME00');
    expect(top.single.score, 10);
  });
}
