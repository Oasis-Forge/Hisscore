import 'package:flutter/material.dart';

import '../game/high_score_store.dart';
import '../game/quests.dart';
import '../game/run_standing.dart';
import '../game/snake_engine.dart';
import 'controls.dart';
import 'end_of_run.dart';
import 'second_chance.dart';
import 'theme.dart';
import 'unlocks.dart';

// ─── GameOverlay (paused / game-over) ───────────────────

class GameOverlay extends StatelessWidget {
  const GameOverlay({
    super.key,
    required this.phase,
    required this.engine,
    required this.won,
    required this.newHighScore,
    required this.isDailyRun,
    this.challengeCode,
    this.outcome,
    required this.dailyDayNumber,
    required this.dailyState,
    required this.onShare,
    required this.onResume,
    required this.onExitToMenu,
    this.highScore = 0,
    this.standing,
    this.quests = const [],
    this.onSecondChance,
    this.onSecondChanceExpired,
  });

  final GamePhase phase;
  final SnakeEngine engine;
  final bool won;
  final bool newHighScore;
  final bool isDailyRun;

  /// The code of a friend-challenge run, shown so it can be passed on.
  final String? challengeCode;

  /// What the run just finished paid out: XP, quests, a new level.
  final RunOutcome? outcome;
  final int dailyDayNumber;
  final DailyState dailyState;
  final VoidCallback onShare;
  final VoidCallback onResume;
  final VoidCallback onExitToMenu;

  /// The best on this device, for the bar the run is measured against.
  final int highScore;

  /// Where the run landed on a board, when one answered.
  final RunStanding? standing;

  /// Today's quests, so the ones this run moved can tick up.
  final List<Quest> quests;

  /// Set when this run could still be brought back. Null means the
  /// offer does not apply, and the card is the plain end of a run.
  final VoidCallback? onSecondChance;
  final VoidCallback? onSecondChanceExpired;

