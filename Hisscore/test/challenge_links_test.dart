import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisscore/game/challenge_code.dart';
import 'package:hisscore/game/challenge_link.dart';
import 'package:hisscore/game/challenge_links.dart';
import 'package:hisscore/game/snake_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(PlatformChallengeLinks.channelName);
  const code = ChallengeCode(mode: GameMode.adventure, seed: 4242);

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  /// Answers `initialLink` with [link] until told otherwise.
  void platformOffers(String? link) {
    messenger.setMockMethodCallHandler(
      channel,
      (call) async => call.method == 'initialLink' ? link : null,
    );
  }

  /// What Android does when a link is tapped while the game is open.
  Future<void> platformSends(String link) {
    return messenger.handlePlatformMessage(
      PlatformChallengeLinks.channelName,
      const StandardMethodCodec().encodeMethodCall(MethodCall('link', link)),
      (_) {},
    );
  }

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  group('the link the app was opened with', () {
    test('is read and parsed', () async {
      platformOffers(ChallengeLink.app(code));
      final links = PlatformChallengeLinks();
      addTearDown(links.dispose);

      expect(await links.initial(), code);
    });

    test('is null when the app was opened normally', () async {
      platformOffers(null);
      final links = PlatformChallengeLinks();
      addTearDown(links.dispose);

      expect(await links.initial(), isNull);
    });

    test('is null, not a crash, when the channel is not there', () async {
      // Every platform but Android, and Android before the activity has
      // wired the channel up.
      messenger.setMockMethodCallHandler(channel, null);
      final links = PlatformChallengeLinks();
      addTearDown(links.dispose);

      expect(await links.initial(), isNull);
    });

    test('is null, not a crash, when the platform throws', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(code: 'nope');
      });
      final links = PlatformChallengeLinks();
      addTearDown(links.dispose);

      expect(await links.initial(), isNull);
    });
  });

  group('links that arrive while the game is running', () {
    test('reach the stream as codes', () async {
      platformOffers(null);
      final links = PlatformChallengeLinks();
      addTearDown(links.dispose);

      final seen = <ChallengeCode>[];
      final sub = links.incoming.listen(seen.add);
      addTearDown(sub.cancel);

      await platformSends(ChallengeLink.web(code));
      await pumpEventQueue();

      expect(seen, [code]);
    });

    test('a link that is not a challenge is dropped, not surfaced', () async {
      // The player tapped something. Telling them it was the wrong
      // something helps nobody, and an error card over a live run is
      // worse than nothing happening.
      platformOffers(null);
      final links = PlatformChallengeLinks();
      addTearDown(links.dispose);

      final seen = <ChallengeCode>[];
      final sub = links.incoming.listen(seen.add);
      addTearDown(sub.cancel);

      await platformSends('hisscore://c/NOT-ACODE');
      await platformSends('https://example.com/');
      await pumpEventQueue();

      expect(seen, isEmpty);
    });

    test('a second one arrives too', () async {
      platformOffers(null);
      final links = PlatformChallengeLinks();
      addTearDown(links.dispose);

      final seen = <ChallengeCode>[];
      final sub = links.incoming.listen(seen.add);
      addTearDown(sub.cancel);

      const other = ChallengeCode(mode: GameMode.zen, seed: 7);
      await platformSends(ChallengeLink.app(code));
      await platformSends(ChallengeLink.app(other));
      await pumpEventQueue();

      expect(seen, [code, other]);
    });

    test('nothing is delivered after dispose', () async {
      platformOffers(null);
      final links = PlatformChallengeLinks();
      final seen = <ChallengeCode>[];
      final sub = links.incoming.listen(seen.add);
      addTearDown(sub.cancel);

      links.dispose();
      await platformSends(ChallengeLink.app(code));
      await pumpEventQueue();

      expect(seen, isEmpty);
    });
  });

  test('the quiet one delivers nothing and finishes', () async {
    const links = NoChallengeLinks();
    expect(await links.initial(), isNull);
    expect(await links.incoming.toList(), isEmpty);
    links.dispose();
  });
}
