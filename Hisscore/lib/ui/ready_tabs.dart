import 'package:flutter/material.dart';

import '../game/daily_challenge.dart';
import '../game/high_score_store.dart';
import '../game/online_scores.dart';
import '../game/quests.dart';
import '../game/snake_engine.dart';
import 'controls.dart';
import 'game_overlay.dart';
import 'online_board.dart';
import 'quests_view.dart';
import 'snake_skin.dart';
import 'theme.dart';

// ─── Ready screen tabs ──────────────────────────────

/// The ready screen used to stack modes, legend, stats and scores in one
/// column, which left everything at 5–6px on a phone. One tab at a time
/// buys the room to set type at a readable size.
enum ReadyTab {
  modes('MODES'),
  how('HOW'),
  stats('STATS'),
  look('LOOK');

  const ReadyTab(this.label);
  final String label;
}

class ReadyTabBar extends StatelessWidget {
  const ReadyTabBar({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  static const _tabFade = Duration(milliseconds: 200);

  final ReadyTab selected;
  final ValueChanged<ReadyTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final tab in ReadyTab.values) ...[
          if (tab != ReadyTab.values.first) const SizedBox(width: 8),
          GestureDetector(
            onTap: () => onChanged(tab),
            child: AnimatedContainer(
              duration: _tabFade,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: tab == selected
                    ? RetroColors.phosphor
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: tab == selected
                      ? RetroColors.phosphor
                      : RetroColors.phosphorDim,
                  width: 1.5,
                ),
              ),
              // The label fades with the fill. Switching it instantly
              // would leave dark text on a still-dark chip for the
              // length of the fade.
              child: AnimatedDefaultTextStyle(
                duration: _tabFade,
                style: RetroText.pixel(
                  size: 8,
                  color: tab == selected
                      ? RetroColors.cabinet
                      : RetroColors.phosphorDim,
                ),
                child: Text(tab.label),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class ReadyModesTab extends StatelessWidget {
  const ReadyModesTab({
    super.key,
    required this.selectedMode,
    required this.onModeChanged,
    required this.dailyDayNumber,
    required this.dailyState,
    required this.playedDailyToday,
    required this.onStartDaily,
    required this.onNewChallenge,
    required this.onEnterCode,
    required this.questSummary,
    required this.onOpenQuests,
  });

  final GameMode selectedMode;
  final ValueChanged<GameMode> onModeChanged;
  final int dailyDayNumber;
  final DailyState dailyState;
  final bool playedDailyToday;
  final VoidCallback onStartDaily;

  /// Start a fresh seeded game in the selected mode, to share as a code.
  final VoidCallback onNewChallenge;

  /// Type in a friend's code and play their game.
  final VoidCallback onEnterCode;

  /// One line on today's quests, e.g. `QUESTS 1/3  ·  LVL 2`.
  final String questSummary;

  /// Jump to the quests page.
  final VoidCallback onOpenQuests;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ModeSelector(selected: selectedMode, onChanged: onModeChanged),
        const SizedBox(height: 18),
        DailyChallengeCard(
          dayNumber: dailyDayNumber,
          dailyState: dailyState,
          playedToday: playedDailyToday,
          onStart: onStartDaily,
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SecondaryArcadeButton(
              label: 'CHALLENGE',
              color: RetroColors.amber,
              onPressed: onNewChallenge,
            ),
            const SizedBox(width: 10),
            SecondaryArcadeButton(
              label: 'ENTER CODE',
              color: RetroColors.zenBlue,
              onPressed: onEnterCode,
            ),
          ],
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: onOpenQuests,
          child: Text(
            questSummary,
            style: RetroText.pixel(size: 7, color: RetroColors.amber),
          ),
        ),
      ],
    );
  }
}

class ReadyHowTab extends StatelessWidget {
  const ReadyHowTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'PICKUPS',
          style: RetroText.pixel(size: 9, color: RetroColors.amberDim),
        ),
        const SizedBox(height: 10),
        const FoodLegend(detailed: true),
        const SizedBox(height: 18),
        Text(
          'CONTROLS',
          style: RetroText.pixel(size: 9, color: RetroColors.amberDim),
        ),
        const SizedBox(height: 10),
        for (final line in const [
          'SWIPE OR DRAG TO TURN',
          'ARROWS / WASD',
          'SPACE: PAUSE  ·  M: MENU',
        ])
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text(
              line,
              textAlign: TextAlign.center,
              style: RetroText.pixel(size: 7, color: RetroColors.metal),
            ),
          ),
      ],
    );
  }
}

/// Which page of the STATS tab is showing.
enum StatsView {
  quests('QUESTS'),
  local('LOCAL'),
  daily('TODAY'),
  allTime('ALL-TIME');

  const StatsView(this.label);
  final String label;

  /// The global boards need a backend; the others always work.
  bool get needsOnline => this == daily || this == allTime;
}

