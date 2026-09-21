import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'challenge_code.dart';
import 'daily_challenge.dart';
import 'food_types.dart';
import 'haptics.dart';
import 'high_score_store.dart';
import 'notification_service.dart';
import 'online_scores.dart';
import 'quests.dart';
import 'review_prompter.dart';
import 'snake_engine.dart';
import 'sound_manager.dart';

/// The grid a fresh engine should get. The page measures the screen;
/// the session only asks for the answer.
typedef GridSize = ({int columns, int rows});

/// One playing session: the engine, the ticker that drives it, and all
/// the persistence and progression hanging off a finished run.
///
/// Everything here used to live in `GamePage`, which meant none of it
/// could be exercised without pumping a widget. The split is by
/// responsibility: rules live in [SnakeEngine], running a game lives
/// here, and drawing it lives in the page. The visual flourishes a run
/// triggers — particles, popups, screen shake — stay in the page and are
/// reached through the callbacks below.
class GameSession extends ChangeNotifier {
  GameSession({
    required this.store,
    required this.onlineScores,
    this.engineFactory,
    SoundManager? sound,
    Haptics? haptics,
    ReviewPrompter? reviewPrompter,
    NotificationService? notifications,
    this.now = DateTime.now,
  }) : sound = sound ?? SoundManager(),
       haptics = haptics ?? Haptics.instance,
       reviewPrompter = reviewPrompter ?? ReviewPrompter(),
       notifications = notifications ?? NotificationService() {
    engine = engineFactory?.call() ?? SnakeEngine(mode: selectedMode);
    _onlineListenable?.addListener(_onOnlineChanged);
  }

  final HighScoreStore store;
  final OnlineScoreBoard onlineScores;
  final SnakeEngine Function()? engineFactory;
  final SoundManager sound;
  final Haptics haptics;
  final ReviewPrompter reviewPrompter;
  final NotificationService notifications;

  /// Wall clock, injectable so tests can pin "today" without waiting for
  /// midnight. The in-game clock is [SnakeEngine.elapsedMs]; this is only
  /// for calendar things (streaks, the daily) and input debouncing.
  final DateTime Function() now;

  // ─── Callbacks the page draws from ────────────────

  /// An apple or pickup was just eaten, worth [gained] points.
  void Function(FoodItem food, int gained)? onAte;

  /// Adventure advanced a level.
  void Function(int level)? onLevelUp;

  /// The snake was held on the brink and steered out of it.
  void Function()? onCloseCall;

  /// The score just passed the best this device had saved.
  void Function()? onNewBest;

  /// The run just ended.
  void Function()? onGameOver;

  /// A tick landed, so the page can restart its movement interpolation.
  void Function()? onTick;

  // ─── State ────────────────────────────────────────

  late SnakeEngine engine;
  Timer? _ticker;

  /// How big a new engine's grid should be, set by the page once it has
  /// measured itself. Null until then, and the engine's default wins.
  GridSize Function()? gridProvider;

  /// Whether [load] has come back. Before it does, everything below is
  /// a default rather than the player's own, which matters for anything
  /// that keys off "has this player played before".
  bool loaded = false;

  int highScore = 0;
  bool newHighScore = false;
  List<ScoreEntry> topScores = [];
  GameStats stats = GameStats();
  DailyState dailyState = const DailyState();
  PlayerProgress progress = const PlayerProgress();
  RunOutcome? outcome;

  GameMode selectedMode = GameMode.classic;
  bool isDailyRun = false;
  ChallengeCode? challenge;

  /// The player's chosen handle for the global boards, if any.
  String? playerName;

  /// The look the player last chose, as loaded from disk. Applying these
  /// is the page's job, because the palette and the skin are UI globals.
  String? savedThemeId;
  String? savedSkinId;

  /// When the current run started, so the tap that starts a game cannot
  /// immediately pause it again.
  DateTime? startedAt;

