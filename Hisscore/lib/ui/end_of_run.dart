import 'package:flutter/material.dart';

import '../game/quests.dart';
import '../game/run_standing.dart';
import 'theme.dart';

/// How long the bars on the end screen take to fill.
///
/// Slow enough to be a movement rather than a redraw, quick enough that
/// PLAY AGAIN is never waiting on it — the animation is decoration, and
/// the button works from the first frame.
const endOfRunFill = Duration(milliseconds: 650);

/// This run's score against the best on this device.
///
/// A number next to a number tells a player very little; a bar that
/// stops just short of the line tells them how close they came without
/// doing any arithmetic.
class ScoreVsBest extends StatelessWidget {
  const ScoreVsBest({super.key, required this.score, required this.best});

  final int score;
  final int best;

  @override
  Widget build(BuildContext context) {
    // A run that beat the best fills the bar; there is nothing left to
    // chase, and the NEW HISCORE line says the rest.
    final beat = score >= best;
    final fraction = best <= 0 ? 1.0 : (score / best).clamp(0.0, 1.0);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _BarRow(
          label: beat ? 'BEST' : 'VS BEST',
          trailing: beat ? score.toString() : '$score / $best',
          fraction: fraction,
          color: beat ? RetroColors.food : RetroColors.phosphor,
        ),
        if (!beat) ...[
          const SizedBox(height: 4),
          Text(
            '${best - score} SHORT',
            style: RetroText.pixel(size: 7, color: RetroColors.phosphorDim),
          ),
        ],
      ],
    );
  }
}

/// This run against the run the friend who sent the challenge set.
///
/// The same bar as [ScoreVsBest], for the same reason: the interesting
/// question is not "what did each of us score" but "how close was it",
/// and a bar answers that without the player doing arithmetic. The
/// verdict is said in words underneath, because that is the part they
/// will repeat to the person they were racing.
class HeadToHead extends StatelessWidget {
  const HeadToHead({
    super.key,
    required this.yours,
    required this.theirs,
    required this.name,
  });

  final int yours;
  final int theirs;

  /// Their display name. May be empty — a link from someone who never
  /// chose one is still a race.
  final String name;

  @override
  Widget build(BuildContext context) {
    final won = yours > theirs;
    final drew = yours == theirs;
    final them = name.isEmpty ? 'THEM' : name;
    final fraction = theirs <= 0 ? 1.0 : (yours / theirs).clamp(0.0, 1.0);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _BarRow(
          label: 'VS $them',
          trailing: '$yours / $theirs',
          fraction: fraction,
          color: won ? RetroColors.food : RetroColors.phosphor,
        ),
        const SizedBox(height: 4),
        Text(
          won
              ? 'YOU BEAT $them'
              : drew
              ? 'DEAD HEAT'
              : '${theirs - yours} SHORT OF $them',
          style: RetroText.pixel(
            size: 7,
            color: won ? RetroColors.food : RetroColors.phosphorDim,
          ),
        ),
      ],
    );
  }
}

/// What greed came to: what was banked against what was still in the
/// pot when the run ended.
///
/// The lost half is the whole reason this is on the card. Banking is
/// already obvious while it happens — a sound, a number, a jump in the
/// score — but the cost of holding on is invisible, because it is a
/// thing that quietly fails to be added. Written down at the end, one
/// run teaches what the mechanic is asking.
class GreedResult extends StatelessWidget {
  const GreedResult({super.key, required this.banked, required this.lost});

  final int banked;

  /// Still in the pot when the run ended, and therefore gone.
  final int lost;

  @override
  Widget build(BuildContext context) {
    final total = banked + lost;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _BarRow(
          label: 'BANKED',
          trailing: '$banked / $total',
          fraction: total <= 0 ? 0.0 : banked / total,
          color: RetroColors.bankOrange,
        ),
        const SizedBox(height: 4),
        Text(
          lost > 0 ? '$lost LEFT IN THE POT' : 'NOTHING LEFT BEHIND',
          style: RetroText.pixel(
            size: 7,
            color: lost > 0 ? RetroColors.phosphorDim : RetroColors.bankOrange,
          ),
        ),
      ],
    );
  }
}

