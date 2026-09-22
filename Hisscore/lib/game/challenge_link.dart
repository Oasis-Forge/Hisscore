import 'challenge_code.dart';

/// Turns a [ChallengeCode] into something a friend can tap, and reads
/// one back out of whatever arrives.
///
/// Two shapes, because neither one is enough on its own:
///
/// - **`hisscore://c/C7K3-F9QX`** always opens the app, with no domain
///   to own and nothing to verify. But most chat apps will not make a
///   custom scheme tappable, so it is rarely what gets sent.
/// - **`https://oasis-forge.github.io/Hisscore/c/?k=C7K3-F9QX`** is a
///   link everything linkifies, and it lands somewhere useful for a
///   person who does not have the game. It is *not* a verified Android
///   App Link yet — that needs `assetlinks.json` at the domain root and
///   the Play signing fingerprint, neither of which exists — so today it
///   opens the page, and the page offers the `hisscore://` link.
///
/// No Flutter dependency, like the engine and the code itself.
abstract final class ChallengeLink {
  /// The app's own scheme. Not registered with anyone; collisions are
  /// possible in principle and have never mattered in practice.
  static const scheme = 'hisscore';

  /// Marks a challenge link in both shapes, so one reader handles them.
  static const marker = 'c';

  static const webHost = 'oasis-forge.github.io';
  static const webPath = '/Hisscore/$marker/';

  /// The code rides in a query parameter rather than the path so the
  /// page is a plain static file with nothing to route.
  static const webParam = 'k';

  /// The one that always opens the app.
  static String app(ChallengeCode code) => '$scheme://$marker/${code.text}';

  /// The one that is tappable everywhere.
  static String web(ChallengeCode code) =>
      'https://$webHost$webPath?$webParam=${code.text}';

  /// Reads a code out of a link, a bare code, or a message containing
  /// either.
  ///
  /// Forgiving on purpose. This is fed by three different things that
  /// have no idea about each other: an Android intent, the route string
  /// the engine hands over on a cold start (which is a path, with no
  /// scheme on it), and whatever a player pasted into ENTER CODE —
  /// which is as likely to be a whole forwarded message as a code.
  /// Returns null when there is no valid code in it.
  static ChallengeCode? parse(String input) {
    for (final token in _candidates(input)) {
      final code = ChallengeCode.parse(token);
      if (code != null) return code;
    }
    return null;
  }

  /// Every substring worth trying as a code, best guess first.
  static Iterable<String> _candidates(String input) sync* {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return;

    // A whole message: try each word, so a link buried in "beat this:
    // <link> 🐍" is found. Done first because a message that contains a
    // link also contains words that are not one.
    final words = trimmed.split(RegExp(r'\s+'));
    if (words.length > 1) {
      for (final word in words) {
        yield* _fromUri(word);
      }
      return;
    }

    yield* _fromUri(trimmed);
    // A bare code, or anything else: let the code parser judge it.
    yield trimmed;
  }

  /// Punctuation a link picks up from the sentence around it. A link is
  /// usually pasted mid-message, so it arrives wearing whatever was
  /// written next to it.
  static final _wrapping = RegExp(
    r'^[(\[<"“'
    "'"
    r']+|[.,;:!?)\]>"”'
    "'"
    r']+$',
  );

  /// The code-shaped parts of one token, if it looks like a link.
  static Iterable<String> _fromUri(String token) sync* {
    final uri = Uri.tryParse(token.replaceAll(_wrapping, ''));
    if (uri == null) return;

    // `?k=CODE`, whichever shape it came in.
    final param = uri.queryParameters[webParam];
    if (param != null) yield param;

    // `hisscore://c/CODE`, `https://host/Hisscore/c/CODE`, and the
    // bare `/c/CODE` an engine route arrives as.
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.isNotEmpty) yield segments.last;

    // `hisscore://CODE` has no path at all — the code is the authority.
    if (uri.host.isNotEmpty && uri.host != webHost && uri.host != marker) {
      yield uri.host;
    }
  }
}
