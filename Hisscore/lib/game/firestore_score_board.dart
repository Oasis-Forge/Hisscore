import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'online_scores.dart';

/// Boards stored in Cloud Firestore, one document per player per board:
/// `boards/{boardId}/entries/{playerUid}` with `{name, score, updatedAt}`.
/// See `firebase/firestore.rules` for what the server allows.
class FirestoreScoreBoard implements OnlineScoreBoard {
  FirestoreScoreBoard(this._db, {required this.playerId});

  final FirebaseFirestore _db;

  @override
  bool get available => true;

  @override
  final String playerId;

  CollectionReference<Map<String, dynamic>> _entries(BoardId board) =>
      _db.collection('boards').doc(board.value).collection('entries');

  @override
  Future<void> submit(
    BoardId board, {
    required String name,
    required int score,
  }) async {
    if (!PlayerName.isValid(name) || score < 0) return;
    final ref = _entries(board).doc(playerId);
    final existing = await ref.get();
    var best = score;
    if (existing.exists) {
      final data = existing.data()!;
      final had = (data['score'] as num?)?.toInt() ?? 0;
      // A row only ever goes up (the rules require it too).
      if (had >= best) best = had;
      if (best == had && data['name'] == name) return;
    }
    await ref.set({
      'name': name,
      'score': best,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<List<BoardEntry>> top(BoardId board, {int limit = 20}) async {
    final snapshot = await _entries(
      board,
    ).orderBy('score', descending: true).limit(limit).get();
    return [
      for (final doc in snapshot.docs)
        BoardEntry(
          playerId: doc.id,
          name: (doc.data()['name'] as String?) ?? '?',
          score: (doc.data()['score'] as num?)?.toInt() ?? 0,
        ),
    ];
  }
}

/// The board the app actually holds. It starts as "no boards", connects to
/// Firebase in the background, and switches over (telling listeners) once
/// it has signed in anonymously. A missing config, no network, or any
/// failure just leaves it offline and retries a few times; the game never
/// waits on it.
class FirebaseScoreBoard extends ChangeNotifier implements OnlineScoreBoard {
  FirebaseScoreBoard({
    this.retryDelays = const [
      Duration(seconds: 15),
      Duration(seconds: 60),
      Duration(minutes: 5),
    ],
  });

  /// How long to wait before each further attempt after a failure.
  final List<Duration> retryDelays;

  OnlineScoreBoard _inner = const NoopOnlineScoreBoard();
  Timer? _retry;
  bool _connecting = false;
  bool _disposed = false;

  @override
  bool get available => _inner.available;

  @override
  String? get playerId => _inner.playerId;

  /// Starts connecting. Safe to call more than once.
  Future<void> connect() => _connect(0);

  Future<void> _connect(int attempt) async {
    if (_connecting || _disposed || _inner.available) return;
    _connecting = true;
    try {
      if (Firebase.apps.isEmpty) await Firebase.initializeApp();
      final auth = FirebaseAuth.instance;
      final user =
          auth.currentUser ??
          (await auth.signInAnonymously().timeout(
            const Duration(seconds: 15),
          )).user;
      if (user == null) throw StateError('anonymous sign-in returned no user');
      _inner = FirestoreScoreBoard(
        FirebaseFirestore.instance,
        playerId: user.uid,
      );
      if (!_disposed) notifyListeners();
    } catch (e) {
      debugPrint('Online boards unavailable: $e');
      if (attempt < retryDelays.length && !_disposed) {
        _retry = Timer(retryDelays[attempt], () {
          unawaited(_connect(attempt + 1));
        });
      }
    } finally {
      _connecting = false;
    }
  }

  @override
  Future<void> submit(
    BoardId board, {
    required String name,
    required int score,
  }) => _inner.submit(board, name: name, score: score);

  @override
  Future<List<BoardEntry>> top(BoardId board, {int limit = 20}) =>
      _inner.top(board, limit: limit);

  @override
  void dispose() {
    _disposed = true;
    _retry?.cancel();
    super.dispose();
  }
}
