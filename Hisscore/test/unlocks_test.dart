import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:hisscore/game/high_score_store.dart';
import 'package:hisscore/game/quests.dart';
import 'package:hisscore/game/snake_engine.dart';
import 'package:hisscore/main.dart';
import 'package:hisscore/ui/snake_skin.dart';
import 'package:hisscore/ui/theme.dart';
import 'package:hisscore/ui/unlocks.dart';

Future<void> _openLook(
  WidgetTester tester,
  InMemoryHighScoreStore store,
) async {
  await tester.pumpWidget(HisscoreApp(highScoreStore: store));
  await tester.pump();
  await tester.pump();
  await tester.tap(find.text('LOOK'));
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  tearDown(() {
    RetroColors.current = GameTheme.phosphorGreen;
    SnakeSkin.current = SnakeSkin.classic;
  });

  group('schedule', () {
    test('the original look and skin are free', () {
      expect(GameTheme.phosphorGreen.unlockLevel, 1);
      expect(SnakeSkin.classic.unlockLevel, 1);
    });

    test('every other look and skin is earned, at distinct levels', () {
      final levels = allUnlocks().map((u) => u.level).toList();
      expect(levels, isNotEmpty);
      expect(levels.every((l) => l > 1), isTrue);
      expect(levels.toSet().length, levels.length);
      expect(levels, orderedEquals([...levels]..sort()));
      expect(
        allUnlocks().length,
        GameTheme.all.length - 1 + SnakeSkin.values.length - 1,
      );
    });

    test('levels are reachable: each costs XP the curve can pay', () {
      final top = allUnlocks().last.level;
      expect(Levels.xpToReach(top), lessThan(20000));
    });
  });

  group('unlocksBetween', () {
    test('lists what a level-up earned, and nothing for no change', () {
      expect(unlocksBetween(1, 1), isEmpty);
      expect(unlocksBetween(1, 2).map((u) => u.name), ['AMBER']);
      expect(unlocksBetween(2, 3).map((u) => u.name), ['PIXEL']);
    });

    test('a jump of several levels lists everything it passed', () {
      final names = unlocksBetween(1, 6).map((u) => u.name);
      expect(names, containsAll(['AMBER', 'PIXEL', 'GAME BOY', 'NEON']));
      expect(names, contains('SYNTHWAVE'));
      expect(names, isNot(contains('RAINBOW')));
    });

    test('does not repeat an unlock already earned', () {
      expect(unlocksBetween(6, 7), isEmpty);
    });
  });

  testWidgets('at level 1 the earned looks are locked and cannot be picked', (
    tester,
  ) async {
    final store = InMemoryHighScoreStore();
    await _openLook(tester, store);

    expect(find.text('LVL 2'), findsOneWidget); // amber
    expect(find.text('LVL 4'), findsOneWidget); // game boy
    expect(find.text('LVL 6'), findsOneWidget); // synthwave
    expect(find.text('LVL 3'), findsOneWidget); // pixel
    expect(find.text('LVL 5'), findsOneWidget); // neon
    expect(find.text('LVL 8'), findsOneWidget); // rainbow

    await tester.tap(find.text('AMBER'));
    await tester.tap(find.text('PIXEL'));
    await tester.pump();
    expect(RetroColors.current, GameTheme.phosphorGreen);
    expect(SnakeSkin.current, SnakeSkin.classic);
    expect(await store.loadThemeId(), isNull);
    expect(await store.loadSkinId(), isNull);
  });

  testWidgets('reaching a level unlocks exactly its looks', (tester) async {
    final store = InMemoryHighScoreStore();
    // Level 5: amber, pixel, game boy and neon are open; synthwave and
    // rainbow are not.
    await store.saveProgress(PlayerProgress(xp: Levels.xpToReach(5)));
    await _openLook(tester, store);

    expect(find.text('LVL 6'), findsOneWidget);
    expect(find.text('LVL 8'), findsOneWidget);
    expect(find.text('LVL 4'), findsNothing);

    await tester.tap(find.text('GAME BOY'));
    await tester.pump();
    expect(RetroColors.current, GameTheme.gameBoy);

    await tester.tap(find.text('SYNTHWAVE'));
    await tester.pump();
    expect(RetroColors.current, GameTheme.gameBoy);

    await tester.tap(find.text('NEON'));
    await tester.pump();
    expect(SnakeSkin.current, SnakeSkin.neon);
  });

  testWidgets('a saved look the player has not earned falls back', (
    tester,
  ) async {
    final store = InMemoryHighScoreStore();
    await store.saveThemeId('synthwave');
    await store.saveSkinId('rainbow');
    await tester.pumpWidget(HisscoreApp(highScoreStore: store));
    await tester.pump();
    await tester.pump();

    expect(RetroColors.current, GameTheme.phosphorGreen);
    expect(SnakeSkin.current, SnakeSkin.classic);
  });

  testWidgets('a saved look that is earned is kept', (tester) async {
    final store = InMemoryHighScoreStore();
    await store.saveProgress(PlayerProgress(xp: Levels.xpToReach(6)));
    await store.saveThemeId('synthwave');
    await tester.pumpWidget(HisscoreApp(highScoreStore: store));
    await tester.pump();
    await tester.pump();

    expect(RetroColors.current, GameTheme.synthwave);
  });

  testWidgets('a level-up on the game-over card names what it unlocked', (
    tester,
  ) async {
    final store = InMemoryHighScoreStore();
    // One XP short of level 2; the run's apple pays it.
    await store.saveProgress(const PlayerProgress(xp: 99));
    await tester.pumpWidget(
      HisscoreApp(
        highScoreStore: store,
        engineFactory: () => SnakeEngine(
          columns: 6,
          rows: 6,
          firstFoodDistance: 1,
          random: Random(1),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('PLAY'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1300));
    // Wait out the slow-motion beat before the card appears.
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('GAME OVER'), findsOneWidget);
    expect(find.text('LEVEL UP! LEVEL 2'), findsOneWidget);
    expect(find.text('UNLOCKED: AMBER THEME'), findsOneWidget);
  });
}
