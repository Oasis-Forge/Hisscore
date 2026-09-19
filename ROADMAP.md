# Hisscore roadmap

Goal: make Hisscore the next viral casual game. Order is by impact per effort.

**Status as of 2026-09-19.** Phases 1 and 2 are done, phase 3 is done except server-side
score verification, phase 4 is about half done, phase 5 has not started. `[x]` done and merged
(or in PR #31), `[ ]` not done, `[~]` deliberately changed or partly done. Each line ends with
where it landed. New developer: read [docs/HANDOFF.md](docs/HANDOFF.md) first.

## Phase 1: First impression and shareability: DONE

- [x] Menu is a compact card so the attract demo shows behind it; mode chips in fixed 3+2 rows (#20)
- [~] Keep the cabinet frame in-game: dropped on purpose, the game screen is full-bleed by design
- [x] Share card: PNG of the final board with score and mode, text as caption and fallback (#20)
- [x] Golden tests for the board painter: snake, pickups, obstacles, skins, effects, backdrops (#20 and later)
- [~] PWA: manifest, icons and Flutter's service worker already existed; added theme-color, viewport,
      iOS standalone meta and a dark page background (#20). Install and offline never tried on a device.
      Web is no longer a target (see HANDOFF).

## Phase 2: Juice, themes and audio: DONE

- [x] Theme system, four looks: Phosphor, Amber, Game Boy, Synthwave (#21)
- [x] Snake skins: Classic, Pixel, Neon, Rainbow (#22, #23)
- [~] Juice: head bulge on eating, combo-scaled glow, speed-burst streaks off the tail, amber level-up
      edge pulse, red death flash (#24). Not done: slow-mo on death, chromatic aberration, motion blur.
- [x] Audio: three-layer chiptune loop that builds with the combo, a sting per power-up, separate
      music toggle (#24). **Never listened to by a person** (see HANDOFF, known issues).
- [x] Per-level Adventure backdrops: Grid, Circuit, Cave, Stars, every three levels (#25)
- [x] Snake starts 20% faster in every mode: 240 ms to 190 ms tick (#26)

## Phase 3: Competition: DONE except verification

- [x] Fixed 20x30 daily grid, letterboxed on other screens, so daily scores are comparable (#27)
- [x] Wordle-style daily result: day, ten-square bar, score, apples, combo, streak (#27)
- [x] Friend challenge codes: CHALLENGE and ENTER CODE, Crockford-base32 with a check character (#27)
- [x] Leaderboard layer: interface, no-op and in-memory boards, STATS tab views, name editing (#28)
- [x] Firebase: anonymous auth + Firestore boards, rules checked live (#31, open until merged)
- [ ] **Server-side score verification.** Scores are client-reported; the rules only cap them. Needs the
      engine replayed on a server from a recorded input log (Cloud Functions, Blaze plan).
- [ ] Tappable seed links (`?seed=` or an app link). Codes must be typed or pasted today.
- [ ] Make all-time boards comparable (normal runs fit the screen, so board sizes differ).

## Phase 4: Depth and retention: HALF DONE

- [x] Daily quests: three a day, same for everyone, one per difficulty (#29)
- [x] XP and player levels (#29)
- [x] Unlockable cosmetics: themes and skins by level (#30)
- [ ] Streak freeze
- [ ] Risk/reward mechanics, each behind a mode or flag so classic stays pure: moving golden apple,
      greed multiplier, poison apple in hardcore, portals
- [ ] Weekly modifier (double speed, no walls, mirrored controls)

## Phase 5: New modes and multiplayer: NOT STARTED

- [ ] Time Attack (60 seconds)
- [ ] Ghost race from a recorded replay (the same input log server verification needs)
- [ ] Battle Royale: shrinking arena with AI snakes
- [ ] Async head-to-head on a shared seed (challenge codes are the start of this)
- [ ] Real-time 2-player, local first, online later

## Cross-cutting

- [ ] **Extract a `GameSession` controller from `lib/ui/game_page.dart`** (1,339 lines and growing).
      Ghosts, replays and multiplayer all hook into it. Do this before phase 5.
- [x] CI stays green: format check, analyze, tests, Android release build, web build
- [ ] Restrict the Firebase API key to the Android app (the repo is public, the key is in `google-services.json`)
- [ ] Opt-in analytics (D1/D7 retention, share rate, daily completion); needs a privacy policy update
- [ ] **Monetization: ads (decided).** Not started. Needs an AdMob account, `google_mobile_ads`, consent
      handling, and store/privacy updates. Suggested placement: after game over, and a rewarded revive.
- [ ] **Privacy and store forms.** First data leaves the device with the leaderboard. Update the privacy
      policy (`docs/index.html`), Play Data safety, and `store/listing.md`. Ads add to this.
- [ ] Device verification of sound, haptics, share sheet, notifications, rating prompt (`RELEASE.md`)
- [ ] First release: nothing has ever been tagged or shipped (see HANDOFF, release section)

## Decisions log

| Date | Decision |
|---|---|
| 2026-09-19 | Backend is Firebase (anonymous auth + Firestore) |
| 2026-09-19 | Monetization is ads |
| 2026-09-19 | Themes and skins unlock by player level |
| 2026-09-19 | App id is `com.oasisforge.hisscore`; every app is `com.oasisforge.<appname>` |
| 2026-09-19 | Verify on the Android emulator, not on web |
