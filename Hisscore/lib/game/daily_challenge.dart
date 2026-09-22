import 'weekly_modifier.dart';

/// What finishing today's daily did to the streak and the freeze bank.
typedef StreakOutcome = ({
  int streak,

  /// Freezes left in the bank afterwards.
  int freezes,

  /// How many banked days this run had to spend to keep the streak
  /// alive. Zero on an unbroken run.
  int freezesSpent,

  /// Whether the streak just passed another seven days and paid for a
  /// freeze.
  bool freezeEarned,
});

/// Pure logic for the daily challenge: everyone who plays on the same
/// calendar day gets the same food/obstacle layout (via a shared RNG
/// seed), and playing on consecutive days builds a streak.
///
/// No Flutter dependency, like snake_engine.dart — this is plain date
/// arithmetic and string keys, easy to unit test.
abstract final class DailyChallenge {
  /// The daily board is the same size on every device, so the same seed
  /// really gives the same game and scores can be compared. Screens that
  /// do not match this shape are letterboxed.
  static const gridColumns = 20;
  static const gridRows = 30;
  static const gridAspect = gridColumns / gridRows;

  /// The Snake game's own "epoch" — day 1 of the daily challenge.
  /// Arbitrary, just needs to be fixed so day numbers are stable.
  static final DateTime epoch = DateTime.utc(2026, 1, 1);

