import 'dart:math';

import 'food_types.dart';
import 'level.dart';
import 'weekly_modifier.dart';

// ─── Enums ──────────────────────────────────────────────

enum Direction {
  up,
  down,
  left,
  right;

  /// Left and right swapped, up and down left alone: a mirror flips
  /// one axis, not both.
  Direction get mirrored => switch (this) {
    Direction.left => Direction.right,
    Direction.right => Direction.left,
    _ => this,
  };

  Direction get opposite => switch (this) {
    Direction.up => Direction.down,
    Direction.down => Direction.up,
    Direction.left => Direction.right,
    Direction.right => Direction.left,
  };

  GridPoint get delta => switch (this) {
    Direction.up => const GridPoint(0, -1),
    Direction.down => const GridPoint(0, 1),
    Direction.left => const GridPoint(-1, 0),
    Direction.right => const GridPoint(1, 0),
  };
}

/// One steer, and the tick it landed on. The unit a run is recorded
/// in; see  for what is done with them.
typedef Steer = ({int tick, Direction direction});

enum GamePhase { ready, running, paused, gameOver }

enum GameMode {
  classic,
  adventure,
  endless,
  hardcore,
  zen,

  /// Sixty seconds on the same board for everyone, so the scores mean
  /// something next to each other.
  timeAttack;

  String get label => switch (this) {
    GameMode.classic => 'CLASSIC',
    GameMode.adventure => 'ADVENTURE',
    GameMode.endless => 'ENDLESS',
    GameMode.hardcore => 'HARDCORE',
    GameMode.zen => 'ZEN',
    GameMode.timeAttack => 'TIME ATTACK',
  };

  String get description => switch (this) {
    GameMode.classic => 'Original snake rules',
    GameMode.adventure => 'Levels with obstacles',
    GameMode.endless => 'Wrap walls, survive!',
    GameMode.hardcore => 'No shields. 2x points. Deadly.',
    GameMode.zen => 'No game over. Just vibes.',
    GameMode.timeAttack => '60 seconds. Eat fast, score double.',
  };

  /// Whether the run is played against a clock rather than until it
  /// ends.
  bool get isTimed => this == GameMode.timeAttack;
}

// ─── GridPoint ──────────────────────────────────────────

class GridPoint {
  const GridPoint(this.x, this.y);

  final int x;
  final int y;

  GridPoint operator +(GridPoint other) => GridPoint(x + other.x, y + other.y);

  @override
  bool operator ==(Object other) =>
      other is GridPoint && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => '($x,$y)';
}

// ─── SnakeEngine ────────────────────────────────────────

/// Pure Snake rules extended with game modes, power-ups, combos, and levels.
/// No Flutter dependency.
class SnakeEngine {
  SnakeEngine({
    this.columns = 20,
    this.rows = 20,
    this.initialLength = 3,
    this.pointsPerFood = 10,
    this.initialTick = const Duration(milliseconds: 190),
    this.minTick = const Duration(milliseconds: 90),
    this.firstFoodDistance = 4,
    this.mode = GameMode.classic,
    this.modifier,
    this.fixedGrid = false,
    Random? random,
  }) : random = random ?? Random() {
    reset();
  }

  // ─── Configuration ────────────────────────────────

  final int columns;
  final int rows;
  final int initialLength;
  final int pointsPerFood;
  final Duration initialTick;
  final Duration minTick;
  final int firstFoodDistance;
  final Random random;
  GameMode mode;

  /// The daily's weekly rule, when this run is one. The engine honours
  /// the parts of it that are rules; the board draws the fog and the
  /// caller picks the grid, because those are not.
  final WeeklyModifier? modifier;

  /// Whether this grid is the same on every device — the daily and a
  /// friend's code — so the screen letterboxes to it instead of the
  /// board being reshaped to the screen. Asked of the engine rather
  /// than guessed from its dimensions, which stopped being a reliable
  /// signal once a modifier could change them.
  final bool fixedGrid;

  // ─── Game state ───────────────────────────────────

  late List<GridPoint> snake;

  /// Where each segment sat before the current tick. The UI lerps
  /// between this and [snake] so the snake glides instead of jumping
  /// a whole cell every tick.
  late List<GridPoint> previousSnake;

  late Direction direction;

  /// Pending turns, applied one per tick. Two slots deep so a quick
  /// L-turn (up, then left) keeps both inputs instead of the second
  /// overwriting the first.
  final List<Direction> inputQueue = [];

  /// The turn that will be applied on the next tick, if any.
  Direction? get queuedDirection =>
      inputQueue.isEmpty ? null : inputQueue.first;

