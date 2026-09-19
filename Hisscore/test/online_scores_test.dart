import 'package:flutter_test/flutter_test.dart';
import 'package:hisscore/game/online_scores.dart';
import 'package:hisscore/game/snake_engine.dart';

void main() {
  group('BoardId', () {
    test('daily and all-time ids are distinct and stable', () {
      expect(BoardId.daily(262).value, 'daily-262');
      expect(BoardId.allTime(GameMode.hardcore).value, 'alltime-hardcore');
      expect(BoardId.daily(1), BoardId.daily(1));
      expect(BoardId.daily(1), isNot(BoardId.daily(2)));
      expect(
        BoardId.allTime(GameMode.classic),
        isNot(BoardId.allTime(GameMode.zen)),
      );
    });
  });

  group('PlayerName', () {
    test('cleans to upper-case, allowed characters, one space, 12 long', () {
      expect(PlayerName.clean('  hassan  k!! '), 'HASSAN K');
      expect(PlayerName.clean('a<b>c'), 'ABC');
      expect(PlayerName.clean('very long nickname here'), 'VERY LONG NI');
      expect(PlayerName.clean('ok_name-1'), 'OK_NAME-1');
    });

    test('never returns something longer than the limit, or padded', () {
      final cut = PlayerName.clean('ABCDEFGHIJK LMNO');
      expect(cut.length, lessThanOrEqualTo(PlayerName.maxLength));
      expect(cut, cut.trim());
    });

    test('valid means 2-12 characters that are already clean', () {
      expect(PlayerName.isValid('AB'), isTrue);
      expect(PlayerName.isValid('A'), isFalse);
      expect(PlayerName.isValid(''), isFalse);
      expect(PlayerName.isValid('lower'), isFalse);
      expect(PlayerName.isValid('HAS<SAN>'), isFalse);
      expect(PlayerName.isValid('A' * 13), isFalse);
    });

    test('the default handle is stable and valid', () {
      final name = PlayerName.defaultFor('abc123XYZ');
      expect(name, 'PLAYER-ABC1');
      expect(name, PlayerName.defaultFor('abc123XYZ'));
      expect(PlayerName.isValid(name), isTrue);
      expect(PlayerName.isValid(PlayerName.defaultFor('')), isTrue);
    });
  });

  group('NoopOnlineScoreBoard', () {
    test('is unavailable and holds nothing', () async {
      const board = NoopOnlineScoreBoard();
      expect(board.available, isFalse);
      await board.submit(BoardId.daily(1), name: 'AB', score: 50);
      expect(await board.top(BoardId.daily(1)), isEmpty);
    });
  });

  group('InMemoryOnlineScoreBoard', () {
    final day = BoardId.daily(5);

    test('ranks entries highest first and honours the limit', () async {
      final board = InMemoryOnlineScoreBoard()
        ..seed(day, 'a', 'ANN', 30)
        ..seed(day, 'b', 'BOB', 90)
        ..seed(day, 'c', 'CAT', 60);
      final top = await board.top(day, limit: 2);
      expect(top.map((e) => e.name), ['BOB', 'CAT']);
    });

    test('a player only ever raises their own entry', () async {
      final board = InMemoryOnlineScoreBoard();
      await board.submit(day, name: 'ME', score: 100);
      await board.submit(day, name: 'ME', score: 40);
      expect((await board.top(day)).single.score, 100);
      await board.submit(day, name: 'ME', score: 150);
      expect((await board.top(day)).single.score, 150);
    });

    test('boards are separate', () async {
      final board = InMemoryOnlineScoreBoard();
      await board.submit(day, name: 'ME', score: 10);
      expect(await board.top(BoardId.daily(6)), isEmpty);
      expect(await board.top(BoardId.allTime(GameMode.classic)), isEmpty);
    });

    test('rejects invalid names and negative scores', () async {
      final board = InMemoryOnlineScoreBoard();
      await board.submit(day, name: 'bad name!', score: 10);
      await board.submit(day, name: 'OK', score: -1);
      expect(await board.top(day), isEmpty);
    });

    test('does nothing when signed out', () async {
      final board = InMemoryOnlineScoreBoard(playerId: null);
      await board.submit(day, name: 'ME', score: 10);
      expect(await board.top(day), isEmpty);
    });
  });
}
