import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisscore/game/high_score_store.dart';
import 'package:hisscore/main.dart';
import 'package:hisscore/ui/snake_skin.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  tearDown(() => SnakeSkin.current = SnakeSkin.classic);

  test('skin ids are unique and unknown ids fall back to classic', () {
    expect(SnakeSkin.values.map((s) => s.id).toSet().length, 4);
    expect(SnakeSkin.byId('nope'), SnakeSkin.classic);
    expect(SnakeSkin.byId(null), SnakeSkin.classic);
    expect(SnakeSkin.byId('neon'), SnakeSkin.neon);
  });

  test('rainbow shifts hue along the body and over time', () {
    Color at(int i, int ms) =>
        SnakeSkin.rainbow.bodyColor(i: i, t: 0.5, elapsedMs: ms);
    expect(at(1, 0), isNot(at(2, 0)));
    expect(at(1, 0), isNot(at(1, 400)));
    expect(SnakeSkin.rainbow.bodyColor(i: 0, t: 0, elapsedMs: 0), Colors.white);
  });

  test('pixel skin alternates two tones and has no taper', () {
    Color at(int i) => SnakeSkin.pixel.bodyColor(i: i, t: 0.5, elapsedMs: 0);
    expect(at(1), at(3));
    expect(at(1), isNot(at(2)));
    expect(SnakeSkin.pixel.taper, 0);
    expect(SnakeSkin.pixel.hasConnectors, isFalse);
  });

  test('stores remember the skin id', () async {
    final memory = InMemoryHighScoreStore();
    expect(await memory.loadSkinId(), isNull);
    await memory.saveSkinId('neon');
    expect(await memory.loadSkinId(), 'neon');

    SharedPreferences.setMockInitialValues({});
    final prefs = SharedPreferencesHighScoreStore();
    expect(await prefs.loadSkinId(), isNull);
    await prefs.saveSkinId('rainbow');
    expect(await prefs.loadSkinId(), 'rainbow');
  });

  testWidgets('LOOK tab switches and saves the skin', (tester) async {
    final store = InMemoryHighScoreStore();
    await tester.pumpWidget(HisscoreApp(highScoreStore: store));
    await tester.pump();

    await tester.tap(find.text('LOOK'));
    await tester.pump();
    expect(find.text('SELECT SNAKE'), findsOneWidget);

    await tester.tap(find.text('NEON'));
    await tester.pump();

    expect(SnakeSkin.current, SnakeSkin.neon);
    expect(await store.loadSkinId(), 'neon');
  });

  testWidgets('a saved skin is applied on launch', (tester) async {
    final store = InMemoryHighScoreStore();
    await store.saveSkinId('pixel');
    await tester.pumpWidget(HisscoreApp(highScoreStore: store));
    await tester.pump();
    await tester.pump();

    expect(SnakeSkin.current, SnakeSkin.pixel);
  });
}
