# Hisscore: a plan to make it more fun

Written 2026-09-21 from the roadmap, the handoff and a skim of the engine, not from playing it.
It is a proposal for the next stretch of work, ordered by fun gained per effort. The roadmap
(`ROADMAP.md`) stays the source of truth for what is done; this file says what to do next and how.

## How to work this plan (read first)

- One theme per PR, branch from a freshly pulled `main`. **Every merged PR is a release**: bump the
  version (`/release minor` for a feature, `patch` for a fix) and add a line under `Unreleased` in
  `CHANGELOG.md` written for players. The first branch should also merge `origin/chore/kit-update`
  (the kit refresh waiting on that branch, no PR of its own).
- Engine changes get a unit test in `Hisscore/test/snake_engine_test.dart` that **fails on the old
  code**; painter changes get a golden in `board_golden_test.dart`. Say in the PR what was run and
  what was only read.
- Verify on the Android emulator (`bash tool/emu.sh`). The emulator has no audio and no vibration:
  anything about sound or haptics is "not verified" until someone holds a phone.
- Classic stays pure: nothing below adds pickups or rules to Classic except the fairness fix (A1)
  and haptics. The daily stays comparable: whatever a mechanic does, it must be deterministic per
  tick so every phone plays the same board.
- Mechanical passes (l10n strings, changelog, golden updates) go to Sonnet; engine and refactor
  work stays on the strong model.

## What the game is today

Retro Snake, five modes (Classic, Adventure with levels and backdrops, Endless wrap, Hardcore 2x
with obstacles, Zen invulnerable). Six pickups: apple, star, shield, speed burst, shrink, magnet.
Combo multiplier on fast eating, speed rises with score and level. Daily challenge on a fixed
20x30 grid with streaks and a Wordle-style share, friend challenge codes, Firebase boards, three
daily quests, XP and levels that unlock four themes and four skins. Chiptune that builds with the
combo. Not released yet; `game_page.dart` is 1,339 lines and owns the whole session.

## Phase A: feel (deaths feel fair, good moments get noticed)

