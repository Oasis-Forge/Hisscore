import 'package:flutter_test/flutter_test.dart';
import 'package:hisscore/game/daily_challenge.dart';
import 'package:hisscore/game/high_score_store.dart';

void main() {
  group('dateKey', () {
    test('formats a UTC date as YYYY-MM-DD', () {
      expect(DailyChallenge.dateKey(DateTime.utc(2026, 3, 4)), '2026-03-04');
    });
  });

  group('dayNumber', () {
    test('day 1 is the epoch date itself', () {
      expect(DailyChallenge.dayNumber(DailyChallenge.epoch), 1);
    });

    test('increments by one per calendar day', () {
      final tomorrow = DailyChallenge.epoch.add(const Duration(days: 1));
      expect(DailyChallenge.dayNumber(tomorrow), 2);
    });
  });

  group('seedForDay', () {
    test('is deterministic for the same day number', () {
      expect(DailyChallenge.seedForDay(100), DailyChallenge.seedForDay(100));
    });

    test('differs across day numbers', () {
      expect(
        DailyChallenge.seedForDay(100),
        isNot(DailyChallenge.seedForDay(101)),
      );
    });
  });

  group('playedToday', () {
    final today = DateTime.utc(2026, 5, 10);

    test('true when last played key matches today', () {
      expect(
        DailyChallenge.playedToday(lastPlayedKey: '2026-05-10', today: today),
        isTrue,
      );
    });

    test('false when last played on a different day', () {
      expect(
        DailyChallenge.playedToday(lastPlayedKey: '2026-05-09', today: today),
        isFalse,
      );
    });

    test('false when never played', () {
      expect(
        DailyChallenge.playedToday(lastPlayedKey: null, today: today),
        isFalse,
      );
    });
  });

  group('nextStreak', () {
    final today = DateTime.utc(2026, 5, 10);

    test('starts a streak at 1 with no previous play', () {
      final streak = DailyChallenge.nextStreak(
        lastPlayedKey: null,
        previousStreak: 0,
        today: today,
      );
      expect(streak, 1);
    });

    test('continues the streak when last played yesterday', () {
      final streak = DailyChallenge.nextStreak(
        lastPlayedKey: '2026-05-09',
        previousStreak: 4,
        today: today,
      );
      expect(streak, 5);
    });

    test('stays unchanged when already played today', () {
      final streak = DailyChallenge.nextStreak(
        lastPlayedKey: '2026-05-10',
        previousStreak: 5,
        today: today,
      );
      expect(streak, 5);
    });

    test('resets to 1 after a gap of more than one day', () {
      final streak = DailyChallenge.nextStreak(
        lastPlayedKey: '2026-05-07',
        previousStreak: 6,
        today: today,
      );
      expect(streak, 1);
    });
  });

  group('streak freeze', () {
    final today = DateTime.utc(2026, 5, 10);

    StreakOutcome roll({
      String? lastPlayedKey,
      int previousStreak = 0,
      int freezes = 0,
      DateTime? on,
    }) => DailyChallenge.nextStreakState(
      lastPlayedKey: lastPlayedKey,
      previousStreak: previousStreak,
      freezes: freezes,
      today: on ?? today,
    );

    test('a missed day with nothing banked still breaks the streak', () {
      final out = roll(
        lastPlayedKey: '2026-05-08',
        previousStreak: 6,
        freezes: 0,
      );
      expect(out.streak, 1);
      expect(out.freezesSpent, 0);
    });

    test('a missed day with one banked keeps it, and spends the day', () {
      final out = roll(
        lastPlayedKey: '2026-05-08',
        previousStreak: 6,
        freezes: 1,
      );
      expect(out.streak, 7, reason: 'the gap never happened');
      expect(out.freezesSpent, 1);
      // Seven days also pays for the next one, so the bank refills.
      expect(out.freezes, 1);
    });

    test('two missed days need two banked', () {
      expect(
        roll(lastPlayedKey: '2026-05-07', previousStreak: 6, freezes: 1).streak,
        1,
        reason: 'one freeze cannot cover two days',
      );
      final covered = roll(
        lastPlayedKey: '2026-05-07',
        previousStreak: 6,
        freezes: 2,
      );
      expect(covered.streak, 7);
      expect(covered.freezesSpent, 2);
    });

    test('an unbroken day spends nothing', () {
      final out = roll(
        lastPlayedKey: '2026-05-09',
        previousStreak: 3,
        freezes: 2,
      );
      expect(out.streak, 4);
      expect(out.freezesSpent, 0);
      expect(out.freezes, 2);
    });

    test('one is earned every seven days', () {
      final out = roll(
        lastPlayedKey: '2026-05-09',
        previousStreak: 6,
        freezes: 0,
      );
      expect(out.streak, 7);
      expect(out.freezeEarned, isTrue);
      expect(out.freezes, 1);

      // Day 8 is not a multiple of seven and pays nothing.
      final next = roll(
        lastPlayedKey: '2026-05-09',
        previousStreak: 7,
        freezes: 1,
      );
      expect(next.freezeEarned, isFalse);
      expect(next.freezes, 1);
    });

    test('the bank does not grow past its cap', () {
      final out = roll(
        lastPlayedKey: '2026-05-09',
        previousStreak: 13,
        freezes: DailyChallenge.maxFreezes,
      );
      expect(out.streak, 14);
      expect(out.freezes, DailyChallenge.maxFreezes);
      expect(
        out.freezeEarned,
        isFalse,
        reason: 'a freeze that is dropped must not be announced',
      );
    });

    test('a second run on the same day pays nothing and spends nothing', () {
      final out = roll(
        lastPlayedKey: '2026-05-10',
        previousStreak: 7,
        freezes: 1,
      );
      expect(out.streak, 7);
      expect(out.freezes, 1);
      expect(out.freezeEarned, isFalse, reason: 'already counted today');
      expect(out.freezesSpent, 0);
    });

    test('a first ever run cannot spend a freeze it has not earned', () {
      final out = roll(lastPlayedKey: null, previousStreak: 0, freezes: 2);
      expect(out.streak, 1);
      expect(out.freezesSpent, 0);
      expect(out.freezes, 2);
    });

    test('missedDays counts the days nobody played', () {
      expect(
        DailyChallenge.missedDays(lastPlayedKey: '2026-05-09', today: today),
        0,
      );
      expect(
        DailyChallenge.missedDays(lastPlayedKey: '2026-05-08', today: today),
        1,
      );
      expect(DailyChallenge.missedDays(lastPlayedKey: null, today: today), -1);
      expect(
        DailyChallenge.missedDays(lastPlayedKey: 'not-a-date', today: today),
        -1,
        reason: 'a key that cannot be read is not a streak to keep',
      );
      expect(
        DailyChallenge.missedDays(lastPlayedKey: '2026-05-20', today: today),
        -1,
        reason: 'a clock that went backwards has no meaningful answer',
      );
    });

    test('the bank survives a round trip to disk', () {
      const state = DailyState(
        lastPlayedKey: '2026-05-09',
        currentStreak: 7,
        bestStreak: 9,
        freezes: 2,
      );
      expect(DailyState.fromJson(state.toJson()).freezes, 2);
      // An old save that predates freezes reads as an empty bank.
      expect(DailyState.fromJson(const {'currentStreak': 3}).freezes, 0);
    });
  });

  group('fixed grid', () {
    test('is portrait and the aspect matches the size', () {
      expect(DailyChallenge.gridRows, greaterThan(DailyChallenge.gridColumns));
      expect(
        DailyChallenge.gridAspect,
        DailyChallenge.gridColumns / DailyChallenge.gridRows,
      );
    });
  });

  group('scoreBar', () {
    test('is empty at zero and full at the cap', () {
      expect(DailyChallenge.scoreBar(0), '⬛' * 10);
      expect(DailyChallenge.scoreBar(500), '🟩' * 5 + '🟨' * 3 + '🟥' * 2);
      expect(DailyChallenge.scoreBar(99999), DailyChallenge.scoreBar(500));
    });

    test('fills one square per 50 points, shaded as it goes', () {
      expect(DailyChallenge.scoreBar(49), '⬛' * 10);
      expect(DailyChallenge.scoreBar(50), '🟩${'⬛' * 9}');
      expect(DailyChallenge.scoreBar(300), '${'🟩' * 5}🟨${'⬛' * 4}');
    });
  });

  group('resultText', () {
    test('lays out the day, bar, stats and streak', () {
      final text = DailyChallenge.resultText(
        dayNumber: 262,
        score: 120,
        apples: 12,
        bestCombo: 4,
        streak: 3,
      );
      expect(text.split('\n'), [
        'HISCORE Daily #262 🐍',
        '🟩🟩⬛⬛⬛⬛⬛⬛⬛⬛',
        '120 pts · 12 🍎 · combo x4',
        'Streak 3 🔥',
      ]);
    });

    test('leaves out the combo when there was none', () {
      final text = DailyChallenge.resultText(
        dayNumber: 1,
        score: 10,
        apples: 1,
        bestCombo: 1,
        streak: 1,
      );
      expect(text.contains('combo'), isFalse);
    });
  });
}