  /// Every turn that actually took effect, with the tick it landed on.
  ///
  /// With the seed this is the whole run: the engine's clock is counted
  /// in ticks rather than read off the wall, so the same seed and the
  /// same turns give the same game, every time, on any device. See
  /// `run_log.dart`.
  final List<Steer> steers = [];

  late GamePhase phase;
  late int score;
  late Duration tickInterval;
  int foodsEaten = 0;
  bool justAte = false;
  bool won = false;

  // ─── Multi-food ───────────────────────────────────

  late List<FoodItem> foods;
  FoodItem? lastEatenFood;

  /// Backward-compatible: position of the primary apple.
  GridPoint get food => foods.isNotEmpty
      ? foods.first.position
      : GridPoint(columns ~/ 2, rows ~/ 2);

  // ─── Levels & obstacles ───────────────────────────

  int level = 1;
  int applesInLevel = 0;
  bool levelJustAdvanced = false;
  late Set<GridPoint> obstacles;

  // ─── Combo system ─────────────────────────────────

  /// How long a combo stays alive, in milliseconds rather than ticks:
  /// tied to ticks it would silently shrink as the game speeds up,
  /// making combos hardest exactly when the snake is longest.
  static const int comboWindowMs = 1920;
  int comboCount = 0;
  int lastEatMs = -comboWindowMs - 1;
  int bestCombo = 0;

  /// Whether a fresh apple would extend the current combo.
  bool get comboAlive => elapsedMs - lastEatMs <= comboWindowMs;

  double get comboMultiplier {
    if (comboCount <= 1) return 1.0;
    return 1.0 + (comboCount - 1) * 0.5;
  }

  // ─── Power-ups ────────────────────────────────────

  /// Power-up durations, in milliseconds for the same reason as
  /// [comboWindowMs].
  static const int speedBurstMs = 2880;
  static const int magnetMs = 4800;

  bool hasShield = false;
  int speedBurstUntilMs = 0;
  int magnetUntilMs = 0;

  bool get speedBurstActive => elapsedMs < speedBurstUntilMs;
  bool get magnetActive =>
      elapsedMs < magnetUntilMs || modifier == WeeklyModifier.magnetMadness;

  /// Whether shields can currently save the snake. Hardcore mode makes
  /// shields purely cosmetic/score fodder — nothing stops a crash.
  bool get shieldActive => hasShield && mode != GameMode.hardcore;

  // ─── Grace ────────────────────────────────────────

  /// Extra ticks a doomed snake gets before the run ends.
  ///
  /// Most deaths that feel unfair are a turn that landed one frame
  /// late: the player did steer, the tick had already gone. One held
  /// tick is enough to make those land, and short enough that nobody
  /// can play off the walls on purpose. Hardcore gets none — being
  /// unforgiving is the whole of what it sells.
  int get graceTicks => mode == GameMode.hardcore ? 0 : 1;

  /// Whether the current brush with death has already been forgiven.
  /// Cleared the moment the snake completes a safe move, so the grace
  /// is per-scrape rather than per-run.
  bool graceSpent = false;

  /// This tick was held on the brink instead of moving. Lives for one
  /// tick, like [justAte], so the UI can react to the moment.
  bool graceHeld = false;

  /// Whether the snake is frozen one move from dying, waiting to see if
  /// a turn arrives.
  bool get onTheBrink => graceHeld;

  // ─── Risk and reward ──────────────────────────────

  /// Where the fleeing golden apple turns up. Not Classic, which stays
  /// the plain game, and not Hardcore, which has enough going on.
  static const goldenModes = {GameMode.adventure, GameMode.endless};

  /// One appears every this many apples, and is gone this long after.
  static const int goldenEveryApples = 12;
  static const int goldenLifetimeMs = 8000;

  /// What it pays, before the combo it is multiplied by. High enough to
  /// be worth chasing into somewhere the player would not otherwise go.
  static const int goldenPoints = 100;

  /// It steps away from the head every this many ticks — slower than
  /// the snake, so it can be caught, but only by cutting it off.
  static const int goldenFleeTicks = 3;

  /// What a poison apple costs.
  static const int poisonSegments = 3;

  /// Set for the tick in which poison was eaten, so the screen can
  /// shake for it.
  bool atePoison = false;

  // ─── Time Attack ──────────────────────────────────

  /// How long a timed run lasts.
  static const int timeAttackMs = 60000;

  /// Eating again this soon after the last apple is worth double.
  ///
  /// Slightly wider than [comboWindowMs] on purpose: the combo is about
  /// a streak, and this is about hurrying, which is a shade easier to
  /// keep up.
  static const int quickEatMs = 2000;

  /// Milliseconds left on the clock, or null when the run is not timed.
  int? get timeLeftMs {
    if (!mode.isTimed) return null;
    final left = timeAttackMs - elapsedMs;
    return left < 0 ? 0 : left;
  }

