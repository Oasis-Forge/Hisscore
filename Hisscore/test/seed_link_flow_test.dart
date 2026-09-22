import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisscore/game/challenge_code.dart';
import 'package:hisscore/game/challenge_links.dart';
import 'package:hisscore/game/high_score_store.dart';
import 'package:hisscore/game/snake_engine.dart';
import 'package:hisscore/main.dart';
import 'package:hisscore/ui/hud_widgets.dart';

/// A [ChallengeLinks] the test drives.
class _FakeLinks implements ChallengeLinks {
  _FakeLinks({this.opening});

  /// The link the app was "opened with".
  final ChallengeCode? opening;

  final _controller = StreamController<ChallengeCode>.broadcast();
  bool _asked = false;

  void send(ChallengeCode code) => _controller.add(code);

  @override
  Future<ChallengeCode?> initial() async {
    // Answered once, as the real one is.
    if (_asked) return null;
    _asked = true;
    return opening;
  }

  @override
  Stream<ChallengeCode> get incoming => _controller.stream;

  @override
  void dispose() => _controller.close();
}

void main() {
  // Time Attack, because its timer ring is on screen for that mode and
  // no other — so finding one proves both that a run started and that
  // it is the mode the link named, rather than the menu's default.
  const code = ChallengeCode(mode: GameMode.timeAttack, seed: 31337);

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('xyz.luan/audioplayers.global'),
          (call) async => null,
        );
  });

  Future<_FakeLinks> pumpGame(
    WidgetTester tester, {
    ChallengeCode? opening,
  }) async {
    final links = _FakeLinks(opening: opening);
    addTearDown(links.dispose);
    await tester.pumpWidget(
      HisscoreApp(highScoreStore: InMemoryHighScoreStore(), links: links),
    );
    // Never pumpAndSettle here: the menu animates forever.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    return links;
  }

  testWidgets('a link the app was opened with starts that challenge', (
    tester,
  ) async {
    await pumpGame(tester, opening: code);
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('PRESS START'), findsNothing);
    expect(find.byType(TimerRing), findsOneWidget);
  });

  testWidgets('a link tapped while on the menu starts it too', (tester) async {
    final links = await pumpGame(tester);
    expect(find.text('PRESS START'), findsOneWidget);

    links.send(code);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('PRESS START'), findsNothing);
    expect(find.byType(TimerRing), findsOneWidget);
  });

  group('a link that arrives mid-run', () {
    /// Starts an ordinary run from the menu, then delivers [code].
    Future<_FakeLinks> interrupt(WidgetTester tester) async {
      final links = await pumpGame(tester);
      await tester.tap(find.text('PLAY'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(TimerRing), findsNothing, reason: 'a classic run');

      links.send(code);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      return links;
    }

    testWidgets('asks before throwing the run away', (tester) async {
      await interrupt(tester);

      expect(find.text('CHALLENGE'), findsOneWidget);
      expect(find.text(code.text), findsOneWidget);
      expect(find.text('NOT NOW'), findsOneWidget);
      expect(find.text('PLAY IT'), findsOneWidget);
    });

    testWidgets('NOT NOW leaves the run alone', (tester) async {
      await interrupt(tester);

      await tester.tap(find.text('NOT NOW'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('CHALLENGE'), findsNothing);
      // Still in the same run: not back on the menu, and not Time Attack.
      expect(find.text('PRESS START'), findsNothing);
      expect(find.byType(TimerRing), findsNothing);
    });

    testWidgets('PLAY IT swaps to the challenge', (tester) async {
      await interrupt(tester);

      await tester.tap(find.text('PLAY IT'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('CHALLENGE'), findsNothing);
      expect(find.byType(TimerRing), findsOneWidget);
    });
  });
}
