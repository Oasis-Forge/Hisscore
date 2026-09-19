import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../game/snake_engine.dart';
import 'board.dart';
import 'theme.dart';

/// Size of the rendered share image, in pixels.
const shareCardWidth = 1080;
const shareCardHeight = 1350;

/// Renders a shareable image of a finished run: the final board with the
/// score, mode and a call to beat it. Returns PNG bytes.
///
/// [subtitle] is the line under the score, e.g. `CLASSIC` or
/// `DAILY #262  ·  STREAK 3`.
Future<Uint8List> renderShareCard({
  required SnakeEngine engine,
  required String subtitle,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(
    recorder,
    Rect.fromLTWH(0, 0, shareCardWidth.toDouble(), shareCardHeight.toDouble()),
  );
  paintShareCard(canvas, engine: engine, subtitle: subtitle);
  final picture = recorder.endRecording();
  final image = await picture.toImage(shareCardWidth, shareCardHeight);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

/// Paints the share card onto [canvas] at [shareCardWidth] ×
/// [shareCardHeight]. Split from [renderShareCard] so it can be tested
/// without an image round trip.
void paintShareCard(
  Canvas canvas, {
  required SnakeEngine engine,
  required String subtitle,
}) {
  const w = 1080.0;
  const h = 1350.0;

  canvas.drawRect(
    const Rect.fromLTWH(0, 0, w, h),
    Paint()
      ..shader = ui.Gradient.radial(const Offset(w / 2, h * 0.4), w, [
        const Color(0xFF10130F),
        RetroColors.voidBg,
      ]),
  );

  _text(
    canvas,
    'HISCORE',
    const Offset(w / 2, 96),
    size: 72,
    color: RetroColors.amber,
    letterSpacing: 10,
  );
  _text(
    canvas,
    engine.score.toString().padLeft(5, '0'),
    const Offset(w / 2, 220),
    size: 96,
    color: RetroColors.phosphor,
  );
  _text(
    canvas,
    subtitle,
    const Offset(w / 2, 318),
    size: 28,
    color: RetroColors.phosphorDim,
  );

  // The final board, scaled to fit its frame while keeping the grid's
  // aspect ratio so cells stay square.
  const frameTop = 390.0;
  const frameBottom = 1180.0;
  const frameMaxW = w - 160;
  const frameMaxH = frameBottom - frameTop;
  final aspect = engine.columns / engine.rows;
  var boardW = frameMaxW;
  var boardH = boardW / aspect;
  if (boardH > frameMaxH) {
    boardH = frameMaxH;
    boardW = boardH * aspect;
  }
  final boardRect = Rect.fromLTWH(
    (w - boardW) / 2,
    frameTop + (frameMaxH - boardH) / 2,
    boardW,
    boardH,
  );

  canvas.drawRRect(
    RRect.fromRectAndRadius(boardRect.inflate(10), const Radius.circular(14)),
    Paint()..color = RetroColors.cabinetRim,
  );
  canvas.save();
  canvas.clipRRect(
    RRect.fromRectAndRadius(boardRect, const Radius.circular(6)),
  );
  canvas.translate(boardRect.left, boardRect.top);
  SnakeBoardPainter(engine: engine, pulse: 0.5).paint(canvas, boardRect.size);
  canvas.restore();

  _text(
    canvas,
    'CAN YOU BEAT IT?',
    const Offset(w / 2, 1262),
    size: 34,
    color: RetroColors.amber,
  );
}

void _text(
  Canvas canvas,
  String text,
  Offset center, {
  required double size,
  required Color color,
  double letterSpacing = 2,
}) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: RetroText.pixel(
        size: size,
        color: color,
        letterSpacing: letterSpacing,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  painter.paint(canvas, center - Offset(painter.width / 2, painter.height / 2));
}
