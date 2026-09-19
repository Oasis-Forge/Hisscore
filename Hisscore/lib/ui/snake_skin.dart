import 'package:flutter/material.dart';

import 'theme.dart';

/// How the snake is drawn. Colors still come from the active theme, so a
/// skin and a theme combine freely.
enum SnakeSkin {
  /// The original tapered, glowing body.
  classic('classic', 'CLASSIC'),

  /// Square, gapless pixels in a two-tone checker, like an old handheld.
  pixel('pixel', 'PIXEL'),

  /// A hollow outline that glows.
  neon('neon', 'NEON'),

  /// A hue that ripples down the body.
  rainbow('rainbow', 'RAINBOW');

  const SnakeSkin(this.id, this.label);

  final String id;
  final String label;

  /// The active skin, read by the board painter.
  static SnakeSkin current = SnakeSkin.classic;

  static SnakeSkin byId(String? id) =>
      values.firstWhere((s) => s.id == id, orElse: () => SnakeSkin.classic);

  /// Corner radius as a fraction of a cell.
  double get cornerRadius => switch (this) {
    SnakeSkin.pixel => 0.04,
    SnakeSkin.neon => 0.22,
    _ => 0.18,
  };

  /// How much the body narrows toward the tail (0 = not at all).
  double get taper => this == SnakeSkin.pixel ? 0 : 1;

  /// Whether the gaps between segments are bridged by connectors.
  bool get hasConnectors => this != SnakeSkin.pixel && this != SnakeSkin.neon;

  /// Fill color of segment [i] of [length]; [t] is 0 at the head and 1 at
  /// the tail. [elapsedMs] animates the rainbow.
  Color bodyColor({required int i, required double t, required int elapsedMs}) {
    final isHead = i == 0;
    return switch (this) {
      SnakeSkin.classic =>
        isHead
            ? RetroColors.phosphorHot
            : Color.lerp(RetroColors.phosphor, RetroColors.snakeTail, t)!,
      SnakeSkin.pixel =>
        isHead
            ? RetroColors.phosphorHot
            : (i.isEven ? RetroColors.phosphor : RetroColors.phosphorDim),
      SnakeSkin.neon => isHead ? RetroColors.phosphorHot : RetroColors.phosphor,
      SnakeSkin.rainbow =>
        isHead
            ? Colors.white
            : HSVColor.fromAHSV(
                1,
                (i * 22.0 + elapsedMs / 8) % 360,
                0.85,
                1,
              ).toColor(),
    };
  }
}