  /// A stable per-day identifier, e.g. "2026-03-14". Two devices on the
  /// same calendar day (UTC) produce the same key.
  static String dateKey(DateTime date) {
    final d = date.toUtc();
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  /// Day number since [epoch] (day 1 = the epoch date itself). Used both
  /// as the shareable "Daily #N" label and as the RNG seed, so every
  /// player on the same day sees the same board.
  static int dayNumber(DateTime date) {
    final today = DateTime.utc(
      date.toUtc().year,
      date.toUtc().month,
      date.toUtc().day,
    );
    return today.difference(epoch).inDays + 1;
  }

  /// Deterministic RNG seed for a given day number.
  static int seedForDay(int dayNumber) => dayNumber * 2654435761 & 0x7FFFFFFF;

  /// The date a day number stands for — [dayNumber] run backwards.
  static DateTime dateForDay(int dayNumber) =>
      epoch.add(Duration(days: dayNumber - 1));

  /// The ISO 8601 week number: weeks run Monday to Sunday, and week 1
  /// is the one holding the first Thursday of the year.
  static int isoWeek(DateTime date) {
    final d = date.toUtc();
    final day = DateTime.utc(d.year, d.month, d.day);
    // The Thursday inside a week decides which year that week belongs
    // to. That is the whole trick of ISO weeks: no week is ever split
    // between two years, so none is ever half a number.
    final thursday = day.add(Duration(days: 4 - day.weekday));
    final firstOfYear = DateTime.utc(thursday.year, 1, 1);
    return thursday.difference(firstOfYear).inDays ~/ 7 + 1;
  }

  /// The rule bending the daily for the week [dayNumber] falls in.
  ///
  /// Keyed off the day number rather than "today" so that a day and its
  /// modifier can never disagree: everything about a daily run comes
  /// from the same one number.
  static WeeklyModifier modifierForDay(int dayNumber) {
    final week = isoWeek(dateForDay(dayNumber));
    return WeeklyModifier.values[week % WeeklyModifier.values.length];
  }

  /// The daily board for a modifier, which only [WeeklyModifier.tinyBoard]
  /// changes.
  static int columnsFor(WeeklyModifier? modifier) =>
      modifier == WeeklyModifier.tinyBoard
      ? WeeklyModifier.tinyColumns
      : gridColumns;

  static int rowsFor(WeeklyModifier? modifier) =>
      modifier == WeeklyModifier.tinyBoard ? WeeklyModifier.tinyRows : gridRows;

  /// A streak survives this many days of not playing, per banked
  /// freeze. One freeze covers one missed day.
  static const int freezePerStreak = 7;

  /// How many freezes can be sitting in the bank at once. Low enough
  /// that a streak still has to be kept rather than bought: two weeks
  /// of playing buys two days of not.
  static const int maxFreezes = 2;

  /// Computes the new streak count given the last day the challenge was
  /// completed and today's date. The no-freeze reading of
  /// [nextStreakState], kept because most of the question is this
  /// simple.
  ///
  /// - Same day as last played: streak is unchanged (already counted).
  /// - Exactly one day after last played: streak continues (+1).
  /// - Any gap, or no previous play: streak restarts at 1.
  static int nextStreak({
    required String? lastPlayedKey,
    required int previousStreak,
    required DateTime today,
  }) => nextStreakState(
    lastPlayedKey: lastPlayedKey,
    previousStreak: previousStreak,
    freezes: 0,
    today: today,
  ).streak;

  /// The streak and the freeze bank after finishing today's daily.
  ///
  /// A missed day is only ever noticed the next time somebody plays, so
  /// this is where a freeze is spent: the gap is counted, and if the
  /// bank covers it the streak carries on as though the days had been
  /// played. Spending is automatic — a player who has to remember to
  /// use the thing that saves them has not been saved.
  static StreakOutcome nextStreakState({
    required String? lastPlayedKey,
    required int previousStreak,
    required int freezes,
    required DateTime today,
  }) {
    if (lastPlayedKey == dateKey(today)) {
      // Already counted today. A second run changes the score, not the
      // streak, and must not pay out a second freeze.
      return (
        streak: previousStreak,
        freezes: freezes,
        freezesSpent: 0,
        freezeEarned: false,
      );
    }

    final missed = missedDays(lastPlayedKey: lastPlayedKey, today: today);
    final covered = missed >= 0 && missed <= freezes;
    final spent = covered ? missed : 0;
    final streak = covered ? previousStreak + 1 : 1;

    var left = freezes - spent;
    // One per seven days kept, and only while there is room for it —
    // so the line on the card is never a lie about a freeze that was
    // quietly dropped.
    final earned = streak % freezePerStreak == 0 && left < maxFreezes;
    if (earned) left++;

    return (
      streak: streak,
      freezes: left,
      freezesSpent: spent,
      freezeEarned: earned,
    );
  }

  /// Days between the last completed daily and today that went
  /// unplayed: 0 for "played yesterday", 1 for one day skipped. -1
  /// when there is no streak to keep, or when the clock has gone
  /// backwards and the answer is not meaningful.
  static int missedDays({
    required String? lastPlayedKey,
    required DateTime today,
  }) {
    final last = _parseKey(lastPlayedKey);
    if (last == null) return -1;
    final d = today.toUtc();
    final gap = DateTime.utc(d.year, d.month, d.day).difference(last).inDays;
    return gap < 1 ? -1 : gap - 1;
  }

  static DateTime? _parseKey(String? key) {
    if (key == null) return null;
    final parts = key.split('-');
    if (parts.length != 3) return null;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return null;
    return DateTime.utc(y, m, d);
  }

  /// Whether the daily challenge has already been completed today.
  static bool playedToday({
    required String? lastPlayedKey,
    required DateTime today,
  }) {
    return lastPlayedKey == dateKey(today);
  }

  /// Points each filled square of the result bar stands for.
  static const pointsPerBarSquare = 50;
  static const _barSquares = 10;

  /// A ten-square bar for the shareable result: one filled square per
  /// [pointsPerBarSquare] points, shaded green, then yellow, then red as
  /// it fills, and the rest black. Read left to right it is Wordle-style:
  /// how far you got, at a glance, without spoiling anything.
  static String scoreBar(int score) {
    final filled = (score ~/ pointsPerBarSquare).clamp(0, _barSquares);
    return [
      for (var i = 0; i < _barSquares; i++)
        if (i >= filled)
          '⬛'
        else if (i < 5)
          '🟩'
        else if (i < 8)
          '🟨'
        else
          '🟥',
    ].join();
  }

  /// The text people paste after a daily run.
  static String resultText({
    required int dayNumber,
    required int score,
    required int apples,
    required int bestCombo,
    required int streak,
    WeeklyModifier? modifier,
  }) {
    final best = bestCombo > 1 ? ' · combo x$bestCombo' : '';
    final rule = modifier == null ? '' : ' · ${modifier.label}';
    return 'HISCORE Daily #$dayNumber 🐍$rule\n'
        '${scoreBar(score)}\n'
        '$score pts · $apples 🍎$best\n'
        'Streak $streak 🔥';
  }
}
