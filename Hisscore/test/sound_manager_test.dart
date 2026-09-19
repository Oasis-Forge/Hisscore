import 'package:flutter_test/flutter_test.dart';
import 'package:hisscore/game/food_types.dart';
import 'package:hisscore/game/sound_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('music layers build up with the combo', () {
    expect(SoundManager.musicLayersForCombo(0), 1);
    expect(SoundManager.musicLayersForCombo(1), 1);
    expect(SoundManager.musicLayersForCombo(2), 2);
    expect(SoundManager.musicLayersForCombo(3), 2);
    expect(SoundManager.musicLayersForCombo(4), 3);
    expect(SoundManager.musicLayersForCombo(9), 3);
  });

  test('every pickup has its own sound', () {
    final names = {
      for (final t in FoodType.values) SoundManager.pickupSound(t),
    };
    expect(names.length, FoodType.values.length);
    expect(SoundManager.pickupSound(FoodType.apple), 'eat');
    expect(SoundManager.pickupSound(FoodType.shield), 'shield');
  });

  test('music calls are harmless without an audio backend', () async {
    final sound = SoundManager();
    sound.syncMusic(playing: true, combo: 5);
    sound.syncMusic(playing: false, combo: 0);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await sound.dispose();
  });
}
