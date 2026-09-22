import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:math';

import 'package:hisscore/game/food_types.dart';
import 'package:hisscore/game/snake_engine.dart';
import 'package:hisscore/ui/game_hud.dart';
import 'package:hisscore/ui/hud_widgets.dart';
import 'package:hisscore/ui/theme.dart';

/// Time Attack's clock.
///
/// These were three goldens first, and they were the wrong tool. The
/// ring is 34px, so the only way to make it a large enough share of a
/// golden to matter was a small canvas — and on a small canvas the
/// handful of pixels that antialiasing and font hinting move between
/// Windows and Linux stop being a rounding error and become 1.7%. All
/// three failed on CI while every board golden passed.
///
/// The percentage tolerance a golden needs to survive two platforms is
/// simply wider than a small widget. Everything worth pinning here —
/// the colour, the number, how full the ring is — can be read straight
/// off the widget tree, which is both platform-proof and a sharper
/// assertion than a pixel count.
Future<void> _pumpRing(
  WidgetTester tester, {
  required double fraction,
  required int seconds,
}) {
  return tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: TimerRing(fraction: fraction, seconds: seconds),
      ),
    ),
  );
}

CircularProgressIndicator _ring(WidgetTester tester) => tester
    .widget<CircularProgressIndicator>(find.byType(CircularProgressIndicator));

Color? _ringColor(WidgetTester tester) => _ring(tester).valueColor?.value;

Color? _numberColor(WidgetTester tester) =>
    tester.widget<Text>(find.byType(Text)).style?.color;

void main() {
  testWidgets('the ring empties with the clock', (tester) async {
    await _pumpRing(tester, fraction: 1.0, seconds: 60);
    expect(_ring(tester).value, 1.0);

    await _pumpRing(tester, fraction: 0.25, seconds: 15);
    expect(_ring(tester).value, 0.25);
  });

  testWidgets('it says how many seconds are left', (tester) async {
    await _pumpRing(tester, fraction: 7 / 60, seconds: 7);
    expect(find.text('7'), findsOneWidget);
  });

  testWidgets('the last ten seconds turn it red', (tester) async {
    await _pumpRing(
      tester,
      fraction: (TimerRing.hurryFrom + 1) / 60,
      seconds: TimerRing.hurryFrom + 1,
    );
    expect(_ringColor(tester), RetroColors.speedYellow);
    expect(_numberColor(tester), RetroColors.speedYellow);

    // The warning starts at the boundary, not one second after it.
    await _pumpRing(
      tester,
      fraction: TimerRing.hurryFrom / 60,
      seconds: TimerRing.hurryFrom,
    );
    expect(_ringColor(tester), RetroColors.cherry);
    expect(_numberColor(tester), RetroColors.cherry);
  });

  testWidgets('a clock that has run over or out still draws', (tester) async {
    // The fraction comes from a live engine clock, so it can overshoot
    // either end by a tick. A CircularProgressIndicator given 1.4 or
    // -0.2 draws nonsense rather than refusing.
    await _pumpRing(tester, fraction: 1.4, seconds: 60);
    expect(_ring(tester).value, 1.0);

    await _pumpRing(tester, fraction: -0.2, seconds: 0);
    expect(_ring(tester).value, 0.0);
    expect(_ringColor(tester), RetroColors.cherry);
  });

  // Read off the tree for the same reason as the ring above: these are
  // 6pt labels over an 11pt number, far too small a share of any golden
  // big enough to survive two platforms.
  group('the greed chips', () {
    Future<void> pumpHud(WidgetTester tester, SnakeEngine engine) {
      return tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameHud(engine: engine, highScore: 0, onPause: () {}),
          ),
        ),
      );
    }

    SnakeEngine endless() => SnakeEngine(
      mode: GameMode.endless,
      firstFoodDistance: 99,
      random: Random(3),
    )..start();

    testWidgets('stay off the band until there is a pot', (tester) async {
      await pumpHud(tester, endless());
      expect(find.text('POT'), findsNothing);
      expect(find.text('GREED'), findsNothing);
    });

    testWidgets('report the pot and what it would pay', (tester) async {
      final engine = endless();
      final ahead = engine.head + engine.direction.delta;
      engine.foods = [FoodItem(position: ahead, type: FoodType.apple)];
      engine.tick();

      await pumpHud(tester, engine);
      expect(find.text('POT'), findsOneWidget);
      expect(find.text(engine.pot.toString()), findsOneWidget);
      expect(find.text('GREED'), findsOneWidget);
      expect(find.text('×1.25'), findsOneWidget);
    });

    testWidgets('and go quiet again once it is banked', (tester) async {
      final engine = endless();
      for (final type in [FoodType.apple, FoodType.bank]) {
        final ahead = engine.head + engine.direction.delta;
        engine.foods = [FoodItem(position: ahead, type: type)];
        engine.tick();
      }
      expect(engine.greedBanked, greaterThan(0));

      await pumpHud(tester, engine);
      expect(find.text('POT'), findsNothing);
      expect(find.text('GREED'), findsNothing);
    });
  });
}
