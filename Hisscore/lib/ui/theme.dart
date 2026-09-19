import 'package:flutter/material.dart';

import '../game/snake_engine.dart';

/// Phosphor CRT palette for the Hisscore cabinet.
abstract final class RetroColors {
  /// The active theme. Themable colors below read from it, so changing it
  /// and rebuilding restyles the whole UI. Pickup colors are semantic
  /// (a shield is always cyan) and stay fixed.
  static GameTheme current = GameTheme.phosphorGreen;

  // ─── Background & cabinet ──────────────────────────
  static Color get voidBg => current.voidBg;
  static Color get cabinet => current.cabinet;
  static Color get cabinetRim => current.cabinetRim;
  static Color get cabinetHighlight => current.cabinetHighlight;
  static Color get metal => current.metal;

  // ─── CRT screen ────────────────────────────────────
  static Color get screen => current.screen;
  static Color get grid => current.grid;
  static const scanline = Color(0x22000000);

  // ─── Snake phosphor ────────────────────────────────
  static Color get phosphor => current.phosphor;
  static Color get phosphorDim => current.phosphorDim;
  static Color get phosphorHot => current.phosphorHot;
  static Color get snakeTail => current.snakeTail;

  // ─── UI accents ────────────────────────────────────
  static Color get amber => current.amber;
  static Color get amberDim => current.amberDim;
  static const cherry = Color(0xFFFF3B3B);
  static Color get food => current.food;

  // ─── Power-up colors ───────────────────────────────
  static const starGold = Color(0xFFFFD700);
  static const shieldCyan = Color(0xFF00E5FF);
  static const speedYellow = Color(0xFFFFEA00);
  static const shrinkPurple = Color(0xFFCE93D8);
  static const magnetPink = Color(0xFFFF6EC7);
  static const zenBlue = Color(0xFF7EC8FF);

  // ─── Gameplay ──────────────────────────────────────
  static const combo = Color(0xFFFFD740);
  static Color get obstacle => current.obstacle;
  static Color get obstacleRim => current.obstacleRim;
  static const levelFlash = Color(0xAAFFFFFF);
}

/// Per-mode accent color for UI badges/chips, so each mode reads as its
/// own risk level at a glance (green=safe, red=danger, blue=calm, ...).
extension GameModeUi on GameMode {
  Color get accentColor => switch (this) {
    GameMode.classic => RetroColors.phosphor,
    GameMode.adventure => RetroColors.amber,
    GameMode.endless => RetroColors.shieldCyan,
    GameMode.hardcore => RetroColors.cherry,
    GameMode.zen => RetroColors.zenBlue,
  };
}

abstract final class RetroText {
  static TextStyle pixel({
    double size = 12,
    Color? color,
    double letterSpacing = 1,
    double height = 1.3,
  }) {
    return TextStyle(
      fontFamily: 'PressStart2P',
      fontSize: size,
      color: color ?? RetroColors.phosphor,
      letterSpacing: letterSpacing,
      height: height,
    );
  }
}

/// A complete look for the cabinet: chrome, CRT screen, snake and UI
/// accents. Pickup and combo colors are not themed.
class GameTheme {
  const GameTheme({
    required this.id,
    required this.label,
    this.unlockLevel = 1,
    required this.voidBg,
    required this.cabinet,
    required this.cabinetRim,
    required this.cabinetHighlight,
    required this.metal,
    required this.screen,
    required this.grid,
    required this.phosphor,
    required this.phosphorDim,
    required this.phosphorHot,
    required this.snakeTail,
    required this.amber,
    required this.amberDim,
    required this.food,
    required this.obstacle,
    required this.obstacleRim,
  });

  final String id;
  final String label;

  /// The player level this look is earned at.
  final int unlockLevel;
  final Color voidBg;
  final Color cabinet;
  final Color cabinetRim;
  final Color cabinetHighlight;
  final Color metal;
  final Color screen;
  final Color grid;
  final Color phosphor;
  final Color phosphorDim;
  final Color phosphorHot;
  final Color snakeTail;
  final Color amber;
  final Color amberDim;
  final Color food;
  final Color obstacle;
  final Color obstacleRim;

