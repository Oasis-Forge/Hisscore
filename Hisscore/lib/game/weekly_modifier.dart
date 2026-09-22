/// One rule that bends the daily challenge for a whole week.
///
/// The daily already gives everyone the same board; a modifier gives
/// everyone the same *strange* board, and changes it often enough that
/// the daily is worth coming back to but rarely enough that a week is
/// long enough to get good at one.
///
/// No Flutter dependency, and no engine dependency either: the engine
/// imports this, not the other way round.
enum WeeklyModifier {
  doubleSpeed('DOUBLE SPEED', 'Everything runs twice as fast'),
  noWalls('NO WALLS', 'Leave by one edge, come back by the other'),
  mirrored('MIRRORED', 'Left steers right, and right steers left'),
  fog('FOG', 'Only the ground near your head is lit'),
  tinyBoard('TINY BOARD', 'A smaller board, with nowhere to hide'),
  magnetMadness('MAGNET MADNESS', 'Food comes to you, all run long');

  const WeeklyModifier(this.label, this.blurb);

  /// Shouted on the daily card and the share image.
  final String label;

  /// One line saying what it does, for the card that offers the run.
  final String blurb;

  /// How far the light reaches under [fog], in cells. Far enough to
  /// see the turn you are about to take, short enough that the apple
  /// has to be hunted.
  static const int fogRadius = 5;

  /// How far past [fogRadius] the light takes to die out, in cells.
  /// A hard edge reads as a hole cut in the board; a short fade reads
  /// as the dark closing in.
  static const double fogFeather = 2;

  /// The board [tinyBoard] plays on. Narrow enough to feel cramped,
  /// still tall enough for the snake to have somewhere to go.
  static const int tinyColumns = 14;
  static const int tinyRows = 20;
}
