import 'package:flutter/material.dart';

import '../game/haptics.dart';
import 'theme.dart';

/// How long the offer stays on the table.
///
/// Short enough to be a decision rather than a menu: the player is
/// still in the run, and a choice they can sit on is a choice they have
/// already left.
const secondChanceWindow = Duration(seconds: 3);

/// SECOND CHANCE, with the time left drawn around it.
///
/// Built as one button with a ring so that the ring can later become
/// the "watch an ad" wait without the card around it changing: the
/// roadmap put ads in, and this is the placement they belong in.
class SecondChanceOffer extends StatefulWidget {
  const SecondChanceOffer({
    super.key,
    required this.onAccept,
    required this.onExpire,
  });

  final VoidCallback onAccept;

  /// The window closed with no answer. The run is over for real.
  final VoidCallback onExpire;

  @override
  State<SecondChanceOffer> createState() => _SecondChanceOfferState();
}

class _SecondChanceOfferState extends State<SecondChanceOffer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ring;

  @override
  void initState() {
    super.initState();
    _ring = AnimationController(vsync: this, duration: secondChanceWindow)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) widget.onExpire();
      })
      ..forward();
  }

  @override
  void dispose() {
    _ring.dispose();
    super.dispose();
  }

  void _accept() {
    _ring.stop();
    Haptics.instance.tap();
    widget.onAccept();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Second chance',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _accept,
        child: AnimatedBuilder(
          animation: _ring,
          builder: (context, _) {
            final left = secondChanceWindow.inSeconds * (1 - _ring.value);
            return CustomPaint(
              painter: _RingPainter(remaining: 1 - _ring.value),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'SECOND CHANCE',
                      style: RetroText.pixel(
                        size: 10,
                        color: RetroColors.shieldCyan,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${left.ceil()}',
                      style: RetroText.pixel(
                        size: 8,
                        color: RetroColors.phosphorDim,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// The border, drained anticlockwise as the window closes.
class _RingPainter extends CustomPainter {
  _RingPainter({required this.remaining});

  final double remaining;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(1),
      const Radius.circular(10),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = RetroColors.phosphorDim.withValues(alpha: 0.4),
    );

    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      final keep = metric.length * remaining.clamp(0.0, 1.0);
      if (keep <= 0) continue;
      canvas.drawPath(
        metric.extractPath(0, keep),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = RetroColors.shieldCyan,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.remaining != remaining;
}

/// 3, 2, 1 over the board after a revive, so the player is counted back
/// in rather than dropped into a game already moving.
class ResumeCountdown extends StatelessWidget {
  const ResumeCountdown({super.key, required this.seconds});

  final int seconds;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ColoredBox(
        color: RetroColors.voidBg.withValues(alpha: 0.45),
        child: Center(
          child: Text(
            '$seconds',
            key: ValueKey(seconds),
            style: RetroText.pixel(size: 48, color: RetroColors.shieldCyan),
          ),
        ),
      ),
    );
  }
}

/// A run that was brought back carries the mark for the rest of its
/// life — on the card and on the share image.
class RevivedMark extends StatelessWidget {
  const RevivedMark({super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      'REVIVED',
      style: RetroText.pixel(
        size: 7,
        color: RetroColors.metal,
        letterSpacing: 2,
      ),
    );
  }
}
