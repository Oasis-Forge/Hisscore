import 'package:flutter_test/flutter_test.dart';
import 'package:hisscore/game/challenge_code.dart';
import 'package:hisscore/game/challenge_link.dart';
import 'package:hisscore/game/snake_engine.dart';

void main() {
  const code = ChallengeCode(mode: GameMode.hardcore, seed: 123456);
  final text = code.text;

  group('building', () {
    test('the app link carries the code after the marker', () {
      expect(ChallengeLink.app(code), 'hisscore://c/$text');
    });

    test('the web link is a real https url on the pages site', () {
      final uri = Uri.parse(ChallengeLink.web(code));
      expect(uri.scheme, 'https');
      expect(uri.host, 'oasis-forge.github.io');
      expect(uri.path, '/Hisscore/c/');
      expect(uri.queryParameters['k'], text);
    });

    test('a code with a dash in it survives the round trip', () {
      // Every code has one, and a dash is legal unescaped in both a
      // path segment and a query value — worth pinning, because
      // percent-escaping it would still parse and would still look
      // wrong in a message.
      expect(text, contains('-'));
      expect(ChallengeLink.app(code), contains(text));
      expect(ChallengeLink.web(code), contains(text));
    });
  });

  group('reading', () {
    test('its own two shapes', () {
      expect(ChallengeLink.parse(ChallengeLink.app(code)), code);
      expect(ChallengeLink.parse(ChallengeLink.web(code)), code);
    });

    test('a bare code, so one reader serves the paste box too', () {
      expect(ChallengeLink.parse(text), code);
      expect(ChallengeLink.parse(text.toLowerCase()), code);
      expect(ChallengeLink.parse('  $text  '), code);
    });

    test('the path an engine route arrives as, with no scheme on it', () {
      // A cold start hands over the intent's path, not the whole URI.
      expect(ChallengeLink.parse('/c/$text'), code);
      expect(ChallengeLink.parse('/Hisscore/c/?k=$text'), code);
    });

    test('the code as the authority, for hisscore://CODE', () {
      expect(ChallengeLink.parse('hisscore://$text'), code);
    });

    test('a link buried in a forwarded message', () {
      expect(
        ChallengeLink.parse(
          'HISCORE challenge $text — HARDCORE — Score 420 🐍\n'
          'Beat it: ${ChallengeLink.web(code)}',
        ),
        code,
      );
    });

    test('a link with a sentence stop stuck to the end of it', () {
      expect(ChallengeLink.parse('try ${ChallengeLink.web(code)}.'), code);
      expect(ChallengeLink.parse('(${ChallengeLink.web(code)})'), code);
    });

    test('every mode makes it round the trip', () {
      for (final mode in GameMode.values) {
        final one = ChallengeCode(mode: mode, seed: 99);
        expect(ChallengeLink.parse(ChallengeLink.app(one)), one);
        expect(ChallengeLink.parse(ChallengeLink.web(one)), one);
      }
    });

    test('the seed survives at both ends of its range', () {
      for (final seed in [0, 1, ChallengeCode.seedLimit - 1]) {
        final one = ChallengeCode(mode: GameMode.zen, seed: seed);
        expect(ChallengeLink.parse(ChallengeLink.web(one)), one);
      }
    });
  });

  group('refusing', () {
    test('nothing, and nothing but space', () {
      expect(ChallengeLink.parse(''), isNull);
      expect(ChallengeLink.parse('   \n '), isNull);
    });

    test('a link to the site that is not a challenge', () {
      expect(
        ChallengeLink.parse('https://oasis-forge.github.io/Hisscore/'),
        isNull,
      );
    });

    test('a code with a character mistyped', () {
      // The check character is the point of the format; a link must not
      // be a way around it.
      final broken = text.replaceRange(1, 2, text[1] == '0' ? '1' : '0');
      expect(broken, isNot(text));
      expect(ChallengeLink.parse('hisscore://c/$broken'), isNull);
    });

    test('a message with no code anywhere in it', () {
      expect(ChallengeLink.parse('beat this if you can'), isNull);
      expect(ChallengeLink.parse('https://example.com/c/NOPE'), isNull);
    });

    test('a mode letter that is not a mode', () {
      // B is in the alphabet and is not a mode. Built with a valid
      // check character so it is the mode that fails, not the checksum.
      final body = 'B${text.replaceAll('-', '').substring(1, 7)}';
      final candidate = ChallengeCode.parse('$body?');
      expect(candidate, isNull);
      expect(ChallengeLink.parse('hisscore://c/$body'), isNull);
    });
  });
}
