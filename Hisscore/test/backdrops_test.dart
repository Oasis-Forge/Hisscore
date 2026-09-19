import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisscore/ui/backdrops.dart';

Future<List<int>> _render(BoardBackdrop backdrop) async {
  final recorder = ui.PictureRecorder();
  backdrop.paint(Canvas(recorder), const Size(280, 400), 14, 20);
  final image = await recorder.endRecording().toImage(280, 400);
  final data = await image.toByteData();
  image.dispose();
  return data!.buffer.asUint8List();
}

void main() {
  test('adventure levels move through the zones three at a time', () {
    expect(BoardBackdrop.forLevel(1), BoardBackdrop.grid);
    expect(BoardBackdrop.forLevel(3), BoardBackdrop.grid);
    expect(BoardBackdrop.forLevel(4), BoardBackdrop.circuit);
    expect(BoardBackdrop.forLevel(6), BoardBackdrop.circuit);
    expect(BoardBackdrop.forLevel(7), BoardBackdrop.cave);
    expect(BoardBackdrop.forLevel(9), BoardBackdrop.cave);
    expect(BoardBackdrop.forLevel(10), BoardBackdrop.stars);
    expect(BoardBackdrop.forLevel(12), BoardBackdrop.stars);
  });

  test('the zones repeat after the last one, and bad levels are safe', () {
    expect(BoardBackdrop.forLevel(13), BoardBackdrop.grid);
    expect(BoardBackdrop.forLevel(16), BoardBackdrop.circuit);
    expect(BoardBackdrop.forLevel(0), BoardBackdrop.grid);
    expect(BoardBackdrop.forLevel(-5), BoardBackdrop.grid);
  });

  testWidgets('each zone draws something different from the others', (
    tester,
  ) async {
    final pictures = <BoardBackdrop, List<int>>{};
    await tester.runAsync(() async {
      for (final b in BoardBackdrop.values) {
        pictures[b] = await _render(b);
      }
    });
    for (final a in BoardBackdrop.values) {
      for (final b in BoardBackdrop.values) {
        if (a.index >= b.index) continue;
        expect(pictures[a], isNot(pictures[b]), reason: '$a vs $b');
      }
    }
  });

  testWidgets('drawing a zone twice gives the identical picture', (
    tester,
  ) async {
    late List<int> first;
    late List<int> second;
    await tester.runAsync(() async {
      first = await _render(BoardBackdrop.cave);
      second = await _render(BoardBackdrop.cave);
    });
    expect(first, second);
  });
}