  /// How much of the clock is left, 0 to 1, for the ring in the HUD.
  double get timeFraction =>
      mode.isTimed ? (timeLeftMs! / timeAttackMs).clamp(0.0, 1.0) : 1.0;

  /// Whether the apple just taken was taken in a hurry. Lives for one
  /// tick, like [justAte].
  bool ateQuickly = false;

  /// Adventure grows portals from this level on.
  static const int portalFromLevel = 7;

  /// The two ends of the portal pair, when the level has one. Empty
  /// otherwise, and never any length but 0 or 2.
  List<GridPoint> portals = [];

  /// What a close call pays. Small on purpose: it is a thank-you for a
  /// save, not a reason to go hunting for walls.
  static const int closeCallPoints = 5;

  /// Scrapes survived this run — held on the brink and steered out of
  /// it. Worth reading on the end screen, and the thing milestones
  /// count.
  int closeCalls = 0;

  /// A scrape was survived on this tick. One tick long, like [justAte].
  bool justSurvivedCloseCall = false;

  // ─── Second chance ────────────────────────────────

  /// Modes a second chance belongs in: the long, exploratory ones.
  /// Classic is the pure ruleset and stays pure, Hardcore sells being
  /// unforgiving, and Zen cannot die in the first place.
  static const reviveModes = {GameMode.adventure, GameMode.endless};

  /// How far from the head obstacles are swept when a run is revived,
  /// so the snake does not come back inside a wall it cannot escape.
  static const int reviveClearRadius = 3;

  /// This run has already been brought back once. Never cleared except
  /// by [reset] — one per run is the whole bargain.
  bool revived = false;

  /// Whether this run could be brought back right now.
  bool get canRevive =>
      !revived &&
      !won &&
      phase == GamePhase.gameOver &&
      reviveModes.contains(mode);

  // ─── Tick tracking ────────────────────────────────

  int totalTicks = 0;
  int totalApplesEaten = 0;

  /// Pickups other than apples eaten this run (star, shield, speed, shrink,
  /// magnet), for quests.
  int powerUpsCollected = 0;

  /// In-game clock, advanced by [tickInterval] on every tick. Keeps all
  /// timed mechanics on wall-clock durations while staying fully
  /// deterministic for tests (no DateTime).
  int elapsedMs = 0;

  // ─── Wrap mode ────────────────────────────────────

  bool get wrapEnabled =>
      mode == GameMode.endless ||
      mode == GameMode.zen ||
      modifier == WeeklyModifier.noWalls;

  /// Under fog, whether a cell is close enough to the head to be lit.
  ///
  /// The rule lives here rather than in the painter so that the board
  /// and anything else that wants to know cannot answer it differently.
  /// Distance is straight-line, so the lit patch is a disc: the board
  /// draws it with a round glow, and a square rule under a round light
  /// would leave cells that count as lit sitting in the dark.
  bool lit(GridPoint cell) {
    if (modifier != WeeklyModifier.fog) return true;
    final dx = cell.x - head.x;
    final dy = cell.y - head.y;
    return dx * dx + dy * dy <=
        WeeklyModifier.fogRadius * WeeklyModifier.fogRadius;
  }

  /// Zen mode never ends the run on a collision — the snake just
  /// glides through itself and any obstacle.
  bool get isInvulnerable => mode == GameMode.zen;

  /// Score multiplier applied to every point gain. Hardcore doubles
  /// the risk/reward.
  double get scoreMultiplier => mode == GameMode.hardcore ? 2.0 : 1.0;

  // ─── Convenience ──────────────────────────────────

  GridPoint get head => snake.first;

  // ═══════════════════════════════════════════════════
  // Lifecycle
  // ═══════════════════════════════════════════════════

  void reset() {
    final startX = (initialLength - 1).clamp(1, columns - 1);
    final startY = rows ~/ 2;
    direction = Direction.right;
    inputQueue.clear();
    steers.clear();
    snake = [
      for (var i = 0; i < initialLength; i++) GridPoint(startX - i, startY),
    ];
    previousSnake = List.of(snake);
    score = 0;
    foodsEaten = 0;
    justAte = false;
    won = false;
    tickInterval = modifier == WeeklyModifier.doubleSpeed
        ? initialTick ~/ 2
        : initialTick;
    phase = GamePhase.ready;
    totalTicks = 0;
    totalApplesEaten = 0;
    powerUpsCollected = 0;
    elapsedMs = 0;

    // Combo
    comboCount = 0;
    lastEatMs = -comboWindowMs - 1;
    bestCombo = 0;

    // Power-ups
    hasShield = false;
    speedBurstUntilMs = 0;
    magnetUntilMs = 0;

    // Grace
    graceSpent = false;
    graceHeld = false;
    closeCalls = 0;
    justSurvivedCloseCall = false;
    revived = false;

    // Level
    level = 1;
    applesInLevel = 0;
    levelJustAdvanced = false;
    obstacles = _initialObstacles();
    atePoison = false;
    ateQuickly = false;
    portals = portalsForLevel(level);

    // Food
    foods = [];
    lastEatenFood = null;
    foods.add(FoodItem(position: _placeFirstFood(), type: FoodType.apple));
  }

