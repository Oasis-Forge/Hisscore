import 'dart:convert';
import 'dart:math';

import 'daily_challenge.dart';

/// What a quest asks for.
enum QuestKind {
  /// Eat apples, across as many runs as it takes today.
  eatApples,

  /// Reach a score in a single run.
  scoreInRun,

  /// Reach a combo in a single run.
  reachCombo,

  /// Pick up power-ups (anything but an apple), across runs today.
  collectPowerUps,

  /// Play runs.
  playRuns;

  /// Whether progress adds up across runs (true) or is the best single run
  /// (false).
  bool get accumulates => switch (this) {
    QuestKind.eatApples ||
    QuestKind.collectPowerUps ||
    QuestKind.playRuns => true,
    QuestKind.scoreInRun || QuestKind.reachCombo => false,
  };

  /// The target for each of the three difficulty tiers, easiest first.
  List<int> get targets => switch (this) {
    QuestKind.eatApples => const [10, 20, 35],
    QuestKind.scoreInRun => const [150, 300, 500],
    QuestKind.reachCombo => const [3, 4, 5],
    QuestKind.collectPowerUps => const [2, 4, 6],
    QuestKind.playRuns => const [2, 3, 5],
  };

  /// XP for finishing the quest at each tier.
  List<int> get rewards => switch (this) {
    QuestKind.playRuns => const [20, 30, 50],
    _ => const [30, 50, 80],
  };
}

/// One quest for one day.
class Quest {
  const Quest({required this.kind, required this.tier});

  final QuestKind kind;

  /// 0 easy, 1 medium, 2 hard.
  final int tier;

  int get target => kind.targets[tier];
  int get xp => kind.rewards[tier];

  /// Stable key for storing progress, e.g. `eatApples-20`.
  String get id => '${kind.name}-$target';

  String get title => switch (kind) {
    QuestKind.eatApples => 'EAT $target APPLES',
    QuestKind.scoreInRun => 'SCORE $target IN ONE RUN',
    QuestKind.reachCombo => 'REACH COMBO x$target',
    QuestKind.collectPowerUps => 'GRAB $target POWER-UPS',
    QuestKind.playRuns => 'PLAY $target RUNS',
  };
}

/// What one finished run contributed, as far as quests care.
class RunSummary {
  const RunSummary({
    required this.apples,
    required this.score,
    required this.bestCombo,
    required this.powerUps,
    this.closeCalls = 0,
  });

  final int apples;
  final int score;
  final int bestCombo;
  final int powerUps;

  /// Scrapes the grace tick let the player steer out of. Pays no XP of
  /// its own — the points already landed — but milestones count it.
  final int closeCalls;

  /// XP for playing, before any quest bonus: an apple is worth 1, and
  /// every 20 points on top of that is worth 1.
  int get xp => apples + score ~/ 20;
}

/// The player's long-term progress and today's quest state.
class PlayerProgress {
  const PlayerProgress({
    this.xp = 0,
    this.questDayKey,
    this.progress = const {},
    this.completed = const {},
  });

  final int xp;

  /// The day the quest state below belongs to (see [DailyChallenge.dateKey]).
  final String? questDayKey;

  /// Progress per quest id, capped at the target when shown.
  final Map<String, int> progress;

  /// Quest ids finished today.
  final Set<String> completed;

  int get level => Levels.levelFor(xp);

  Map<String, dynamic> toJson() => {
    'xp': xp,
    'questDayKey': questDayKey,
    'progress': progress,
    'completed': completed.toList(),
  };

  factory PlayerProgress.fromJson(Map<String, dynamic> json) => PlayerProgress(
    xp: json['xp'] as int? ?? 0,
    questDayKey: json['questDayKey'] as String?,
    progress: {
      for (final e in (json['progress'] as Map? ?? {}).entries)
        e.key as String: e.value as int,
    },
    completed: {
      for (final id in (json['completed'] as List? ?? [])) id as String,
    },
  );

