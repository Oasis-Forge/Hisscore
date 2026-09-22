# Hisscore roadmap

Goal: make Hisscore the next viral casual game. Order is by impact per effort.

**Status as of 2026-09-22.** Phases 1, 2 and 4 are done. Phase 3 is done except server-side score
verification, seed links and comparable all-time boards. Phase 5 is two of five. `[x]` done and
merged, `[ ]` not done, `[~]` deliberately changed or partly done. Each line ends with where it
landed. New developer: read [docs/HANDOFF.md](docs/HANDOFF.md) first.

The "fun track" ([docs/FUN_PLAN.md](docs/FUN_PLAN.md)) ran from 2026-09-21 to 2026-09-22 and
shipped all fifteen of its items across PRs #42–#46. It closed out the whole of phase 4, two of
phase 5, the last of phase 2's juice, and the cross-cutting `GameSession` refactor. That plan is
now a record rather than a to-do list; this file is the source of truth again.

**Nothing has been released yet.** Version is still `1.0.1+2` and `CHANGELOG.md` holds 18 entries
under `Unreleased`: the whole fun track is meant to go out as one release. The agreed order is
**the rest of this roadmap, then the release** — see section 9 of the handoff.

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
      edge pulse, red death flash (#24), slow-mo on death (#42). Not done, and not planned:
      chromatic aberration, motion blur.
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
- [~] **Server-side score verification.** Scores are still client-reported; the rules only cap them.
      **The client half is done** (#46): `RunLog` records a run as a seed plus the turns that were
      applied, and a replay recomputes the score rather than trusting it. What remains is the server
      — a Cloud Function that replays the log (Blaze plan).
- [ ] Tappable seed links (`?seed=` or an app link). Codes must be typed or pasted today.
- [~] Make all-time boards comparable (normal runs fit the screen, so board sizes differ). Time
      Attack (#45) is on the fixed grid and so *is* comparable; the other five modes are not.

## Phase 4: Depth and retention: DONE

- [x] Daily quests: three a day, same for everyone, one per difficulty (#29)
- [x] XP and player levels (#29)
- [x] Unlockable cosmetics: themes and skins by level (#30)
- [x] Streak freeze: one per 7-day streak, 2 banked, spent automatically on a missed day (#45)
- [~] Risk/reward mechanics, each behind a mode or flag so classic stays pure: moving golden apple
      (#45), poison apple in hardcore (#45), portals in Adventure 7+ (#45). **The greed multiplier
      was not built**; the ripening star — worth 50 on sight, 150 in its last second (#45) — is the
      nearest thing to it, but it is a pickup, not a run-long multiplier.
- [x] Weekly modifier (#44). Six rather than the three listed: double speed, no walls, mirrored
      controls, fog, tiny board, magnet madness. Picked by ISO week.
- [x] Milestones: 21 local firsts paying XP once, some granting a rank on the menu (#45). Not on the
      original plan; added by the fun track.

## Phase 5: New modes and multiplayer: TWO OF FIVE

- [x] Time Attack (60 seconds) on the fixed grid, with a double-score window and its own board (#45)
- [x] Ghost race from a recorded replay (#46) — the same input log server verification needs
- [ ] Battle Royale: shrinking arena with AI snakes
- [ ] Async head-to-head on a shared seed (challenge codes are the start of this)
- [ ] Real-time 2-player, local first, online later

## Cross-cutting

- [~] **Languages: English only, decided 2026-09-22.** Not a "not yet" — a decision. The look is
      the product: `PressStart2P` has almost no glyphs beyond ASCII, so any language with accents
      or a non-Latin script needs a second font, and the pixel face is most of what the game is.
      The UI is also laid out for short upper-case English; the daily card and the pickup legend
      are already tight. If this is ever revisited, the font question has to be settled first, and
      `flutter_localizations` + ARB files is the path. **Until then, keep strings as they are** —
      do not half-extract them into a bundle nobody will translate.
- [x] **Extract a `GameSession` controller from `lib/ui/game_page.dart`** (#42). The page was 1,339
      lines; it is 598 now, and everything phase 5 has shipped so far hooks into the session.
- [x] CI stays green: format check, analyze, tests, Android release build, web build
- [ ] Restrict the Firebase API key to the Android app (the repo is public, the key is in `google-services.json`)
- [ ] Opt-in analytics (D1/D7 retention, share rate, daily completion); needs a privacy policy update
- [ ] **Monetization: ads (decided).** Not started. Needs an AdMob account, `google_mobile_ads`,
      consent handling, and store/privacy updates. **The rewarded-revive placement is already
      built**: the second-chance card (#42) is a button with a countdown ring precisely so the ring
      can become the "watch an ad" wait without the card around it changing.
- [ ] **Privacy and store forms.** The privacy policy (`docs/index.html`) now describes the
      leaderboard and is live at <https://oasis-forge.github.io/Hisscore/>. Still open: the Play
      Data safety form, `store/listing.md`, and an in-app opt-out for score submission, which
      today happens silently at the end of every run. Ads add to this.
- [ ] Device verification (`RELEASE.md` section 1). Share, notifications and lifecycle were
      confirmed on the emulator 2026-09-20. Sound, haptics and the rating prompt still need
      real hardware: the emulator has no working audio output, no vibration motor, and no
      Play Store.
- [ ] First release. Nothing is on Play. Releasing from GitHub was dropped on 2026-09-20:
      no release workflow, no tags, no GitHub Releases. A Play-ready `app-release.aab`,
      signed with the real upload key, builds locally and is uploaded by hand
      (`RELEASE.md` section 3). Still needed: keystore backup, screenshots, store forms.
      **Deliberately last**: the roadmap items above land first, and one version
      bump covers the lot.

## Decisions log

| Date | Decision |
|---|---|
| 2026-09-19 | Backend is Firebase (anonymous auth + Firestore) |
| 2026-09-19 | Monetization is ads |
| 2026-09-19 | Themes and skins unlock by player level |
| 2026-09-19 | App id is `com.oasisforge.hisscore`; every app is `com.oasisforge.<appname>` |
| 2026-09-19 | Verify on the Android emulator, not on web |
| 2026-09-20 | Nothing is released from GitHub; builds are local and uploaded by hand |
| 2026-09-22 | The whole fun track ships as one release, so version bumps were collected, not taken per PR |
| 2026-09-22 | A daily no longer posts to its mode's all-time board: every week bends the rules, so a daily score is not a plain one |
| 2026-09-22 | English only. The pixel font has almost no glyphs beyond ASCII and the look is the product |
| 2026-09-22 | Order of remaining work: the rest of this roadmap, then the release |
