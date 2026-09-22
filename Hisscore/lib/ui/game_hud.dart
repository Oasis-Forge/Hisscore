import 'package:flutter/material.dart';

import '../game/snake_engine.dart';
import 'controls.dart';
import 'hud_widgets.dart';
import 'theme.dart';

/// The thin band of readouts above the playfield.
///
/// It gets its own band rather than floating over the board — otherwise
/// the snake runs underneath the score and neither is readable.
class GameHud extends StatelessWidget {
  const GameHud({
    super.key,
    required this.engine,
    required this.highScore,
    required this.onPause,
  });

  /// How tall the band is. The page subtracts this from the viewport
  /// before shaping the grid, so the two must agree.
  static const double height = 52;

  final SnakeEngine engine;
  final int highScore;
  final VoidCallback onPause;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
      decoration: BoxDecoration(
        color: RetroColors.voidBg,
        border: Border(
          bottom: BorderSide(color: RetroColors.phosphorDim, width: 1.5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ScoreReadout(label: 'SCORE', value: engine.score),
          if (engine.mode.isTimed) ...[
            const SizedBox(width: 10),
            TimerRing(
              fraction: engine.timeFraction,
              seconds: (engine.timeLeftMs! / 1000).ceil(),
            ),
          ],
          const SizedBox(width: 14),
          Expanded(child: _buildStatusChips()),
          const SizedBox(width: 14),
          ScoreReadout(label: 'HI', value: highScore, highlight: true),
          const SizedBox(width: 10),
          PauseButton(onPressed: onPause),
        ],
      ),
    );
  }

  /// Only what is currently true: the level in Adventure, a live combo,
  /// an unbanked pot in Endless, and any power-up actually running.
  Widget _buildStatusChips() {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (engine.mode == GameMode.adventure)
          MiniStat(label: 'LVL', value: engine.level.toString()),
        if (engine.comboCount > 1)
          MiniStat(
            label: 'COMBO',
            value: '×${engine.comboMultiplier.toStringAsFixed(1)}',
            color: RetroColors.combo,
          ),
        // Both or neither: the apple that fills the pot is the apple
        // that raises greed, so a pot with nothing in it has no
        // multiplier to report either.
        if (engine.pot > 0) ...[
          MiniStat(
            label: 'POT',
            value: engine.pot.toString(),
            color: RetroColors.bankOrange,
          ),
          MiniStat(
            label: 'GREED',
            value: '×${engine.greed.toStringAsFixed(2)}',
            color: RetroColors.bankOrange,
          ),
        ],
        if (engine.hasShield)
          const MiniStat(label: '', value: '🛡', color: RetroColors.shieldCyan),
        if (engine.magnetActive)
          const MiniStat(label: '', value: '🧲', color: RetroColors.magnetPink),
      ],
    );
  }
}
