import 'package:flutter_test/flutter_test.dart';
import 'package:hisscore/game/high_score_store.dart';
import 'package:hisscore/game/milestones.dart';
import 'package:hisscore/game/quests.dart';
import 'package:hisscore/game/snake_engine.dart';

/// Local firsts: paid once, kept forever, and never confused with the
/// quests that reset every morning.
void main() {
  Milestone byId(String id) {
    final m = Milestone.byId(id);
    expect(m, isNotNull, reason: 'no milestone called $id');
    return m!;
  }

  group('the list itself', () {
    test('is about twenty of them', () {
      expect(Milestone.all.length, greaterThanOrEqualTo(18));
    });

    test('every id is unique, because an id is what gets paid', () {
      final ids = Milestone.all.map((m) => m.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('every one says what it is and what it took', () {
      for (final m in Milestone.all) {
        expect(m.title, isNotEmpty, reason: m.id);
        expect(m.blurb, isNotEmpty, reason: m.id);
        expect(m.xp, greaterThan(0), reason: m.id);
      }
    });

    test('none is reached by a player who has done nothing', () {
      const nothing = MilestoneFacts();
      for (final m in Milestone.all) {
        expect(m.met(nothing), isFalse, reason: '${m.id} is free');
      }
    });
  });

  group('milestonesEarned', () {
    test('pays for what has just been reached', () {
      final earned = milestonesEarned(
        const MilestoneFacts(),
        const MilestoneFacts(gamesPlayed: 1),
      );
      expect(earned.map((m) => m.id), contains('first-run'));
    });

    test('and not for what was already true', () {
      final earned = milestonesEarned(
        const MilestoneFacts(gamesPlayed: 1),
        const MilestoneFacts(gamesPlayed: 2),
      );
      expect(earned, isEmpty);
    });

    test('a run can reach several at once', () {
      final earned = milestonesEarned(
        const MilestoneFacts(),
        const MilestoneFacts(gamesPlayed: 10, totalApples: 100, level: 5),
      );
      final ids = earned.map((m) => m.id).toSet();
      expect(ids, containsAll(['first-run', 'runs-10', 'apples-100']));
    });

    test('nothing changing pays nothing', () {
      const same = MilestoneFacts(gamesPlayed: 40, level: 6);
      expect(milestonesEarned(same, same), isEmpty);
    });

    test('every mode needs every mode', () {
      final short = milestonesEarned(
        const MilestoneFacts(),
        MilestoneFacts(
          modesPlayed: GameMode.values.toSet()..remove(GameMode.zen),
        ),
      );
      expect(short.map((m) => m.id), isNot(contains('every-mode')));

      final all = milestonesEarned(
        const MilestoneFacts(),
        MilestoneFacts(modesPlayed: GameMode.values.toSet()),
      );
      expect(all.map((m) => m.id), contains('every-mode'));
    });

    test('a streak that falls back can reach the same one twice', () {
      // Which is exactly why the caller keeps the ids it has settled:
      // this function answers "newly reached", not "not yet paid for".
      final first = milestonesEarned(
        const MilestoneFacts(streak: 2),
        const MilestoneFacts(streak: 3),
      );
      expect(first.map((m) => m.id), contains('streak-3'));

      final again = milestonesEarned(
        const MilestoneFacts(streak: 1),
        const MilestoneFacts(streak: 3),
      );
      expect(again.map((m) => m.id), contains('streak-3'));
    });
  });

  group('ranks', () {
    test('the dearest one earned is the one carried', () {
      final veteran = byId('level-10');
      final legend = byId('level-25');
      expect(
        Milestone.rankFor({veteran.id, legend.id}),
        legend.rank,
        reason: 'the one that took the most doing',
      );
    });

    test('a milestone without a rank grants none', () {
      expect(byId('first-run').rank, isNull);
      expect(Milestone.rankFor({'first-run'}), isNull);
    });

    test('an id from a future release is ignored, not crashed on', () {
      expect(Milestone.rankFor({'something-else-entirely'}), isNull);
    });
  });

  group('paying out', () {
    RunOutcome outcome({
      Set<String> milestones = const {},
      int xp = 100,
      int gained = 10,
    }) => RunOutcome(
      before: const PlayerProgress(),
      progress: PlayerProgress(xp: xp, milestones: milestones),
      xpGained: gained,
      completedNow: const [],
    );

    test('the XP lands on top of what the quests paid', () {
      final first = byId('first-run');
      final paid = outcome().withMilestones([first]);

      expect(paid.xpGained, 10 + first.xp);
      expect(paid.progress.xp, 100 + first.xp);
      expect(paid.milestonesEarned, [first]);
      expect(paid.progress.milestones, contains(first.id));
    });

    test('earning nothing changes nothing', () {
      final plain = outcome();
      expect(plain.withMilestones([]), same(plain));
    });

    test('what was already settled is kept', () {
      final paid = outcome(
        milestones: {'runs-10'},
      ).withMilestones([byId('first-run')]);
      expect(paid.progress.milestones, containsAll(['runs-10', 'first-run']));
    });
  });

  group('what a run counts for', () {
    SnakeEngine finished({
      GameMode mode = GameMode.classic,
      int apples = 3,
      int combo = 4,
      int powerUps = 2,
      int closeCalls = 1,
    }) {
      final game = SnakeEngine(mode: mode, random: null);
      game.totalApplesEaten = apples;
      game.bestCombo = combo;
      game.powerUpsCollected = powerUps;
      game.closeCalls = closeCalls;
      return game;
    }

    test('a run is folded into the stats the milestones read', () {
      final stats = GameStats();
      stats.record(finished());

      expect(stats.gamesPlayed, 1);
      expect(stats.totalApples, 3);
      expect(stats.bestCombo, 4);
      expect(stats.powerUps, 2);
      expect(stats.bestCloseCalls, 1);
      expect(stats.challengesPlayed, 0);
      expect(stats.modesPlayed, {GameMode.classic.name});
    });

    test('bests keep the best and totals keep adding', () {
      final stats = GameStats();
      stats.record(finished(combo: 9, closeCalls: 5, powerUps: 2));
      stats.record(finished(combo: 2, closeCalls: 1, powerUps: 3));

      expect(stats.bestCombo, 9, reason: 'a worse run does not undo a best');
      expect(stats.bestCloseCalls, 5);
      expect(stats.powerUps, 5, reason: 'these accumulate');
    });

    test('each mode played is remembered once', () {
      final stats = GameStats();
      for (final mode in GameMode.values) {
        stats.record(finished(mode: mode));
        stats.record(finished(mode: mode));
      }
      expect(stats.modesPlayed.length, GameMode.values.length);
    });

    test("a friend's code is counted only when it was one", () {
      final stats = GameStats();
      stats.record(finished());
      expect(stats.challengesPlayed, 0);
      stats.record(finished(), challenge: true);
      expect(stats.challengesPlayed, 1);
    });

    test('the new counts survive a round trip to disk', () {
      final stats = GameStats();
      stats.record(finished(mode: GameMode.hardcore), challenge: true);
      final back = GameStats.fromJson(stats.toJson());

      expect(back.powerUps, stats.powerUps);
      expect(back.bestCloseCalls, stats.bestCloseCalls);
      expect(back.challengesPlayed, 1);
      expect(back.modesPlayed, {GameMode.hardcore.name});
    });

    test('a save that predates all this reads as zero', () {
      final old = GameStats.fromJson(const {
        'gamesPlayed': 12,
        'totalApples': 40,
        'bestCombo': 3,
      });
      expect(old.gamesPlayed, 12);
      expect(old.powerUps, 0);
      expect(old.bestCloseCalls, 0);
      expect(old.challengesPlayed, 0);
      expect(old.modesPlayed, isEmpty);
    });
  });

  group('kept apart from quests', () {
    test('a new day drops the quests and keeps the milestones', () {
      const before = PlayerProgress(
        xp: 500,
        questDayKey: '2026-05-09',
        progress: {'q': 3},
        completed: {'q'},
        milestones: {'first-run', 'runs-10'},
      );

      final rolled = Quests.rolled(before, '2026-05-10');

      expect(rolled.progress, isEmpty, reason: "yesterday's job");
      expect(rolled.completed, isEmpty);
      expect(rolled.xp, 500);
      expect(rolled.milestones, {'first-run', 'runs-10'});
    });

    test('they survive a round trip to disk', () {
      const progress = PlayerProgress(xp: 90, milestones: {'combo-5'});
      expect(PlayerProgress.decode(progress.encode()).milestones, {'combo-5'});
    });

    test('a save that predates them reads as none', () {
      expect(PlayerProgress.decode('{"xp": 40}').milestones, isEmpty);
    });
  });
}