  void start() {
    if (phase == GamePhase.gameOver) {
      reset();
    }
    if (phase == GamePhase.ready || phase == GamePhase.paused) {
      phase = GamePhase.running;
    }
  }

  void pause() {
    if (phase == GamePhase.running) {
      phase = GamePhase.paused;
    } else if (phase == GamePhase.paused) {
      phase = GamePhase.running;
    }
  }

  /// Queue a 90-degree turn, up to [maxQueuedTurns] deep.
  ///
  /// Each turn is checked against the direction the snake will actually
  /// be travelling when it lands — the last queued turn if one is
  /// pending, otherwise the current heading — so a buffered L-turn
  /// works but a reverse is still rejected.
  static const int maxQueuedTurns = 2;

  void queueTurn(Direction wanted) {
    // Mirroring happens here rather than in the input layer so that
    // every way in — swipe, arrow key, WASD — is bent the same way,
    // and so the rule can be tested without a finger.
    final next = modifier == WeeklyModifier.mirrored ? wanted.mirrored : wanted;
    final reference = inputQueue.isNotEmpty ? inputQueue.last : direction;
    if (next == reference || next == reference.opposite) {
      return;
    }
    if (phase == GamePhase.ready) {
      inputQueue.add(next);
      start();
      return;
    }
    if (phase == GamePhase.running && inputQueue.length < maxQueuedTurns) {
      inputQueue.add(next);
    }
  }

  // ═══════════════════════════════════════════════════
  // Tick
  // ═══════════════════════════════════════════════════

  void tick() {
    if (phase != GamePhase.running) {
      return;
    }

    // A timed run ends when the clock does, wherever the snake is and
    // whatever it was about to reach.
    if (mode.isTimed && elapsedMs >= timeAttackMs) {
      phase = GamePhase.gameOver;
      return;
    }

    justAte = false;
    lastEatenFood = null;
    levelJustAdvanced = false;
    justSurvivedCloseCall = false;
    atePoison = false;
    ateQuickly = false;
    // Whether the tick about to run is the one the snake was given to
    // save itself. Read before the flag is cleared for this tick.
    final wasHeld = graceHeld;
    graceHeld = false;
    totalTicks++;
    elapsedMs += tickInterval.inMilliseconds;
    previousSnake = List.of(snake);

    // Apply the next queued turn.
    if (inputQueue.isNotEmpty) {
      final next = inputQueue.removeAt(0);
      if (next != direction.opposite) {
        direction = next;
        // Recorded here rather than where the input arrived, because
        // this is the only place that knows which of the turns a player
        // asked for actually became one.
        steers.add((tick: totalTicks, direction: next));
      }
    }

    // Calculate next head position.
    var next = head + direction.delta;

    // ── Portals ──
    // Before every check below, so that what the snake is judged on is
    // where it actually ends up.
    next = _throughPortal(next);

    // ── Wall handling ──
    if (next.x < 0 || next.y < 0 || next.x >= columns || next.y >= rows) {
      if (wrapEnabled) {
        next = _wrap(next);
      } else if (shieldActive) {
        hasShield = false;
        next = _wrap(next);
      } else {
        _fatalMove();
        return;
      }
    }

    // ── Obstacle collision ──
    if (obstacles.contains(next)) {
      if (isInvulnerable) {
        // Pass straight through.
      } else if (shieldActive) {
        hasShield = false;
      } else {
        _fatalMove();
        return;
      }
    }

    // ── Check if eating ──
    final eatenIndex = foods.indexWhere((f) => f.position == next);
    final eating = eatenIndex >= 0;

    // ── Self-collision ──
    final bodyToCheck = eating ? snake : snake.sublist(0, snake.length - 1);
    if (!isInvulnerable && bodyToCheck.contains(next)) {
      _fatalMove();
      return;
    }

    // ── Move snake ──
    snake = [next, ...snake];

    if (eating) {
      final eaten = foods.removeAt(eatenIndex);
      lastEatenFood = eaten;
      justAte = true;
      _handleFoodEffect(eaten);

      // Ensure there's always a primary apple on the field.
      _ensurePrimaryApple();

      // Maybe spawn a bonus food.
      _maybeSpawnGoldenApple();
      _maybeSpawnBonusFood();
    } else {
      snake.removeLast();
    }

    // ── Combo decay ──
    if (!comboAlive) {
      comboCount = 0;
    }

    // ── Speed burst expiry ──
    if (speedBurstUntilMs > 0 && !speedBurstActive) {
      speedBurstUntilMs = 0;
      _recalculateSpeed();
    }

    // ── Despawn timed foods ──
    foods.removeWhere((f) => f.isExpired(elapsedMs));

    // ── Magnet pull ──
    _applyMagnet();

    // ── The golden apple runs ──
    _applyFlight();

    // Ensure we always have at least one apple.
    _ensurePrimaryApple();

    // The snake got through a whole tick alive, so the next scrape
    // starts with its grace intact — and if it was on the brink when
    // the tick began, it just steered out of one.
    graceSpent = false;
    if (wasHeld) {
      closeCalls++;
      justSurvivedCloseCall = true;
      score += (closeCallPoints * scoreMultiplier).round();
    }
  }

