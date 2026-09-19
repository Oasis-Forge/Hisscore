import 'package:flutter/material.dart';

import '../game/quests.dart';
import 'theme.dart';

/// Player level with an XP bar, and today's quests with their progress.
class QuestsView extends StatelessWidget {
  const QuestsView({super.key, required this.progress, required this.quests});

  /// Already rolled over to today (see `Quests.rolled`).
  final PlayerProgress progress;
  final List<Quest> quests;

  @override
  Widget build(BuildContext context) {
    final within = Levels.within(progress.xp);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'LEVEL ${progress.level}',
          style: RetroText.pixel(size: 12, color: RetroColors.amber),
        ),
        const SizedBox(height: 6),
        _Bar(fraction: within.into / within.span, width: 200),
        const SizedBox(height: 4),
        Text(
          'XP ${within.into} / ${within.span}',
          style: RetroText.pixel(size: 7, color: RetroColors.metal),
        ),
        const SizedBox(height: 16),
        Text(
          "TODAY'S QUESTS",
          style: RetroText.pixel(size: 9, color: RetroColors.amberDim),
        ),
        const SizedBox(height: 8),
        for (final quest in quests)
          _QuestRow(
            quest: quest,
            have: progress.progress[quest.id] ?? 0,
            done: progress.completed.contains(quest.id),
          ),
      ],
    );
  }
}

class _QuestRow extends StatelessWidget {
  const _QuestRow({
    required this.quest,
    required this.have,
    required this.done,
  });

  final Quest quest;
  final int have;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final shown = have > quest.target ? quest.target : have;
    final color = done ? RetroColors.phosphorHot : RetroColors.phosphorDim;
    return Semantics(
      label:
          '${quest.title}, ${done ? 'done' : '$shown of ${quest.target}'}, '
          '${quest.xp} XP',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              done ? '[X] ${quest.title}' : quest.title,
              style: RetroText.pixel(size: 8, color: color),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Bar(fraction: shown / quest.target, width: 130, done: done),
                const SizedBox(width: 8),
                Text(
                  done ? '+${quest.xp} XP' : '$shown/${quest.target}',
                  style: RetroText.pixel(
                    size: 7,
                    color: done ? RetroColors.amber : RetroColors.metal,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.fraction, required this.width, this.done = false});

  final double fraction;
  final double width;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 7,
      decoration: BoxDecoration(
        border: Border.all(color: RetroColors.phosphorDim, width: 1),
        borderRadius: BorderRadius.circular(2),
      ),
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: fraction.clamp(0.0, 1.0),
        child: Container(
          color: done ? RetroColors.amber : RetroColors.phosphor,
        ),
      ),
    );
  }
}
