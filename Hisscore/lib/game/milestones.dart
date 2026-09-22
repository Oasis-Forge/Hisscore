import 'snake_engine.dart';

/// Everything a milestone can be measured against, gathered in one
/// place so that [milestonesEarned] can stay what it should be: a
/// function of where the player was and where they are, and nothing
/// else.
///
/// Every field only ever goes up, except [streak], which can fall back
/// to 1 — which is why the caller also keeps the ids it has already
/// paid for.
class MilestoneFacts {
  const MilestoneFacts({
    this.gamesPlayed = 0,
    this.totalApples = 0,
    this.bestCombo = 0,
    this.bestScore = 0,
    this.level = 1,
    this.streak = 0,
    this.powerUps = 0,
    this.bestCloseCalls = 0,
    this.challengesPlayed = 0,
    this.modesPlayed = const {},
  });

  final int gamesPlayed;
  final int totalApples;

  /// The longest combo ever reached, as a step count, not a multiplier.
  final int bestCombo;

  /// The best single-run score on this device.
  final int bestScore;
  final int level;

  /// The current daily streak, which is the only fact here that can go
  /// down.
  final int streak;
  final int powerUps;

  /// The most close calls steered out of in any one run.
  final int bestCloseCalls;

  /// Friends' challenge codes played to the end.
  final int challengesPlayed;
  final Set<GameMode> modesPlayed;
}

/// A local first, paid once.
///
/// Milestones are deliberately not quests: a quest is today's job and
/// resets, a milestone is something that happened to this player and
/// stays happened. They never leave the device — a [rank] is a private
/// label on the menu, not a name on a board, where only the Firestore
/// rules decide what a player may call themselves.
class Milestone {
  const Milestone({
    required this.id,
    required this.title,
    required this.blurb,
    required this.xp,
    required this.met,
    this.rank,
  });

  /// Stable across releases: it is what a paid-out milestone is
  /// remembered by, so renaming one must not re-pay it.
  final String id;

  final String title;

  /// What it took, in the player's words.
  final String blurb;
  final int xp;

  /// Whether the player has reached it.
  final bool Function(MilestoneFacts facts) met;

  /// A label the player carries on the menu afterwards, if this one
  /// grants one. The highest-paying rank earned is the one shown.
  final String? rank;