**DONE — A1. Grace tick and death slow-mo.** Most Snake deaths that feel unfair are a turn that landed one
frame late. Add `graceTicks` to the engine (1 in every mode but Hardcore): when the next tick would
kill and the input queue is empty, hold for one more tick before dying; a turn that arrives in that
window is applied and the snake lives. In the UI, play the last 400 ms before the overlay at 0.3x
speed with the existing red flash (the roadmap's missing "slow-mo on death"). Tests: heading into a
wall with no input dies exactly one tick later than today (fails on old); a turn queued during the
grace tick survives; Hardcore unchanged; the daily replays identically on two engines with the same
seed and inputs.

**DONE — A2. Close calls and "new best" in the moment.** Every turn the grace tick saved is a CLOSE CALL:
floating label (`floating_label.dart`), +5 points, a short sting, counted per run and shown on the
end screen. When the score passes the saved best mid-run, a NEW BEST label with its own sting; today
the player only learns it at game over. Add `closeCalls` to the run outcome so milestones (B4) can
use it.

**DONE — A3. Haptics pass.** Light tap on eat, medium on each combo step, selection click on a pickup,
heavy on death, a double pulse on level up. Check where haptics fire today and add a toggle next to
the music toggle if there is none. Cannot be verified on the emulator: say so in the PR.

**DONE — A4. Onboarding.** First run: the attract demo behind the menu gets a swipe hint, and the pause
menu gets a pickup legend (what shrink and magnet do is not obvious). Small, can go first.

## Phase B: the reward loop (why play one more run)

**DONE — B1. Second chance.** Once per run in Adventure and Endless (never daily, Hardcore or Zen): on death
the overlay offers SECOND CHANCE with a 3-second countdown ring. Accept: snake cut to
`max(3, length / 2)`, obstacles within 3 cells of the head cleared, combo reset, 3-2-1 resume. The run
is flagged `revived`; it still counts for XP, quests and boards (boards are unverified anyway) but the
share card and end screen carry a small "revived" mark. Build the button so it can become "watch an
ad" later: the roadmap decided on ads and this is the rewarded placement. Tests: `engine.revive()`
unit tests; overlay widget test for the countdown and the one-per-run rule.

**DONE — B2. End-of-run screen.** Today it shows +XP, finished quests and a level-up. Add: score against best
as a bar, best combo, apples, close calls, the XP bar animating from old to new, quest progress
ticking up, and when the board answered, "12 points behind #8 on the daily". PLAY AGAIN is the primary
button; mode change is secondary. This is the screen that decides whether the next run happens.

**B3. Streak freeze.** One freeze earned per 7-day daily streak, at most 2 banked, spent
automatically on a missed day, shown as a count on the daily tab. Tests in `daily_challenge_test.dart`
for the rollover with and without a freeze.

**B4. Milestones.** About twenty local firsts, each paying XP once with a toast: first star, 10 combo,
level 10, 100 apples lifetime, 5 close calls in one run, a 7-day streak, one run in every mode, beat
a challenge code. Some grant a title shown on the menu card (titles stay local; board names are
validated by the Firestore rules). Test the pure function `milestonesEarned(before, after)`.

## Phase C: variety (every day feels different)

**C1. Risk/reward pickups.** A ripening star: worth 50 when it appears, growing to 150 just before it
despawns, blinking faster near the end, current value drawn on it. A fleeing golden apple in Adventure
and Endless: appears every N apples, worth 100 x combo, moves one cell away from the head every 3
ticks, gone after 8 s. Engine tests for the value curve and the flee rule; goldens for both sprites.
One PR, or two if the diff grows.

**C2. Poison apple (Hardcore only) and portals (Adventure level 7+).** Poison looks like an apple with a
darker tint as its tell; eating it loses 3 segments, resets the combo and shakes the screen. Portals are
paired tiles; the head enters one and leaves the other keeping its direction, the body follows. Two
PRs. Both need engine tests and goldens.

**DONE — C3. Weekly modifier on the daily.** Picked by ISO week number from a fixed list: double speed, no
walls, mirrored controls, fog (only cells within 5 of the head drawn), tiny board (14x20), magnet
madness. Named on the daily tab and the share card. Tests: the modifier for a week is deterministic,
and each flag has an engine test. Cheap, because the daily is already seeded and fixed-size.

**C4. Time Attack.** 60 seconds on the fixed daily grid so scores compare across phones; apples eaten
within 2 s of the last are worth double; a timer ring in the HUD; its own `alltime-timeattack` board.
The menu's mode chips go from 3+2 to 3+3. Check `firebase/firestore.rules` for a board id allowlist
before adding the board.

## Phase D: competition (play against people), in this order

**DONE — D1. Extract `GameSession` from `game_page.dart`.** Pure refactor: engine lifecycle, ticker,
persistence, quests and online submit move to a controller; goldens and widget tests must pass
unchanged; the page drops well under 600 lines. The roadmap asks for this before phase 5, and D2, D3
and server verification all hook into it.

**D2. Input log per run.** The engine records `(tick, direction)` pairs; seed plus log replays a run
deterministically. Test: a replay reproduces the score and the final board exactly. Keep the best
daily run's log locally, compact. This is also the prerequisite the roadmap names for server-side
verification.

**D3. Ghost race.** On the daily, draw the player's best run as a translucent ghost snake and show
"beat your ghost" on the tab. A friend's ghost through a code comes later and needs storage and rules.

After D3 the roadmap items follow naturally: server verification, tappable seed links, ads.

## Balance, alongside everything

- The music has never been heard by a person. Listen on a phone before adding any more audio.
- Add a local death-cause stat (wall, self, obstacle, poison) and median run length to the STATS
  tab. Players like reading "70% of your deaths are walls", and it is the data the tick-speed curve
  and the quest targets (both guesses, per the handoff) need.

## Suggested order

| # | PR | Version | Shipped |
|---|---|---|---|
| 1 | A4 onboarding, with the kit-update merge | minor | #42 |
| 2 | A1 grace tick and slow-mo | minor | #42 |
| 3 | A2 close calls and new best | minor | #42 |
| 4 | B2 end-of-run screen | minor | #42, fixed in #43 |
| 5 | B1 second chance | minor | #42, fixed in #43 |
| 6 | C3 weekly modifier | minor | #44 |
| 7 | B3 streak freeze, then B4 milestones | minor each | |
| 8 | C1, then C2 (two PRs) | minor each | |
| 9 | C4 Time Attack | minor | |
| 10 | D1, D2, D3 in order | D1 patch, others minor | D1 in #42 |

Phases A and D1 went out as one PR (#42) rather than five, and the
version bumps were collected instead of taken per PR: the whole fun
track is meant to be one release. A3 haptics shipped with it and is
still unverified on real hardware, per the note above.

A3 haptics and the balance stats fit anywhere a phone is available. Stop and reorder if playing the
game on a real phone says otherwise; nothing above has been tested against a player.
