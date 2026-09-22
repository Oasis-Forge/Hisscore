import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'challenge_code.dart';
import 'daily_challenge.dart';
import 'food_types.dart';
import 'haptics.dart';
import 'high_score_store.dart';
import 'milestones.dart';
import 'notification_service.dart';
import 'online_scores.dart';
import 'quests.dart';
import 'review_prompter.dart';
import 'rival_run.dart';
import 'run_log.dart';
import 'run_standing.dart';
import 'snake_engine.dart';
import 'sound_manager.dart';
import 'weekly_modifier.dart';

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

  /// What the daily run just finished did to the streak, so the end
  /// card can say a freeze was spent rather than leaving the player to
  /// work out why their streak survived a day they did not play.
  /// Null for anything that is not a daily.
  StreakOutcome? streakOutcome;

  /// Where the finished run landed on a board, once the board has
  /// answered. Null while the request is in flight, and null forever
  /// when there is no backend — the end screen simply leaves the line
  /// out rather than showing a placeholder.
  RunStanding? standing;

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

  /// The rule bending this week's daily. Read before a run to name it
  /// on the card that offers it, and after one to put it on the share.
  WeeklyModifier get dailyModifier =>
      DailyChallenge.modifierForDay(dailyDayNumber);

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

  /// Whether the run belongs on its mode's all-time board.
  ///
  /// A daily played under a weekly rule does not: no walls takes away
  /// the main way to die and magnet madness hands the player their
  /// food, so a score earned that way would sit above Classic runs it
  /// never competed with. It still counts on the daily's own board,
  /// where everyone played the same strange game.
  bool get countsForAllTimeBoard =>
      countsForLeaderboard && engine.modifier == null;

  // ─── Second chance ────────────────────────────────

  /// The offer lapsed, or the player waved it away.
  bool secondChanceRefused = false;

  /// Counting the player back in after a revive: 3, 2, 1, then 0 for
  /// not counting.
  int resumeCountdown = 0;
  Timer? _resumeTimer;

  /// Whether the card should be offering a second chance.
  ///
  /// The engine rules out the modes; this rules out the runs whose
  /// whole point is that everyone played the same game. Reviving on a
  /// daily or a friend's code would put a score next to other people's
  /// that was not earned the same way.
  bool get offerSecondChance =>
      engine.canRevive &&
      !secondChanceRefused &&
      !isDailyRun &&
      challenge == null;

  /// Takes the second chance: the engine brings the run back paused,
  /// and the player is counted in rather than dropped into a moving
  /// game.
  void acceptSecondChance() {
    if (!offerSecondChance) return;
    engine.revive();
    resumeCountdown = 3;
    _resumeTimer?.cancel();
    _resumeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      resumeCountdown--;
      if (resumeCountdown <= 0) {
        timer.cancel();
        _resumeTimer = null;
        resumeCountdown = 0;
        engine.start();
        armTicker();
      }
      _notify();
    });
    _notify();
  }

  /// The offer lapsed or was turned down: now the run is really over,
  /// so now it gets written down.
  void refuseSecondChance() {
    if (secondChanceRefused) return;
    secondChanceRefused = true;
    _recordRunIfNeeded();
    _notify();
  }

  /// A finished run is saved exactly once, whenever it becomes final —
  /// which is at the death for most runs, and only after the offer
  /// lapses for one that could still have come back.
  bool _runRecorded = false;

  void _recordRunIfNeeded() {
    if (_runRecorded || engine.phase != GamePhase.gameOver) return;
    _runRecorded = true;
    saveInFlight = persistGameEnd();
  }

  void _resetRunFlags() {
    _resumeTimer?.cancel();
    _resumeTimer = null;
    resumeCountdown = 0;
    secondChanceRefused = false;
    _runRecorded = false;
  }

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
    savedGhost = await store.loadDailyGhost();
    leaderboardOptIn = await store.loadLeaderboardOptIn();
    loaded = true;
    _notify();
  }

  // ─── Going on the boards ──────────────────────────

  /// Whether the player agreed to their name and score going on the
  /// public boards. **Null means they have not been asked yet**, and
  /// nothing is sent in that state.
  bool? leaderboardOptIn;

  /// A finished run had somewhere to go and was held back for want of
  /// an answer. The page owes the player the question.
  bool _submissionHeld = false;

  /// Whether the game owes the player a decision right now.
  ///
  /// True only after a run that would actually have been submitted, so
  /// the question is asked in the one moment it means something rather
  /// than as a dialog on first launch that everybody dismisses.
  bool get owesLeaderboardChoice => leaderboardOptIn == null && _submissionHeld;

  /// Records the answer, and sends the run that was waiting on it.
  ///
  /// The engine still holds the finished run at this point — the card
  /// is on screen — so a yes can submit the score the player was just
  /// asked about, rather than making them play another to be counted.
  Future<void> setLeaderboardOptIn(bool value) async {
    leaderboardOptIn = value;
    await store.saveLeaderboardOptIn(value);
    final held = _submissionHeld;
    _submissionHeld = false;
    _notify();
    if (value && held) await _submitOnline();
  }

  // ─── The ghost ────────────────────────────────────

  /// The best daily run kept on this device, as a replayable log.
  RunLog? savedGhost;

  /// The saved run, but only when it is of *today's* board. Yesterday's
  /// ghost is a ghost of a different game.
  RunLog? get todaysGhost {
    final ghost = savedGhost;
    if (ghost == null || ghost.dayNumber != dailyDayNumber) return null;
    return ghost;
  }

  /// The ghost being raced, replayed one tick behind the live run.
  ///
  /// A second engine rather than a stored list of positions, because
  /// the log is a list of turns and the engine is the only thing that
  /// knows what a turn does. It costs one extra tick of pure Dart per
  /// frame and keeps the ghost honest.
  SnakeEngine? ghost;

  /// Where the ghost is now, or nothing when no race is on.
  List<GridPoint> get ghostSnake => _ghostRunning ? ghost!.snake : const [];

  /// Where it was last tick, so the board can slide it rather than
  /// jump it a whole cell at a time.
  List<GridPoint> get ghostPreviousSnake =>
      _ghostRunning ? ghost!.previousSnake : const [];

  bool get _ghostRunning => ghost != null && ghost!.phase != GamePhase.gameOver;

  /// The friend's run on the challenge being played, when their link
  /// carried one. Null on the daily and on a challenge nobody raced.
  RivalRun? rival;

  /// The run to race: on the daily, the best one kept on this device;
  /// on a challenge, whoever sent it.
  ///
  /// One ghost, two sources. The racing machinery below neither knows
  /// nor cares which — a replay is a replay.
  RunLog? get _ghostToRace {
    final code = challenge;
    if (code != null) return rival?.toLog(code);
    return todaysGhost;
  }

  /// The score to beat, when there is anything to beat it.
  int? get ghostScore => challenge != null ? rival?.score : todaysGhost?.score;

  /// How the run stands against the friend who sent the challenge.
  ///
  /// Live during the run, not only at the end, so the HUD could show it
  /// mid-race. Null whenever there is nobody to be measured against.
  ({int yours, int theirs, String name, bool won, bool drew})? get headToHead {
    final them = rival;
    if (them == null || challenge == null) return null;
    return (
      yours: engine.score,
      theirs: them.score,
      name: them.name,
      won: engine.score > them.score,
      drew: engine.score == them.score,
    );
  }

  /// This run, in the shape that rides in a link back to them.
  RivalRun? get myRun =>
      challenge == null ? null : RivalRun.of(engine, name: displayName);

  /// A rival kept from the last time this challenge was played, if any.
  ///
  /// Asked *before* [startChallenge] rather than inside it, because a
  /// ghost has to be there when the run begins — a race that joins
  /// halfway through is not one.
  Future<RivalRun?> savedRivalFor(ChallengeCode code) =>
      store.loadRival(code.text);

  void _startGhost() {
    final log = _ghostToRace;
    ghost = null;
    _ghostSteer = 0;
    if (log == null) return;
    ghost = log.engineForReplay()..start();
    _ghostLog = log;
  }

  RunLog? _ghostLog;
  int _ghostSteer = 0;

  /// Moves the ghost on by the one tick the live run just took.
  void _tickGhost() {
    final runner = ghost;
    final log = _ghostLog;
    if (runner == null || log == null) return;
    if (runner.phase != GamePhase.running) return;
    if (runner.totalTicks >= log.ticks) {
      runner.phase = GamePhase.gameOver;
      return;
    }
    final at = runner.totalTicks + 1;
    while (_ghostSteer < log.steers.length &&
        log.steers[_ghostSteer].tick <= at) {
      runner.direction = log.steers[_ghostSteer].direction;
      _ghostSteer++;
    }
    runner.tick();
  }

  /// Keeps the best daily run on this device, so there is something to
  /// race next time. Only a better score replaces it, and only today's
  /// board is worth keeping at all.
  Future<void> _keepGhost(int seed) async {
    if (!isDailyRun) return;
    final best = todaysGhost;
    if (best != null && best.score >= engine.score) return;
    final log = RunLog.of(engine, seed: seed, dayNumber: dailyDayNumber);
    savedGhost = log;
    await store.saveDailyGhost(log);
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
    WeeklyModifier? modifier,
  }) {
    final injected = engineFactory;
    if (injected != null && random == null) return injected();
    // The daily and challenge codes are one fixed size on every device;
    // everything else is shaped to the screen.
    final grid = fixedGrid
        ? (
            columns: DailyChallenge.columnsFor(modifier),
            rows: DailyChallenge.rowsFor(modifier),
          )
        : gridProvider?.call();
    return SnakeEngine(
      columns: grid?.columns ?? 20,
      rows: grid?.rows ?? 20,
      mode: mode ?? selectedMode,
      modifier: modifier,
      fixedGrid: fixedGrid,
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
    // A finished run being walked away from is still a finished run.
    _recordRunIfNeeded();
    _resetRunFlags();
    newHighScore = false;
    outcome = null;
    streakOutcome = null;
    standing = null;
    if (engine.phase == GamePhase.gameOver || engine.phase == GamePhase.ready) {
      // A fresh run gets an engine sized to this screen — except Time
      // Attack, whose whole claim is that sixty seconds on one board
      // means the same thing on every phone.
      engine = newEngine(fixedGrid: selectedMode.isTimed);
      engine.mode = selectedMode;
      isDailyRun = false;
      challenge = null;
      rival = null;
      ghost = null;
    }
    engine.start();
    startedAt = now();
    armTicker();
    _notify();
  }

  /// Starts today's daily challenge: a Classic run seeded from the date,
  /// on the fixed grid, so every device gets the same board all day.
  void startDaily() {
    _recordRunIfNeeded();
    _resetRunFlags();
    _ticker?.cancel();
    final seed = DailyChallenge.seedForDay(dailyDayNumber);
    engine = newEngine(
      mode: GameMode.classic,
      random: Random(seed),
      fixedGrid: true,
      modifier: dailyModifier,
    );
    engine.mode = GameMode.classic;
    selectedMode = GameMode.classic;
    isDailyRun = true;
    challenge = null;
    rival = null;
    newHighScore = false;
    outcome = null;
    streakOutcome = null;
    standing = null;
    // The race starts with the run, so the two are on the same tick
    // from the first move.
    _startGhost();
    engine.start();
    startedAt = now();
    armTicker();
    _notify();
  }

  /// Starts the game a challenge code names: its mode, its seed, and the
  /// daily's fixed grid, so everyone playing the code plays one board.
  /// [rival] is the sender's own run, when their link carried one. It is
  /// kept, so backing out to the menu and tapping the challenge again
  /// still races them — the link that brought it is not coming back.
  void startChallenge(ChallengeCode code, {RivalRun? rival}) {
    _recordRunIfNeeded();
    _resetRunFlags();
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
    this.rival = rival;
    if (rival != null) unawaited(store.saveRival(code.text, rival));
    _startGhost();
    newHighScore = false;
    outcome = null;
    streakOutcome = null;
    standing = null;
    engine.start();
    startedAt = now();
    armTicker();
    _notify();
  }

  /// Back to a clean ready state for the menu.
  void returnToMenu() {
    _recordRunIfNeeded();
    _resetRunFlags();
    _ticker?.cancel();
    engine = newEngine();
    engine.reset();
    engine.phase = GamePhase.ready;
    newHighScore = false;
    outcome = null;
    streakOutcome = null;
    standing = null;
    isDailyRun = false;
    challenge = null;
    rival = null;
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
    _tickGhost();

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
      // A run that could still come back has not finished, so nothing
      // is written down until the offer lapses.
      if (!offerSecondChance) _recordRunIfNeeded();
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

  /// Where the player stands, for the milestones. Reads [progress]
  /// unless given a newer one — the quest payout lands before the
  /// milestones are settled, and the level they see has to be the one
  /// that payout produced.
  MilestoneFacts _milestoneFacts({PlayerProgress? progress}) => MilestoneFacts(
    gamesPlayed: stats.gamesPlayed,
    totalApples: stats.totalApples,
    bestCombo: stats.bestCombo,
    bestScore: highScore,
    level: (progress ?? this.progress).level,
    streak: dailyState.currentStreak,
    powerUps: stats.powerUps,
    bestCloseCalls: stats.bestCloseCalls,
    challengesPlayed: stats.challengesPlayed,
    modesPlayed: GameMode.values
        .where((m) => stats.modesPlayed.contains(m.name))
        .toSet(),
  );

  @visibleForTesting
  Future<void> persistGameEnd() async {
    // Taken before anything is written down: it is the "before" half of
    // every milestone question asked below.
    final wasAt = _milestoneFacts();
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
    await store.updateStats(engine, challenge: challenge != null);
    topScores = await store.loadTopScores();
    stats = await store.loadStats();
    _notify();
    if (isDailyRun) {
      await _persistDailyResult();
      await _keepGhost(DailyChallenge.seedForDay(dailyDayNumber));
    }
    await _recordProgress(wasAt);
    // Awaited, not fired and forgotten: nothing in the app waits on
    // `persistGameEnd` itself, so a slow board delays only the standing
    // line appearing — and folding it in here gives that line one
    // future to be waited on instead of two.
    await _submitOnline();
  }

  /// Pays out XP for the run just finished and moves today's quests
  /// along, and remembers what changed so the game-over card can show it.
  Future<void> _recordProgress(MilestoneFacts wasAt) async {
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
    // A streak can fall back and climb again, so "newly reached" is not
    // enough on its own to mean "not yet paid for": the ids already
    // settled have the last word.
    final fresh = milestonesEarned(
      wasAt,
      _milestoneFacts(progress: result.progress),
    ).where((m) => !result.progress.milestones.contains(m.id)).toList();

    final paid = result.withMilestones(fresh);
    await store.saveProgress(paid.progress);
    progress = paid.progress;
    outcome = paid;
    _notify();
  }

  /// Updates the daily-challenge streak after a daily run ends, and — the
  /// first time a daily run is completed — asks for notification
  /// permission and schedules a "keep your streak" reminder for tomorrow.
  Future<void> _persistDailyResult() async {
    final today = now();
    final alreadyPlayedToday = playedDailyToday;
    final streak = DailyChallenge.nextStreakState(
      lastPlayedKey: dailyState.lastPlayedKey,
      previousStreak: dailyState.currentStreak,
      freezes: dailyState.freezes,
      today: today,
    );
    final newStreak = streak.streak;
    streakOutcome = streak;
    final newState = DailyState(
      lastPlayedKey: DailyChallenge.dateKey(today),
      lastScore: alreadyPlayedToday
          ? max(engine.score, dailyState.lastScore)
          : engine.score,
      currentStreak: newStreak,
      bestStreak: max(newStreak, dailyState.bestStreak),
      freezes: streak.freezes,
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
    // Nothing goes up until the player has actually said yes. Null is
    // "not asked", not "yes": this run waits, and the page asks.
    if (leaderboardOptIn != true) {
      _submissionHeld = leaderboardOptIn == null;
      _notify();
      return;
    }
    final name = displayName;
    final score = engine.score;
    try {
      if (isDailyRun) {
        await onlineScores.submit(
          BoardId.daily(dailyDayNumber),
          name: name,
          score: score,
        );
      }
      if (countsForAllTimeBoard) {
        await onlineScores.submit(
          BoardId.allTime(engine.mode),
          name: name,
          score: score,
        );
      }
      await _readStanding(score);
    } catch (e) {
      debugPrint('Online score submit failed: $e');
    }
  }

  /// Asks the board the run belongs on where the run landed, so the end
  /// screen can name the next target. The daily wins when a run is both,
  /// because that is the board the player came for.
  Future<void> _readStanding(int score) async {
    final (board, label) = isDailyRun
        ? (BoardId.daily(dailyDayNumber), 'THE DAILY')
        : (BoardId.allTime(engine.mode), '${engine.mode.label} ALL-TIME');
    if (!isDailyRun && !countsForAllTimeBoard) return;
    final entries = await onlineScores.top(board);
    standing = RunStanding.of(entries: entries, score: score, board: label);
    _notify();
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
    _resumeTimer?.cancel();
    _onlineListenable?.removeListener(_onOnlineChanged);
    unawaited(sound.dispose());
    super.dispose();
  }
}
