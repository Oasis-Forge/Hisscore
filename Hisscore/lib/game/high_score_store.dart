import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'quests.dart';
import 'run_log.dart';
import 'snake_engine.dart';

// ─── Score entry for the top-5 leaderboard ──────────

class ScoreEntry {
  const ScoreEntry({
    required this.score,
    this.level = 1,
    this.mode = 'CLASSIC',
  });

  final int score;
  final int level;
  final String mode;

  Map<String, dynamic> toJson() => {
    'score': score,
    'level': level,
    'mode': mode,
  };

  factory ScoreEntry.fromJson(Map<String, dynamic> json) => ScoreEntry(
    score: json['score'] as int? ?? 0,
    level: json['level'] as int? ?? 1,
    mode: json['mode'] as String? ?? 'CLASSIC',
  );
}

// ─── Cumulative stats ───────────────────────────────

class GameStats {
  GameStats({
    this.gamesPlayed = 0,
    this.totalApples = 0,
    this.bestCombo = 0,
    this.powerUps = 0,
    this.bestCloseCalls = 0,
    this.challengesPlayed = 0,
    Set<String>? modesPlayed,
  }) : modesPlayed = modesPlayed ?? {};

  int gamesPlayed;
  int totalApples;
  int bestCombo;

  /// Lifetime pickups taken, and the most close calls steered out of in
  /// any one run. Both exist for the milestones; nothing else reads
  /// them yet.
  int powerUps;
  int bestCloseCalls;

  /// Friends' challenge codes played to the end.
  int challengesPlayed;

  /// [GameMode.name]s this player has finished a run in.
  Set<String> modesPlayed;

  /// Folds a finished run in.
  ///
  /// Both stores call this rather than each doing the arithmetic, so
  /// the in-memory one and the real one cannot drift over what a run
  /// counts for — which they had already started to, before there was
  /// anything here to drift about.
  void record(SnakeEngine engine, {bool challenge = false}) {
    gamesPlayed++;
    totalApples += engine.totalApplesEaten;
    if (engine.bestCombo > bestCombo) bestCombo = engine.bestCombo;
    powerUps += engine.powerUpsCollected;
    if (engine.closeCalls > bestCloseCalls) {
      bestCloseCalls = engine.closeCalls;
    }
    if (challenge) challengesPlayed++;
    modesPlayed = {...modesPlayed, engine.mode.name};
  }

  Map<String, dynamic> toJson() => {
    'gamesPlayed': gamesPlayed,
    'totalApples': totalApples,
    'bestCombo': bestCombo,
    'powerUps': powerUps,
    'bestCloseCalls': bestCloseCalls,
    'challengesPlayed': challengesPlayed,
    'modesPlayed': modesPlayed.toList(),
  };

  factory GameStats.fromJson(Map<String, dynamic> json) => GameStats(
    gamesPlayed: json['gamesPlayed'] as int? ?? 0,
    totalApples: json['totalApples'] as int? ?? 0,
    bestCombo: json['bestCombo'] as int? ?? 0,
    powerUps: json['powerUps'] as int? ?? 0,
    bestCloseCalls: json['bestCloseCalls'] as int? ?? 0,
    challengesPlayed: json['challengesPlayed'] as int? ?? 0,
    modesPlayed: {
      for (final m in (json['modesPlayed'] as List? ?? [])) m as String,
    },
  );
}

// ─── Daily challenge state ───────────────────────────

class DailyState {
  const DailyState({
    this.lastPlayedKey,
    this.lastScore = 0,
    this.currentStreak = 0,
    this.bestStreak = 0,
    this.freezes = 0,
  });

  /// dateKey (e.g. "2026-03-14") of the last completed daily run.
  final String? lastPlayedKey;
  final int lastScore;
  final int currentStreak;
  final int bestStreak;

  /// Days banked against a missed daily: earned one per seven days of
  /// streak, spent without being asked.
  final int freezes;

  Map<String, dynamic> toJson() => {
    'lastPlayedKey': lastPlayedKey,
    'lastScore': lastScore,
    'currentStreak': currentStreak,
    'bestStreak': bestStreak,
    'freezes': freezes,
  };

  factory DailyState.fromJson(Map<String, dynamic> json) => DailyState(
    lastPlayedKey: json['lastPlayedKey'] as String?,
    lastScore: json['lastScore'] as int? ?? 0,
    currentStreak: json['currentStreak'] as int? ?? 0,
    bestStreak: json['bestStreak'] as int? ?? 0,
    freezes: json['freezes'] as int? ?? 0,
  );
}