  /// The save kicked off by the run that just ended, while it is still
  /// running. Ending a run must not block the game-over card on disk,
  /// so the write is fired and forgotten — but it is still worth being
  /// able to wait for it, and tests have nothing else to wait on.
  Future<void>? saveInFlight;

  /// The page can go away mid-save. Notifying a disposed [ChangeNotifier]
  /// is an error, so the tail of a write that outlived its listener has
  /// to fall silent rather than throw.
  bool _disposed = false;

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  // ─── Derived ──────────────────────────────────────

  String get todayKey => DailyChallenge.dateKey(now());

  int get dailyDayNumber => DailyChallenge.dayNumber(now());

  /// Progress as of today: yesterday's quest state is dropped, XP kept.
  PlayerProgress get todayProgress => Quests.rolled(progress, todayKey);

  String get displayName =>
      playerName ?? PlayerName.defaultFor(onlineScores.playerId ?? '');

  bool get playedDailyToday => DailyChallenge.playedToday(
    lastPlayedKey: dailyState.lastPlayedKey,
    today: now(),
  );

  /// Zen mode never ends and scores climb forever — it doesn't compete
  /// on the leaderboard or count toward the high score.
  bool get countsForLeaderboard => engine.mode != GameMode.zen;

  // ═══════════════════════════════════════════════════
  // Loading
  // ═══════════════════════════════════════════════════

  Future<void> load() async {
    highScore = await store.load();
    topScores = await store.loadTopScores();
    stats = await store.loadStats();
    dailyState = await store.loadDailyState();
    savedThemeId = await store.loadThemeId();
    savedSkinId = await store.loadSkinId();
    playerName = await store.loadPlayerName();
    progress = await store.loadProgress();
    loaded = true;
    _notify();
  }

  /// Nobody has finished a run on this device yet, so the game should
  /// explain itself. False until [load] answers, so a returning player
  /// never sees the onboarding flash past.
  bool get isFirstTimePlayer => loaded && stats.gamesPlayed == 0;

  /// The boards, if they can change under us (the real one connects in the
  /// background); the no-op and test boards never change.
  Listenable? get _onlineListenable {
    final online = onlineScores;
    return online is Listenable ? online as Listenable : null;
  }

  void _onOnlineChanged() => _notify();

  // ═══════════════════════════════════════════════════
  // Starting and stopping a run
  // ═══════════════════════════════════════════════════

  /// Builds an engine sized to the current screen. Tests inject their
  /// own engine and keep whatever grid they asked for.
  SnakeEngine newEngine({
    GameMode? mode,
    Random? random,
    bool fixedGrid = false,
  }) {
    final injected = engineFactory;
    if (injected != null && random == null) return injected();
    // The daily and challenge codes are one fixed size on every device;
    // everything else is shaped to the screen.
    final grid = fixedGrid
        ? (columns: DailyChallenge.gridColumns, rows: DailyChallenge.gridRows)
        : gridProvider?.call();
    return SnakeEngine(
      columns: grid?.columns ?? 20,
      rows: grid?.rows ?? 20,
      mode: mode ?? selectedMode,
      random: random,
    );
  }

  /// The PLAY / PAUSE / RESUME button, and the space bar: whatever the
  /// one primary action means in the phase the game is in.
  void primaryAction() {
    if (engine.phase == GamePhase.running) {
      final started = startedAt;
      final justStarted =
          started != null &&
          now().difference(started) < const Duration(milliseconds: 400);
      if (justStarted) return;
      _pauseRun();
      _notify();
      return;
    }
    newHighScore = false;
    outcome = null;
    if (engine.phase == GamePhase.gameOver || engine.phase == GamePhase.ready) {
      // A fresh run always gets an engine sized to this screen.
      engine = newEngine();
      engine.mode = selectedMode;
      isDailyRun = false;
      challenge = null;
    }
    engine.start();
    startedAt = now();
    armTicker();
    _notify();
  }

