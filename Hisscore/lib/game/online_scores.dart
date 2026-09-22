import 'snake_engine.dart';

/// Which global board a score belongs to.
///
/// A daily board is one day's challenge, everyone on the same seed and
/// grid. An all-time board is the best score ever per mode.
class BoardId {
  const BoardId._(this.value);

  /// The daily challenge for [dayNumber] (see `DailyChallenge.dayNumber`).
  factory BoardId.daily(int dayNumber) => BoardId._('daily-$dayNumber');

  /// Best-ever scores in [mode].
  ///
  /// Lower-cased because a board id is a document key that outlives the
  /// enum spelling: `timeAttack` in Dart must not become a different
  /// board from the `timeattack` anybody would write by hand.
  factory BoardId.allTime(GameMode mode) =>
      BoardId._('alltime-${mode.name.toLowerCase()}');

  /// The stable id used as the document / collection key.
  final String value;

  @override
  bool operator ==(Object other) => other is BoardId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'BoardId($value)';
}

/// One row of a board.
class BoardEntry {
  const BoardEntry({
    required this.playerId,
    required this.name,
    required this.score,
  });

  final String playerId;
  final String name;
  final int score;
}

/// The public handle shown on boards. Kept short and plain: letters,
/// digits, space, underscore and dash, so there is nothing to render or
/// escape and no room for anything but a nickname.
abstract final class PlayerName {
  static const maxLength = 12;
  static const minLength = 2;

  /// Cleans up [input]: upper-cased, disallowed characters dropped, runs
  /// of spaces collapsed, and cut to [maxLength]. May return something
  /// shorter than [minLength]; check with [isValid].
  static String clean(String input) {
    final kept = input.toUpperCase().replaceAll(RegExp('[^A-Z0-9 _-]'), '');
    final collapsed = kept.replaceAll(RegExp(' +'), ' ').trim();
    return collapsed.length > maxLength
        ? collapsed.substring(0, maxLength).trim()
        : collapsed;
  }

  static bool isValid(String name) =>
      name.length >= minLength &&
      name.length <= maxLength &&
      clean(name) == name;

  /// A default handle for a player who has not picked one, derived from
  /// [playerId] so it stays the same between launches.
  static String defaultFor(String playerId) {
    final tail = playerId.replaceAll(RegExp('[^A-Za-z0-9]'), '').toUpperCase();
    final short = tail.length >= 4
        ? tail.substring(0, 4)
        : tail.padRight(4, '0');
    return 'PLAYER-$short';
  }
}

/// A global score board. The real one talks to a backend; the game only
/// ever sees this interface, so it works (with no board) when there is no
/// backend configured, and tests can use [InMemoryOnlineScoreBoard].
abstract class OnlineScoreBoard {
  /// Whether boards can be used at all. When false the UI hides them.
  bool get available;

  /// The signed-in (anonymous) player's id, once known.
  String? get playerId;

  /// Records [score] for [name] on [board]. Only ever raises a player's
  /// entry: a lower score than the one already there is ignored.
  Future<void> submit(
    BoardId board, {
    required String name,
    required int score,
  });

  /// The best [limit] entries on [board], highest first.
  Future<List<BoardEntry>> top(BoardId board, {int limit = 20});
}

/// Used when no backend is configured: nothing is available or stored.
class NoopOnlineScoreBoard implements OnlineScoreBoard {
  const NoopOnlineScoreBoard();

  @override
  bool get available => false;

  @override
  String? get playerId => null;

  @override
  Future<void> submit(
    BoardId board, {
    required String name,
    required int score,
  }) async {}

  @override
  Future<List<BoardEntry>> top(BoardId board, {int limit = 20}) async => [];
}

/// A board held in memory, for tests and previews.
class InMemoryOnlineScoreBoard implements OnlineScoreBoard {
  InMemoryOnlineScoreBoard({this.playerId = 'me', this.available = true});

  @override
  final String? playerId;

  @override
  final bool available;

  final Map<BoardId, Map<String, BoardEntry>> _boards = {};

  /// Adds another player, as if they had submitted, for tests.
  void seed(BoardId board, String id, String name, int score) {
    _boards.putIfAbsent(board, () => {})[id] = BoardEntry(
      playerId: id,
      name: name,
      score: score,
    );
  }

  @override
  Future<void> submit(
    BoardId board, {
    required String name,
    required int score,
  }) async {
    final id = playerId;
    if (id == null || !PlayerName.isValid(name) || score < 0) return;
    final entries = _boards.putIfAbsent(board, () => {});
    final existing = entries[id];
    if (existing != null && existing.score >= score) return;
    entries[id] = BoardEntry(playerId: id, name: name, score: score);
  }

  @override
  Future<List<BoardEntry>> top(BoardId board, {int limit = 20}) async {
    final all = (_boards[board]?.values.toList() ?? [])
      ..sort((a, b) => b.score.compareTo(a.score));
    return all.take(limit).toList();
  }
}
