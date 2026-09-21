import 'package:flutter/material.dart';

import 'controls.dart';
import 'theme.dart';

/// The arcade cabinet the menu lives inside: chrome, the glowing title,
/// the sound toggles, the demo screen and the PLAY button.
///
/// The cabinet knows nothing about a run. Whatever should appear on its
/// screen is passed in as [screen], which keeps the mode picker, the
/// tabs and the attract demo out of here.
class IntroCabinet extends StatelessWidget {
  const IntroCabinet({
    super.key,
    required this.titleGlow,
    required this.subtitle,
    required this.subtitleColor,
    required this.soundEnabled,
    required this.musicEnabled,
    required this.hapticsEnabled,
    required this.onToggleSound,
    required this.onToggleMusic,
    required this.onToggleHaptics,
    required this.screen,
    required this.onPlay,
  });

  /// Drives the sweep of light across the title.
  final Animation<double> titleGlow;

  /// 'RETRO SNAKE' before a run, the mode's name once one is picked.
  final String subtitle;
  final Color subtitleColor;

  final bool soundEnabled;
  final bool musicEnabled;
  final bool hapticsEnabled;
  final VoidCallback onToggleSound;
  final VoidCallback onToggleMusic;
  final VoidCallback onToggleHaptics;

  /// What plays inside the cabinet's screen.
  final Widget screen;

  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF201810),
            RetroColors.cabinet,
            const Color(0xFF181010),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: RetroColors.cabinetRim, width: 5),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 28,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
        child: Column(
          children: [
            GlowingTitle(glow: titleGlow),
            const SizedBox(height: 4),
            _buildSubtitleRow(),
            const SizedBox(height: 12),
            Expanded(child: screen),
            const SizedBox(height: 14),
            ArcadeActionButton(label: 'PLAY', onPressed: onPlay),
            const SizedBox(height: 8),
            Text(
              'SWIPE TO STEER  ·  ARROWS / WASD',
              textAlign: TextAlign.center,
              style: RetroText.pixel(size: 7, color: RetroColors.metal),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubtitleRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(subtitle, style: RetroText.pixel(size: 7, color: subtitleColor)),
        const SizedBox(width: 10),
        _ToggleIcon(
          icon: soundEnabled ? Icons.volume_up : Icons.volume_off,
          onTap: onToggleSound,
        ),
        const SizedBox(width: 8),
        _ToggleIcon(
          icon: musicEnabled ? Icons.music_note : Icons.music_off,
          onTap: onToggleMusic,
        ),
        const SizedBox(width: 8),
        _ToggleIcon(
          icon: hapticsEnabled ? Icons.vibration : Icons.smartphone,
          onTap: onToggleHaptics,
        ),
      ],
    );
  }
}

class _ToggleIcon extends StatelessWidget {
  const _ToggleIcon({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Icon(icon, size: 12, color: RetroColors.phosphorDim),
    );
  }
}

/// HISCORE, with a band of light sweeping across the letters.
class GlowingTitle extends StatelessWidget {
  const GlowingTitle({super.key, required this.glow});

  final Animation<double> glow;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: glow,
      builder: (context, _) {
        return ShaderMask(
          shaderCallback: (bounds) {
            final pos = glow.value;
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                RetroColors.amber,
                RetroColors.phosphorHot,
                RetroColors.amber,
              ],
              stops: [
                (pos - 0.3).clamp(0.0, 1.0),
                pos,
                (pos + 0.3).clamp(0.0, 1.0),
              ],
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcIn,
          child: Text(
            'HISCORE',
            style: RetroText.pixel(
              size: 22,
              color: Colors.white,
              letterSpacing: 4,
            ),
          ),
        );
      },
    );
  }
}
