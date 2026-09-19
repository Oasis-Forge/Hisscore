import 'dart:math';

import 'package:flutter/material.dart';

import 'theme.dart';

/// What the board looks like behind the snake. Adventure moves through
/// these zones as levels climb, three levels each; every other mode stays
/// on [grid]. All zones are drawn in the active theme's colors.
enum BoardBackdrop {
  /// The plain CRT grid (levels 1–3, and every non-adventure mode).
  grid,

  /// Circuit-board traces and solder nodes (levels 4–6).
  circuit,

  /// Speckled rock with stalactites (levels 7–9).
  cave,

  /// A starfield (levels 10–12), then the cycle starts over.
  stars;

  /// The zone for an adventure [level] (1-based).
  static BoardBackdrop forLevel(int level) =>
      values[(((level < 1 ? 1 : level) - 1) ~/ 3) % values.length];

  /// Paints this zone onto [canvas], which is [size] pixels for a board of
  /// [columns] × [rows] cells. Deterministic: the same inputs always give
  /// the same picture, so it can be cached and tested.
  void paint(Canvas canvas, Size size, int columns, int rows) {
    final cellW = size.width / columns;
    final cellH = size.height / rows;
    canvas.drawRect(Offset.zero & size, Paint()..color = RetroColors.screen);
    switch (this) {
      case BoardBackdrop.grid:
        _grid(canvas, size, cellW, cellH, columns, rows, RetroColors.grid);
      case BoardBackdrop.circuit:
        _grid(
          canvas,
          size,
          cellW,
          cellH,
          columns,
          rows,
          RetroColors.grid.withValues(alpha: 0.5),
        );
        _circuit(canvas, cellW, cellH, columns, rows);
      case BoardBackdrop.cave:
        _cave(canvas, size, cellW, cellH, columns, rows);
      case BoardBackdrop.stars:
        _stars(canvas, size, columns, rows);
    }
  }

  static void _grid(
    Canvas canvas,
    Size size,
    double cellW,
    double cellH,
    int columns,
    int rows,
    Color color,
  ) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 0.8;
    for (var x = 1; x < columns; x++) {
      canvas.drawLine(
        Offset(x * cellW, 0),
        Offset(x * cellW, size.height),
        paint,
      );
    }
    for (var y = 1; y < rows; y++) {
      canvas.drawLine(
        Offset(0, y * cellH),
        Offset(size.width, y * cellH),
        paint,
      );
    }
  }

  /// Random walks along grid lines, ending in a node: a circuit board.
  static void _circuit(
    Canvas canvas,
    double cellW,
    double cellH,
    int columns,
    int rows,
  ) {
    final random = Random(4);
    final trace = Paint()
      ..color = RetroColors.phosphorDim.withValues(alpha: 0.35)
      ..strokeWidth = max(1.5, cellW * 0.07)
      ..strokeCap = StrokeCap.round;
    final node = Paint()
      ..color = RetroColors.phosphorDim.withValues(alpha: 0.5);
    final traces = max(4, columns * rows ~/ 30);
    for (var t = 0; t < traces; t++) {
      var x = random.nextInt(columns + 1);
      var y = random.nextInt(rows + 1);
      var horizontal = random.nextBool();
      final steps = 3 + random.nextInt(3);
      for (var step = 0; step < steps; step++) {
        final run = 1 + random.nextInt(4);
        final dir = random.nextBool() ? 1 : -1;
        final nx = horizontal ? (x + dir * run).clamp(0, columns) : x;
        final ny = horizontal ? y : (y + dir * run).clamp(0, rows);
        canvas.drawLine(
          Offset(x * cellW, y * cellH),
          Offset(nx * cellW, ny * cellH),
          trace,
        );
        x = nx;
        y = ny;
        horizontal = !horizontal;
      }
      canvas.drawCircle(Offset(x * cellW, y * cellH), cellW * 0.16, node);
    }
  }

  /// Flecks of rock everywhere, and stalactites hanging from the top and
  /// rising from the bottom.
  static void _cave(
    Canvas canvas,
    Size size,
    double cellW,
    double cellH,
    int columns,
    int rows,
  ) {
    final random = Random(7);
    final fleck = Paint();
    for (var i = 0; i < columns * rows; i++) {
      fleck.color = RetroColors.grid.withValues(
        alpha: 0.35 + random.nextDouble() * 0.5,
      );
      final w = cellW * (0.1 + random.nextDouble() * 0.3);
      canvas.drawRect(
        Rect.fromLTWH(
          random.nextDouble() * size.width,
          random.nextDouble() * size.height,
          w,
          w * (0.6 + random.nextDouble()),
        ),
        fleck,
      );
    }
    final rock = Paint()..color = RetroColors.obstacle.withValues(alpha: 0.55);
    for (var x = 0; x < columns; x++) {
      if (random.nextDouble() < 0.45) {
        final h = cellH * (0.4 + random.nextDouble() * 1.2);
        canvas.drawPath(
          Path()
            ..moveTo(x * cellW, 0)
            ..lineTo((x + 1) * cellW, 0)
            ..lineTo((x + 0.5) * cellW, h)
            ..close(),
          rock,
        );
      }
      if (random.nextDouble() < 0.45) {
        final h = cellH * (0.4 + random.nextDouble() * 1.2);
        canvas.drawPath(
          Path()
            ..moveTo(x * cellW, size.height)
            ..lineTo((x + 1) * cellW, size.height)
            ..lineTo((x + 0.5) * cellW, size.height - h)
            ..close(),
          rock,
        );
      }
    }
  }

  /// Dots of varying size and brightness, a few with a sparkle cross.
  static void _stars(Canvas canvas, Size size, int columns, int rows) {
    final random = Random(10);
    final star = Paint();
    final count = max(30, columns * rows ~/ 3);
    for (var i = 0; i < count; i++) {
      final p = Offset(
        random.nextDouble() * size.width,
        random.nextDouble() * size.height,
      );
      final bright = random.nextDouble();
      star.color = RetroColors.phosphorHot.withValues(
        alpha: 0.2 + bright * 0.6,
      );
      canvas.drawCircle(p, 0.6 + bright * 1.4, star);
      if (bright > 0.93) {
        final arm = 3 + bright * 4;
        final sparkle = Paint()
          ..color = RetroColors.phosphorHot.withValues(alpha: 0.5)
          ..strokeWidth = 1;
        canvas.drawLine(p - Offset(arm, 0), p + Offset(arm, 0), sparkle);
        canvas.drawLine(p - Offset(0, arm), p + Offset(0, arm), sparkle);
      }
    }
  }
}