  // ═══════════════════════════════════════════════════
  // Second chance
  // ═══════════════════════════════════════════════════

  /// Brings a finished run back, once, leaving it paused at the brink
  /// it died on.
  ///
  /// What survives is what the player earned: the score, the apples,
  /// the level, the clock. What is taken is the position they had
  /// built — the snake is halved, the combo is dropped, and the
  /// obstacles crowding the head are swept so the snake does not come
  /// back inside a wall it cannot escape.
  ///
  /// The phase is left [GamePhase.paused] rather than running, because
  /// dropping a player straight back into a moving game is how you
  /// turn a rescue into a second death. Whoever called this counts
  /// them back in.
  void revive() {
    if (!canRevive) return;
    revived = true;

    final keep = max(3, snake.length ~/ 2);
    snake = snake.sublist(0, min(keep, snake.length));
    previousSnake = List.of(snake);

    obstacles = {
      for (final o in obstacles)
        if (_chebyshev(o, head) > reviveClearRadius) o,
    };

    comboCount = 0;
    lastEatMs = -comboWindowMs - 1;
    inputQueue.clear();
    graceSpent = false;
    graceHeld = false;
    justSurvivedCloseCall = false;

    // The heading that killed the snake will kill it again on the very
    // first tick, so it is turned to whichever way is actually open.
    direction = _openDirection();

    _ensurePrimaryApple();
    phase = GamePhase.paused;
  }

  static int _chebyshev(GridPoint a, GridPoint b) {
    final dx = (a.x - b.x).abs();
    final dy = (a.y - b.y).abs();
    return dx > dy ? dx : dy;
  }

  /// The current heading if it is survivable, otherwise a turn that is
  /// — and the current one again if the snake is boxed in, which is
  /// the player's problem to solve in the second they are given.
  Direction _openDirection() {
    final candidates = [
      direction,
      for (final d in Direction.values)
        if (d != direction && d != direction.opposite) d,
    ];
    for (final d in candidates) {
      if (_survivable(d)) return d;
    }
    return direction;
  }

  bool _survivable(Direction d) {
    var next = head + d.delta;
    final outside =
        next.x < 0 || next.y < 0 || next.x >= columns || next.y >= rows;
    if (outside) {
      if (!wrapEnabled) return false;
      next = _wrap(next);
    }
    if (obstacles.contains(next)) return false;
    // The tail vacates as the snake moves, so the last segment is free.
    return !snake.sublist(0, snake.length - 1).contains(next);
  }

  /// The move the snake was about to make would have killed it.
  ///
  /// Once per scrape, and never in Hardcore, the snake is held exactly
  /// where it is for one tick instead — the rest of this tick is
  /// skipped, so nothing moves, spawns, despawns or decays and the
  /// board is untouched when the player's late turn lands. A second
  /// doomed tick with nothing queued is the real thing.
  ///
  /// Grace is only offered with an empty input queue: a player who has
  /// already banked a turn is steering, not scraping, and that turn
  /// gets applied on the next tick regardless.
  void _fatalMove() {
    if (graceTicks > 0 && !graceSpent && inputQueue.isEmpty) {
      graceSpent = true;
      graceHeld = true;
      return;
    }
    phase = GamePhase.gameOver;
  }

  // ═══════════════════════════════════════════════════
  // Food effects
  // ═══════════════════════════════════════════════════