  String encode() => jsonEncode(toJson());

  static PlayerProgress decode(String? raw) {
    if (raw == null) return const PlayerProgress();
    try {
      return PlayerProgress.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const PlayerProgress();
    }
  }
}

/// What applying a run changed.
class RunOutcome {
  const RunOutcome({
    required this.progress,
    required this.xpGained,
    required this.completedNow,
    required this.levelBefore,
  });

  final PlayerProgress progress;

  /// Total XP from this run: play XP plus quest bonuses.
  final int xpGained;

  /// Quests this run finished.
  final List<Quest> completedNow;

  final int levelBefore;

  int get levelAfter => progress.level;
  bool get leveledUp => levelAfter > levelBefore;
}

/// Player levels: level 1 at 0 XP, then each level costs 100 XP more than
/// the last (level 2 at 100, 3 at 300, 4 at 600, 5 at 1000...).
abstract final class Levels {
  static int xpToReach(int level) => 50 * level * (level - 1);

  static int levelFor(int xp) {
    var level = 1;
    while (xpToReach(level + 1) <= xp) {
      level++;
    }
    return level;
  }

  /// XP earned inside the current level, and the size of that level.
  static ({int into, int span}) within(int xp) {
    final level = levelFor(xp);
    final start = xpToReach(level);
    return (into: xp - start, span: xpToReach(level + 1) - start);
  }
}

abstract final class Quests {
  static const perDay = 3;

  /// Today's quests. Everyone gets the same three for a given day: three
  /// different kinds, one at each difficulty, in a shuffled order.
  static List<Quest> forDay(int dayNumber) {
    final random = Random(DailyChallenge.seedForDay(dayNumber) ^ 0x5EED);
    final kinds = QuestKind.values.toList()..shuffle(random);
    final tiers = [0, 1, 2]..shuffle(random);
    return [
      for (var i = 0; i < perDay; i++) Quest(kind: kinds[i], tier: tiers[i]),
    ]..sort((a, b) => a.tier.compareTo(b.tier));
  }

  /// [progress], rolled over to [dayKey]: yesterday's quest progress is
  /// dropped, XP stays.
  static PlayerProgress rolled(PlayerProgress progress, String dayKey) {
    if (progress.questDayKey == dayKey) return progress;
    return PlayerProgress(xp: progress.xp, questDayKey: dayKey);
  }

  /// Applies a finished [run] to [before] for the day [dayNumber] /
  /// [dayKey]: updates quest progress, pays out XP for the run and any
  /// quests it completed.
  static RunOutcome apply(
    PlayerProgress before,
    RunSummary run, {
    required int dayNumber,
    required String dayKey,
  }) {
    final start = rolled(before, dayKey);
    final progress = Map<String, int>.of(start.progress);
    final completed = Set<String>.of(start.completed);
    final completedNow = <Quest>[];

    for (final quest in forDay(dayNumber)) {
      final have = progress[quest.id] ?? 0;
      final value = switch (quest.kind) {
        QuestKind.eatApples => run.apples,
        QuestKind.scoreInRun => run.score,
        QuestKind.reachCombo => run.bestCombo,
        QuestKind.collectPowerUps => run.powerUps,
        // A run only counts if it ate something, so crashing on purpose
        // five times does not finish "play 5 runs".
        QuestKind.playRuns => run.apples > 0 ? 1 : 0,
      };
      final next = quest.kind.accumulates ? have + value : max(have, value);
      progress[quest.id] = next;
      if (next >= quest.target && completed.add(quest.id)) {
        completedNow.add(quest);
      }
    }

    final gained =
        run.xp + completedNow.fold<int>(0, (sum, quest) => sum + quest.xp);
    return RunOutcome(
      progress: PlayerProgress(
        xp: start.xp + gained,
        questDayKey: dayKey,
        progress: progress,
        completed: completed,
      ),
      xpGained: gained,
      completedNow: completedNow,
      levelBefore: start.level,
    );
  }
}