  @override
  Widget build(BuildContext context) {
    final isOver = phase == GamePhase.gameOver;
    final title = isOver ? (won ? 'YOU WIN' : 'GAME OVER') : 'PAUSED';

    return ColoredBox(
      color: RetroColors.screen.withValues(alpha: 0.9),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: RetroText.pixel(size: 16, color: RetroColors.amber),
                ),
                // Above everything else it is competing with, because
                // it is the only thing here with a clock on it.
                if (isOver && onSecondChance != null) ...[
                  const SizedBox(height: 16),
                  SecondChanceOffer(
                    onAccept: onSecondChance!,
                    onExpire: onSecondChanceExpired ?? () {},
                  ),
                ],
                if (isOver) ...[
                  const SizedBox(height: 14),
                  Text(
                    engine.score.toString().padLeft(5, '0'),
                    style: RetroText.pixel(
                      size: 18,
                      color: RetroColors.phosphor,
                    ),
                  ),
                  if (engine.revived) ...[
                    const SizedBox(height: 6),
                    const RevivedMark(),
                  ],
                  const SizedBox(height: 10),
                  ScoreBreakdown(engine: engine),
                  // Everything below is the answer to "was that any
                  // good, and what would be better" — the question the
                  // player is actually asking at this moment.
                  if (highScore > 0) ...[
                    const SizedBox(height: 14),
                    ScoreVsBest(score: engine.score, best: highScore),
                  ],
                  if (standing != null) ...[
                    const SizedBox(height: 12),
                    BoardStanding(standing: standing!),
                  ],
                  if (isDailyRun) ...[
                    const SizedBox(height: 10),
                    Text(
                      'DAILY #$dailyDayNumber  ·  STREAK ${dailyState.currentStreak}',
                      style: RetroText.pixel(
                        size: 8,
                        color: RetroColors.zenBlue,
                      ),
                    ),
                    // Named again on the way out: a score under a rule
                    // is only comparable to other scores under it.
                    if (engine.modifier != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        engine.modifier!.label,
                        style: RetroText.pixel(
                          size: 7,
                          color: RetroColors.amber,
                        ),
                      ),
                    ],
                  ],
                  if (challengeCode != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      'CHALLENGE $challengeCode',
                      style: RetroText.pixel(size: 8, color: RetroColors.amber),
                    ),
                  ],
                  if (outcome != null) ...[
                    const SizedBox(height: 14),
                    XpBar(outcome: outcome!),
                    QuestProgressList(outcome: outcome!, quests: quests),
                    const SizedBox(height: 10),
                    _ProgressLines(outcome: outcome!),
                  ],
                  if (newHighScore) ...[
                    const SizedBox(height: 12),
                    Text(
                      'NEW HISCORE',
                      style: RetroText.pixel(size: 11, color: RetroColors.food),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SecondaryArcadeButton(
                    label: 'SHARE SCORE',
                    color: RetroColors.zenBlue,
                    onPressed: onShare,
                  ),
                ],
                // Paused is the only moment a player has both the time
                // to read and a reason to care what a pickup does, so
                // the legend lives here rather than behind a menu tab.
                if (!isOver) ...[
                  const SizedBox(height: 18),
                  Text(
                    'PICKUPS',
                    style: RetroText.pixel(
                      size: 8,
                      color: RetroColors.amberDim,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const FoodLegend(detailed: true),
                ],
                const SizedBox(height: 22),
                ArcadeActionButton(
                  label: isOver ? 'PLAY AGAIN' : 'RESUME',
                  onPressed: onResume,
                ),
                const SizedBox(height: 12),
                SecondaryArcadeButton(
                  label: 'MENU',
                  color: RetroColors.amber,
                  onPressed: onExitToMenu,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Score breakdown on game-over ────────────────────

class ScoreBreakdown extends StatelessWidget {
  const ScoreBreakdown({super.key, required this.engine});

  final SnakeEngine engine;

  @override
  Widget build(BuildContext context) {
    final items = <BreakdownItem>[
      BreakdownItem('APPLES', engine.totalApplesEaten.toString()),
      if (engine.mode == GameMode.adventure)
        BreakdownItem('LEVEL', engine.level.toString()),
      if (engine.bestCombo > 1)
        BreakdownItem(
          'BEST COMBO',
          '×${(1.0 + (engine.bestCombo - 1) * 0.5).toStringAsFixed(1)}',
        ),
      if (engine.closeCalls > 0)
        BreakdownItem('CLOSE CALLS', engine.closeCalls.toString()),
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: 16),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                items[i].label,
                style: RetroText.pixel(size: 6, color: RetroColors.phosphorDim),
              ),
              const SizedBox(height: 2),
              Text(
                items[i].value,
                style: RetroText.pixel(size: 9, color: RetroColors.phosphor),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class BreakdownItem {
  const BreakdownItem(this.label, this.value);
  final String label;
  final String value;
}

// ─── Lifetime stats (ready screen) ──────────────────

class StatsRow extends StatelessWidget {
  const StatsRow({super.key, required this.stats});

  final GameStats stats;

  @override
  Widget build(BuildContext context) {
    final comboMult = stats.bestCombo <= 1
        ? 1.0
        : 1.0 + (stats.bestCombo - 1) * 0.5;
    final items = [
      BreakdownItem('GAMES', stats.gamesPlayed.toString()),
      BreakdownItem('APPLES', stats.totalApples.toString()),
      BreakdownItem('BEST COMBO', '×${comboMult.toStringAsFixed(1)}'),
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: 16),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                items[i].label,
                style: RetroText.pixel(size: 7, color: RetroColors.metal),
              ),
              const SizedBox(height: 2),
              Text(
                items[i].value,
                style: RetroText.pixel(size: 9, color: RetroColors.phosphorDim),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// "+N XP", each quest the run finished, and a level-up.
class _ProgressLines extends StatelessWidget {
  const _ProgressLines({required this.outcome});

  final RunOutcome outcome;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '+${outcome.xpGained} XP',
          style: RetroText.pixel(size: 8, color: RetroColors.phosphorHot),
        ),
        for (final quest in outcome.completedNow)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'QUEST DONE: ${quest.title}',
              textAlign: TextAlign.center,
              style: RetroText.pixel(size: 7, color: RetroColors.amber),
            ),
          ),
        if (outcome.leveledUp)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'LEVEL UP! LEVEL ${outcome.levelAfter}',
              style: RetroText.pixel(size: 10, color: RetroColors.amber),
            ),
          ),
        if (outcome.leveledUp)
          for (final unlock in unlocksBetween(
            outcome.levelBefore,
            outcome.levelAfter,
          ))
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'UNLOCKED: $unlock',
                style: RetroText.pixel(size: 8, color: RetroColors.phosphorHot),
              ),
            ),
      ],
    );
  }
}