  /// The original green-phosphor CRT.
  static const phosphorGreen = GameTheme(
    id: 'phosphor',
    label: 'PHOSPHOR',
    voidBg: Color(0xFF07080A),
    cabinet: Color(0xFF1A1410),
    cabinetRim: Color(0xFF3A2A1C),
    cabinetHighlight: Color(0xFF5A4A38),
    metal: Color(0xFF8A8478),
    screen: Color(0xFF03140A),
    grid: Color(0xFF0C2A16),
    phosphor: Color(0xFF7CFF6B),
    phosphorDim: Color(0xFF2E8A3A),
    phosphorHot: Color(0xFFD4FF9A),
    snakeTail: Color(0xFF1A6030),
    amber: Color(0xFFFFB000),
    amberDim: Color(0xFF8A6000),
    food: Color(0xFFFF5A6A),
    obstacle: Color(0xFF3A3028),
    obstacleRim: Color(0xFF5A4A3C),
  );

  /// Amber monochrome terminal.
  static const amberTerminal = GameTheme(
    id: 'amber',
    label: 'AMBER',
    unlockLevel: 2,
    voidBg: Color(0xFF0A0804),
    cabinet: Color(0xFF17120C),
    cabinetRim: Color(0xFF3A2C18),
    cabinetHighlight: Color(0xFF5A4A30),
    metal: Color(0xFF8A8070),
    screen: Color(0xFF140C02),
    grid: Color(0xFF2A1A06),
    phosphor: Color(0xFFFFB000),
    phosphorDim: Color(0xFF8A5A00),
    phosphorHot: Color(0xFFFFE0A0),
    snakeTail: Color(0xFF6A4200),
    amber: Color(0xFFFFD060),
    amberDim: Color(0xFF8A6A20),
    food: Color(0xFFFF6A3A),
    obstacle: Color(0xFF3A2A18),
    obstacleRim: Color(0xFF5A4630),
  );

  /// Handheld olive-green LCD.
  static const gameBoy = GameTheme(
    id: 'gameboy',
    label: 'GAME BOY',
    unlockLevel: 4,
    voidBg: Color(0xFF0B0F0A),
    cabinet: Color(0xFF3A3F36),
    cabinetRim: Color(0xFF555B4C),
    cabinetHighlight: Color(0xFF747B68),
    metal: Color(0xFFA8B096),
    screen: Color(0xFF0F2A0F),
    grid: Color(0xFF1A3D1A),
    phosphor: Color(0xFF9BBC0F),
    phosphorDim: Color(0xFF5A7A1A),
    phosphorHot: Color(0xFFCADC9F),
    snakeTail: Color(0xFF4A6A1A),
    amber: Color(0xFFCADC9F),
    amberDim: Color(0xFF5A7A1A),
    food: Color(0xFFE0F8D0),
    obstacle: Color(0xFF2A4A1A),
    obstacleRim: Color(0xFF8BAC0F),
  );

  /// Neon magenta and cyan on deep purple.
  static const synthwave = GameTheme(
    id: 'synthwave',
    label: 'SYNTHWAVE',
    unlockLevel: 6,
    voidBg: Color(0xFF0A0614),
    cabinet: Color(0xFF1A0F2E),
    cabinetRim: Color(0xFF4A2A7A),
    cabinetHighlight: Color(0xFF7A4AB0),
    metal: Color(0xFF9A88C0),
    screen: Color(0xFF12082A),
    grid: Color(0xFF2A1450),
    phosphor: Color(0xFF00F0FF),
    phosphorDim: Color(0xFF1A8AA0),
    phosphorHot: Color(0xFFB0FFFF),
    snakeTail: Color(0xFF7A2A9A),
    amber: Color(0xFFFF3EC8),
    amberDim: Color(0xFF8A2A6A),
    food: Color(0xFFFFE03A),
    obstacle: Color(0xFF3A1A5A),
    obstacleRim: Color(0xFF6A3A9A),
  );

  static const all = [phosphorGreen, amberTerminal, gameBoy, synthwave];

  static GameTheme byId(String? id) =>
      all.firstWhere((t) => t.id == id, orElse: () => phosphorGreen);
}
