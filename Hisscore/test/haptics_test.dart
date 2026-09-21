import 'dart:math';

import 'package:flutter/material.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisscore/game/food_types.dart';
import 'package:hisscore/game/game_session.dart';
import 'package:hisscore/game/haptics.dart';
import 'package:hisscore/game/high_score_store.dart';
import 'package:hisscore/game/online_scores.dart';
import 'package:hisscore/game/snake_engine.dart';
import 'package:hisscore/main.dart';

/// Vibration cannot be seen, heard or screenshotted, and the emulator
/// has none — so what is testable is *which* buzz is asked for at
/// *which* moment, and that the toggle silences all of them. Whether
/// the phone actually shakes is still a job for a human with a phone.
class _RecordingHaptics implements HapticImpl {
  final List<String> fired = [];

  @override
  void light() => fired.add('light');

  @override
  void medium() => fired.add('medium');

  @override
  void heavy() => fired.add('heavy');

  @override
  void selection() => fired.add('selection');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _RecordingHaptics recorder;
  late Haptics haptics;

  setUp(() {
    recorder = _RecordingHaptics();
    haptics = Haptics(impl: recorder);
  });

  group('which buzz', () {
    test('an apple is a light tap and a pickup is a click', () {
      haptics.ate(FoodType.apple);
      haptics.ate(FoodType.magnet);
      haptics.ate(FoodType.shield);

      expect(recorder.fired, ['light', 'selection', 'selection']);
    });

    test('a combo step is stronger than an apple', () {
      haptics.combo();
      expect(recorder.fired, ['medium']);
    });

    test('death is the heaviest thing the game does', () {
      haptics.death();
      expect(recorder.fired, ['heavy']);
    });

    test('a close call is a click, not a celebration', () {
      haptics.closeCall();
      expect(recorder.fired, ['selection']);
    });

    test('a level-up is two pulses, so it is not a combo', () {
      fakeAsync((async) {
        haptics.levelUp();
        expect(recorder.fired, ['medium'], reason: 'the first half');

        async.elapse(Haptics.doublePulseGap);

        expect(recorder.fired, ['medium', 'medium']);
      });
    });
  });

  group('the toggle', () {
    test('silences every moment', () {
      haptics.setEnabled(false);

      haptics
        ..tap()
        ..select()
        ..ate(FoodType.apple)
        ..ate(FoodType.star)
        ..combo()
        ..closeCall()
        ..death()
        ..levelUp();

      expect(recorder.fired, isEmpty);
    });

    test('catches a level-up mid-pulse', () {
      fakeAsync((async) {
        haptics.levelUp();
        expect(recorder.fired, hasLength(1));

        haptics.setEnabled(false);
        async.elapse(Haptics.doublePulseGap);

        expect(
          recorder.fired,
          hasLength(1),
          reason: 'the second pulse must not escape the switch',
        );
      });
    });

    test('is on by default', () {
      expect(Haptics().enabled, isTrue);
    });
  });

  group('in a run', () {
    test('the moments of a run reach the phone', () async {
      final session = GameSession(
        store: InMemoryHighScoreStore(),
        onlineScores: const NoopOnlineScoreBoard(),
        engineFactory: () => SnakeEngine(random: Random(1)),
        haptics: haptics,
        now: () => DateTime(2026, 9, 21),
      );
      session.primaryAction();
      for (
        var i = 0;
        i < 200 && session.engine.phase == GamePhase.running;
        i++
      ) {
        session.onTicker();
      }
      await session.saveInFlight;

      expect(recorder.fired, contains('light'), reason: 'an apple');
      expect(recorder.fired.last, 'heavy', reason: 'the death, last');
      session.dispose();
    });

    test('a silenced phone stays silent through a whole run', () async {
      haptics.setEnabled(false);
      final session = GameSession(
        store: InMemoryHighScoreStore(),
        onlineScores: const NoopOnlineScoreBoard(),
        engineFactory: () => SnakeEngine(random: Random(1)),
        haptics: haptics,
        now: () => DateTime(2026, 9, 21),
      );
      session.primaryAction();
      for (
        var i = 0;
        i < 200 && session.engine.phase == GamePhase.running;
        i++
      ) {
        session.onTicker();
      }
      await session.saveInFlight;

      expect(recorder.fired, isEmpty);
      session.dispose();
    });
  });

  group('the switch on the cabinet', () {
    testWidgets('is there, and flips', (tester) async {
      final previous = Haptics.instance;
      Haptics.instance = haptics;
      addTearDown(() => Haptics.instance = previous);

      await tester.pumpWidget(
        HisscoreApp(highScoreStore: InMemoryHighScoreStore()),
      );
      await tester.pump();

      expect(find.byIcon(Icons.vibration), findsOneWidget);
      expect(find.byIcon(Icons.smartphone), findsNothing);

      await tester.tap(find.byIcon(Icons.vibration));
      await tester.pump();

      expect(find.byIcon(Icons.smartphone), findsOneWidget);
      expect(haptics.enabled, isFalse);
    });
  });
}
