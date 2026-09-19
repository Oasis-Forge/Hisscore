import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hisscore/game/snake_engine.dart';
import 'package:hisscore/ui/share_card.dart';

void main() {
  testWidgets('renderShareCard produces a PNG of the expected size', (
    tester,
  ) async {
    final engine = SnakeEngine(columns: 16, rows: 24);
    engine.start();
    for (var i = 0; i < 3; i++) {
      engine.tick();
    }

    final png = (await tester.runAsync(
      () => renderShareCard(engine: engine, subtitle: 'CLASSIC'),
    ))!;

    // PNG signature, then IHDR's width and height.
    expect(png.sublist(0, 8), [137, 80, 78, 71, 13, 10, 26, 10]);
    final header = ByteData.sublistView(png, 16, 24);
    expect(header.getUint32(0), shareCardWidth);
    expect(header.getUint32(4), shareCardHeight);
  });
}
