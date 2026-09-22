import 'challenge_code.dart';
import 'daily_challenge.dart';
import 'run_log.dart';
import 'snake_engine.dart';

/// Somebody else's run on a challenge, small enough to ride in a link.
///
/// A [RunLog] is self-contained — it carries the seed, the grid and the
/// mode, because it has to stand on its own in storage. Next to a
/// challenge code all three are already known, so a rival only needs
/// what the code cannot say: who, how long, how well, and every turn.
///
/// That, plus delta-encoded ticks, is the difference between a link a
/// messaging app will carry and one it will not.
class RivalRun {
  const RivalRun({
    required this.name,
    required this.ticks,
    required this.score,
    this.steers = const [],
  });

  /// Their display name. May be empty — a link from a player who never
  /// chose one is still a race.
  final String name;

  final int ticks;
  final int score;
  final List<Steer> steers;

  /// How long an encoded rival may be before it is left out of the
  /// link entirely.
  ///
  /// A good Classic run is about 300 characters and a Time Attack one
  /// about half that, so this is generous. But Zen never ends: a run
  /// left going for an hour would encode to tens of thousands, and a
  /// link that long is silently truncated by the app carrying it —
  /// which is worse than no ghost, because it arrives looking fine and
  /// races wrong. Over this, the challenge travels without the run.
  static const maxEncodedLength = 1500;

  factory RivalRun.of(SnakeEngine engine, {String name = ''}) => RivalRun(
    name: name,
    ticks: engine.totalTicks,
    score: engine.score,
    steers: List.of(engine.steers),
  );

  /// The same run as a [RunLog], which is what the ghost racer takes.
  ///
  /// The board comes from the code, exactly as it does when the
  /// challenge is played — same seed, same fixed grid — so the ghost
  /// runs the board the player is looking at.
  RunLog toLog(ChallengeCode code) => RunLog(
    seed: code.seed,
    columns: DailyChallenge.columnsFor(null),
    rows: DailyChallenge.rowsFor(null),
    mode: code.mode,
    ticks: ticks,
    score: score,
    steers: steers,
  );

  // ─── Storage ──────────────────────────────────────

  /// Direction letters, fixed forever: they are in saved and shared
  /// runs. The same four [RunLog] uses.
  static const _letters = {
    Direction.up: 'U',
    Direction.down: 'D',
    Direction.left: 'L',
    Direction.right: 'R',
  };

  /// `~` separates the fields: it is unreserved in a URL, so it
  /// survives being put in one without escaping, and it is not one of
  /// the characters a display name may contain.
  static const _sep = '~';

  /// `score~ticks~steers~name`.
  ///
  /// Ticks are stored as the gap since the last turn rather than the
  /// tick itself. The gaps are small — a player turns every few ticks —
  /// so late turns in a long run cost two characters instead of five.
  /// Name is last, so it is the only field that could ever contain a
  /// separator and it does not have to be escaped against one.
  String encode() {
    final buffer = StringBuffer();
    var last = 0;
    for (final steer in steers) {
      buffer.write(steer.tick - last);
      buffer.write(_letters[steer.direction]);
      last = steer.tick;
    }
    return [score, ticks, buffer, name].join(_sep);
  }

  /// The reverse, and forgiving in the same way [RunLog.decode] is:
  /// anything unreadable is a rival who simply is not there, never an
  /// exception into a game that was about to start.
  static RivalRun? decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final parts = raw.split(_sep);
      if (parts.length < 3) return null;
      final steers = _decodeSteers(parts[2]);
      if (steers == null) return null;
      final ticks = int.parse(parts[1]);
      if (ticks < 0) return null;
      // A turn after the run ended would replay past its own ending.
      if (steers.isNotEmpty && steers.last.tick > ticks) return null;
      return RivalRun(
        score: int.parse(parts[0]),
        ticks: ticks,
        // Anything after the third separator is part of the name, so a
        // name is never cut short by one that slipped through.
        name: parts.length > 3 ? parts.sublist(3).join(_sep) : '',
        steers: steers,
      );
    } catch (_) {
      return null;
    }
  }

  /// Null rather than a partial list when the text is malformed — half
  /// a rival's turns is a ghost that plays a different run.
  static List<Steer>? _decodeSteers(String raw) {
    final steers = <Steer>[];
    final digits = StringBuffer();
    var at = 0;
    for (final rune in raw.runes) {
      final char = String.fromCharCode(rune);
      final direction = _letters.entries
          .where((e) => e.value == char)
          .firstOrNull
          ?.key;
      if (direction == null) {
        if (char.codeUnitAt(0) < 0x30 || char.codeUnitAt(0) > 0x39) return null;
        digits.write(char);
        continue;
      }
      if (digits.isEmpty) return null;
      at += int.parse(digits.toString());
      steers.add((tick: at, direction: direction));
      digits.clear();
    }
    // Trailing digits with no letter after them: the text was cut off.
    return digits.isEmpty ? steers : null;
  }

  @override
  bool operator ==(Object other) =>
      other is RivalRun &&
      other.name == name &&
      other.ticks == ticks &&
      other.score == score &&
      other.steers.length == steers.length &&
      _sameSteers(other.steers);

  bool _sameSteers(List<Steer> other) {
    for (var i = 0; i < steers.length; i++) {
      if (other[i].tick != steers[i].tick ||
          other[i].direction != steers[i].direction) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(name, ticks, score, steers.length);

  @override
  String toString() => 'RivalRun($name, $score in $ticks ticks)';
}
