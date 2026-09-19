import 'package:flutter_test/flutter_test.dart';
import 'package:hisscore/game/daily_challenge.dart';

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
