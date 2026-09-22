import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game/food_types.dart';
import '../game/haptics.dart';
import '../game/snake_engine.dart';
import 'theme.dart';

// ─── Arcade action button (PLAY / PAUSE / etc.) ─────

class ArcadeActionButton extends StatefulWidget {
  const ArcadeActionButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  State<ArcadeActionButton> createState() => _ArcadeActionButtonState();
}

class _ArcadeActionButtonState extends State<ArcadeActionButton>
    with TickerProviderStateMixin {
  late final AnimationController _glow;
  late final AnimationController _press;

  @override
  void initState() {
    super.initState();
    _glow = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _press = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 70),
    );
  }

  @override
  void dispose() {
    _glow.dispose();
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_glow, _press]),
      builder: (context, child) {
        final scale = 1.0 - _press.value * 0.08;
        return Semantics(
          button: true,
          label: widget.label,
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (_) {
                _press.forward();
                Haptics.instance.tap();
                widget.onPressed();
              },
              onTapUp: (_) => _press.reverse(),
              onTapCancel: () => _press.reverse(),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF5A4432), Color(0xFF281C12)],
                    ),
                    border: Border.all(
                      color: RetroColors.cabinetHighlight.withValues(
                        alpha: 0.5,
                      ),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: RetroColors.cherry.withValues(
                          alpha: 0.25 + _glow.value * 0.25,
                        ),
                        blurRadius: 10 + _glow.value * 6,
                        spreadRadius: _glow.value * 1.5,
                      ),
                    ],
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFFFF5252),
                          RetroColors.cherry,
                          Color(0xFFB71C1C),
                        ],
                        stops: [0.0, 0.45, 1.0],
                      ),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.35),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      widget.label,
                      style: RetroText.pixel(size: 9.5, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─── Secondary arcade button (MENU / CHANGE MODE / RESUME) ────

class SecondaryArcadeButton extends StatelessWidget {
  const SecondaryArcadeButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color,
  });

  final String label;
  final VoidCallback onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? RetroColors.metal;
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Haptics.instance.tap();
            onPressed();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: RetroColors.screen,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: c.withValues(alpha: 0.7), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: c.withValues(alpha: 0.2),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Text(label, style: RetroText.pixel(size: 7.5, color: c)),
          ),
        ),
      ),
    );
  }
}

// ─── Score readout ───────────────────────────────────

class ScoreReadout extends StatelessWidget {
  const ScoreReadout({
    super.key,
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final int value;
  final bool highlight;

  String get padded => value.toString().padLeft(5, '0');

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: RetroText.pixel(size: 7, color: RetroColors.phosphorDim),
        ),
        const SizedBox(height: 4),
        Text(
          padded,
          key: Key('score-$label'),
          style: RetroText.pixel(
            size: 13,
            color: highlight ? RetroColors.amber : RetroColors.phosphor,
          ),
        ),
      ],
    );
  }
}

// ─── Game mode selector ─────────────────────────────

class ModeSelector extends StatelessWidget {
  const ModeSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final GameMode selected;
  final ValueChanged<GameMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'SELECT MODE',
          style: RetroText.pixel(size: 9, color: RetroColors.phosphorDim),
        ),
        const SizedBox(height: 8),
        // Fixed rows so the last chip is never left orphaned on a line of
        // its own when the screen is narrow.
        for (final row in [
          GameMode.values.take(3).toList(),
          GameMode.values.skip(3).toList(),
        ]) ...[
          if (row.first != GameMode.values.first) const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final mode in row) ...[
                if (mode != row.first) const SizedBox(width: 8),
                _ModeChip(
                  mode: mode,
                  isSelected: mode == selected,
                  onTap: () => onChanged(mode),
                ),
              ],
            ],
          ),
        ],
        const SizedBox(height: 6),
        Text(
          selected.description,
          style: RetroText.pixel(size: 8, color: RetroColors.metal),
        ),
      ],
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.mode,
    required this.isSelected,
    required this.onTap,
  });

  final GameMode mode;
  final bool isSelected;
  final VoidCallback onTap;

  static const _chipFade = Duration(milliseconds: 200);

  @override
  Widget build(BuildContext context) {
    final accent = mode.accentColor;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: _chipFade,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? accent : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isSelected ? accent : accent.withValues(alpha: 0.55),
            width: 1.5,
          ),
        ),
        // The label fades with the fill — switching it instantly leaves
        // dark text on a still-dark chip for the length of the fade.
        child: AnimatedDefaultTextStyle(
          duration: _chipFade,
          style: RetroText.pixel(
            size: 7,
            color: isSelected ? RetroColors.cabinet : accent,
          ),
          child: Text(mode.label),
        ),
      ),
    );
  }
}

