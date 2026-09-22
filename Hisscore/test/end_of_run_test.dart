import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisscore/game/game_session.dart';
import 'package:hisscore/game/high_score_store.dart';
import 'package:hisscore/game/online_scores.dart';
import 'package:hisscore/game/quests.dart';
import 'package:hisscore/game/run_standing.dart';
import 'package:hisscore/game/snake_engine.dart';
import 'package:hisscore/ui/end_of_run.dart';
import 'package:hisscore/ui/theme.dart';

/// The screen that decides whether the next run happens: how this run
/// did against the best, how far up the board it landed, and what it
/// moved.
void main() {
  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        backgroundColor: RetroColors.voidBg,
        body: Center(child: child),
      ),
    ),
  );

  // ═══════════════════════════════════════════════════
  // Where the run landed on a board
  // ═══════════════════════════════════════════════════

  group('standing', () {
    BoardEntry entry(int score) =>
        BoardEntry(playerId: 'p$score', name: 'P$score', score: score);

    test('an empty board says nothing', () {
      expect(
        RunStanding.of(entries: [], score: 100, board: 'THE DAILY'),
        isNull,
      );
    });

    test('names the place above and the gap to it', () {
      final standing = RunStanding.of(
        entries: [entry(300), entry(250), entry(212), entry(200)],
        score: 200,
        board: 'THE DAILY',
      );

      expect(standing!.rank, 4);
      expect(standing.pointsBehind, 12);
      expect(standing.line, '12 POINTS BEHIND #3 ON THE DAILY');
    });

    test('the top of the board has nothing to chase', () {
      final standing = RunStanding.of(
        entries: [entry(500), entry(100)],
        score: 500,
        board: 'CLASSIC ALL-TIME',
      );

      expect(standing!.rank, 1);
      expect(standing.isTop, isTrue);
      expect(standing.line, '#1 ON CLASSIC ALL-TIME');
    });

    test('one point behind is singular', () {
      final standing = RunStanding.of(
        entries: [entry(101), entry(100)],
        score: 100,
        board: 'THE DAILY',
      );

      expect(standing!.line, '1 POINT BEHIND #1 ON THE DAILY');
    });

    test('a tie does not count as being behind', () {
      final standing = RunStanding.of(
        entries: [entry(200), entry(200)],
        score: 200,
        board: 'THE DAILY',
      );

      expect(standing!.rank, 1, reason: 'nobody is strictly above');
    });

    test('a session reads its standing back off the board', () async {
      final board = InMemoryOnlineScoreBoard();
      await board.submit(
        BoardId.allTime(GameMode.classic),
        name: 'ACE',
        score: 9999,
      );
      final session = GameSession(
        store: InMemoryHighScoreStore(),
        onlineScores: board,
        engineFactory: () => SnakeEngine(random: Random(1)),
        now: () => DateTime(2026, 9, 21),
      )..leaderboardOptIn = true;
      session.primaryAction();
      while (session.engine.phase == GamePhase.running) {
        session.onTicker();
      }
      await session.saveInFlight;

      expect(session.standing, isNotNull);
      expect(session.standing!.isTop, isFalse);
      expect(session.standing!.pointsBehind, 9999 - session.engine.score);
      session.dispose();
    });

    test('a fresh run clears the old standing', () async {
      final board = InMemoryOnlineScoreBoard();
      final session = GameSession(
        store: InMemoryHighScoreStore(),
        onlineScores: board,
        engineFactory: () => SnakeEngine(random: Random(1)),
        now: () => DateTime(2026, 9, 21),
      )..leaderboardOptIn = true;
      session.primaryAction();
      while (session.engine.phase == GamePhase.running) {
        session.onTicker();
      }
      await session.saveInFlight;
      expect(session.standing, isNotNull);

      session.primaryAction();

      expect(session.standing, isNull);
      session.dispose();
    });

    testWidgets('the card says it out loud', (tester) async {
      await pump(
        tester,
        const BoardStanding(
          standing: RunStanding(rank: 9, board: 'THE DAILY', pointsBehind: 12),
        ),
      );

      expect(find.text('12 POINTS BEHIND #8 ON THE DAILY'), findsOneWidget);
    });
  });

  // ═══════════════════════════════════════════════════
  // This run against the best
  // ═══════════════════════════════════════════════════

  group('score against best', () {
    testWidgets('a short run says how short', (tester) async {
      await pump(tester, const ScoreVsBest(score: 340, best: 500));

      expect(find.text('VS BEST'), findsOneWidget);
      expect(find.text('340 / 500'), findsOneWidget);
      expect(find.text('160 SHORT'), findsOneWidget);
    });

    testWidgets('beating it drops the chase', (tester) async {
      await pump(tester, const ScoreVsBest(score: 600, best: 500));

      expect(find.text('BEST'), findsOneWidget);
      expect(find.text('600'), findsOneWidget);
      expect(find.textContaining('SHORT'), findsNothing);
    });

    testWidgets('a first-ever best does not divide by zero', (tester) async {
      await pump(tester, const ScoreVsBest(score: 10, best: 0));

      expect(tester.takeException(), isNull);
      expect(find.textContaining('SHORT'), findsNothing);
    });
  });

  // ═══════════════════════════════════════════════════
  // What the run moved
  // ═══════════════════════════════════════════════════

  group('progress', () {
    const dayKey = '2026-09-21';
    const dayNumber = 264;

    RunOutcome outcomeFor(PlayerProgress before, RunSummary run) =>
        Quests.apply(before, run, dayNumber: dayNumber, dayKey: dayKey);

    test('an outcome remembers where the player started', () {
      final before = Quests.rolled(const PlayerProgress(xp: 120), dayKey);
      final outcome = outcomeFor(
        before,
        const RunSummary(apples: 5, score: 100, bestCombo: 2, powerUps: 1),
      );

      expect(outcome.before.xp, 120);
      expect(outcome.progress.xp, 120 + outcome.xpGained);
      expect(outcome.levelBefore, before.level);
    });

    test('a quest reports where it was and where it got to', () {
      final quests = Quests.forDay(dayNumber);
      final apples = quests.firstWhere(
        (q) => q.kind == QuestKind.eatApples,
        orElse: () => quests.first,
      );
      final outcome = outcomeFor(
        const PlayerProgress(),
        const RunSummary(apples: 4, score: 40, bestCombo: 1, powerUps: 0),
      );

      expect(outcome.progressBefore(apples), 0);
      expect(outcome.progressAfter(apples), greaterThan(0));
    });

    testWidgets('the XP bar names the level it is filling', (tester) async {
      final outcome = outcomeFor(
        const PlayerProgress(xp: 40),
        const RunSummary(apples: 6, score: 120, bestCombo: 3, powerUps: 2),
      );

      await pump(tester, XpBar(outcome: outcome));
      await tester.pumpAndSettle();

      expect(find.text('LVL ${outcome.progress.level}'), findsOneWidget);
      expect(find.textContaining('XP'), findsOneWidget);
    });

    testWidgets('only the quests this run moved are listed', (tester) async {
      final quests = Quests.forDay(dayNumber);
      // A run that ate nothing and scored nothing moves nothing.
      final still = outcomeFor(
        const PlayerProgress(),
        const RunSummary(apples: 0, score: 0, bestCombo: 0, powerUps: 0),
      );

      await pump(tester, QuestProgressList(outcome: still, quests: quests));

      for (final quest in quests) {
        expect(find.text(quest.title), findsNothing);
      }
    });

    testWidgets('a quest that moved ticks up', (tester) async {
      final quests = Quests.forDay(dayNumber);
      final outcome = outcomeFor(
        const PlayerProgress(),
        const RunSummary(apples: 7, score: 200, bestCombo: 3, powerUps: 2),
      );
      final moved = quests
          .where((q) => outcome.progressAfter(q) > outcome.progressBefore(q))
          .toList();

      await pump(tester, QuestProgressList(outcome: outcome, quests: quests));
      await tester.pumpAndSettle();

      expect(moved, isNotEmpty, reason: 'this run should move something');
      for (final quest in moved) {
        expect(find.text(quest.title), findsOneWidget);
        // Overshooting a target reads as done, not as 200/150.
        final shown = outcome.progressAfter(quest).clamp(0, quest.target);
        expect(find.text('$shown / ${quest.target}'), findsOneWidget);
      }
    });

    testWidgets('a barely-started bar is still a bar', (tester) async {
      // The track keeps its width whatever the fill is. A bar that
      // shrink-wraps its own progress shows no remainder, so 1 of 100
      // renders as a speck with a border round it rather than a bar
      // that has barely started.
      await pump(tester, const ScoreVsBest(score: 1, best: 100));
      await tester.pumpAndSettle();
      final nearlyEmpty = tester
          .getSize(find.byType(FractionallySizedBox))
          .width;

      await pump(tester, const ScoreVsBest(score: 99, best: 100));
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byType(FractionallySizedBox)).width,
        nearlyEmpty,
      );
      expect(nearlyEmpty, greaterThan(100));
    });
  });
}
