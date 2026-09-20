# Handoff: Hisscore

For the developer picking this up. Read this, then [ROADMAP.md](../ROADMAP.md) (what is done and
what is next) and [CLAUDE.md](../CLAUDE.md) (architecture, commands, conventions). Written
2026-09-19. Nothing here is in anyone's head: if it matters, it is in the repo or in this file.

## 1. Where things stand

Hisscore is a single-player retro Snake for Android (iOS untried), written in Flutter. It has five
modes, a daily challenge, friend challenge codes, daily quests with XP and levels, unlockable
themes and skins, music, and a global leaderboard on Firebase.

- **Roadmap:** phases 1 and 2 done, phase 3 done except server-side verification, phase 4 half done,
  phase 5 not started. See ROADMAP.md.
- **Code:** `main` is green. 207 tests in 20 test files. CI runs format check, analyze, tests, an Android
  release build and a web build on every PR.
- **The leaderboard is live on `main`.** PR #31 merged (as #32), so the Firebase backend is wired up, not
  just the layer. It also fixed the release workflow (section 8). Two starter-kit tooling PRs (#33, #34)
  landed on top.
- **Nothing is released, and nothing releases from GitHub.** Version is `1.0.1+2`. There are no tags
  and no GitHub Releases: that machinery was removed on 2026-09-20 because everything CI can build is
  debug-signed and Play rejects it. Releases are built locally and uploaded by hand (section 8).
- **Not verified by a person on a real phone:** sound, haptics, share sheet, notifications, rating
  prompt. Everything was checked on the Android emulator, by tests, and by screenshots.

## 2. Set up

```bash
git clone https://github.com/Oasis-Forge/Hisscore.git
cd Hisscore/Hisscore                                        # the app lives in the Hisscore/ subfolder
flutter pub get
flutter analyze                                             # must be clean
dart format --output=none --set-exit-if-changed .          # CI's format check
flutter test                                                # all 207 should pass
```

- **Flutter 3.44.8 / Dart 3.12.2, pinned in CI** (`FLUTTER_VERSION` in `.github/workflows/`). Use the same
  version locally. Android Gradle Plugin 9.1.0, Kotlin 2.4.0.
- Everything is run **from `Hisscore/`**, not the repo root (CI does the same).
- The repo was developed on Windows with Git Bash. Line-ending warnings (`LF will be replaced by CRLF`)
  are normal there.

### Running the game: use the Android emulator, not web

Web is not a target any more (a decision, see the log in ROADMAP.md). Web hid a real bug (audio focus)
that only showed on Android.

```bash
bash tool/emu.sh start          # boots the AVD "Medium_Phone" (run as a background command)
bash tool/emu.sh ready          # wait for boot
flutter run -d emulator-5554 --debug --no-resident
bash tool/emu.sh screen         # the UI as text: label @ x,y  (cheaper than screenshots)
bash tool/emu.sh tap "PLAY"     # tap by label; `tapxy X Y` for coordinates
bash tool/emu.sh shot out.png   # screenshot, for when the look matters
```

The emulator needs Google Play services (the `google_apis_playstore` image) for Firebase. The full
command list is at the top of `Hisscore/tool/emu.sh`.

## 3. Repo map

```
Hisscore/                       the Flutter app
  lib/game/                     game logic, no Flutter dependency where possible
    snake_engine.dart             the whole ruleset: movement, food, combos, power-ups, levels, modes
    quests.dart                   quests, XP, levels (pure)
    challenge_code.dart           friend codes (pure)
    daily_challenge.dart          seed, streak, fixed grid size, shareable result (pure)
    online_scores.dart            OnlineScoreBoard interface + no-op + in-memory + name rules
    firestore_score_board.dart    the real Firebase boards
    high_score_store.dart         everything persisted locally (interface + 2 implementations)
    sound_manager.dart            SFX and the layered music
  lib/ui/                       screens and painters
    game_page.dart                the big stateful orchestrator (1,339 lines: see "Refactor" below)
    board.dart                    the board painter; backdrops.dart, snake_skin.dart, theme.dart
    ready_tabs.dart, intro_panel.dart, quests_view.dart, online_board.dart   the menu
  test/                         unit, widget and golden tests (goldens in test/goldens/)
  tool/                         asset generators (icon, sfx, music) and emu.sh
  android/, ios/, web/          platform code
firebase/firestore.rules        the Firestore security rules (deploy by pasting in the console)
docs/                           LEADERBOARD.md (Firebase), this file, the privacy policy page (index.html)
store/                          store listing text and graphics
.github/workflows/              ci.yaml -- the only workflow; nothing is released from GitHub
.claude/                        Claude Code settings, skills and a format hook (optional tooling)
RELEASE.md                      pre-launch checklist: read it before shipping
```

## 4. How it fits together (the parts you will trip over)

- **Engine/UI split.** `SnakeEngine` is plain Dart driven by `tick()`, `queueTurn()`, `start()`. Widgets
  read it and call it; they do not contain rules. Timing is deterministic (`elapsedMs`, never
  `DateTime.now()`), which is what makes tests and future replays possible.
- **Determinism is a feature.** The daily, challenge codes, and any future ghost/replay rely on the same
  seed + the same inputs giving the same game. Do not add unseeded randomness to the engine.
- **Fixed grid.** The daily and challenge codes always play on 20x30 (`DailyChallenge.gridColumns/Rows`)
  and are letterboxed. Normal runs fit the screen. So all-time boards compare different-sized boards.
- **Themes and skins are globals.** `RetroColors.current` (a `GameTheme`) and `SnakeSkin.current` are
  read while painting. `RetroColors.phosphor` etc. are *getters*, so they cannot be used in `const`
  widgets. Changing a theme calls `_rebuildAll()` in `game_page.dart`, which marks the whole tree dirty.
  The board caches its static layers; the cache is keyed on size, theme and backdrop.
- **Storage seam.** `HighScoreStore` has two implementations, `SharedPreferencesHighScoreStore` and
  `InMemoryHighScoreStore` (tests). **When you add a persisted field, add it to both**, plus a test.
- **Online seam.** The game only knows `OnlineScoreBoard`. `FirebaseScoreBoard` connects in the
  background and swaps itself in; until then (or offline, or with no `google-services.json`) the boards
  are simply hidden. `GamePage` listens to it and redraws when it connects.
- **Unlocks.** Each theme/skin has an `unlockLevel`; the schedule is in `lib/ui/unlocks.dart`. A saved
  look the player has not earned falls back to the free one on launch.
- **Crash reporting.** Local ring buffer always; Sentry only if built with
  `--dart-define=SENTRY_DSN=...`. See CLAUDE.md.

## 5. Firebase (live)

- Project **`oasisforge-hisscore`**, Android app **`com.oasisforge.hisscore`**. Console:
  console.firebase.google.com. Anonymous sign-in and Firestore are on.
- Config: `Hisscore/android/app/google-services.json` is **committed** (identifiers, not secrets). **The GitHub
  repo is public**, so that file, including its API key, is public. That is normal for Firebase and the
  security rules are what protect the data, but you should still restrict the key: Google Cloud console ->
  APIs & Services -> Credentials -> the Android key -> restrict to package `com.oasisforge.hisscore` (+ the
  release SHA-1), and consider Firebase App Check later. Not done yet. The
  Google services Gradle plugin is applied only when that file exists, so a checkout without it still
  builds and runs with no boards.
- Data: `boards/{boardId}/entries/{playerUid}` = `{name, score, updatedAt}`. `boardId` is `daily-<n>` or
  `alltime-<mode>`.
- Rules live in `firebase/firestore.rules` and are **deployed by pasting into Firestore -> Rules** (no CLI
  set up). Change the file and the console together, or they drift.
- The rules were checked against the live project by sending abusive writes with an anonymous test user
  (all refused, HTTP 403); details in `docs/LEADERBOARD.md`. They are **not** unit-tested: the fake
  Firestore cannot evaluate rule functions and would pass a test for the wrong reason.
- **Scores are client-reported.** The rules cap and validate but cannot detect a fake score. Real fix: a
  server that replays a recorded input log (Cloud Functions, Blaze plan). Not built.
- One anonymous test user (uid starts `SYpnMn`) was left in Firebase Authentication; delete it in the console.

## 6. Conventions

- **Package id:** `com.oasisforge.<appname>` for every app. Hisscore was renamed from
  `com.hisscore.hisscore` before it was ever published. Once an id is on Play it can never change.
- **One PR per feature, branched from `main`.** Add files by path (`git add Hisscore/lib ...`), never
  `git add -A`: running Flutter rewrites `Hisscore/linux/flutter/generated_*` locally and that is noise
  (line endings only). `Hisscore/pubspec.lock` is *not* noise: if you touched `pubspec.yaml`, run
  `flutter pub get` on the SDK `FLUTTER_VERSION` pins and commit the regenerated lock in the same PR.
  Skipping it once already left the entire Firebase tree out of the lockfile. Use `git rebase --autostash`.
- **Stacked PRs:** if PR B is based on PR A, change B's base to `main` *before* merging A, or GitHub merges
  B into A's branch and it never reaches `main`. This happened once (skins, PR #22 to #23).
- **Verify on the emulator, and say what was and was not verified in the PR.** PR descriptions here list
  what was driven on a device versus only compiled.
- Keep tool output small (CLAUDE.md "Working conventions"): it exists to save tokens when using Claude Code.
- Commit trailer used so far: `Co-Authored-By: Claude ...`; drop it if you are not using Claude Code.

## 7. Gotchas that cost time

- **`tester.pumpAndSettle()` never returns on the menu** (looping animations). Use
  `tester.pump(const Duration(milliseconds: 400))`.
- **A dialog that owns a `TextEditingController` must dispose it in its own `State`**, not from the caller
  after `showDialog` returns. Doing it from the caller crashed the app on the device
  (`used after being disposed`) and *the widget tests did not catch it*. See `EnterCodeDialog`.
- **Goldens** use a small tolerance (`board_golden_test.dart`) so ones generated on Windows pass on Linux
  CI. Regenerate with `flutter test test/board_golden_test.dart --update-goldens`, then look at the PNGs.
- **The pixel font `PressStart2P` has almost no glyphs beyond ASCII.** No check marks or emoji in UI text
  (the share text is separate and does use emoji). Use plain ASCII like `[X]`.
- `0` and `O` look alike in that font, which is why challenge codes use Crockford base32.
- **The first tap after a dialog closes is often eaten** on the emulator: `screen`, then retry. And do not
  send `key back` from the menu: it leaves the app.
- The emulator may still have the **old `com.hisscore.hisscore`** install (with old preview data). It is
  harmless; uninstall it if it confuses you.
- **Adding an Android permission** (including via a new plugin) fails CI's permission allow-list until
  you update `ALLOWED` in `.github/workflows/ci.yaml` (`build-android`) *and* the privacy policy /
  Data safety answers. That is the point of the check (it is called RUN-2 in the file).
- Plugin warnings about "Built-in Kotlin" during Android builds are from third-party plugins; harmless now,
  but they will need plugin upgrades eventually.

## 8. Release: nothing has shipped, and nothing releases from GitHub

- **Releasing from GitHub was dropped on 2026-09-20.** There is no `release.yml`, no tags and no
  GitHub Releases. Two draft releases had already been produced, both holding **debug-signed** APKs
  that Play would reject, which is exactly the trap: an artifact attached to something called a
  "release" invites someone to upload it. The keystore is deliberately kept off CI, so CI can only
  ever produce debug-signed builds.
- **A release is now:** bump the version and changelog on the branch, merge, then build locally with
  `flutter build appbundle --release`, copy into `Hisscore/dist/`, and upload the AAB to Play by hand.
  Verify the signer first -- `apksigner verify --print-certs` must not print `CN=Android Debug`.
  `jarsigner` cannot check an APK here: Flutter signs v2-only, which `jarsigner` does not read.
- **An upload keystore exists** (`~/hisscore-upload.jks`, alias `upload`, RSA 2048). `key.properties`
  is gitignored. Losing that file means never updating the app under the same listing, so confirm it
  is backed up somewhere off the machine before relying on it.
- Versions are read from `Hisscore/pubspec.yaml` by `scripts/version.sh`; `CHANGELOG.md` is the record
  of what shipped, since there are no tags to compare against. Note `scripts/version.sh check` is
  **not** wired into CI -- nothing enforces a version bump automatically.
- `RELEASE.md` is the pre-launch checklist: real-phone verification, screenshots, iOS (never built),
  store listing, Data safety form.
- **Before any release:** the Play Data safety form and `store/listing.md` still need to match the
  privacy policy, which was corrected on 2026-09-20 to admit the leaderboard uploads a name, score
  and anonymous Firebase ID at the end of every run. Ads will add more.

## 9. What to do next (suggested order)

1. ~~Merge #31 and get a release out of CI.~~ **Abandoned on purpose.** It worked, but every artifact it
   produced was debug-signed, so releasing from GitHub was dropped entirely (section 8). Build locally.
   **Back up `~/hisscore-upload.jks` off the machine** if that has not been done -- it is the one step
   here with no recovery path.
2. **Play it on a real phone** and work through `RELEASE.md` section 1. Music was never heard by a person
   (loop, mix levels, and whether the three layers stay in step); quest and level balance are guesses.
3. **Privacy, Data safety, store listing** updated for the leaderboard.
4. **Refactor `game_page.dart`**: extract a `GameSession` controller (engine lifecycle, ticker,
   persistence, quests, online submit). It is 1,339 lines and everything in phase 5 hooks into it.
5. **Ads** (decided): AdMob, `google_mobile_ads`, consent (UMP), and the privacy/store updates.
6. **Server-side score verification** (input log + replay on a server) before the leaderboard matters.
7. Phase 4 leftovers (streak freeze, risk/reward mechanics, weekly modifier), then phase 5.

## 10. Known issues and untested edges

- Scores on the leaderboard can be faked within the cap.
- First launch with no network: boards retry at 15 s, 60 s, 5 min, then stay off for that session.
- Two devices on one board, and a lost connection mid-run, were not tried.
- Web/PWA install and offline were never tried (and web is out of scope now).
- Daily quests roll over at UTC midnight (unit-tested only, never seen live).
- iOS has never been built (`RELEASE.md` section 5).

## 11. Working with Claude Code (optional)

`.claude/` holds project settings, a `dart format` hook, and skills (`verify`, `emulator`, `coverage`,
`release`, `ship`, `handoff`). They are conveniences, not requirements. **Claude's memory is stored
outside the repo, per user**, so a new developer's Claude will not have it. The two preferences it holds are
already written down above: verify on the emulator (not web), and `com.oasisforge.<appname>` ids.