// ─── Abstract store ─────────────────────────────────

abstract class HighScoreStore {
  Future<int> load();
  Future<void> save(int score);
  Future<List<ScoreEntry>> loadTopScores();
  Future<void> saveScoreEntry(ScoreEntry entry);
  Future<GameStats> loadStats();
  Future<void> updateStats(SnakeEngine engine, {bool challenge = false});
  Future<DailyState> loadDailyState();
  Future<void> saveDailyState(DailyState state);

  /// Id of the chosen [GameTheme] (see `ui/theme.dart`), or null if the
  /// player has never picked one. Kept as a plain string so this layer
  /// stays free of UI types.
  Future<String?> loadThemeId();
  Future<void> saveThemeId(String id);

  /// Id of the chosen snake skin (see `ui/snake_skin.dart`), or null.
  Future<String?> loadSkinId();
  Future<void> saveSkinId(String id);

  /// The public handle shown on the global boards, or null if the player
  /// has not chosen one (a default is derived from their player id).
  Future<String?> loadPlayerName();
  Future<void> savePlayerName(String name);

  /// XP, level and today's quest state.
  Future<PlayerProgress> loadProgress();
  Future<void> saveProgress(PlayerProgress progress);

  /// The best daily run on this device, kept as a replayable log so it
  /// can be raced against. One only: a ghost from yesterday is a ghost
  /// of a different board. Null when there is none, or none worth
  /// keeping.
  Future<RunLog?> loadDailyGhost();
  Future<void> saveDailyGhost(RunLog log);

  /// Whether the player agreed to their name and score going on the
  /// public boards.
  ///
  /// **Null means they have never been asked**, and is not the same as
  /// no: nothing is sent until there is an actual answer. Anything that
  /// treats null as consent has misread this.
  Future<bool?> loadLeaderboardOptIn();
  Future<void> saveLeaderboardOptIn(bool value);
}

// ─── In-memory (testing) ────────────────────────────

class InMemoryHighScoreStore implements HighScoreStore {
  InMemoryHighScoreStore([this.value = 0]);

  int value;
  final List<ScoreEntry> _scores = [];
  final GameStats _stats = GameStats();
  DailyState _daily = const DailyState();
  String? _themeId;
  String? _skinId;
  String? _playerName;
  PlayerProgress _progress = const PlayerProgress();
  String? _ghost;
  bool? _optIn;

  @override
  Future<int> load() async => value;

  @override
  Future<void> save(int score) async {
    if (score > value) {
      value = score;
    }
  }

  @override
  Future<List<ScoreEntry>> loadTopScores() async =>
      List.of(_scores)..sort((a, b) => b.score.compareTo(a.score));

  @override
  Future<void> saveScoreEntry(ScoreEntry entry) async {
    _scores.add(entry);
    _scores.sort((a, b) => b.score.compareTo(a.score));
    while (_scores.length > 5) {
      _scores.removeLast();
    }
    if (entry.score > value) {
      value = entry.score;
    }
  }

  @override
  Future<GameStats> loadStats() async => _stats;

  @override
  Future<void> updateStats(SnakeEngine engine, {bool challenge = false}) async {
    _stats.record(engine, challenge: challenge);
  }

  @override
  Future<DailyState> loadDailyState() async => _daily;

  @override
  Future<void> saveDailyState(DailyState state) async => _daily = state;

  @override
  Future<String?> loadThemeId() async => _themeId;

  @override
  Future<void> saveThemeId(String id) async => _themeId = id;

  @override
  Future<String?> loadSkinId() async => _skinId;

  @override
  Future<void> saveSkinId(String id) async => _skinId = id;

  @override
  Future<String?> loadPlayerName() async => _playerName;

  @override
  Future<void> savePlayerName(String name) async => _playerName = name;

  @override
  Future<PlayerProgress> loadProgress() async => _progress;

  @override
  Future<void> saveProgress(PlayerProgress progress) async =>
      _progress = progress;

  @override
  Future<RunLog?> loadDailyGhost() async => RunLog.decode(_ghost);

  @override
  Future<void> saveDailyGhost(RunLog log) async => _ghost = log.encode();

  @override
  Future<bool?> loadLeaderboardOptIn() async => _optIn;