  void _handleFoodEffect(FoodItem eaten) {
    final shouldGrow = eaten.type.growsSnake;

    if (!shouldGrow) {
      // Remove the tail we just added (snake moved but shouldn't grow).
      if (snake.length > 1) snake.removeLast();
    }

    if (eaten.type != FoodType.apple) powerUpsCollected++;

    switch (eaten.type) {
      case FoodType.apple:
        // Read before the combo is updated, because it is the gap since
        // the *previous* apple that decides this.
        ateQuickly = mode.isTimed && elapsedMs - lastEatMs <= quickEatMs;
        foodsEaten++;
        totalApplesEaten++;
        applesInLevel++;
        final points =
            (pointsPerFood *
                    comboMultiplier *
                    scoreMultiplier *
                    (ateQuickly ? 2 : 1))
                .round();
        score += points;
        _updateCombo();
        _checkSpeedIncrease();
        _checkLevelAdvance();
        _checkHardcoreObstacles();

      case FoodType.star:
        // Worth what it had ripened to, not what it was worth when it
        // appeared.
        final points =
            (eaten.ripePoints(elapsedMs) * comboMultiplier * scoreMultiplier)
                .round();
        score += points;
        _updateCombo();

      case FoodType.golden:
        score += (goldenPoints * comboMultiplier * scoreMultiplier).round();
        _updateCombo();

      case FoodType.poison:
        atePoison = true;
        for (var i = 0; i < poisonSegments && snake.length > 2; i++) {
          snake.removeLast();
        }
        // The combo goes with the segments: the run does not simply
        // carry on as though nothing had happened.
        comboCount = 0;
        lastEatMs = -comboWindowMs - 1;

      case FoodType.shield:
        hasShield = true;
        score += (5 * scoreMultiplier).round();

      case FoodType.speedBurst:
        speedBurstUntilMs = elapsedMs + speedBurstMs;
        score += (5 * scoreMultiplier).round();
        _recalculateSpeed();

      case FoodType.shrink:
        score += (15 * scoreMultiplier).round();
        for (var i = 0; i < 2 && snake.length > 2; i++) {
          snake.removeLast();
        }

      case FoodType.magnet:
        magnetUntilMs = elapsedMs + magnetMs;
        score += (10 * scoreMultiplier).round();
    }
  }

  // ═══════════════════════════════════════════════════
  // Combo
  // ═══════════════════════════════════════════════════

  void _updateCombo() {
    if (comboAlive) {
      comboCount++;
    } else {
      comboCount = 1;
    }
    if (comboCount > bestCombo) {
      bestCombo = comboCount;
    }
    lastEatMs = elapsedMs;
  }

  // ═══════════════════════════════════════════════════
  // Speed
  // ═══════════════════════════════════════════════════

  void _checkSpeedIncrease() {
    if (foodsEaten % 4 == 0) {
      _recalculateSpeed();
    }
  }

  void _recalculateSpeed() {
    var baseMs = initialTick.inMilliseconds - (foodsEaten ~/ 4) * 10;
    baseMs = baseMs.clamp(minTick.inMilliseconds, initialTick.inMilliseconds);

    // Adventure mode speed multiplier.
    if (mode == GameMode.adventure) {
      final mult = LevelData.speedMultiplier(level);
      baseMs = (baseMs / mult).round().clamp(
        minTick.inMilliseconds,
        initialTick.inMilliseconds,
      );
    }

    // Hardcore mode: always a little faster.
    if (mode == GameMode.hardcore) {
      baseMs = (baseMs * 0.85).round().clamp(
        minTick.inMilliseconds,
        initialTick.inMilliseconds,
      );
    }

    // Double speed, for the whole run rather than for a pickup.
    if (modifier == WeeklyModifier.doubleSpeed) {
      baseMs = (baseMs * 0.5).round().clamp(
        (minTick.inMilliseconds * 0.5).round(),
        initialTick.inMilliseconds,
      );
    }

    // Speed burst doubles the speed.
    if (speedBurstActive) {
      baseMs = (baseMs * 0.5).round().clamp(
        (minTick.inMilliseconds * 0.5).round(),
        initialTick.inMilliseconds,
      );
    }

    tickInterval = Duration(milliseconds: baseMs);
  }

  // ═══════════════════════════════════════════════════
  // Levels (Adventure)
  // ═══════════════════════════════════════════════════

  void _checkLevelAdvance() {
    if (mode != GameMode.adventure) return;
    final required = LevelData.applesRequired(level);
    if (applesInLevel >= required) {
      level++;
      applesInLevel = 0;
      levelJustAdvanced = true;
      obstacles = LevelData.safeObstacles(
        LevelData.obstaclesForLevel(level, columns, rows),
        snake,
        columns,
        rows,
      );
      portals = portalsForLevel(level);
      _clearBuriedFood();
      _recalculateSpeed();
    }
  }

