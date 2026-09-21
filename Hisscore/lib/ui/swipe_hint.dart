import 'package:flutter/material.dart';

import 'theme.dart';

/// Shown over the attract demo until the player has finished a run.
///
/// The cabinet has always said SWIPE TO STEER in small text under the
/// PLAY button, where a first-time player reads it after they have
/// already started. This puts the one control the game has on the
/// screen they are looking at, and moves it, because an arrow that
/// travels reads as a gesture and a static one reads as decoration.
class SwipeHint extends StatelessWidget {
  const SwipeHint({super.key, required this.sweep});

  /// Where in the sweep the arrow is, 0 (far left) to 1 (far right).
  /// Driven by the menu's existing pulse, so the hint costs no ticker
  /// of its own.
  final double sweep;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 110,
                height: 20,
                child: Align(
                  // -1 is the left edge of the track, 1 the right.
                  alignment: Alignment(sweep * 2 - 1, 0),
                  child: Icon(
                    Icons.arrow_forward,
                    size: 16,
                    color: RetroColors.amber,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'SWIPE TO STEER',
                textAlign: TextAlign.center,
                style: RetroText.pixel(size: 8, color: RetroColors.amber),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
