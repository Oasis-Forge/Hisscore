import 'package:flutter/material.dart';

import '../game/snake_engine.dart';
import 'board.dart';
import 'floating_label.dart';
import 'particles.dart';
import 'screen_shake.dart';
import 'second_chance.dart';
import 'theme.dart';

/// The playfield and everything drawn on top of it: the shake, the
/// level-up edge glow, the floating score popups, the pause / game-over
/// card, and the red flash a death leaves behind.
///
/// The layers are ordered deliberately. The glow sits over the board but
/// under the popups so the snake stays readable while it plays; the
/// death flash sits over everything, including the card, so it reads as
/// the moment of dying rather than as part of the card.
class GameBoardView extends StatelessWidget {
  const GameBoardView({
    super.key,
    required this.engine,
    required this.pulse,
    required this.tickProgress,
    required this.particles,
    required this.shake,
    required this.labels,
    required this.levelFlashOpacity,
    required this.deathFlashOpacity,
    required this.onSwipe,
    this.overlay,
    this.countdown = 0,
    this.ghost = const [],
    this.ghostPrevious = const [],
  });

  final SnakeEngine engine;
  final Animation<double> pulse;
  final double tickProgress;
  final ParticleSystem particles;
  final ScreenShakeController shake;
  final List<FloatingLabel> labels;
  final double levelFlashOpacity;
  final double deathFlashOpacity;
  final void Function(Direction) onSwipe;

  /// The pause or game-over card, when one is showing.
  final Widget? overlay;

  /// Seconds left of the 3-2-1 after a second chance; 0 for none.
  final int countdown;

  /// The best run on this board so far, where it has got to.
  final List<GridPoint> ghost;

  /// Where the ghost was last tick, so it can be slid rather than
  /// jumped.
  final List<GridPoint> ghostPrevious;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (context, _) {
        return Stack(
          fit: StackFit.expand,
          children: [
            ScreenShake(
              controller: shake,
              child: SnakeBoard(
                engine: engine,
                pulse: pulse.value,
                tickProgress: tickProgress,
                particles: particles,
                onSwipe: onSwipe,
                fullBleed: true,
                ghost: ghost,
                ghostPrevious: ghostPrevious,
              ),
            ),
            if (levelFlashOpacity > 0) _buildLevelGlow(),
            for (final label in labels)
              FloatingLabelView(key: ValueKey(label.id), label: label),
            ?overlay,
            if (countdown > 0) ResumeCountdown(seconds: countdown),
            if (deathFlashOpacity > 0) _buildDeathFlash(),
          ],
        );
      },
    );
  }

  /// Level-up: the screen edges pulse amber. An edge glow rather than a
  /// full-screen flash, so the board underneath stays legible.
  Widget _buildLevelGlow() {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            radius: 0.95,
            colors: [
              Colors.transparent,
              RetroColors.amber.withValues(alpha: 0.6 * levelFlashOpacity),
            ],
            stops: const [0.55, 1.0],
          ),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }

  Widget _buildDeathFlash() {
    return IgnorePointer(
      child: ColoredBox(
        color: RetroColors.cherry.withValues(alpha: 0.4 * deathFlashOpacity),
        child: const SizedBox.expand(),
      ),
    );
  }
}
