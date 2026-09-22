import 'weekly_modifier.dart';

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

  /// Computes the new streak count given the last day the challenge was
  /// completed and today's date.
  ///
  /// - Same day as last played: streak is unchanged (already counted).
  /// - Exactly one day after last played: streak continues (+1).
  /// - Any gap, or no previous play: streak restarts at 1.
  static int nextStreak({
    required String? lastPlayedKey,
    required int previousStreak,
    required DateTime today,
  }) {
    final todayKey = dateKey(today);
    if (lastPlayedKey == todayKey) return previousStreak;
    final yesterday = today.toUtc().subtract(const Duration(days: 1));
    if (lastPlayedKey == dateKey(yesterday)) return previousStreak + 1;
    return 1;
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
