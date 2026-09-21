# Changelog

Notable changes per release, written for users. Versions follow [Semantic Versioning](https://semver.org) and match the app version (`Hisscore/pubspec.yaml`).

## [Unreleased]

### Added
- Deaths are fairer. A turn that lands a frame too late now still counts: the
  snake freezes for one tick on the brink instead of dying outright, so the
  input you swear you made actually saves you. Hardcore is untouched.
- Dying now plays out in slow motion for a moment before the game-over card
  appears, so you can see what actually killed you.
- Every scrape you steer out of is a CLOSE CALL: a label, a sting and +5
  points, counted on the end screen.
- Beating your own best is announced the moment it happens, instead of only
  at game over.
- First-time players get a moving SWIPE TO STEER hint on the menu, over the demo
  snake, until they have finished a run.
- Pausing now shows what every pickup does, not just its name — no more guessing
  what SHRINK or MAGNET are for. The HOW tab spells them out too.

## [1.0.1] - 2026-09-20

### Fixed
- Sound effects no longer silence your own music. Starting a game used to take over
  the phone's audio and stop whatever you had playing, and never hand it back; the
  game's sounds now mix with it instead.

## [1.0.0] - 2026-09-19

The first release.

### Added
- Retro Snake with Classic, Adventure, Endless, Hardcore and Zen modes, power-ups and combos.
- Adventure levels that change scenery every three levels.
- Four looks (Phosphor, Amber, Game Boy, Synthwave) and four snake skins (Classic, Pixel, Neon, Rainbow), earned by playing.
- Daily quests, XP and player levels.
- A daily challenge with streaks, the same board for everyone on every screen, and a shareable result.
- Challenge codes: play a friend's exact game and compare scores.
- Global leaderboards for the daily and for each mode, with a name you choose.
- Chiptune music that builds with your combo, and a sound for each power-up.
- Share your score as a picture.
