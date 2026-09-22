import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:hisscore/game/auto_player.dart';
import 'package:hisscore/game/challenge_code.dart';
import 'package:hisscore/game/challenge_link.dart';
import 'package:hisscore/game/daily_challenge.dart';
import 'package:hisscore/game/rival_run.dart';
import 'package:hisscore/game/snake_engine.dart';

/// A real run of [code]'s board, played by the bot, so the sizes and
/// the replay in these tests are a run and not a hand-written list.
({SnakeEngine engine, RivalRun rival}) botRun(
  ChallengeCode code, {
  String name = 'RIVAL',
  int maxTicks = 6000,
}) {
  final engine = SnakeEngine(
    columns: DailyChallenge.columnsFor(null),
    rows: DailyChallenge.rowsFor(null),
    mode: code.mode,
    fixedGrid: true,
    random: Random(code.seed),
  )..start();
  var guard = 0;
  while (engine.phase == GamePhase.running && guard++ < maxTicks) {
    final direction = AutoPlayer.chooseDirection(engine);
    if (direction != null) engine.queueTurn(direction);
    engine.tick();
  }
  return (engine: engine, rival: RivalRun.of(engine, name: name));
}

void main() {
  const code = ChallengeCode(mode: GameMode.classic, seed: 123456);

  group('encoding', () {
    test('a run survives the round trip exactly', () {
      final rival = botRun(code).rival;
      expect(rival.steers, isNotEmpty);
      expect(RivalRun.decode(rival.encode()), rival);
    });

    test('an empty run — quit before turning — survives too', () {
      const rival = RivalRun(name: 'NOBODY', ticks: 0, score: 0);
      expect(RivalRun.decode(rival.encode()), rival);
    });

    test('a name with a space survives', () {
      const rival = RivalRun(name: 'BIG SNAKE', ticks: 4, score: 10);
      expect(RivalRun.decode(rival.encode())?.name, 'BIG SNAKE');
    });

    test('no name at all is still a race', () {
      const rival = RivalRun(name: '', ticks: 4, score: 10);
      final back = RivalRun.decode(rival.encode());
      expect(back?.name, isEmpty);
      expect(back?.score, 10);
    });

    test('ticks are stored as gaps, so a late turn stays cheap', () {
      // The same two turns, one early and one very late. Delta encoding
      // is the whole reason a long run fits in a link, so it is worth
      // pinning rather than trusting.
      const early = RivalRun(
        name: '',
        ticks: 10,
        score: 0,
        steers: [(tick: 1, direction: Direction.up)],
      );
      const late = RivalRun(
        name: '',
        ticks: 9000,
        score: 0,
        steers: [(tick: 8999, direction: Direction.up)],
      );
      final earlySteers = early.encode().split('~')[2];
      final lateSteers = late.encode().split('~')[2];
      expect(earlySteers, '1U');
      expect(lateSteers, '8999U');

      // And the gap is what shrinks: a second turn right after a late
      // one costs two characters, not five.
      const pair = RivalRun(
        name: '',
        ticks: 9000,
        score: 0,
        steers: [
          (tick: 8999, direction: Direction.up),
          (tick: 9000, direction: Direction.left),
        ],
      );
      expect(pair.encode().split('~')[2], '8999U1L');
    });
  });

  group('refusing', () {
    test('nothing', () {
      expect(RivalRun.decode(null), isNull);
      expect(RivalRun.decode(''), isNull);
    });

    test('too few fields', () {
      expect(RivalRun.decode('100~50'), isNull);
    });

    test('a score or tick count that is not a number', () {
      expect(RivalRun.decode('lots~50~1U~X'), isNull);
      expect(RivalRun.decode('100~soon~1U~X'), isNull);
    });

    test('negative ticks', () {
      expect(RivalRun.decode('100~-5~1U~X'), isNull);
    });

    test('a turn after the run ended', () {
      // It would replay past its own ending, which is a ghost that
      // keeps playing after it died.
      expect(RivalRun.decode('100~10~99U~X'), isNull);
    });

    test('turns cut off mid-number', () {
      // Half a rival's turns is a ghost running a different race, so a
      // truncated link has to be refused outright rather than trimmed.
      expect(RivalRun.decode('100~50~1U2D3~X'), isNull);
    });

    test('a letter that is not a direction', () {
      expect(RivalRun.decode('100~50~1U2Q~X'), isNull);
    });

    test('a turn with no tick in front of it', () {
      expect(RivalRun.decode('100~50~UD~X'), isNull);
    });
  });

  group('replaying', () {
    test('the rival plays back the score it claims', () {
      // The point of carrying turns rather than a number: the score can
      // be recomputed instead of believed.
      final run = botRun(code);
      final replayed = run.rival.toLog(code).replay();
      expect(replayed.score, run.engine.score);
      expect(replayed.snake, run.engine.snake);
    });

    test('and on the board the code deals, not some other one', () {
      final run = botRun(code);
      final log = run.rival.toLog(code);
      expect(log.seed, code.seed);
      expect(log.mode, code.mode);
      expect(log.columns, DailyChallenge.columnsFor(null));
      expect(log.rows, DailyChallenge.rowsFor(null));
    });

    test('a claimed score that the turns do not earn is caught', () {
      final run = botRun(code);
      final lying = RivalRun(
        name: run.rival.name,
        ticks: run.rival.ticks,
        score: run.rival.score + 5000,
        steers: run.rival.steers,
      );
      expect(lying.toLog(code).replay().score, isNot(lying.score));
    });
  });

  group('riding in a link', () {
    test('there and back', () {
      final rival = botRun(code).rival;
      final read = ChallengeLink.read(ChallengeLink.web(code, rival: rival));
      expect(read?.code, code);
      expect(read?.rival, rival);
    });

    test('the app link carries one too', () {
      final rival = botRun(code).rival;
      final read = ChallengeLink.read(ChallengeLink.app(code, rival: rival));
      expect(read?.code, code);
      expect(read?.rival, rival);
    });

    test('a real run is short enough to be worth sending', () {
      // The number that decides whether this feature is a link or a
      // file transfer. A bot plays a long, busy run, so this is a
      // pessimistic reading of a human one.
      final link = ChallengeLink.web(code, rival: botRun(code).rival);
      expect(link.length, lessThan(600));
    });

    test('a run too long to carry leaves the challenge intact', () {
      // Zen never ends. A run left going all day encodes to tens of
      // thousands of characters, and a link that long is truncated by
      // whatever carries it — which arrives looking fine and races
      // wrong. Better to send a board with no ghost on it.
      final huge = RivalRun(
        name: 'MARATHON',
        ticks: 90000,
        score: 99999,
        steers: [
          for (var i = 1; i < 5000; i++)
            (tick: i * 3, direction: Direction.values[i % 4]),
        ],
      );
      expect(huge.encode().length, greaterThan(RivalRun.maxEncodedLength));

      final link = ChallengeLink.web(code, rival: huge);
      expect(link, isNot(contains('&r=')));
      final read = ChallengeLink.read(link);
      expect(read?.code, code, reason: 'still a challenge');
      expect(read?.rival, isNull, reason: 'just not a race');
    });

    test('a damaged run leaves the challenge intact', () {
      final link = '${ChallengeLink.web(code)}&r=100~50~1U2D3~X';
      final read = ChallengeLink.read(link);
      expect(read?.code, code);
      expect(read?.rival, isNull);
    });

    test('a link with no run at all is still read', () {
      final read = ChallengeLink.read(ChallengeLink.web(code));
      expect(read?.code, code);
      expect(read?.rival, isNull);
    });

    test('a run found in a whole forwarded message', () {
      final rival = botRun(code).rival;
      final message =
          'HISCORE challenge ${code.text} — CLASSIC — Score ${rival.score} 🐍\n'
          'Beat it: ${ChallengeLink.web(code, rival: rival)}';
      final read = ChallengeLink.read(message);
      expect(read?.code, code);
      expect(read?.rival, rival);
    });
  });
}
