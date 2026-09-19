import 'dart:math';

import 'snake_engine.dart';

/// A short code that names one exact game: a mode and a board seed. Give
/// it to a friend and they get the same food and obstacles, on the same
/// fixed-size grid as the daily, so scores are comparable.
///
/// Format: eight characters shown as `XXXX-XXXX`: a mode letter, a
/// six-character seed, and a check character that catches any single
/// mistyped character. The alphabet is Crockford base32, which has no
/// I, L, O or U, and `O` / `I` / `L` typed by hand are read as `0` / `1`,
/// so a code survives being read aloud or set in a font where 0 and O look
/// alike. No Flutter dependency, like the engine.
class ChallengeCode {
  const ChallengeCode({required this.mode, required this.seed});

  final GameMode mode;

  /// Below 2^30: exactly six base-32 characters.
  final int seed;

  static const seedLimit = 1 << 30;

  static const _alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';

  /// Mode letters, all of which are in [_alphabet].
  static const _modeLetters = {
    GameMode.classic: 'C',
    GameMode.adventure: 'A',
    GameMode.endless: 'E',
    GameMode.hardcore: 'H',
    GameMode.zen: 'Z',
  };

  /// A fresh code for a new game in [mode].
  factory ChallengeCode.random(GameMode mode, [Random? random]) =>
      ChallengeCode(
        mode: mode,
        seed: (random ?? Random.secure()).nextInt(seedLimit),
      );

  /// The code to show and share, e.g. `C7K3-F9QX`.
  String get text {
    var digits = '';
    for (var shift = 25; shift >= 0; shift -= 5) {
      digits += _alphabet[(seed >> shift) & 31];
    }
    final body = _modeLetters[mode]! + digits;
    final full = body + _check(body);
    return '${full.substring(0, 4)}-${full.substring(4)}';
  }

  /// Reads a code typed or pasted by a person: case, spaces and dashes are
  /// ignored, and look-alike letters are corrected. Returns null when it is
  /// not a valid code.
  static ChallengeCode? parse(String input) {
    final clean = input
        .toUpperCase()
        .replaceAll(RegExp('[^A-Z0-9]'), '')
        .replaceAll('O', '0')
        .replaceAll('I', '1')
        .replaceAll('L', '1');
    if (clean.length != 8) return null;
    final body = clean.substring(0, 7);
    final values = [for (final c in clean.split('')) _alphabet.indexOf(c)];
    if (values.contains(-1) || _check(body) != clean[7]) return null;
    final mode = _modeLetters.entries
        .where((e) => e.value == clean[0])
        .map((e) => e.key)
        .firstOrNull;
    if (mode == null) return null;
    var seed = 0;
    for (var i = 1; i < 7; i++) {
      seed = (seed << 5) | values[i];
    }
    return ChallengeCode(mode: mode, seed: seed);
  }

  /// Odd weights, so changing any one character always changes the sum
  /// modulo 32 and the typo is always caught.
  static const _weights = [1, 3, 5, 7, 9, 11, 13];

  /// A weighted sum of the characters, as one alphabet character.
  static String _check(String body) {
    var sum = 0;
    for (var i = 0; i < body.length; i++) {
      sum += _alphabet.indexOf(body[i]) * _weights[i];
    }
    return _alphabet[sum % 32];
  }

  @override
  bool operator ==(Object other) =>
      other is ChallengeCode && other.mode == mode && other.seed == seed;

  @override
  int get hashCode => Object.hash(mode, seed);

  @override
  String toString() => 'ChallengeCode($text)';
}
