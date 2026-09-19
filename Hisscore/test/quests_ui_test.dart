import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:hisscore/game/daily_challenge.dart';
import 'package:hisscore/game/high_score_store.dart';
import 'package:hisscore/game/quests.dart';
import 'package:hisscore/game/snake_engine.dart';
import 'package:hisscore/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

SnakeEngine _wallCrash() =>
    SnakeEngine(columns: 6, rows: 6, firstFoodDistance: 1, random: Random(1));

void main() {
  final today = DailyChallenge.dayNumber(DateTime.now());
  final quests = Quests.forDay(today);

  test('stores remember progress', () async {
    const progress = PlayerProgress(xp: 130, questDayKey: '2026-09-19');
    final memory = InMemoryHighScoreStore();
    expect((await memory.loadProgress()).xp, 0);
    await memory.saveProgress(progress);
    expect((await memory.loadProgress()).xp, 130);

    SharedPreferences.setMockInitialValues({});
    final prefs = SharedPreferencesHighScoreStore();
    expect((await prefs.loadProgress()).xp, 0);
    await prefs.saveProgress(progress);
    final back = await prefs.loadProgress();
    expect(back.xp, 130);
    expect(back.questDayKey, '2026-09-19');
  });

  testWidgets('the menu summarises quests and opens them on tap', (
    tester,
  ) async {
    await tester.pumpWidget(
      HisscoreApp(highScoreStore: InMemoryHighScoreStore()),
    );
    await tester.pump();

    expect(find.textContaining('QUESTS 0/3'), findsOneWidget);
    expect(find.textContaining('LVL 1'), findsOneWidget);

    await tester.tap(find.textContaining('QUESTS 0/3'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('LEVEL 1'), findsOneWidget);
    expect(find.text("TODAY'S QUESTS"), findsOneWidget);
    for (final quest in quests) {
      expect(find.text(quest.title), findsOneWidget);
    }
  });

  testWidgets('the quests page can be reached from the STATS tab too', (
    tester,
  ) async {
    await tester.pumpWidget(
      HisscoreApp(highScoreStore: InMemoryHighScoreStore()),
    );
    await tester.pump();
    await tester.tap(find.text('STATS'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('NO RUNS YET'), findsOneWidget);

    await tester.tap(find.text('QUESTS'));
    await tester.pump();
    expect(find.text('LEVEL 1'), findsOneWidget);
    expect(find.text('NO RUNS YET'), findsNothing);
  });

  testWidgets('a finished run pays XP, shows it, and saves it', (tester) async {
    final store = InMemoryHighScoreStore();
    await tester.pumpWidget(
      HisscoreApp(highScoreStore: store, engineFactory: _wallCrash),
    );
    await tester.pump();
    await tester.tap(find.text('PLAY'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1300));
    await tester.pump();

    // One apple (10 points): 1 XP for the apple, 0 for the score.
    expect(find.text('GAME OVER'), findsOneWidget);
    expect(find.text('+1 XP'), findsOneWidget);
    final saved = await store.loadProgress();
    expect(saved.xp, greaterThanOrEqualTo(1));
    expect(saved.questDayKey, DailyChallenge.dateKey(DateTime.now()));
  });

  testWidgets('each of today'
      's quests moves by what the run did', (tester) async {
    final store = InMemoryHighScoreStore();
    await tester.pumpWidget(
      HisscoreApp(highScoreStore: store, engineFactory: _wallCrash),
    );
    await tester.pump();
    await tester.tap(find.text('PLAY'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1300));
    await tester.pump();

    // The run ate one apple for 10 points and no power-ups.
    final saved = await store.loadProgress();
    for (final quest in quests) {
      final expected = switch (quest.kind) {
        QuestKind.eatApples => 1,
        QuestKind.scoreInRun => 10,
        QuestKind.collectPowerUps => 0,
        QuestKind.playRuns => 1,
        QuestKind.reachCombo => null,
      };
      if (expected != null) {
        expect(saved.progress[quest.id], expected, reason: quest.id);
      }
    }
    expect(saved.progress.keys.toSet(), quests.map((q) => q.id).toSet());
  });
}
