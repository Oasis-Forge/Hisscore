import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:hisscore/game/challenge_code.dart';
import 'package:hisscore/game/snake_engine.dart';

void main() {
  test('a code is eight characters shown as XXXX-XXXX', () {
    final text = ChallengeCode(mode: GameMode.classic, seed: 12345).text;
    expect(text, matches(RegExp(r'^[A-Z0-9]{4}-[A-Z0-9]{4}$')));
    expect(text[0], 'C');
  });

  test('every mode and a spread of seeds survive a round trip', () {
    final random = Random(7);
    for (final mode in GameMode.values) {
      for (final seed in [
        0,
        1,
        35,
        36,
        ChallengeCode.seedLimit - 1,
        for (var i = 0; i < 40; i++) random.nextInt(ChallengeCode.seedLimit),
      ]) {
        final code = ChallengeCode(mode: mode, seed: seed);
        expect(ChallengeCode.parse(code.text), code, reason: '$mode $seed');
      }
    }
  });

  test('parsing ignores case, spaces and dashes', () {
    final code = ChallengeCode(mode: GameMode.hardcore, seed: 987654);
    final plain = code.text.replaceAll('-', '');
    expect(ChallengeCode.parse(plain.toLowerCase()), code);
    expect(ChallengeCode.parse(' ${code.text.toLowerCase()} '), code);
    expect(ChallengeCode.parse(plain.split('').join(' ')), code);
  });

  test('a single mistyped character is caught', () {
    final text = ChallengeCode(mode: GameMode.classic, seed: 424242).text;
    final plain = text.replaceAll('-', '');
    var caught = 0;
    var tried = 0;
    for (var i = 0; i < 7; i++) {
      for (final c in '0123456789ABCDEFGHJKMNPQRSTVWXYZ'.split('')) {
        if (c == plain[i]) continue;
        tried++;
        final typo = plain.replaceRange(i, i + 1, c);
        if (ChallengeCode.parse(typo) == null) caught++;
      }
    }
    // The weighted check character catches every single-character change,
    // including in the mode letter.
    expect(caught, tried);
  });

  test(
    'the alphabet has no look-alikes, and typed look-alikes are corrected',
    () {
      final code = ChallengeCode(mode: GameMode.classic, seed: 0);
      expect(code.text, isNot(matches(RegExp('[ILOU]'))));
      for (var seed = 0; seed < 5000; seed += 7) {
        final text = ChallengeCode(mode: GameMode.zen, seed: seed).text;
        expect(text.replaceAll('-', ''), isNot(matches(RegExp('[ILOU]'))));
      }
      // A code full of zeros and ones, typed with O, I and l instead.
      final zeros = ChallengeCode(mode: GameMode.classic, seed: 1 << 25 | 1);
      final typed = zeros.text.replaceAll('0', 'O').replaceAll('1', 'l');
      expect(typed, isNot(zeros.text));
      expect(ChallengeCode.parse(typed), zeros);
    },
  );

  test('junk is rejected', () {
    expect(ChallengeCode.parse(''), isNull);
    expect(ChallengeCode.parse('HELLO'), isNull);
    expect(ChallengeCode.parse('C000-0000000'), isNull);
    expect(ChallengeCode.parse('!!!!-????'), isNull);
    // Valid shape and check, but an unknown mode letter.
    expect(ChallengeCode.parse('Q000-0000'), isNull);
  });

  test('random codes are valid and reproducible from a seeded Random', () {
    final a = ChallengeCode.random(GameMode.endless, Random(3));
    final b = ChallengeCode.random(GameMode.endless, Random(3));
    expect(a, b);
    expect(a.seed, lessThan(ChallengeCode.seedLimit));
    expect(ChallengeCode.parse(a.text), a);
  });

  test('the same code gives the same first apple', () {
    final code = ChallengeCode(mode: GameMode.classic, seed: 5150);
    SnakeEngine play() => SnakeEngine(
      columns: 20,
      rows: 30,
      mode: code.mode,
      random: Random(code.seed),
    )..start();
    expect(play().food, play().food);
  });
}
