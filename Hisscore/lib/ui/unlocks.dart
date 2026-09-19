import 'snake_skin.dart';
import 'theme.dart';

/// Something earned by reaching a player level.
class Unlock {
  const Unlock({required this.kind, required this.name, required this.level});

  /// `THEME` or `SKIN`.
  final String kind;
  final String name;
  final int level;

  @override
  String toString() => '$name $kind';
}

/// Every theme and skin that needs more than the starting level, in the
/// order they are earned.
List<Unlock> allUnlocks() => [
  for (final t in GameTheme.all)
    if (t.unlockLevel > 1)
      Unlock(kind: 'THEME', name: t.label, level: t.unlockLevel),
  for (final s in SnakeSkin.values)
    if (s.unlockLevel > 1)
      Unlock(kind: 'SKIN', name: s.label, level: s.unlockLevel),
]..sort((a, b) => a.level.compareTo(b.level));

/// What reaching level [after] from level [before] earned.
List<Unlock> unlocksBetween(int before, int after) => [
  for (final u in allUnlocks())
    if (u.level > before && u.level <= after) u,
];
