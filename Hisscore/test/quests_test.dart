import 'package:flutter_test/flutter_test.dart';
import 'package:hisscore/game/quests.dart';

RunSummary run({int apples = 0, int score = 0, int combo = 0, int power = 0}) =>
    RunSummary(apples: apples, score: score, bestCombo: combo, powerUps: power);

/// The first day whose quests include [kind], and that quest.
(int, Quest) _dayWith(QuestKind kind) {
  for (var d = 1; d < 400; d++) {
    for (final q in Quests.forDay(d)) {
      if (q.kind == kind) return (d, q);
    }
  }
  throw StateError('no day has $kind');
}

void main() {
  group('Levels', () {
    test('thresholds grow by 100 XP each level', () {
      expect(Levels.xpToReach(1), 0);
      expect(Levels.xpToReach(2), 100);
      expect(Levels.xpToReach(3), 300);
      expect(Levels.xpToReach(4), 600);
      expect(Levels.xpToReach(5), 1000);
    });

    test('levelFor is the highest level reached', () {
      expect(Levels.levelFor(0), 1);
      expect(Levels.levelFor(99), 1);
      expect(Levels.levelFor(100), 2);
      expect(Levels.levelFor(299), 2);
      expect(Levels.levelFor(300), 3);
      expect(Levels.levelFor(100000), greaterThan(20));
    });

    test('within reports progress through the current level', () {
      expect(Levels.within(0), (into: 0, span: 100));
      expect(Levels.within(150), (into: 50, span: 200));
      expect(Levels.within(300), (into: 0, span: 300));
    });
  });

  group('forDay', () {
    test('is the same for everyone on a day and differs across days', () {
      final a = Quests.forDay(262).map((q) => q.id).toList();
      expect(Quests.forDay(262).map((q) => q.id).toList(), a);
      final other = {
        for (var d = 1; d <= 30; d++) Quests.forDay(d).map((q) => q.id).join(),
      };
      expect(other.length, greaterThan(20));
    });

    test('is three different kinds, one at each difficulty, easiest first', () {
      for (var day = 1; day <= 200; day++) {
        final quests = Quests.forDay(day);
        expect(quests, hasLength(Quests.perDay));
        expect(quests.map((q) => q.kind).toSet(), hasLength(3), reason: '$day');
        expect(quests.map((q) => q.tier).toList(), [0, 1, 2], reason: '$day');
        expect(quests.map((q) => q.id).toSet(), hasLength(3));
      }
    });

    test('harder tiers ask for more and pay more', () {
      for (final kind in QuestKind.values) {
        expect(kind.targets, orderedEquals([...kind.targets]..sort()));
        expect(kind.rewards, orderedEquals([...kind.rewards]..sort()));
      }
    });
  });

  group('apply', () {
    const day = 262;
    const key = '2026-09-19';
    final quests = Quests.forDay(day);

    // A run that satisfies nothing much, so play XP is easy to reason about.
    test('a run pays play XP: an apple is 1, every 20 points 1 more', () {
      final out = Quests.apply(
        const PlayerProgress(),
        run(apples: 4, score: 45),
        dayNumber: day,
        dayKey: key,
      );
      expect(
        out.progress.xp - out.completedNow.fold<int>(0, (s, q) => s + q.xp),
        4 + 2,
      );
    });

    test('accumulating quests add up across runs', () {
      final (d, quest) = _dayWith(QuestKind.eatApples);
      var progress = const PlayerProgress();
      progress = Quests.apply(
        progress,
        run(apples: quest.target - 1),
        dayNumber: d,
        dayKey: key,
      ).progress;
      expect(progress.completed, isNot(contains(quest.id)));
      final out = Quests.apply(
        progress,
        run(apples: 1),
        dayNumber: d,
        dayKey: key,
      );
      expect(out.completedNow.map((q) => q.id), contains(quest.id));
    });

    test('single-run quests keep the best run, not the total', () {
      for (final kind in [QuestKind.scoreInRun, QuestKind.reachCombo]) {
        final (d, quest) = _dayWith(kind);
        final almost = kind == QuestKind.scoreInRun
            ? run(score: quest.target - 1)
            : run(combo: quest.target - 1);
        var progress = const PlayerProgress();
        for (var i = 0; i < 3; i++) {
          progress = Quests.apply(
            progress,
            almost,
            dayNumber: d,
            dayKey: key,
          ).progress;
        }
        // Three near-misses do not add up to a hit.
        expect(progress.completed, isNot(contains(quest.id)), reason: '$kind');
        expect(progress.progress[quest.id], quest.target - 1);
        final hit = Quests.apply(
          progress,
          kind == QuestKind.scoreInRun
              ? run(score: quest.target)
              : run(combo: quest.target),
          dayNumber: d,
          dayKey: key,
        );
        expect(hit.completedNow.map((q) => q.id), contains(quest.id));
      }
    });

    test('a quest pays out once and reports itself once', () {
      final big = run(apples: 99, score: 9999, combo: 9, power: 9);
      final first = Quests.apply(
        const PlayerProgress(),
        big,
        dayNumber: day,
        dayKey: key,
      );
      expect(
        first.completedNow.map((q) => q.id).toSet(),
        quests.map((q) => q.id).toSet(),
      );
      final second = Quests.apply(
        first.progress,
        big,
        dayNumber: day,
        dayKey: key,
      );
      expect(second.completedNow, isEmpty);
      expect(second.xpGained, big.xp);
    });

    test('completing quests adds their XP on top of the run XP', () {
      final big = run(apples: 99, score: 9999, combo: 9, power: 9);
      final out = Quests.apply(
        const PlayerProgress(),
        big,
        dayNumber: day,
        dayKey: key,
      );
      final bonus = quests.fold<int>(0, (s, q) => s + q.xp);
      expect(out.xpGained, big.xp + bonus);
      expect(out.progress.xp, out.xpGained);
    });

    test('a new day drops quest progress but keeps XP', () {
      final today = Quests.apply(
        const PlayerProgress(),
        run(apples: 99, score: 9999, combo: 9, power: 9),
        dayNumber: day,
        dayKey: key,
      ).progress;
      final rolled = Quests.rolled(today, '2026-09-20');
      expect(rolled.xp, today.xp);
      expect(rolled.progress, isEmpty);
      expect(rolled.completed, isEmpty);
      expect(Quests.rolled(today, key), same(today));
    });

    test('reports a level-up', () {
      final out = Quests.apply(
        const PlayerProgress(xp: 95),
        run(apples: 10),
        dayNumber: day,
        dayKey: key,
      );
      expect(out.levelBefore, 1);
      expect(out.levelAfter, greaterThanOrEqualTo(2));
      expect(out.leveledUp, isTrue);
    });
  });

  group('PlayerProgress json', () {
    test('round trips', () {
      const p = PlayerProgress(
        xp: 420,
        questDayKey: '2026-09-19',
        progress: {'eatApples-20': 12},
        completed: {'playRuns-2'},
      );
      final back = PlayerProgress.decode(p.encode());
      expect(back.xp, 420);
      expect(back.questDayKey, '2026-09-19');
      expect(back.progress, {'eatApples-20': 12});
      expect(back.completed, {'playRuns-2'});
    });

    test('bad or missing data decodes to a fresh state', () {
      expect(PlayerProgress.decode(null).xp, 0);
      expect(PlayerProgress.decode('not json').xp, 0);
      expect(PlayerProgress.decode('{"xp": "x"}').xp, 0);
    });
  });

  test('a run that ate nothing does not count as a played run', () {
    final (d, quest) = _dayWith(QuestKind.playRuns);
    var progress = const PlayerProgress();
    for (var i = 0; i < 10; i++) {
      progress = Quests.apply(
        progress,
        run(),
        dayNumber: d,
        dayKey: '2026-09-19',
      ).progress;
    }
    expect(progress.completed, isNot(contains(quest.id)));
    expect(progress.progress[quest.id], 0);
  });
}
