import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisscore/game/challenge_code.dart';
import 'package:hisscore/game/game_session.dart';
import 'package:hisscore/game/haptics.dart';
import 'package:hisscore/game/high_score_store.dart';
import 'package:hisscore/game/online_scores.dart';
import 'package:hisscore/game/rival_run.dart';
import 'package:hisscore/game/snake_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A run that eats, and one that dies, both reach for hardware that is
  // not here.
  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('xyz.luan/audioplayers.global'),
          (call) async => null,
        );
  });

  const code = ChallengeCode(mode: GameMode.classic, seed: 4242);
  const other = ChallengeCode(mode: GameMode.endless, seed: 99);

  const rival = RivalRun(
    name: 'SAM',
    ticks: 40,
    score: 120,
    steers: [
      (tick: 3, direction: Direction.down),
      (tick: 9, direction: Direction.left),
    ],
  );

  GameSession session([HighScoreStore? store]) => GameSession(
    store: store ?? InMemoryHighScoreStore(),
    onlineScores: const NoopOnlineScoreBoard(),
    haptics: Haptics(impl: const _SilentHaptics()),
  );

  group('the race', () {
    test('a challenge with a rival has a ghost to run', () {
      final s = session()..startChallenge(code, rival: rival);
      addTearDown(s.dispose);

      expect(s.rival, rival);
      expect(s.ghostSnake, isNotEmpty);
      expect(s.ghostScore, 120);
    });

    test('a challenge without one does not', () {
      final s = session()..startChallenge(code);
      addTearDown(s.dispose);

      expect(s.rival, isNull);
      expect(s.ghostSnake, isEmpty);
      expect(s.ghostScore, isNull);
      expect(s.headToHead, isNull);
    });

    test('the ghost runs the board the code deals', () {
      // Not some other board: the rival's turns only mean anything
      // against the same food in the same places.
      final s = session()..startChallenge(code, rival: rival);
      addTearDown(s.dispose);

      expect(s.ghost!.columns, s.engine.columns);
      expect(s.ghost!.rows, s.engine.rows);
      expect(s.ghost!.mode, code.mode);
      expect(s.ghost!.foods.first.position, s.engine.foods.first.position);
    });

    test('and stops when their run ended, not when ours does', () {
      final s = session()..startChallenge(code, rival: rival);
      addTearDown(s.dispose);

      for (var i = 0; i < rival.ticks + 10; i++) {
        s.onTicker();
      }
      expect(s.ghost!.totalTicks, lessThanOrEqualTo(rival.ticks));
      expect(s.ghostSnake, isEmpty, reason: 'their run is over');
    });
  });

  group('the result', () {
    test('ahead, behind and level are each said plainly', () {
      final s = session()..startChallenge(code, rival: rival);
      addTearDown(s.dispose);

      s.engine.score = 200;
      expect(s.headToHead?.won, isTrue);
      expect(s.headToHead?.drew, isFalse);
      expect(s.headToHead?.theirs, 120);
      expect(s.headToHead?.name, 'SAM');

      s.engine.score = 120;
      expect(s.headToHead?.won, isFalse);
      expect(s.headToHead?.drew, isTrue);

      s.engine.score = 10;
      expect(s.headToHead?.won, isFalse);
      expect(s.headToHead?.drew, isFalse);
    });

    test('there is no result without a challenge', () {
      final s = session()..primaryAction();
      addTearDown(s.dispose);
      expect(s.headToHead, isNull);
      expect(s.myRun, isNull);
    });

    test('our own run comes back in the shape that goes in a link', () {
      final s = session()..startChallenge(code, rival: rival);
      addTearDown(s.dispose);

      s.onTicker();
      s.onTicker();
      final mine = s.myRun;
      expect(mine, isNotNull);
      expect(mine!.ticks, s.engine.totalTicks);
      expect(mine.score, s.engine.score);
      expect(mine.name, s.displayName);
    });
  });

  group('keeping a rival', () {
    test('a challenge raced once can be raced again from the menu', () async {
      // The link that carried them is not coming back, so the run has
      // to outlive it.
      final store = InMemoryHighScoreStore();
      final first = session(store)..startChallenge(code, rival: rival);
      await Future<void>.delayed(Duration.zero);
      first.dispose();

      final second = session(store);
      addTearDown(second.dispose);
      expect(await second.savedRivalFor(code), rival);
    });

    test('a rival is kept per challenge, not globally', () async {
      final store = InMemoryHighScoreStore();
      final s = session(store)..startChallenge(code, rival: rival);
      await Future<void>.delayed(Duration.zero);
      addTearDown(s.dispose);

      expect(await s.savedRivalFor(code), rival);
      expect(await s.savedRivalFor(other), isNull);
    });

    test('only the most recent handful are kept', () async {
      final store = InMemoryHighScoreStore();
      for (var i = 0; i < HighScoreStore.maxRivals + 5; i++) {
        await store.saveRival(
          'CODE-$i',
          RivalRun(name: 'P$i', ticks: 10, score: i),
        );
      }
      // The oldest fell off; the newest are all there.
      expect(await store.loadRival('CODE-0'), isNull);
      expect(await store.loadRival('CODE-4'), isNull);
      expect((await store.loadRival('CODE-5'))?.score, 5);
      expect(
        (await store.loadRival('CODE-${HighScoreStore.maxRivals + 4}'))?.score,
        HighScoreStore.maxRivals + 4,
      );
    });

    test('playing one again keeps it from falling off the end', () async {
      final store = InMemoryHighScoreStore();
      await store.saveRival(
        'OLDEST',
        const RivalRun(name: 'FIRST', ticks: 1, score: 1),
      );
      for (var i = 0; i < HighScoreStore.maxRivals - 1; i++) {
        await store.saveRival(
          'CODE-$i',
          RivalRun(name: 'P$i', ticks: 10, score: i),
        );
      }
      // Touch the oldest, then push one more in. The one that goes
      // should be the one nobody came back to.
      await store.saveRival(
        'OLDEST',
        const RivalRun(name: 'FIRST', ticks: 1, score: 1),
      );
      await store.saveRival(
        'NEWEST',
        const RivalRun(name: 'LAST', ticks: 1, score: 1),
      );

      expect(await store.loadRival('OLDEST'), isNotNull);
      expect(await store.loadRival('CODE-0'), isNull);
    });

    test('starting the daily forgets whoever we were racing', () {
      final s = session()..startChallenge(code, rival: rival);
      addTearDown(s.dispose);
      expect(s.rival, isNotNull);

      s.startDaily();
      expect(s.rival, isNull);
      expect(s.headToHead, isNull);
    });

    test('so does going back to the menu', () {
      final s = session()..startChallenge(code, rival: rival);
      addTearDown(s.dispose);

      s.returnToMenu();
      expect(s.rival, isNull);
      expect(s.challenge, isNull);
    });
  });
}

class _SilentHaptics implements HapticImpl {
  const _SilentHaptics();

  @override
  void light() {}

  @override
  void medium() {}

  @override
  void heavy() {}

  @override
  void selection() {}
}
