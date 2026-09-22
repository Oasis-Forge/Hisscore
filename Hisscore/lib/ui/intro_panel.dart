import 'package:flutter/material.dart';

import '../game/high_score_store.dart';
import '../game/online_scores.dart';
import '../game/quests.dart';
import '../game/snake_engine.dart';
import 'ready_tabs.dart';
import 'snake_skin.dart';
import 'theme.dart';

// ─── Intro panel (over the attract demo) ────────────

class IntroPanel extends StatelessWidget {
  const IntroPanel({
    super.key,
    required this.blinkOn,
    required this.selectedMode,
    required this.onModeChanged,
    required this.readyTab,
    required this.onReadyTabChanged,
    required this.stats,
    required this.topScores,
    required this.dailyDayNumber,
    required this.dailyState,
    required this.playedDailyToday,
    required this.onStartDaily,
    required this.onNewChallenge,
    required this.onEnterCode,
    required this.online,
    required this.playerName,
    required this.onEditName,
    required this.statsView,
    required this.onStatsViewChanged,
    required this.progress,
    required this.quests,
    required this.onOpenQuests,
    required this.selectedTheme,
    required this.onThemeChanged,
    required this.selectedSkin,
    required this.onSkinChanged,
  });

  final bool blinkOn;
  final GameMode selectedMode;
  final ValueChanged<GameMode> onModeChanged;
  final ReadyTab readyTab;
  final ValueChanged<ReadyTab> onReadyTabChanged;
  final GameStats stats;
  final List<ScoreEntry> topScores;
  final int dailyDayNumber;
  final DailyState dailyState;
  final bool playedDailyToday;
  final VoidCallback onStartDaily;
  final VoidCallback onNewChallenge;
  final VoidCallback onEnterCode;
  final OnlineScoreBoard online;
  final String playerName;
  final VoidCallback onEditName;
  final StatsView statsView;
  final ValueChanged<StatsView> onStatsViewChanged;
  final PlayerProgress progress;
  final List<Quest> quests;
  final VoidCallback onOpenQuests;
  final GameTheme selectedTheme;
  final ValueChanged<GameTheme> onThemeChanged;
  final SnakeSkin selectedSkin;
  final ValueChanged<SnakeSkin> onSkinChanged;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      // Only a light tint over the screen: the demo is the hero, and the
      // menu sits on its own card so it stays readable.
      color: RetroColors.screen.withValues(alpha: 0.2),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: RetroColors.screen.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: RetroColors.phosphorDim, width: 1.5),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Opacity(
                    opacity: blinkOn ? 1 : 0.35,
                    child: Text(
                      'PRESS START',
                      textAlign: TextAlign.center,
                      style: RetroText.pixel(
                        size: 14,
                        color: RetroColors.amber,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  ReadyTabBar(selected: readyTab, onChanged: onReadyTabChanged),
                  const SizedBox(height: 14),
                  switch (readyTab) {
                    ReadyTab.modes => ReadyModesTab(
                      selectedMode: selectedMode,
                      onModeChanged: onModeChanged,
                      dailyDayNumber: dailyDayNumber,
                      dailyState: dailyState,
                      playedDailyToday: playedDailyToday,
                      onStartDaily: onStartDaily,
                      onNewChallenge: onNewChallenge,
                      onEnterCode: onEnterCode,
                      questSummary:
                          'QUESTS ${quests.where((q) => progress.completed.contains(q.id)).length}/${quests.length}  \u00B7  LVL ${progress.level}',
                      onOpenQuests: onOpenQuests,
                      rank: progress.rank,
                    ),
                    ReadyTab.how => const ReadyHowTab(),
                    ReadyTab.look => ReadyLookTab(
                      level: progress.level,
                      selected: selectedTheme,
                      onChanged: onThemeChanged,
                      selectedSkin: selectedSkin,
                      onSkinChanged: onSkinChanged,
                    ),
                    ReadyTab.stats => ReadyStatsTab(
                      stats: stats,
                      topScores: topScores,
                      dailyState: dailyState,
                      online: online,
                      dailyDayNumber: dailyDayNumber,
                      mode: selectedMode,
                      playerName: playerName,
                      onEditName: onEditName,
                      view: statsView,
                      onViewChanged: onStatsViewChanged,
                      progress: progress,
                      quests: quests,
                    ),
                  },
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