  /// Starts today's daily challenge: a Classic run seeded from the date,
  /// on the fixed grid, so every device gets the same board all day.
  void startDaily() {
    _ticker?.cancel();
    final seed = DailyChallenge.seedForDay(dailyDayNumber);
    engine = newEngine(
      mode: GameMode.classic,
      random: Random(seed),
      fixedGrid: true,
    );
    engine.mode = GameMode.classic;
    selectedMode = GameMode.classic;
    isDailyRun = true;
    challenge = null;
    newHighScore = false;
    outcome = null;
    engine.start();
    startedAt = now();
    armTicker();
    _notify();
  }

  /// Starts the game a challenge code names: its mode, its seed, and the
  /// daily's fixed grid, so everyone playing the code plays one board.
  void startChallenge(ChallengeCode code) {
    _ticker?.cancel();
    engine = newEngine(
      mode: code.mode,
      random: Random(code.seed),
      fixedGrid: true,
    );
    engine.mode = code.mode;
    selectedMode = code.mode;
    isDailyRun = false;
    challenge = code;
    newHighScore = false;
    outcome = null;
    engine.start();
    startedAt = now();
    armTicker();
    _notify();
  }

  /// Back to a clean ready state for the menu.
  void returnToMenu() {
    _ticker?.cancel();
    engine = newEngine();
    engine.reset();
    engine.phase = GamePhase.ready;
    newHighScore = false;
    outcome = null;
    isDailyRun = false;
    challenge = null;
    _notify();
  }

  void setMode(GameMode mode) {
    selectedMode = mode;
    engine.mode = mode;
    _notify();
  }

  void turn(Direction direction) {
    final wasReady = engine.phase == GamePhase.ready;
    engine.queueTurn(direction);
    if (wasReady && engine.phase == GamePhase.running) {
      armTicker();
    }
    _notify();
  }

  /// Pauses a running game; does nothing in any other phase.
  void pause() {
    if (engine.phase != GamePhase.running) return;
    _pauseRun();
    _notify();
  }

  void _pauseRun() {
    engine.pause();
    _ticker?.cancel();
  }

  /// Leaving the foreground must not cost the player a run: a call or a
  /// notification would otherwise keep the ticker going and kill the
  /// snake off-screen.
  void handleAppBackgrounded() => pause();

  // ═══════════════════════════════════════════════════
  // The ticker
  // ═══════════════════════════════════════════════════

  @visibleForTesting
  void armTicker() {
    _ticker?.cancel();
    if (engine.phase != GamePhase.running) return;
    _ticker = Timer.periodic(engine.tickInterval, (_) => onTicker());
  }

  @visibleForTesting
  void onTicker() {
    final scoreBefore = engine.score;
    onTick?.call();
    engine.tick();

    final eaten = engine.lastEatenFood;
    if (engine.justAte && eaten != null) {
      unawaited(sound.playPickup(eaten.type));
      haptics.ate(eaten.type);
      if (engine.comboCount > 1) haptics.combo();
      onAte?.call(eaten, engine.score - scoreBefore);
    }

    if (engine.justSurvivedCloseCall) {
      unawaited(sound.playCloseCall());
      haptics.closeCall();
      onCloseCall?.call();
    }

    // Checked every tick, not only on an apple: a close call pays
    // points too, and the whole point of the label is that the player
    // learns about their new best while it is happening.
    _noteHighScore();

    // Speed changed → re-arm the ticker at the new interval.
    if (engine.justAte) armTicker();

    if (engine.levelJustAdvanced) {
      unawaited(sound.playLevelUp());
      haptics.levelUp();
      onLevelUp?.call(engine.level);
    }

    if (engine.phase == GamePhase.gameOver) {
      _ticker?.cancel();
      unawaited(sound.playGameOver());
      haptics.death();
      onGameOver?.call();
      saveInFlight = persistGameEnd();
    }

    _notify();
  }

  // ═══════════════════════════════════════════════════
  // Persistence
  // ═══════════════════════════════════════════════════

