import 'challenge_code.dart';
import 'rival_run.dart';

/// A challenge and, when the link carried one, the run to race.
typedef Challenge = ({ChallengeCode code, RivalRun? rival});

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

  /// The sender's own run on that challenge, so the link is a race and
  /// not just a board. Optional: a link without it is still a
  /// challenge, and one whose run is too long to carry drops back to
  /// being one.
  static const rivalParam = 'r';

  /// The one that always opens the app.
  static String app(ChallengeCode code, {RivalRun? rival}) {
    final run = _carryable(rival);
    return '$scheme://$marker/${code.text}'
        '${run == null ? '' : '?$rivalParam=${Uri.encodeQueryComponent(run)}'}';
  }

  /// The one that is tappable everywhere.
  static String web(ChallengeCode code, {RivalRun? rival}) {
    final run = _carryable(rival);
    return 'https://$webHost$webPath?$webParam=${code.text}'
        '${run == null ? '' : '&$rivalParam=${Uri.encodeQueryComponent(run)}'}';
  }

  /// A rival's run, encoded, unless it is too big to survive the trip —
  /// see [RivalRun.maxEncodedLength].
  static String? _carryable(RivalRun? rival) {
    if (rival == null) return null;
    final encoded = rival.encode();
    return encoded.length > RivalRun.maxEncodedLength ? null : encoded;
  }

  /// Reads a challenge — and the sender's run on it, when the link
  /// carries one — out of a link, a bare code, or a message containing
  /// either.
  ///
  /// Forgiving on purpose. This is fed by three different things that
  /// have no idea about each other: an Android intent, the route string
  /// the engine hands over on a cold start (which is a path, with no
  /// scheme on it), and whatever a player pasted into ENTER CODE —
  /// which is as likely to be a whole forwarded message as a code.
  /// Returns null when there is no valid code in it.
  ///
  /// A damaged run is dropped and the challenge is kept: the board is
  /// the part that has to be right, and a race is the part that can be
  /// done without.
  /// A race beats a bare code, wherever each sits in the text. The
  /// shared message names the code in prose *before* it gives the link
  /// — "HISCORE challenge C7K3-F9QX ... Beat it: <link>" — so taking
  /// the first valid code would read the sentence and throw away the
  /// run attached to the thing that was actually sent to be tapped.
  static Challenge? read(String input) {
    Challenge? plain;
    for (final candidate in _candidates(input)) {
      final code = ChallengeCode.parse(candidate.code);
      if (code == null) continue;
      final rival = RivalRun.decode(candidate.rival);
      if (rival != null) return (code: code, rival: rival);
      plain ??= (code: code, rival: null);
    }
    return plain;
  }

  /// The challenge alone, for the callers that have no use for a rival.
  static ChallengeCode? parse(String input) => read(input)?.code;

  /// Every substring worth trying as a code, best guess first, each
  /// with whatever run was attached to the same token.
  static Iterable<({String code, String? rival})> _candidates(
    String input,
  ) sync* {
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
    yield (code: trimmed, rival: null);
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

  /// The code-shaped parts of one token, if it looks like a link, each
  /// paired with the run attached to that same link.
  static Iterable<({String code, String? rival})> _fromUri(String token) sync* {
    final uri = Uri.tryParse(token.replaceAll(_wrapping, ''));
    if (uri == null) return;
    final rival = uri.queryParameters[rivalParam];

    // `?k=CODE`, whichever shape it came in.
    final param = uri.queryParameters[webParam];
    if (param != null) yield (code: param, rival: rival);

    // `hisscore://c/CODE`, `https://host/Hisscore/c/CODE`, and the
    // bare `/c/CODE` an engine route arrives as.
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.isNotEmpty) yield (code: segments.last, rival: rival);

    // `hisscore://CODE` has no path at all — the code is the authority.
    if (uri.host.isNotEmpty && uri.host != webHost && uri.host != marker) {
      yield (code: uri.host, rival: rival);
    }
  }
}
