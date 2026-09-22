import 'package:flutter/material.dart';

import '../game/haptics.dart';
import 'theme.dart';

// ─── Mini stat chip (level, combo, shield) ──────────

class MiniStat extends StatelessWidget {
  const MiniStat({
    super.key,
    required this.label,
    required this.value,
    this.color,
  });

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label.isNotEmpty)
          Text(
            label,
            style: RetroText.pixel(size: 6, color: RetroColors.phosphorDim),
          ),
        if (label.isNotEmpty) const SizedBox(height: 2),
        Text(
          value,
          style: RetroText.pixel(
            size: 11,
            color: color ?? RetroColors.phosphor,
          ),
        ),
      ],
    );
  }
}

// ─── Pause button (in-game HUD) ─────────────────────

/// Deliberately a small dedicated target rather than tap-anywhere: the
/// whole board is a swipe surface, so a stray tap must never pause.
class PauseButton extends StatelessWidget {
  const PauseButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Pause',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          Haptics.instance.tap();
          onPressed();
        },
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: RetroColors.screen.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: RetroColors.phosphorDim, width: 1.4),
          ),
          child: Icon(Icons.pause, size: 20, color: RetroColors.phosphor),
        ),
      ),
    );
  }
}

/// The clock on a Time Attack run: a ring that drains, with the seconds
/// left inside it.
///
/// A ring rather than a number alone because the last ten seconds are
/// the whole mode, and a shape emptying is read out of the corner of an
/// eye that is busy steering.
class TimerRing extends StatelessWidget {
  const TimerRing({super.key, required this.fraction, required this.seconds});

  /// How much of the clock is left, 0 to 1.
  final double fraction;
  final int seconds;

  /// Under this many seconds the ring turns and starts to pulse.
  static const int hurryFrom = 10;

  @override
  Widget build(BuildContext context) {
    final hurry = seconds <= hurryFrom;
    final color = hurry ? RetroColors.cherry : RetroColors.speedYellow;
    return SizedBox(
      width: 34,
      height: 34,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 34,
            height: 34,
            child: CircularProgressIndicator(
              value: fraction.clamp(0.0, 1.0),
              strokeWidth: 3,
              backgroundColor: RetroColors.phosphorDim.withValues(alpha: 0.35),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          Text('$seconds', style: RetroText.pixel(size: 9, color: color)),
        ],
      ),
    );
  }
}