class ReadyStatsTab extends StatelessWidget {
  const ReadyStatsTab({
    super.key,
    required this.stats,
    required this.topScores,
    required this.dailyState,
    this.view = StatsView.local,
    this.onViewChanged,
    this.progress = const PlayerProgress(),
    this.quests = const [],
    this.online = const NoopOnlineScoreBoard(),
    this.dailyDayNumber = 1,
    this.mode = GameMode.classic,
    this.playerName = '',
    this.onEditName,
  });

  final GameStats stats;
  final List<ScoreEntry> topScores;
  final DailyState dailyState;

  final StatsView view;
  final ValueChanged<StatsView>? onViewChanged;

  /// Level, XP and today's quest state (already rolled over to today).
  final PlayerProgress progress;
  final List<Quest> quests;

  /// The global boards. When it is not available only the views that work
  /// offline are offered.
  final OnlineScoreBoard online;
  final int dailyDayNumber;

  /// The mode whose all-time board is shown.
  final GameMode mode;
  final String playerName;
  final VoidCallback? onEditName;

  @override
  Widget build(BuildContext context) {
    final views = [
      for (final v in StatsView.values)
        if (!v.needsOnline || online.available) v,
    ];
    final current = views.contains(view) ? view : StatsView.local;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final v in views) ...[
              if (v != views.first) const SizedBox(width: 10),
              GestureDetector(
                onTap: () => onViewChanged?.call(v),
                child: Text(
                  v.label,
                  style:
                      RetroText.pixel(
                        size: 8,
                        color: v == current
                            ? RetroColors.phosphorHot
                            : RetroColors.phosphorDim,
                      ).copyWith(
                        decoration: v == current
                            ? TextDecoration.underline
                            : null,
                        decorationColor: RetroColors.phosphorHot,
                      ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        switch (current) {
          StatsView.quests => QuestsView(progress: progress, quests: quests),
          StatsView.local => _local(),
          StatsView.daily => OnlineBoardView(
            scores: online,
            board: BoardId.daily(dailyDayNumber),
          ),
          StatsView.allTime => OnlineBoardView(
            scores: online,
            board: BoardId.allTime(mode),
          ),
        },
        if (current.needsOnline) ...[
          const SizedBox(height: 4),
          Text(
            current == StatsView.daily ? 'DAILY #$dailyDayNumber' : mode.label,
            style: RetroText.pixel(size: 7, color: RetroColors.metal),
          ),
        ],
        if (online.available) ...[
          const SizedBox(height: 12),
          GestureDetector(
            onTap: onEditName,
            child: Text(
              'YOU: $playerName  [EDIT]',
              style: RetroText.pixel(size: 7, color: RetroColors.zenBlue),
            ),
          ),
        ],
      ],
    );
  }

  Widget _local() {
    if (stats.gamesPlayed == 0 && topScores.isEmpty) {
      return Text(
        'NO RUNS YET',
        style: RetroText.pixel(size: 8, color: RetroColors.metal),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (stats.gamesPlayed > 0) ...[
          StatsRow(stats: stats),
          const SizedBox(height: 16),
        ],
        if (dailyState.bestStreak > 0) ...[
          Text(
            'BEST STREAK ${dailyState.bestStreak} DAY'
            '${dailyState.bestStreak == 1 ? '' : 'S'}',
            style: RetroText.pixel(size: 7, color: RetroColors.zenBlue),
          ),
          const SizedBox(height: 16),
        ],
        if (topScores.isNotEmpty) TopScoresList(scores: topScores),
      ],
    );
  }
}

// ─── Daily challenge card (ready screen) ─────────────

class DailyChallengeCard extends StatelessWidget {
  const DailyChallengeCard({
    super.key,
    required this.dayNumber,
    required this.dailyState,
    required this.playedToday,
    required this.onStart,
  });

  final int dayNumber;
  final DailyState dailyState;
  final bool playedToday;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    // Derived from the day rather than passed in, so the rule named on
    // the card and the rule the run is played under cannot drift apart.
    // It is named before the run, not sprung on the player once they
    // are in it: a modifier is a reason to press the button.
    final modifier = DailyChallenge.modifierForDay(dayNumber);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: RetroColors.zenBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: RetroColors.zenBlue.withValues(alpha: 0.5),
          width: 1.2,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'DAILY CHALLENGE #$dayNumber',
            style: RetroText.pixel(size: 8, color: RetroColors.zenBlue),
          ),
          const SizedBox(height: 6),
          Text(
            'THIS WEEK: ${modifier.label}',
            textAlign: TextAlign.center,
            style: RetroText.pixel(size: 8, color: RetroColors.amber),
          ),
          const SizedBox(height: 3),
          Text(
            modifier.blurb.toUpperCase(),
            textAlign: TextAlign.center,
            style: RetroText.pixel(size: 6, color: RetroColors.metal),
          ),
          if (dailyState.currentStreak > 0) ...[
            const SizedBox(height: 6),
            Text(
              'STREAK ${dailyState.currentStreak} DAY'
              '${dailyState.currentStreak == 1 ? '' : 'S'}'
              '${dailyState.bestStreak > dailyState.currentStreak ? '  ·  BEST ${dailyState.bestStreak}' : ''}',
              style: RetroText.pixel(size: 7, color: RetroColors.metal),
            ),
          ],
          if (playedToday) ...[
            const SizedBox(height: 4),
            Text(
              "TODAY'S SCORE ${dailyState.lastScore}",
              style: RetroText.pixel(size: 7, color: RetroColors.phosphorDim),
            ),
          ],
          const SizedBox(height: 8),
          SecondaryArcadeButton(
            label: playedToday ? 'PLAY DAILY AGAIN' : 'PLAY DAILY',
            color: RetroColors.zenBlue,
            onPressed: onStart,
          ),
        ],
      ),
    );
  }
}

