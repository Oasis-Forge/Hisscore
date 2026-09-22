import 'dart:async';

import 'package:flutter/material.dart';

import '../game/attract_demo.dart';
import '../game/challenge_code.dart';
import '../game/daily_challenge.dart';
import '../game/game_session.dart';
import '../game/high_score_store.dart';
import '../game/online_scores.dart';
import '../game/quests.dart';
import '../game/snake_engine.dart';
import 'board.dart';
import 'controls.dart';
import 'enter_code_dialog.dart';
import 'game_board_view.dart';
import 'game_hud.dart';
import 'game_overlay.dart';
import 'intro_cabinet.dart';
import 'intro_panel.dart';
import 'online_board.dart';
import 'ready_tabs.dart';
import 'run_effects.dart';
import 'share_run.dart';
import 'snake_skin.dart';
import 'swipe_hint.dart';
import 'theme.dart';

/// The whole game, on one page: the arcade-cabinet menu and the
/// full-screen run.
///
/// The page is the seam between three things that used to be tangled
/// together here. [GameSession] runs the game, [RunEffects] makes the
/// noise, and this widget measures the screen, routes input and decides
/// which of the two screens is showing.
class GamePage extends StatefulWidget {
  const GamePage({
    super.key,
    required this.highScoreStore,
    this.engineFactory,
    this.onlineScores = const NoopOnlineScoreBoard(),
  });

  final HighScoreStore highScoreStore;
  final OnlineScoreBoard onlineScores;
  final SnakeEngine Function()? engineFactory;

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  /// The run itself — engine, ticker, saving, progression.
  late final GameSession session;

  /// The snake playing itself behind the menu.
  late final AttractDemo demo;

  /// Particles, popups, shake and flashes.
  late final RunEffects effects;

  SnakeEngine get engine => session.engine;

  late AnimationController pulse;
  late AnimationController titleGlow;

  final focusNode = FocusNode();

  /// Which ready-screen tab, and which page of the STATS tab, is showing.
  ReadyTab readyTab = ReadyTab.modes;
  StatsView _statsView = StatsView.local;

  /// Intro (cabinet, attract demo, mode picking) versus the full-screen
  /// game. The engine's own phase drives everything inside the game.
  bool showIntro = true;

  /// Last measured viewport, so a new game's grid can be sized to the
  /// device instead of a fixed square.
  Size _viewport = Size.zero;

  /// Status-bar / notch inset, excluded from the play area.
  double _topInset = 0;

  /// What the board itself will get once the HUD band is taken off the
  /// top — the grid is shaped to this, not to the whole screen.
  Size get _playAreaSize => Size(
    _viewport.width,
    (_viewport.height - _topInset - GameHud.height).clamp(1, double.infinity),
  );

  /// Movement interpolation: when the current tick started, so the board
  /// can animate the snake between cells instead of jumping.
  DateTime _lastTickAt = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    effects = RunEffects()..addListener(_redraw);

    session =
        GameSession(
            store: widget.highScoreStore,
            onlineScores: widget.onlineScores,
            engineFactory: widget.engineFactory,
          )
          ..gridProvider = (() => boardGridFor(_playAreaSize))
          ..onTick = (() => _lastTickAt = DateTime.now())
          ..onAte = ((food, gained) => effects.ate(
            food,
            gained,
            comboCount: engine.comboCount,
            multiplier: engine.comboMultiplier,
          ))
          ..onLevelUp = effects.levelUp
          ..onCloseCall = (() => effects.closeCall(engine.head))
          ..onNewBest = effects.newBest
          ..onGameOver = (() => effects.died(engine.head))
          ..addListener(_redraw);

    demo = AttractDemo()..addListener(_redraw);

    pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    titleGlow = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    unawaited(_load());
    unawaited(session.sound.init());
    unawaited(session.haptics.init());
    unawaited(session.notifications.init());
    demo.start();
  }

  void _redraw() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    await session.load();
    if (!mounted) return;
    // A saved look the player has not earned (or has not earned yet)
    // falls back to the free one.
    final level = session.progress.level;
    final theme = GameTheme.byId(session.savedThemeId);
    final skin = SnakeSkin.byId(session.savedSkinId);
    RetroColors.current = theme.unlockLevel <= level
        ? theme
        : GameTheme.phosphorGreen;
    SnakeSkin.current = skin.unlockLevel <= level ? skin : SnakeSkin.classic;
    _rebuildAll();
  }

  /// Leaving the foreground must not cost the player a run. The attract
  /// demo stops too, rather than animating a menu nobody is looking at.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (!mounted) return;
    if (state == AppLifecycleState.resumed) {
      // A paused run stays paused — the player decides when to go
      // again — but the menu comes back to life.
      if (showIntro && !demo.running) demo.start();
      return;
    }
    session.handleAppBackgrounded();
    demo.stop();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    session.removeListener(_redraw);
    demo.removeListener(_redraw);
    effects.removeListener(_redraw);
    session.dispose();
    demo.dispose();
    effects.dispose();
    pulse.dispose();
    titleGlow.dispose();
    focusNode.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════
  // Input
  // ═══════════════════════════════════════════════════

  void _onPrimary() {
    // A run that is about to start gets a clean screen; pausing and
    // resuming keeps whatever is on it.
    if (engine.phase != GamePhase.running) effects.clear();
    session.primaryAction();
    focusNode.requestFocus();
  }

  void _onTurn(Direction direction) => session.turn(direction);

  /// The run comes back, so the wreckage of the death goes with it.
  void _takeSecondChance() {
    effects.clear();
    session.acceptSecondChance();
    focusNode.requestFocus();
  }

  /// Leaves the intro for the full-screen game.
  void _enterGame() {
    demo.stop();
    setState(() => showIntro = false);
    _onPrimary();
  }

  /// Back to the intro, demo running again.
  void _returnToIntro() {
    session.returnToMenu();
    effects.clear();
    setState(() => showIntro = true);
    focusNode.requestFocus();
    demo.start();
  }

  /// Android's back gesture: pause a run, leave a finished or paused
  /// one, and only close the app from the intro.
  void _onSystemBack() {
    if (showIntro) return;
    if (engine.phase == GamePhase.running) {
      session.pause();
      return;
    }
    _returnToIntro();
  }

  /// Both seeded starts — today's daily and a friend's code — leave the
  /// menu the same way.
  void _startSeeded(void Function() start) {
    demo.stop();
    effects.clear();
    setState(() => showIntro = false);
    start();
    focusNode.requestFocus();
  }

  /// Asks for a friend's code and, if it is valid, plays it.
  Future<void> _enterCode() async {
    final code = await showDialog<ChallengeCode>(
      context: context,
      builder: (context) => const EnterCodeDialog(),
    );
    if (code != null && mounted) {
      _startSeeded(() => session.startChallenge(code));
    }
  }

  Future<void> _editName() async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => EditNameDialog(current: session.displayName),
    );
    if (name == null || !mounted) return;
    await session.setPlayerName(name);
  }

  Future<void> _shareScore() => shareRun(
    engine: engine,
    isDailyRun: session.isDailyRun,
    dailyDayNumber: session.dailyDayNumber,
    dailyState: session.dailyState,
    challenge: session.challenge,
  );

  // ═══════════════════════════════════════════════════
  // Look
  // ═══════════════════════════════════════════════════

  /// Applies [theme] everywhere and remembers it. Most widgets read the
  /// palette in build(), but some are const and would never notice, so
  /// the whole tree is marked dirty (state is kept).
  void _setTheme(GameTheme theme) {
    if (theme.unlockLevel > session.progress.level) return;
    RetroColors.current = theme;
    unawaited(widget.highScoreStore.saveThemeId(theme.id));
    _rebuildAll();
  }

  void _setSkin(SnakeSkin skin) {
    if (skin.unlockLevel > session.progress.level) return;
    setState(() => SnakeSkin.current = skin);
    unawaited(widget.highScoreStore.saveSkinId(skin.id));
  }

  void _rebuildAll() {
    void visit(Element element) {
      element.markNeedsBuild();
      element.visitChildren(visit);
    }

    (context as Element).visitChildren(visit);
    setState(() {});
  }

  // ═══════════════════════════════════════════════════
  // Build
  // ═══════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    // Every transition that matters (play, pause, game over, menu, a
    // combo change) goes through a rebuild, so the music follows along
    // from here. syncMusic only acts when something actually changed.
    session.sound.syncMusic(
      playing: !showIntro && engine.phase == GamePhase.running,
      combo: engine.comboCount,
    );
    return CallbackShortcuts(
      bindings: gameKeyBindings(
        phase: () => engine.phase,
        onTurn: _onTurn,
        onPrimary: _onPrimary,
        onPause: session.pause,
        onExitToMenu: _returnToIntro,
      ),
      child: Focus(
        focusNode: focusNode,
        autofocus: true,
        child: Scaffold(
          backgroundColor: RetroColors.voidBg,
          body: PopScope(
            // Back belongs to the game first: pause a run, leave a
            // finished one, and only then close the app.
            canPop: showIntro,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) _onSystemBack();
            },
            child: LayoutBuilder(
              builder: (context, constraints) {
                _viewport = constraints.biggest;
                _topInset = MediaQuery.paddingOf(context).top;
                return showIntro ? _buildIntro() : _buildGameScreen();
              },
            ),
          ),
        ),
      ),
    );
  }

  /// The intro: cabinet chrome, the attract demo playing in its screen,
  /// and everything you pick before a run.
  Widget _buildIntro() {
    final ready = engine.phase == GamePhase.ready;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -0.2),
          radius: 1.2,
          colors: [const Color(0xFF10130F), RetroColors.voidBg],
        ),
      ),
      child: SafeArea(
        child: Center(
          child: FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
              width: 440,
              height: 800,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: IntroCabinet(
                  titleGlow: titleGlow,
                  subtitle: ready ? 'RETRO SNAKE' : engine.mode.label,
                  subtitleColor: ready
                      ? RetroColors.phosphorDim
                      : engine.mode.accentColor,
                  soundEnabled: session.sound.enabled,
                  musicEnabled: session.sound.musicEnabled,
                  onToggleSound: () {
                    unawaited(session.sound.setEnabled(!session.sound.enabled));
                    setState(() {});
                  },
                  onToggleMusic: () {
                    unawaited(
                      session.sound.setMusicEnabled(
                        !session.sound.musicEnabled,
                      ),
                    );
                    setState(() {});
                  },
                  hapticsEnabled: session.haptics.enabled,
                  onToggleHaptics: () {
                    unawaited(
                      session.haptics.setEnabled(!session.haptics.enabled),
                    );
                    setState(() {});
                  },
                  screen: _buildIntroScreenArea(),
                  onPlay: _enterGame,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The cabinet's screen on the intro: the demo snake playing itself,
  /// with the mode picker and friends laid over it.
  Widget _buildIntroScreenArea() {
    final demoEngine = demo.engine;
    return AnimatedBuilder(
      animation: pulse,
      builder: (context, _) {
        return Stack(
          fit: StackFit.expand,
          children: [
            if (demoEngine != null)
              SnakeBoard(
                engine: demoEngine,
                pulse: pulse.value,
                tickProgress: demo.tickProgress,
              ),
            IntroPanel(
              blinkOn: pulse.value > 0.4,
              selectedMode: session.selectedMode,
              onModeChanged: session.setMode,
              readyTab: readyTab,
              onReadyTabChanged: (tab) => setState(() => readyTab = tab),
              stats: session.stats,
              topScores: session.topScores,
              dailyDayNumber: session.dailyDayNumber,
              dailyState: session.dailyState,
              playedDailyToday: session.playedDailyToday,
              onStartDaily: () => _startSeeded(session.startDaily),
              onNewChallenge: () => _startSeeded(
                () => session.startChallenge(
                  ChallengeCode.random(session.selectedMode),
                ),
              ),
              onEnterCode: _enterCode,
              online: widget.onlineScores,
              playerName: session.displayName,
              onEditName: _editName,
              statsView: _statsView,
              onStatsViewChanged: (v) => setState(() => _statsView = v),
              progress: session.todayProgress,
              quests: Quests.forDay(session.dailyDayNumber),
              onOpenQuests: () => setState(() {
                readyTab = ReadyTab.stats;
                _statsView = StatsView.quests;
              }),
              selectedTheme: RetroColors.current,
              onThemeChanged: _setTheme,
              selectedSkin: SnakeSkin.current,
              onSkinChanged: _setSkin,
            ),
            if (session.isFirstTimePlayer) SwipeHint(sweep: pulse.value),
          ],
        );
      },
    );
  }

  /// The game: board edge to edge, a thin HUD over it, gestures only.
  Widget _buildGameScreen() {
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          // The HUD gets its own band rather than floating over the
          // playfield — otherwise the snake runs underneath the score.
          SizedBox(
            height: GameHud.height,
            child: GameHud(
              engine: engine,
              highScore: session.highScore,
              onPause: session.pause,
            ),
          ),
          Expanded(child: _buildBoardStack()),
        ],
      ),
    );
  }

  Widget _buildBoardStack() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // The board fills this area edge to edge, so its geometry is
        // simply the area itself — particles and popups ride on it.
        final area = constraints.biggest;
        // The daily and challenges have a fixed shape; on a screen of
        // another shape they are letterboxed rather than stretched.
        final fixed =
            (session.isDailyRun || session.challenge != null) &&
            engine.columns == DailyChallenge.gridColumns &&
            engine.rows == DailyChallenge.gridRows;
        final size = fixed ? _fitAspect(area, DailyChallenge.gridAspect) : area;
        effects.measure(
          size: size,
          offset: Offset.zero,
          columns: engine.columns,
          rows: engine.rows,
        );
        final layers = _buildBoardLayers();
        if (!fixed) return layers;
        return Center(
          child: SizedBox(
            width: size.width,
            height: size.height,
            child: layers,
          ),
        );
      },
    );
  }

  /// The largest box of the given width / height [aspect] that fits [area].
  static Size _fitAspect(Size area, double aspect) {
    if (area.width / area.height > aspect) {
      return Size(area.height * aspect, area.height);
    }
    return Size(area.width, area.width / aspect);
  }

  double get _tickProgress {
    if (engine.phase != GamePhase.running) return 1.0;
    final tickMs = engine.tickInterval.inMilliseconds;
    if (tickMs <= 0) return 1.0;
    final elapsed = DateTime.now().difference(_lastTickAt).inMicroseconds;
    return (elapsed / (tickMs * 1000)).clamp(0.0, 1.0);
  }

  Widget _buildBoardLayers() {
    // The card waits out the slow-motion beat: covering the board on
    // the same frame as the death hides the one thing the player wants
    // to see.
    // A revive parks the engine in `paused` while the player is counted
    // back in. That is not a pause the player asked for, so the card —
    // and its live RESUME and MENU buttons under the see-through
    // countdown — has no business being there.
    final showOverlay =
        session.resumeCountdown == 0 &&
        (engine.phase == GamePhase.paused ||
            (engine.phase == GamePhase.gameOver && !effects.dying));
    return GameBoardView(
      engine: engine,
      pulse: pulse,
      tickProgress: _tickProgress,
      particles: effects.particles,
      shake: effects.shake,
      labels: effects.labels,
      levelFlashOpacity: effects.levelFlashOpacity,
      deathFlashOpacity: effects.deathFlashOpacity,
      onSwipe: _onTurn,
      overlay: showOverlay
          ? GameOverlay(
              phase: engine.phase,
              engine: engine,
              won: engine.won,
              newHighScore: session.newHighScore,
              isDailyRun: session.isDailyRun,
              challengeCode: session.challenge?.text,
              outcome: session.outcome,
              dailyDayNumber: session.dailyDayNumber,
              dailyState: session.dailyState,
              highScore: session.highScore,
              standing: session.standing,
              quests: Quests.forDay(session.dailyDayNumber),
              onShare: _shareScore,
              onExitToMenu: _returnToIntro,
              onResume: _onPrimary,
              onSecondChance: session.offerSecondChance
                  ? _takeSecondChance
                  : null,
              onSecondChanceExpired: session.refuseSecondChance,
            )
          : null,
      countdown: session.resumeCountdown,
    );
  }
}