  /// Obstacles just moved. Anything they landed on top of can never be
  /// reached again, so clear it and let a fresh apple spawn.
  void _clearBuriedFood() {
    foods.removeWhere((f) => obstacles.contains(f.position));
    _ensurePrimaryApple();
  }

  Set<GridPoint> _initialObstacles() {
    // Adventure starts clean and earns its obstacles by level; hardcore
    // opens with them already on the board.
    final startLevel = switch (mode) {
      GameMode.adventure => 1,
      GameMode.hardcore => hardcoreStartLevel,
      _ => null,
    };
    if (startLevel == null) return {};
    return LevelData.safeObstacles(
      LevelData.obstaclesForLevel(startLevel, columns, rows),
      [
        for (var i = 0; i < initialLength; i++)
          GridPoint((initialLength - 1) - i, rows ~/ 2),
      ],
      columns,
      rows,
    );
  }

  // ═══════════════════════════════════════════════════
  // Obstacles (Hardcore)
  // ═══════════════════════════════════════════════════

  /// Hardcore has no levels, so its obstacles escalate on apples eaten:
  /// it opens on [hardcoreStartLevel]'s layout and moves up a pattern
  /// every [hardcoreApplesPerStep] apples.
  ///
  /// Level 7 (corner blocks) is the opener because it keeps the centre
  /// row clear — the snake starts there heading right, and a pattern
  /// across that lane would kill it before it could react.
  static const int hardcoreStartLevel = 7;
  static const int hardcoreApplesPerStep = 8;

  void _checkHardcoreObstacles() {
    if (mode != GameMode.hardcore) return;
    if (totalApplesEaten == 0 ||
        totalApplesEaten % hardcoreApplesPerStep != 0) {
      return;
    }
    final pseudoLevel =
        hardcoreStartLevel + totalApplesEaten ~/ hardcoreApplesPerStep;
    obstacles = LevelData.safeObstacles(
      LevelData.obstaclesForLevel(pseudoLevel, columns, rows),
      snake,
      columns,
      rows,
    );
    _clearBuriedFood();
  }

  // ═══════════════════════════════════════════════════
  // Food spawning
  // ═══════════════════════════════════════════════════

  void _ensurePrimaryApple() {
    final hasApple = foods.any((f) => f.type == FoodType.apple);
    if (!hasApple) {
      final pos = _spawnFood();
      if (pos == null) {
        won = true;
        phase = GamePhase.gameOver;
        return;
      }
      foods.insert(0, FoodItem(position: pos, type: FoodType.apple));
    }
  }

  /// A golden apple every [goldenEveryApples], in the two modes that
  /// have room for one. Counted, not rolled for: a thing worth chasing
  /// should be something the player can feel coming.
  void _maybeSpawnGoldenApple() {
    if (!goldenModes.contains(mode)) return;
    if (totalApplesEaten == 0) return;
    if (totalApplesEaten % goldenEveryApples != 0) return;
    if (foods.any((f) => f.type.flees)) return;
    final pos = _spawnFood();
    if (pos == null) return;
    foods.add(
      FoodItem(
        position: pos,
        type: FoodType.golden,
        spawnMs: elapsedMs,
        lifetimeMs: goldenLifetimeMs,
      ),
    );
  }

  /// Everything that runs takes a step away from the head, every
  /// [goldenFleeTicks] ticks.
  void _applyFlight() {
    if (totalTicks % goldenFleeTicks != 0) return;
    if (!foods.any((f) => f.type.flees)) return;
    foods = [for (final f in foods) f.type.flees ? _fleeStep(f) : f];
  }

  /// One step directly away from the head where it can, sideways where
  /// it cannot, and nowhere at all when it is cornered — which is how
  /// the thing is caught.
  FoodItem _fleeStep(FoodItem item) {
    final pos = item.position;
    final dx = (pos.x - head.x).sign;
    final dy = (pos.y - head.y).sign;
    for (final next in [
      GridPoint(pos.x + dx, pos.y + dy),
      GridPoint(pos.x + dx, pos.y),
      GridPoint(pos.x, pos.y + dy),
    ]) {
      if (next == pos) continue;
      if (next.x < 0 || next.y < 0 || next.x >= columns || next.y >= rows) {
        continue;
      }
      if (_isOccupied(next) || portals.contains(next)) continue;
      return FoodItem(
        position: next,
        type: item.type,
        spawnMs: item.spawnMs,
        lifetimeMs: item.lifetimeMs,
      );
    }
    return item;
  }

  /// A head stepping onto one end of a portal comes out of the other,
  /// still travelling the way it was. The body follows on its own,
  /// because a snake is only a list of where its head has been.
  GridPoint _throughPortal(GridPoint next) {
    if (portals.length != 2) return next;
    if (next == portals.first) return portals.last;
    if (next == portals.last) return portals.first;
    return next;
  }