  /// Not const because each carries a closure, and a function literal
  /// is not a constant expression.
  static final List<Milestone> all = [
    Milestone(
      id: 'first-run',
      title: 'FIRST STEPS',
      blurb: 'Play your first game',
      xp: 25,
      met: (f) => f.gamesPlayed >= 1,
    ),
    Milestone(
      id: 'runs-10',
      title: 'REGULAR',
      blurb: 'Play 10 games',
      xp: 50,
      met: (f) => f.gamesPlayed >= 10,
    ),
    Milestone(
      id: 'runs-100',
      title: 'DEVOTED',
      blurb: 'Play 100 games',
      xp: 200,
      rank: 'DEVOTED',
      met: (f) => f.gamesPlayed >= 100,
    ),
    Milestone(
      id: 'apples-100',
      title: 'ORCHARD',
      blurb: 'Eat 100 apples',
      xp: 75,
      met: (f) => f.totalApples >= 100,
    ),
    Milestone(
      id: 'apples-1000',
      title: 'GLUTTON',
      blurb: 'Eat 1,000 apples',
      xp: 250,
      rank: 'GLUTTON',
      met: (f) => f.totalApples >= 1000,
    ),
    Milestone(
      id: 'powerup-first',
      title: 'CURIOUS',
      blurb: 'Take your first pickup',
      xp: 25,
      met: (f) => f.powerUps >= 1,
    ),
    Milestone(
      id: 'powerups-50',
      title: 'COLLECTOR',
      blurb: 'Take 50 pickups',
      xp: 100,
      met: (f) => f.powerUps >= 50,
    ),
    Milestone(
      id: 'combo-5',
      title: 'ON A ROLL',
      blurb: 'Reach a five-apple combo',
      xp: 50,
      met: (f) => f.bestCombo >= 5,
    ),
    Milestone(
      id: 'combo-10',
      title: 'UNSTOPPABLE',
      blurb: 'Reach a ten-apple combo',
      xp: 150,
      rank: 'UNSTOPPABLE',
      met: (f) => f.bestCombo >= 10,
    ),
    Milestone(
      id: 'score-500',
      title: 'WARMED UP',
      blurb: 'Score 500 in one run',
      xp: 50,
      met: (f) => f.bestScore >= 500,
    ),
    Milestone(
      id: 'score-1000',
      title: 'FOUR FIGURES',
      blurb: 'Score 1,000 in one run',
      xp: 100,
      met: (f) => f.bestScore >= 1000,
    ),
    Milestone(
      id: 'score-5000',
      title: 'HIGH ROLLER',
      blurb: 'Score 5,000 in one run',
      xp: 300,
      rank: 'HIGH ROLLER',
      met: (f) => f.bestScore >= 5000,
    ),
    Milestone(
      id: 'level-5',
      title: 'GETTING GOOD',
      blurb: 'Reach level 5',
      xp: 50,
      met: (f) => f.level >= 5,
    ),
    Milestone(
      id: 'level-10',
      title: 'VETERAN',
      blurb: 'Reach level 10',
      xp: 150,
      rank: 'VETERAN',
      met: (f) => f.level >= 10,
    ),
    Milestone(
      id: 'level-25',
      title: 'LEGEND',
      blurb: 'Reach level 25',
      xp: 400,
      rank: 'LEGEND',
      met: (f) => f.level >= 25,
    ),
    Milestone(
      id: 'streak-3',
      title: 'SHOWING UP',
      blurb: 'A three-day daily streak',
      xp: 50,
      met: (f) => f.streak >= 3,
    ),
    Milestone(
      id: 'streak-7',
      title: 'DEDICATED',
      blurb: 'A seven-day daily streak',
      xp: 150,
      rank: 'DEDICATED',
      met: (f) => f.streak >= 7,
    ),
    Milestone(
      id: 'streak-30',
      title: 'RELENTLESS',
      blurb: 'A thirty-day daily streak',
      xp: 500,
      rank: 'RELENTLESS',
      met: (f) => f.streak >= 30,
    ),
    Milestone(
      id: 'close-calls-5',
      title: 'TIGHTROPE',
      blurb: 'Steer out of five close calls in one run',
      xp: 100,
      rank: 'TIGHTROPE',
      met: (f) => f.bestCloseCalls >= 5,
    ),
    Milestone(
      id: 'every-mode',
      title: 'WELL ROUNDED',
      blurb: 'Play a run in every mode',
      xp: 200,
      met: (f) => f.modesPlayed.length >= GameMode.values.length,
    ),
    Milestone(
      id: 'challenge-played',
      title: 'RIVAL',
      blurb: "Finish a friend's challenge",
      xp: 100,
      met: (f) => f.challengesPlayed >= 1,
    ),
  ];

  static Milestone? byId(String id) {
    for (final m in all) {
      if (m.id == id) return m;
    }
    return null;
  }

  /// The label the player carries, given everything they have earned:
  /// the dearest rank among them, because that is the one that took
  /// the most doing.
  static String? rankFor(Set<String> earnedIds) {
    Milestone? best;
    for (final id in earnedIds) {
      final m = byId(id);
      if (m?.rank == null) continue;
      if (best == null || m!.xp > best.xp) best = m;
    }
    return best?.rank;
  }
}

/// The milestones [after] has reached that [before] had not.
///
/// Pure, and deliberately ignorant of what has already been paid for:
/// a streak can fall back and climb again, so the caller keeps the ids
/// it has settled and filters with them.
List<Milestone> milestonesEarned(MilestoneFacts before, MilestoneFacts after) =>
    [
      for (final milestone in Milestone.all)
        if (!milestone.met(before) && milestone.met(after)) milestone,
    ];
