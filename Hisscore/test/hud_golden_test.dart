import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisscore/ui/hud_widgets.dart';
import 'package:hisscore/ui/theme.dart';

import 'support/pixel_font.dart';
import 'support/tolerant_goldens.dart';

Widget _framed(Widget child) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Center(
      child: RepaintBoundary(
        key: goldenBoundary,
        child: ColoredBox(
          color: RetroColors.screen,
          child: SizedBox(width: 60, height: 60, child: Center(child: child)),
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(loadPixelFont);
  setUp(() => useTolerantGoldens('hud_golden_test.dart'));

  // Time Attack's clock. The colour change is the whole warning — under
  // ten seconds the ring and the number turn from yellow to cherry —
  // and a colour is exactly the kind of thing no other test in this
  // repo can see.
  for (final (name, seconds, fraction) in [
    ('full', 60, 1.0),
    ('half', 30, 0.5),
    ('hurry', 7, 7 / 60),
  ]) {
    testWidgets('the timer ring at $seconds seconds', (tester) async {
      await tester.pumpWidget(
        _framed(TimerRing(fraction: fraction, seconds: seconds)),
      );
      await expectLater(
        find.byKey(goldenBoundary),
        matchesGoldenFile('goldens/timer_ring_$name.png'),
      );
    });
  }
}
