import 'online_scores.dart';

/// Where a finished run landed on a board.
///
/// The end screen's job is to make the next run happen, and "12 points
/// behind #8" does that better than any number the run itself
/// produced: it is a target, it is close, and it is somebody else.
class RunStanding {
  const RunStanding({
    required this.rank,
    required this.board,
    required this.pointsBehind,
  });

  /// 1-based place on the board.
  final int rank;

  /// What to call the board out loud, e.g. `THE DAILY`.
  final String board;

  /// How far behind the place above, or null at the top.
  final int? pointsBehind;

  bool get isTop => rank == 1;

  /// The one line the card shows.
  String get line => isTop
      ? '#1 ON $board'
      : '$pointsBehind ${pointsBehind == 1 ? 'POINT' : 'POINTS'}'
            ' BEHIND #${rank - 1} ON $board';

  /// Works out where [score] sits among [entries], which the boards
  /// return highest first.
  ///
  /// Computed from the scores alone rather than by looking for the
  /// player's own row: a submit that has not propagated yet, a board
  /// that trims to a top N, or two players on the same score would all
  /// break a search by id, and none of them change the answer.
  static RunStanding? of({
    required List<BoardEntry> entries,
    required int score,
    required String board,
  }) {
    if (entries.isEmpty) return null;
    final above = entries.where((e) => e.score > score).toList();
    if (above.isEmpty) {
      return RunStanding(rank: 1, board: board, pointsBehind: null);
    }
    return RunStanding(
      rank: above.length + 1,
      board: board,
      pointsBehind: above.last.score - score,
    );
  }
}