/// The XP bar, filling from where the player was to where they are.
class XpBar extends StatelessWidget {
  const XpBar({super.key, required this.outcome});

  final RunOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final after = Levels.within(outcome.progress.xp);
    // A level-up mid-run would make the bar run backwards, so it starts
    // from empty instead of from a position in the old level.
    final from = outcome.leveledUp
        ? 0.0
        : Levels.within(outcome.before.xp).into /
              Levels.within(outcome.before.xp).span;
    return _BarRow(
      label: 'LVL ${outcome.progress.level}',
      trailing: '${after.into} / ${after.span} XP',
      fraction: after.span <= 0 ? 1.0 : after.into / after.span,
      from: from,
      color: RetroColors.amber,
    );
  }
}

/// Today's quests, each ticking from where it was to where it is.
class QuestProgressList extends StatelessWidget {
  const QuestProgressList({
    super.key,
    required this.outcome,
    required this.quests,
  });

  final RunOutcome outcome;
  final List<Quest> quests;

  @override
  Widget build(BuildContext context) {
    final moved = [
      for (final quest in quests)
        if (outcome.progressAfter(quest) > outcome.progressBefore(quest)) quest,
    ];
    // A run that moved nothing gets no list: the screen is for what
    // just happened, not a standing report.
    if (moved.isEmpty) return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final quest in moved)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: _QuestRow(quest: quest, outcome: outcome),
          ),
      ],
    );
  }
}

class _QuestRow extends StatelessWidget {
  const _QuestRow({required this.quest, required this.outcome});

  final Quest quest;
  final RunOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final before = outcome.progressBefore(quest).clamp(0, quest.target);
    final after = outcome.progressAfter(quest).clamp(0, quest.target);
    final done = after >= quest.target;
    return _BarRow(
      label: quest.title,
      trailing: '$after / ${quest.target}',
      fraction: after / quest.target,
      from: before / quest.target,
      color: done ? RetroColors.phosphorHot : RetroColors.amberDim,
      labelSize: 6,
    );
  }
}

/// "12 POINTS BEHIND #8 ON THE DAILY" — the next target, named.
class BoardStanding extends StatelessWidget {
  const BoardStanding({super.key, required this.standing});

  final RunStanding standing;

  @override
  Widget build(BuildContext context) {
    return Text(
      standing.line,
      textAlign: TextAlign.center,
      style: RetroText.pixel(
        size: 8,
        color: standing.isTop ? RetroColors.amber : RetroColors.zenBlue,
      ),
    );
  }
}

/// A labelled bar that grows into place: label and value on one line,
/// the bar under it.
class _BarRow extends StatelessWidget {
  const _BarRow({
    required this.label,
    required this.trailing,
    required this.fraction,
    required this.color,
    this.from = 0,
    this.labelSize = 7,
  });

  final String label;
  final String trailing;

  /// Where the bar ends up, 0 to 1.
  final double fraction;

  /// Where it starts from, so a bar can animate the part this run added
  /// rather than filling from nothing every time.
  final double from;

  final Color color;
  final double labelSize;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: RetroText.pixel(size: labelSize, color: color),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                trailing,
                style: RetroText.pixel(
                  size: labelSize,
                  color: RetroColors.phosphorDim,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          _Bar(from: from, to: fraction, color: color),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.from, required this.to, required this.color});

  final double from;
  final double to;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      // Without a width the container shrink-wraps the filled part and
      // the empty remainder disappears, so a bar at 1% reads as a
      // speck rather than a bar that has barely started.
      width: double.infinity,
      height: 6,
      decoration: BoxDecoration(
        color: RetroColors.voidBg,
        border: Border.all(color: RetroColors.phosphorDim, width: 1),
      ),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: from.clamp(0.0, 1.0), end: to.clamp(0.0, 1.0)),
        duration: endOfRunFill,
        curve: Curves.easeOutCubic,
        builder: (context, value, _) => FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: value,
          child: ColoredBox(color: color),
        ),
      ),
    );
  }
}