// ─── Food legend (ready screen) ─────────────────────

/// Small key showing what each collectible on the board does, so a
/// first-time player isn't guessing what the colored shapes mean.
class FoodLegend extends StatelessWidget {
  const FoodLegend({super.key, this.detailed = false});

  /// Whether each pickup also says what it does. The compact form is a
  /// reminder for someone who already knows; the detailed one is the
  /// only place the rules are actually written down.
  final bool detailed;

  /// Read live rather than held in a const map: the palette swaps with
  /// the chosen theme, so a cached colour would go stale.
  static Color colorFor(FoodType type) => switch (type) {
    FoodType.apple => RetroColors.food,
    FoodType.star => RetroColors.starGold,
    FoodType.shield => RetroColors.shieldCyan,
    FoodType.speedBurst => RetroColors.speedYellow,
    FoodType.shrink => RetroColors.shrinkPurple,
    FoodType.magnet => RetroColors.magnetPink,
    FoodType.golden => RetroColors.starGold,
    // Deliberately close to the apple: the tint is the whole tell, and
    // a poison apple that announced itself would not be one.
    FoodType.poison => RetroColors.poison,
  };

  @override
  Widget build(BuildContext context) {
    if (detailed) {
      // One left edge for the whole block, or every row centres itself
      // and the dots and names come out ragged. IntrinsicWidth sizes
      // the column to its widest row and the rows align inside it.
      return IntrinsicWidth(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final type in FoodType.values)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: _LegendRow(type: type, detailed: true),
              ),
          ],
        ),
      );
    }
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 10,
      runSpacing: 4,
      children: [for (final type in FoodType.values) _LegendRow(type: type)],
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.type, this.detailed = false});

  final FoodType type;
  final bool detailed;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: FoodLegend.colorFor(type),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        if (detailed)
          SizedBox(
            // Wide enough for MAGNET plus a gap, so the effects line up
            // in their own column rather than butting against the name.
            width: 68,
            child: Text(
              type.label,
              style: RetroText.pixel(size: 7, color: FoodLegend.colorFor(type)),
            ),
          )
        else
          Text(
            type.label,
            style: RetroText.pixel(size: 7, color: RetroColors.metal),
          ),
        if (detailed)
          Text(
            type.effect,
            style: RetroText.pixel(size: 7, color: RetroColors.metal),
          ),
      ],
    );
  }
}

// ─── Keyboard ───────────────────────────────────────

/// Everything the keyboard can do during a game.
///
/// Arrows and WASD steer; space and enter are the one primary action
/// (play, pause, resume); escape pauses a run and leaves a finished
/// one; P toggles pause; M and Q go back to the menu. The bindings that
/// depend on where the game is read [phase] when they fire rather than
/// when they are built, so one map serves every phase.
Map<ShortcutActivator, VoidCallback> gameKeyBindings({
  required GamePhase Function() phase,
  required void Function(Direction) onTurn,
  required VoidCallback onPrimary,
  required VoidCallback onPause,
  required VoidCallback onExitToMenu,
}) {
  SingleActivator key(LogicalKeyboardKey k) => SingleActivator(k);
  return {
    key(LogicalKeyboardKey.arrowUp): () => onTurn(Direction.up),
    key(LogicalKeyboardKey.arrowDown): () => onTurn(Direction.down),
    key(LogicalKeyboardKey.arrowLeft): () => onTurn(Direction.left),
    key(LogicalKeyboardKey.arrowRight): () => onTurn(Direction.right),
    key(LogicalKeyboardKey.keyW): () => onTurn(Direction.up),
    key(LogicalKeyboardKey.keyS): () => onTurn(Direction.down),
    key(LogicalKeyboardKey.keyA): () => onTurn(Direction.left),
    key(LogicalKeyboardKey.keyD): () => onTurn(Direction.right),
    key(LogicalKeyboardKey.space): onPrimary,
    key(LogicalKeyboardKey.enter): onPrimary,
    key(LogicalKeyboardKey.escape): () {
      final at = phase();
      if (at == GamePhase.running) {
        onPause();
      } else if (at == GamePhase.paused || at == GamePhase.gameOver) {
        onExitToMenu();
      }
    },
    key(LogicalKeyboardKey.keyP): () {
      final at = phase();
      if (at == GamePhase.running || at == GamePhase.paused) onPrimary();
    },
    key(LogicalKeyboardKey.keyM): () {
      if (phase() != GamePhase.ready) onExitToMenu();
    },
    key(LogicalKeyboardKey.keyQ): () {
      if (phase() != GamePhase.ready) onExitToMenu();
    },
  };
}