  /// The portal pair for a level, or nothing below [portalFromLevel].
  ///
  /// The two ends are put far apart and off the snake's opening lane,
  /// so arriving through one is a change of scene rather than a step
  /// sideways.
  List<GridPoint> portalsForLevel(int level) {
    if (mode != GameMode.adventure || level < portalFromLevel) return [];
    final lane = rows ~/ 2;
    final candidates = <GridPoint>[
      GridPoint(1, 1),
      GridPoint(columns - 2, rows - 2),
      GridPoint(columns - 2, 1),
      GridPoint(1, rows - 2),
    ].where((p) => p.y != lane && !obstacles.contains(p)).toList();
    if (candidates.length < 2) return [];
    final first = candidates[level % candidates.length];
    final second = candidates.firstWhere(
      (p) => p != first && (p.x - first.x).abs() + (p.y - first.y).abs() > 4,
      orElse: () => candidates.firstWhere((p) => p != first),
    );
    return [first, second];
  }

  void _maybeSpawnBonusFood() {
    if (foods.length >= 3) return;
    final chance = mode == GameMode.adventure ? 0.25 + level * 0.02 : 0.18;
    if (random.nextDouble() >= chance) return;

    final types = [
      FoodType.star,
      FoodType.shield,
      FoodType.speedBurst,
      FoodType.shrink,
      FoodType.magnet,
      // Hardcore is the mode that can afford to be unfair about it.
      if (mode == GameMode.hardcore) FoodType.poison,
    ];
    final type = types[random.nextInt(types.length)];
    final pos = _spawnFood();
    if (pos != null) {
      foods.add(
        FoodItem(
          position: pos,
          type: type,
          spawnMs: elapsedMs,
          lifetimeMs: bonusFoodLifetimeMs,
        ),
      );
    }
  }

  /// How long a bonus pickup stays on the board.
  static const int bonusFoodLifetimeMs = 6000;

  /// Food never spawns right on top of the player: closer than this many
  /// cells (Chebyshev) to the head is free points, or a combo handed out
  /// by luck instead of steering.
  static const int minSpawnDistance = 3;

  GridPoint _placeFirstFood() {
    final target = GridPoint(head.x + firstFoodDistance, head.y);
    if (target.x < columns &&
        !_isOccupied(target) &&
        !obstacles.contains(target)) {
      return target;
    }
    return _spawnFood() ?? target;
  }

  bool _isOccupied(GridPoint point) =>
      snake.contains(point) ||
      foods.any((f) => f.position == point) ||
      obstacles.contains(point);

  GridPoint? _spawnFood() {
    final empty = <GridPoint>[
      for (var y = 0; y < rows; y++)
        for (var x = 0; x < columns; x++)
          if (!_isOccupied(GridPoint(x, y))) GridPoint(x, y),
    ];
    if (empty.isEmpty) {
      return null;
    }
    // Prefer cells a fair distance from the head; fall back to anywhere
    // free once the board is too crowded to be choosy.
    final farEnough = empty.where(_isFarFromHead).toList();
    final candidates = farEnough.isEmpty ? empty : farEnough;
    return candidates[random.nextInt(candidates.length)];
  }

  bool _isFarFromHead(GridPoint point) {
    final dx = (point.x - head.x).abs();
    final dy = (point.y - head.y).abs();
    return (dx > dy ? dx : dy) >= minSpawnDistance;
  }

  // ═══════════════════════════════════════════════════
  // Magnet
  // ═══════════════════════════════════════════════════

  /// Pulls every food item one grid step toward the head, once per
  /// tick, while [magnetActive]. Never pulls a food onto the snake, an
  /// obstacle, or another food.
  void _applyMagnet() {
    if (!magnetActive) return;
    foods = [for (final f in foods) _magnetStep(f)];
  }

  FoodItem _magnetStep(FoodItem item) {
    final pos = item.position;
    final dx = (head.x - pos.x).clamp(-1, 1);
    final dy = (head.y - pos.y).clamp(-1, 1);
    if (dx == 0 && dy == 0) return item;

    final next = GridPoint(pos.x + dx, pos.y + dy);
    final blocked =
        snake.contains(next) ||
        obstacles.contains(next) ||
        foods.any((other) => !identical(other, item) && other.position == next);
    if (blocked) return item;

    return FoodItem(
      position: next,
      type: item.type,
      spawnMs: item.spawnMs,
      lifetimeMs: item.lifetimeMs,
    );
  }

  GridPoint _wrap(GridPoint p) {
    return GridPoint(
      ((p.x % columns) + columns) % columns,
      ((p.y % rows) + rows) % rows,
    );
  }
}