  @override
  Future<void> saveLeaderboardOptIn(bool value) async => _optIn = value;
}

// ─── SharedPreferences (production) ─────────────────

class SharedPreferencesHighScoreStore implements HighScoreStore {
  SharedPreferencesHighScoreStore({this.key = 'hisscore.high_score'});

  static const defaultKey = 'hisscore.high_score';
  static const _topScoresKey = 'hisscore.top_scores';
  static const _statsKey = 'hisscore.stats';
  static const _dailyKey = 'hisscore.daily_state';
  static const _themeKey = 'hisscore.theme';
  static const _skinKey = 'hisscore.skin';
  static const _playerNameKey = 'hisscore.player_name';
  static const _progressKey = 'hisscore.progress';
  static const _ghostKey = 'hisscore.daily_ghost';
  static const _optInKey = 'hisscore.leaderboard_opt_in';

  final String key;
  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  @override
  Future<int> load() async {
    await init();
    return _prefs!.getInt(key) ?? 0;
  }

  @override
  Future<void> save(int score) async {
    await init();
    final current = _prefs!.getInt(key) ?? 0;
    if (score > current) {
      await _prefs!.setInt(key, score);
    }
  }

  @override
  Future<List<ScoreEntry>> loadTopScores() async {
    await init();
    final raw = _prefs!.getString(_topScoresKey);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => ScoreEntry.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.score.compareTo(a.score));
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> saveScoreEntry(ScoreEntry entry) async {
    await init();
    final scores = await loadTopScores();
    scores.add(entry);
    scores.sort((a, b) => b.score.compareTo(a.score));
    final top5 = scores.take(5).toList();
    await _prefs!.setString(
      _topScoresKey,
      jsonEncode(top5.map((e) => e.toJson()).toList()),
    );
    // Also update the legacy single high score.
    await save(entry.score);
  }

  @override
  Future<GameStats> loadStats() async {
    await init();
    final raw = _prefs!.getString(_statsKey);
    if (raw == null) return GameStats();
    try {
      return GameStats.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return GameStats();
    }
  }

  @override
  Future<void> updateStats(SnakeEngine engine, {bool challenge = false}) async {
    await init();
    final stats = await loadStats();
    stats.record(engine, challenge: challenge);
    await _prefs!.setString(_statsKey, jsonEncode(stats.toJson()));
  }

  @override
  Future<DailyState> loadDailyState() async {
    await init();
    final raw = _prefs!.getString(_dailyKey);
    if (raw == null) return const DailyState();
    try {
      return DailyState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const DailyState();
    }
  }

  @override
  Future<void> saveDailyState(DailyState state) async {
    await init();
    await _prefs!.setString(_dailyKey, jsonEncode(state.toJson()));
  }

  @override
  Future<String?> loadThemeId() async {
    await init();
    return _prefs!.getString(_themeKey);
  }

  @override
  Future<void> saveThemeId(String id) async {
    await init();
    await _prefs!.setString(_themeKey, id);
  }

  @override
  Future<String?> loadSkinId() async {
    await init();
    return _prefs!.getString(_skinKey);
  }

  @override
  Future<void> saveSkinId(String id) async {
    await init();
    await _prefs!.setString(_skinKey, id);
  }

  @override
  Future<String?> loadPlayerName() async {
    await init();
    return _prefs!.getString(_playerNameKey);
  }

  @override
  Future<void> savePlayerName(String name) async {
    await init();
    await _prefs!.setString(_playerNameKey, name);
  }

  @override
  Future<PlayerProgress> loadProgress() async {
    await init();
    return PlayerProgress.decode(_prefs!.getString(_progressKey));
  }

  @override
  Future<void> saveProgress(PlayerProgress progress) async {
    await init();
    await _prefs!.setString(_progressKey, progress.encode());
  }

  @override
  Future<RunLog?> loadDailyGhost() async {
    await init();
    return RunLog.decode(_prefs!.getString(_ghostKey));
  }

  @override
  Future<void> saveDailyGhost(RunLog log) async {
    await init();
    await _prefs!.setString(_ghostKey, log.encode());
  }

  @override
  Future<bool?> loadLeaderboardOptIn() async {
    await init();
    // Absent on purpose until answered — see the interface.
    return _prefs!.getBool(_optInKey);
  }

  @override
  Future<void> saveLeaderboardOptIn(bool value) async {
    await init();
    await _prefs!.setBool(_optInKey, value);
  }
}
