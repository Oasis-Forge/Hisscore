# Changelog

Notable changes per release, written for users. Versions follow [Semantic Versioning](https://semver.org) and match the app version (`Hisscore/pubspec.yaml`).

## [Unreleased]

### Changed
- **Your scores are not sent anywhere unless you say so.** The first time you
  finish a run worth sending, the game asks — and until you answer, and if you
  answer no, nothing about you leaves the phone. You can change your mind any
  time under SENDING YOUR SCORES on the STATS tab. Everything except the global
  boards works either way.
- Every phone now plays the same amount of board. The grid used to be 20 wide
  with as many rows as your screen was tall, which handed a tall phone 60% more
  room than a short one — and then put both on the same leaderboard. Runs still
  fill the screen edge to edge; the cells are just sized to fit.

### Added
- Race yourself on the daily. Your best run of the day comes back as a faint
  ghost snake running the board alongside you, and the daily card says the
  score to beat. It only ever shows on the board it was set on.
- A sixth mode: TIME ATTACK. Sixty seconds on the same board on every phone,
  with a timer ring in the corner that turns red for the last ten seconds, and
  apples worth double when you take one within two seconds of the last. It has
  its own all-time leaderboard.
- Stars now ripen. One is worth 50 the moment it appears and 150 in the last
  second before it goes, with its price written on it and a blink that gets
  frantic near the end — so leaving it is worth points, and leaving it too long
  is worth nothing.
- A golden apple that runs away, in Adventure and Endless. It turns up every
  dozen apples, pays a hundred points times your combo, and steps away from your
  head every few ticks: you catch it by cutting it off, not by chasing it. It is
  gone in eight seconds.
- Hardcore now hides a poison apple among the real ones. The only tell is the
  colour. Eating it costs three segments and your combo.
- Adventure grows a pair of portals from level 7: go in one, come out of the
  other still travelling the way you were.
- Your daily streak now survives a day you miss. Every seven days in a row banks
  a streak freeze, up to two, and one is spent by itself the next time you play
  after a gap — the game tells you it did it rather than leaving you to wonder.
  The daily card says how many you have in hand.
- Twenty-one local firsts, each paying XP the once: your first pickup, a ten-apple
  combo, a thousand apples, level 25, a thirty-day streak, five close calls in
  one run, a run in every mode, finishing a friend's challenge. Some carry a
  label you wear on the menu afterwards. They stay on your device.
- The daily challenge now plays by a different rule every week, the same one
  for everybody: everything twice as fast, no walls, mirrored steering, fog
  that lights only the ground near your head, a smaller board, or food that
  comes to you. The week's rule is named on the daily card before you press
  play, on the game-over card, and on what you share.
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
