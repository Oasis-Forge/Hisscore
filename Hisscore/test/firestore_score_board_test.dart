import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisscore/game/firestore_score_board.dart';
import 'package:hisscore/game/online_scores.dart';
import 'package:hisscore/game/snake_engine.dart';

void main() {
  final day = BoardId.daily(262);

  group('FirestoreScoreBoard', () {
    late FakeFirebaseFirestore db;
    late FirestoreScoreBoard me;

    setUp(() {
      db = FakeFirebaseFirestore();
      me = FirestoreScoreBoard(db, playerId: 'me');
    });

    Future<Map<String, dynamic>?> rowOf(String uid) async =>
        (await db
                .collection('boards')
                .doc(day.value)
                .collection('entries')
                .doc(uid)
                .get())
            .data();

    test('is available and reports its player id', () {
      expect(me.available, isTrue);
      expect(me.playerId, 'me');
    });

    test(
      'a first score creates the row at boards/{id}/entries/{uid}',
      () async {
        await me.submit(day, name: 'ACE', score: 120);
        final row = await rowOf('me');
        expect(row, isNotNull);
        expect(row!['name'], 'ACE');
        expect(row['score'], 120);
        expect(row.keys.toSet(), {'name', 'score', 'updatedAt'});
      },
    );

    test('a row only ever goes up', () async {
      await me.submit(day, name: 'ACE', score: 120);
      await me.submit(day, name: 'ACE', score: 40);
      expect((await rowOf('me'))!['score'], 120);
      await me.submit(day, name: 'ACE', score: 200);
      expect((await rowOf('me'))!['score'], 200);
    });

    test('a new name is saved without lowering the score', () async {
      await me.submit(day, name: 'ACE', score: 120);
      await me.submit(day, name: 'ACE PILOT', score: 30);
      final row = (await rowOf('me'))!;
      expect(row['name'], 'ACE PILOT');
      expect(row['score'], 120);
    });

    test('an unchanged score and name writes nothing new', () async {
      await me.submit(day, name: 'ACE', score: 120);
      final first = (await rowOf('me'))!['updatedAt'];
      await me.submit(day, name: 'ACE', score: 120);
      await me.submit(day, name: 'ACE', score: 5);
      expect((await rowOf('me'))!['updatedAt'], first);
    });

    test('invalid names and negative scores are not sent', () async {
      await me.submit(day, name: 'bad name!', score: 10);
      await me.submit(day, name: 'OK', score: -1);
      expect(await rowOf('me'), isNull);
    });

    test('boards are separate', () async {
      await me.submit(day, name: 'ACE', score: 10);
      await me.submit(
        BoardId.allTime(GameMode.hardcore),
        name: 'ACE',
        score: 99,
      );
      expect(await me.top(BoardId.daily(263)), isEmpty);
      expect((await me.top(day)).single.score, 10);
      expect(
        (await me.top(BoardId.allTime(GameMode.hardcore))).single.score,
        99,
      );
    });

    test('top ranks players highest first and honours the limit', () async {
      final ann = FirestoreScoreBoard(db, playerId: 'ann');
      final bob = FirestoreScoreBoard(db, playerId: 'bob');
      await ann.submit(day, name: 'ANN', score: 30);
      await bob.submit(day, name: 'BOB', score: 90);
      await me.submit(day, name: 'ME', score: 60);

      final all = await me.top(day);
      expect(all.map((e) => e.name), ['BOB', 'ME', 'ANN']);
      expect(all.map((e) => e.playerId), ['bob', 'me', 'ann']);
      expect(all.map((e) => e.score), [90, 60, 30]);
      expect((await me.top(day, limit: 2)).map((e) => e.name), ['BOB', 'ME']);
    });

    test('an empty board is an empty list', () async {
      expect(await me.top(day), isEmpty);
    });
  });

  group('FirebaseScoreBoard', () {
    test('starts with no boards and tells nobody', () {
      final board = FirebaseScoreBoard(retryDelays: const []);
      var notified = 0;
      board.addListener(() => notified++);
      expect(board.available, isFalse);
      expect(board.playerId, isNull);
      expect(notified, 0);
      board.dispose();
    });

    test(
      'with no Firebase to connect to it stays offline without failing',
      () async {
        final board = FirebaseScoreBoard(retryDelays: const []);
        await board.connect();
        expect(board.available, isFalse);
        // Offline, the calls are harmless.
        await board.submit(BoardId.daily(1), name: 'AB', score: 5);
        expect(await board.top(BoardId.daily(1)), isEmpty);
        board.dispose();
      },
    );
  });
}
