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
- A second chance, once per run, in Adventure and Endless: take it within three
  seconds of dying and the run carries on with your score, apples and level
  intact — at the cost of half your snake, your combo, and a "REVIVED" mark on
  the card and the share image. Not offered on the daily or a friend's code,
  where everyone has to have played the same game.
- The game-over screen now tells you where you stand: a bar showing this run
  against your best and how far short it fell, your place on the board and the
  points to the person above you, an XP bar that fills from where you were, and
  each daily quest ticking up by what the run just added.
- The game now buzzes where it should: a tap on an apple, a click on a pickup
  or a close call, a stronger pulse on each combo step, two on a level-up and a
  heavy one on death. There is a vibration switch on the menu next to the sound
  and music ones, and turning it off silences the buttons too.
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
