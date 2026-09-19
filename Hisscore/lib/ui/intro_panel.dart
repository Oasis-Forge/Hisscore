import 'package:flutter/material.dart';

import '../game/high_score_store.dart';
import '../game/snake_engine.dart';
import 'ready_tabs.dart';
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

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      // Only a light tint over the screen: the demo is the hero, and the
      // menu sits on its own card so it stays readable.
      color: const Color(0x3303140A),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xE603140A),
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
                    ),
                    ReadyTab.how => const ReadyHowTab(),
                    ReadyTab.stats => ReadyStatsTab(
                      stats: stats,
                      topScores: topScores,
                      dailyState: dailyState,
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