// ─── Top 5 leaderboard ──────────────────────────────

class TopScoresList extends StatelessWidget {
  const TopScoresList({super.key, required this.scores});

  final List<ScoreEntry> scores;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'TOP SCORES',
          style: RetroText.pixel(size: 9, color: RetroColors.amberDim),
        ),
        const SizedBox(height: 6),
        for (var i = 0; i < scores.length && i < 5; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 1),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 22,
                  child: Text(
                    '${i + 1}.',
                    style: RetroText.pixel(
                      size: 7,
                      color: i == 0 ? RetroColors.amber : RetroColors.metal,
                    ),
                  ),
                ),
                Text(
                  scores[i].score.toString().padLeft(5, '0'),
                  style: RetroText.pixel(
                    size: 9,
                    color: i == 0 ? RetroColors.amber : RetroColors.phosphorDim,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'L${scores[i].level}',
                  style: RetroText.pixel(size: 7, color: RetroColors.metal),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Pick the cabinet's look. Each chip is drawn in its own theme's colors
/// so the choice previews itself.
class ReadyLookTab extends StatelessWidget {
  const ReadyLookTab({
    super.key,
    required this.selected,
    required this.onChanged,
    required this.selectedSkin,
    required this.onSkinChanged,
    required this.level,
  });

  /// The player's level; looks that need more are shown locked.
  final int level;
  final GameTheme selected;
  final ValueChanged<GameTheme> onChanged;
  final SnakeSkin selectedSkin;
  final ValueChanged<SnakeSkin> onSkinChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'SELECT LOOK',
          style: RetroText.pixel(size: 9, color: RetroColors.phosphorDim),
        ),
        const SizedBox(height: 10),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final theme in GameTheme.all)
              _ThemeChip(
                theme: theme,
                isSelected: theme.id == selected.id,
                locked: theme.unlockLevel > level,
                onTap: () => onChanged(theme),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'SELECT SNAKE',
          style: RetroText.pixel(size: 9, color: RetroColors.phosphorDim),
        ),
        const SizedBox(height: 10),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final skin in SnakeSkin.values)
              _SkinChip(
                skin: skin,
                isSelected: skin == selectedSkin,
                locked: skin.unlockLevel > level,
                onTap: () => onSkinChanged(skin),
              ),
          ],
        ),
      ],
    );
  }
}

class _ThemeChip extends StatelessWidget {
  const _ThemeChip({
    required this.theme,
    required this.isSelected,
    required this.locked,
    required this.onTap,
  });

  final GameTheme theme;
  final bool isSelected;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      enabled: !locked,
      label: locked
          ? '${theme.label}, unlocks at level ${theme.unlockLevel}'
          : theme.label,
      child: GestureDetector(
        onTap: locked ? null : onTap,
        child: Opacity(
          opacity: locked ? 0.4 : 1,
          child: Container(
            width: 112,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: theme.screen,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isSelected ? theme.phosphor : theme.phosphorDim,
                width: isSelected ? 2.5 : 1.2,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  theme.label,
                  style: RetroText.pixel(size: 8, color: theme.phosphor),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final c in [theme.phosphor, theme.amber, theme.food])
                      Container(
                        width: 10,
                        height: 10,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        color: c,
                      ),
                  ],
                ),
                if (locked) ...[
                  const SizedBox(height: 6),
                  Text(
                    'LVL ${theme.unlockLevel}',
                    style: RetroText.pixel(size: 7, color: theme.amber),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SkinChip extends StatelessWidget {
  const _SkinChip({
    required this.skin,
    required this.isSelected,
    required this.locked,
    required this.onTap,
  });

  final SnakeSkin skin;
  final bool isSelected;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      enabled: !locked,
      label: locked
          ? '${skin.label}, unlocks at level ${skin.unlockLevel}'
          : skin.label,
      child: GestureDetector(
        onTap: locked ? null : onTap,
        child: Opacity(
          opacity: locked ? 0.4 : 1,
          child: Container(
            width: 112,
            padding: const EdgeInsets.symmetric(vertical: 8),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSelected ? RetroColors.phosphor : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: RetroColors.phosphorDim, width: 1.2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  skin.label,
                  style: RetroText.pixel(
                    size: 8,
                    color: isSelected
                        ? RetroColors.cabinet
                        : RetroColors.phosphor,
                  ),
                ),
                if (locked) ...[
                  const SizedBox(height: 4),
                  Text(
                    'LVL ${skin.unlockLevel}',
                    style: RetroText.pixel(size: 7, color: RetroColors.amber),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
