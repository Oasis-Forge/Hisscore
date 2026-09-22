import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:hisscore/game/daily_challenge.dart';
import 'package:hisscore/game/game_session.dart';
import 'package:hisscore/game/high_score_store.dart';
import 'package:hisscore/game/online_scores.dart';
import 'package:hisscore/game/snake_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Nothing about a player reaches a public board until they have said
/// so. "Not asked" is not "yes".
void main() {
  GameSession sessionWith(
    InMemoryOnlineScoreBoard board, {
    HighScoreStore? store,
  }) => GameSession(
    store: store ?? InMemoryHighScoreStore(),
    onlineScores: board,
    engineFactory: () => SnakeEngine(random: Random(1)),
    now: () => DateTime(2026, 9, 22),
  );

  /// Ends a run with a real score, the way `persistGameEnd` expects.
  Future<void> finish(GameSession session, {int score = 250}) async {
    session.primaryAction();
    session.engine.score = score;
    session.engine.phase = GamePhase.gameOver;
    await session.persistGameEnd();
  }

  group('the gate', () {
    test('an unanswered player sends nothing', () async {
      final board = InMemoryOnlineScoreBoard();
      final session = sessionWith(board);
      expect(session.leaderboardOptIn, isNull);

      await finish(session);

      expect(await board.top(BoardId.allTime(GameMode.classic)), isEmpty);
      session.dispose();
    });

    test('and is owed the question', () async {
      final board = InMemoryOnlineScoreBoard();
      final session = sessionWith(board);
      expect(session.owesLeaderboardChoice, isFalse, reason: 'nothing yet');

      await finish(session);

      expect(session.owesLeaderboardChoice, isTrue);
      session.dispose();
    });

    test('a refusal sends nothing, and is not asked again', () async {
      final board = InMemoryOnlineScoreBoard();
      final session = sessionWith(board);
      await finish(session);

      await session.setLeaderboardOptIn(false);

      expect(await board.top(BoardId.allTime(GameMode.classic)), isEmpty);
      expect(session.owesLeaderboardChoice, isFalse);

      // A second run is not an excuse to ask again.
      await finish(session, score: 400);
      expect(session.owesLeaderboardChoice, isFalse);
      expect(await board.top(BoardId.allTime(GameMode.classic)), isEmpty);
      session.dispose();
    });

    test('a yes sends the run they were asked about', () async {
      final board = InMemoryOnlineScoreBoard();
      final session = sessionWith(board);
      await finish(session, score: 250);

      await session.setLeaderboardOptIn(true);

      final top = await board.top(BoardId.allTime(GameMode.classic));
      expect(top, hasLength(1));
      expect(
        top.single.score,
        250,
        reason: 'the score on screen, not the next one',
      );
      expect(session.owesLeaderboardChoice, isFalse);
      session.dispose();
    });

    test('and every run after it goes without asking', () async {
      final board = InMemoryOnlineScoreBoard();
      final session = sessionWith(board);
      await session.setLeaderboardOptIn(true);

      await finish(session, score: 300);

      expect(await board.top(BoardId.allTime(GameMode.classic)), hasLength(1));
      expect(session.owesLeaderboardChoice, isFalse);
      session.dispose();
    });

    test('turning it back off stops the next run', () async {
      final board = InMemoryOnlineScoreBoard();
      final session = sessionWith(board);
      await session.setLeaderboardOptIn(true);
      await finish(session, score: 300);

      await session.setLeaderboardOptIn(false);
      await finish(session, score: 900);

      final top = await board.top(BoardId.allTime(GameMode.classic));
      expect(top.single.score, 300, reason: 'the 900 stayed home');
      session.dispose();
    });

    test('a scoreless run is never worth asking about', () async {
      final board = InMemoryOnlineScoreBoard();
      final session = sessionWith(board);

      await finish(session, score: 0);

      expect(
        session.owesLeaderboardChoice,
        isFalse,
        reason: 'there was nothing to send either way',
      );
      session.dispose();
    });

    test('the daily is gated too, not just the all-time boards', () async {
      final board = InMemoryOnlineScoreBoard();
      final session = GameSession(
        store: InMemoryHighScoreStore(),
        onlineScores: board,
        now: () => DailyChallenge.dateForDay(265),
      );
      session.startDaily();
      session.engine.score = 500;
      session.engine.phase = GamePhase.gameOver;
      await session.persistGameEnd();

      expect(await board.top(BoardId.daily(265)), isEmpty);
      expect(session.owesLeaderboardChoice, isTrue);
      session.dispose();
    });
  });

  group('remembering the answer', () {
    test('it survives a restart', () async {
      final store = InMemoryHighScoreStore();
      final first = sessionWith(InMemoryOnlineScoreBoard(), store: store);
      await first.setLeaderboardOptIn(true);
      first.dispose();

      final second = sessionWith(InMemoryOnlineScoreBoard(), store: store);
      await second.load();

      expect(second.leaderboardOptIn, isTrue);
      second.dispose();
    });

    test('a refusal survives it too', () async {
      final store = InMemoryHighScoreStore();
      final first = sessionWith(InMemoryOnlineScoreBoard(), store: store);
      await first.setLeaderboardOptIn(false);
      first.dispose();

      final second = sessionWith(InMemoryOnlineScoreBoard(), store: store);
      await second.load();

      expect(
        second.leaderboardOptIn,
        isFalse,
        reason: 'a no that forgets itself is not a no',
      );
      second.dispose();
    });

    test('both stores agree, including on never having asked', () async {
      SharedPreferences.setMockInitialValues({});
      for (final store in <HighScoreStore>[
        InMemoryHighScoreStore(),
        SharedPreferencesHighScoreStore(),
      ]) {
        expect(
          await store.loadLeaderboardOptIn(),
          isNull,
          reason: '${store.runtimeType} should start unasked',
        );
        await store.saveLeaderboardOptIn(true);
        expect(await store.loadLeaderboardOptIn(), isTrue);
        await store.saveLeaderboardOptIn(false);
        expect(await store.loadLeaderboardOptIn(), isFalse);
      }
    });
  });
}