  /// Tracks a new high score in memory while the run is going.
  ///
  /// Writing to disk on every apple meant a store write (and a second
  /// prefs read from the review prompter) every tick or so late in a
  /// run. The number on screen is state, not storage — it gets flushed
  /// once, when the run ends.
  void _noteHighScore() {
    if (!countsForLeaderboard) return;
    if (engine.score <= highScore) return;
    // A best of zero is not a best, so a player's first ever points do
    // not get announced as beating anything.
    final worthSaying = highScore > 0 && !newHighScore;
    highScore = engine.score;
    newHighScore = true;
    if (worthSaying) {
      unawaited(sound.playNewBest());
      onNewBest?.call();
    }
  }

  Future<void> _persistHighScore() async {
    if (!countsForLeaderboard) return;
    if (engine.score > highScore) {
      highScore = engine.score;
      newHighScore = true;
    }
    if (!newHighScore) return;
    await store.save(highScore);
    unawaited(reviewPrompter.maybePrompt(gamesPlayed: stats.gamesPlayed));
  }

  @visibleForTesting
  Future<void> persistGameEnd() async {
    await _persistHighScore();
    if (countsForLeaderboard) {
      await store.saveScoreEntry(
        ScoreEntry(
          score: engine.score,
          level: engine.level,
          mode: engine.mode.label,
        ),
      );
    }
    await store.updateStats(engine);
    topScores = await store.loadTopScores();
    stats = await store.loadStats();
    _notify();
    if (isDailyRun) {
      await _persistDailyResult();
    }
    await _recordProgress();
    unawaited(_submitOnline());
  }

  /// Pays out XP for the run just finished and moves today's quests
  /// along, and remembers what changed so the game-over card can show it.
  Future<void> _recordProgress() async {
    final result = Quests.apply(
      progress,
      RunSummary(
        apples: engine.totalApplesEaten,
        score: engine.score,
        bestCombo: engine.bestCombo,
        powerUps: engine.powerUpsCollected,
        closeCalls: engine.closeCalls,
      ),
      dayNumber: dailyDayNumber,
      dayKey: todayKey,
    );
    await store.saveProgress(result.progress);
    progress = result.progress;
    outcome = result;
    _notify();
  }

  /// Updates the daily-challenge streak after a daily run ends, and — the
  /// first time a daily run is completed — asks for notification
  /// permission and schedules a "keep your streak" reminder for tomorrow.
  Future<void> _persistDailyResult() async {
    final today = now();
    final alreadyPlayedToday = playedDailyToday;
    final newStreak = DailyChallenge.nextStreak(
      lastPlayedKey: dailyState.lastPlayedKey,
      previousStreak: dailyState.currentStreak,
      today: today,
    );
    final newState = DailyState(
      lastPlayedKey: DailyChallenge.dateKey(today),
      lastScore: alreadyPlayedToday
          ? max(engine.score, dailyState.lastScore)
          : engine.score,
      currentStreak: newStreak,
      bestStreak: max(newStreak, dailyState.bestStreak),
    );
    await store.saveDailyState(newState);
    dailyState = newState;
    _notify();
    if (!alreadyPlayedToday) {
      await notifications.requestPermission();
      await notifications.scheduleStreakReminder(streak: newStreak);
    }
  }

  /// Posts this run to the global boards, best-effort: a missing backend
  /// or a failed request must never get in the way of the game.
  Future<void> _submitOnline() async {
    if (!onlineScores.available || engine.score <= 0) return;
    final name = displayName;
    try {
      if (isDailyRun) {
        await onlineScores.submit(
          BoardId.daily(dailyDayNumber),
          name: name,
          score: engine.score,
        );
      }
      if (countsForLeaderboard) {
        await onlineScores.submit(
          BoardId.allTime(engine.mode),
          name: name,
          score: engine.score,
        );
      }
    } catch (e) {
      debugPrint('Online score submit failed: $e');
    }
  }

  Future<void> setPlayerName(String name) async {
    playerName = name;
    _notify();
    await store.savePlayerName(name);
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _ticker?.cancel();
    _onlineListenable?.removeListener(_onOnlineChanged);
    unawaited(sound.dispose());
    super.dispose();
  }
}
