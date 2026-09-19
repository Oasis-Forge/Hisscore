import 'package:flutter_test/flutter_test.dart';
import 'package:hisscore/game/high_score_store.dart';
import 'package:hisscore/game/quests.dart';
import 'package:hisscore/main.dart';
import 'package:hisscore/ui/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  tearDown(() => RetroColors.current = GameTheme.phosphorGreen);

  test('theme ids are unique and unknown ids fall back to phosphor', () {
    final ids = GameTheme.all.map((t) => t.id).toSet();
    expect(ids.length, GameTheme.all.length);
    expect(GameTheme.byId('nope'), GameTheme.phosphorGreen);
    expect(GameTheme.byId(null), GameTheme.phosphorGreen);
    expect(GameTheme.byId('synthwave'), GameTheme.synthwave);
  });

  test('RetroColors follows the current theme', () {
    RetroColors.current = GameTheme.synthwave;
    expect(RetroColors.phosphor, GameTheme.synthwave.phosphor);
    expect(RetroColors.screen, GameTheme.synthwave.screen);
  });

  test('stores remember the theme id', () async {
    final memory = InMemoryHighScoreStore();
    expect(await memory.loadThemeId(), isNull);
    await memory.saveThemeId('amber');
    expect(await memory.loadThemeId(), 'amber');

    SharedPreferences.setMockInitialValues({});
    final prefs = SharedPreferencesHighScoreStore();
    expect(await prefs.loadThemeId(), isNull);
    await prefs.saveThemeId('gameboy');
    expect(await prefs.loadThemeId(), 'gameboy');
  });

  testWidgets('LOOK tab switches and saves the theme', (tester) async {
    final store = InMemoryHighScoreStore();
    await store.saveProgress(const PlayerProgress(xp: 100000));
    await tester.pumpWidget(HisscoreApp(highScoreStore: store));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('LOOK'));
    await tester.pump();
    expect(find.text('SELECT LOOK'), findsOneWidget);

    await tester.tap(find.text('SYNTHWAVE'));
    await tester.pump();

    expect(RetroColors.current, GameTheme.synthwave);
    expect(await store.loadThemeId(), 'synthwave');
  });

  testWidgets('a saved theme is applied on launch', (tester) async {
    final store = InMemoryHighScoreStore();
    await store.saveProgress(const PlayerProgress(xp: 100000));
    await store.saveThemeId('amber');
    await tester.pumpWidget(HisscoreApp(highScoreStore: store));
    await tester.pump();
    await tester.pump();

    expect(RetroColors.current, GameTheme.amberTerminal);
  });
}
