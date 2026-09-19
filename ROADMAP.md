# Hisscore roadmap

Goal: make Hisscore the next viral casual game. Order is by impact per effort.

## Phase 1: First impression and shareability (~1 week)

| Task | Where | Done when |
|---|---|---|
| Shrink the menu overlay so the attract demo is visible; fix wrapped `ZEN` chip | `ready_tabs.dart`, `game_overlay.dart` | Board at least 50% visible behind the menu |
| Keep the cabinet frame in-game (no full-bleed jump) | `game_page.dart` | Layout identical in menu and play |
| Share card: render final board with score, mode, daily number to an image | new `ui/share_card.dart`, existing share flow | Shares on web and Android |
| Golden tests for the board painter | `test/` | Covers snake, all 6 pickups, obstacles |
| PWA: installable and offline | `web/` | Passes Lighthouse PWA checks |

## Phase 2: Juice, themes and audio (~2 weeks)

1. **Theme system.** Turn `RetroColors` into a `GameTheme` (palette, CRT strength, grid style). Ship 5 themes: Phosphor, Amber, Game Boy, Synthwave, Vector. Persist the choice in the store.
2. **Snake skins.** `SnakeSkin` painter strategy: pixel-block, scaled, neon-trail, combo rainbow.
3. **Juice.** Head squash-and-stretch, combo-scaled trail glow, speed-burst blur, death flash and slow-mo, level-up edge pulse.
4. **Audio.** Layered chiptune music that follows combo intensity (via `tool/generate_sfx.dart`), per-power-up stingers, volume and mute setting.
5. **Per-level adventure backdrops.**

## Phase 3: Competition (~2 weeks)

1. **Fixed-grid daily.** Pin the daily to one grid size and letterbox it on other screens so scores are comparable.
2. **Firebase anonymous auth + Firestore.** `RemoteScoreStore` behind the `HighScoreStore` seam; daily and all-time leaderboards; server-side sanity checks by replaying the input log (the engine is deterministic).
3. **Friend codes and seed links.** `?seed=...` opens a specific board for "beat my score".
4. **Wordle-style result grid** for the daily.

## Phase 4: Depth and retention (~3 weeks)

1. **Progression.** XP and player level, unlockable cosmetics, 3 daily quests, streak freeze.
2. **Risk/reward mechanics** (each behind a mode or flag so classic stays pure): moving golden apple, greed multiplier, poison apple in hardcore, portals.
3. **Weekly modifier** (double speed, no walls, mirrored controls).

## Phase 5: New modes and multiplayer (~4 weeks)

1. Time Attack (60 seconds).
2. Ghost race from a recorded replay.
3. Battle Royale: shrinking arena with AI snakes.
4. Async head-to-head on a shared seed.
5. Real-time 2-player, local first, online later.

## Cross-cutting

- **Refactor first:** extract a `GameSession` controller from `game_page.dart` before phase 4 (quests, ghosts and multiplayer all hook into it).
- **CI stays green:** each phase ships as its own PR with tests; `flutter analyze`, format check and the Android build must pass.
- **Measure:** opt-in analytics (D1/D7 retention, share rate, daily completion); requires a privacy policy update.
- **Device verification** of sound, haptics, share and notifications (see `RELEASE.md`) before each release.

## Open decisions

1. **Backend:** Firebase (recommended) or custom?
2. **Monetization:** none, cosmetic-only IAP, or ads? Shapes progression design.
3. **Launch scope:** ship after phase 1, or after phase 3?
