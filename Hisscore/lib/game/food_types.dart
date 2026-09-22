import 'snake_engine.dart';

/// Types of collectible food that appear on the board.
enum FoodType {
  /// Standard apple: +10 points, snake grows by 1.
  apple,

  /// High-value star: +50 points, no growth. Despawns after a timeout.
  star,

  /// Shield pickup: pass through one wall or obstacle collision. Despawns.
  shield,

  /// Speed burst: doubles tick speed for ~3 seconds. Despawns.
  speedBurst,

  /// Shrink potion: snake loses up to 2 tail segments. Despawns.
  shrink,

  /// Magnet: pulls every other food item one step closer each tick
  /// for a short while. Despawns.
  magnet,

  /// A golden apple that runs: worth a great deal times the combo, and
  /// nothing at all if it gets away. Adventure and Endless only.
  golden,

  /// Hardcore only. It looks like an apple; the tint is the tell.
  /// Eating it costs three segments and the combo.
  poison;

  /// Whether eating this type causes the snake to grow by one segment.
  bool get growsSnake => this == FoodType.apple;

  /// Whether this pickup is worth more the longer it is left alone.
  bool get ripens => this == FoodType.star;

  /// Whether this pickup runs from the head instead of waiting to be
  /// taken.
  bool get flees => this == FoodType.golden;

  /// Whether taking this hurts.
  bool get harmful => this == FoodType.poison;

  /// Display label for UI.
  String get label => switch (this) {
    FoodType.apple => 'APPLE',
    FoodType.star => 'STAR',
    FoodType.shield => 'SHIELD',
    FoodType.speedBurst => 'SPEED',
    FoodType.shrink => 'SHRINK',
    FoodType.magnet => 'MAGNET',
    FoodType.golden => 'GOLDEN',
    FoodType.poison => 'POISON',
  };

  /// What eating it actually does, in the fewest words that still say
  /// it. A coloured dot and a name told nobody what SHRINK or MAGNET
  /// were for, and a pickup the player cannot read is a pickup they
  /// avoid.
  String get effect => switch (this) {
    FoodType.apple => 'GROW  ·  +10',
    FoodType.star => 'RIPENS FROM +50 TO +150',
    FoodType.shield => 'SURVIVE ONE HIT',
    FoodType.speedBurst => 'DOUBLE SPEED, BRIEFLY',
    FoodType.shrink => 'LOSE 2 SEGMENTS',
    FoodType.magnet => 'DRAGS FOOD TO YOU',
    FoodType.golden => 'RUNS AWAY  ·  +100 × COMBO',
    FoodType.poison => 'LOOKS LIKE AN APPLE. IS NOT',
  };
}

/// A single collectible item on the game board.
///
/// Lifetimes are tracked in milliseconds off the engine's own clock, not
/// tick counts — the tick interval shrinks as the game speeds up, so a
/// tick-based lifetime would quietly halve in real time.
class FoodItem {
  const FoodItem({
    required this.position,
    required this.type,
    this.spawnMs = 0,
    this.lifetimeMs,
  });

  /// Grid position of this item.
  final GridPoint position;

  /// What kind of food this is.
  final FoodType type;

  /// Engine clock reading when this item was spawned.
  final int spawnMs;

  /// How long this item lives before despawning, in milliseconds.
  /// `null` means it stays until eaten (apples).
  final int? lifetimeMs;

  /// How long this item has been on the board at [nowMs].
  int ageMs(int nowMs) => nowMs - spawnMs;

  /// Whether this food has expired at the given clock reading.
  bool isExpired(int nowMs) {
    if (lifetimeMs == null) return false;
    return ageMs(nowMs) >= lifetimeMs!;
  }

  /// Fraction of lifetime remaining (1.0 = just spawned, 0.0 = about to expire).
  double lifeFraction(int nowMs) {
    if (lifetimeMs == null) return 1.0;
    return (1.0 - ageMs(nowMs) / lifetimeMs!).clamp(0.0, 1.0);
  }

  /// What a star is worth the moment it appears, and in its last
  /// moment before it goes.
  ///
  /// The gap between them is the whole point: a star taken on sight is
  /// worth having, and a star left to ripen is worth three times as
  /// much — if the player can still reach it, and if they can bear to
  /// leave it that long.
  static const int starPointsFresh = 50;
  static const int starPointsRipe = 150;

  /// What a ripening pickup is worth at [nowMs], before combos and mode
  /// multipliers. Zero for anything that does not ripen, which is
  /// everything except the star.
  int ripePoints(int nowMs) {
    if (!type.ripens) return 0;
    final ripeness = 1 - lifeFraction(nowMs);
    return (starPointsFresh + (starPointsRipe - starPointsFresh) * ripeness)
        .round();
  }
}
