# Handoff: Hisscore

For the developer picking this up. Read this, then [ROADMAP.md](../ROADMAP.md) (what is done and
what is next) and [CLAUDE.md](../CLAUDE.md) (architecture, commands, conventions). Written
2026-09-19, rewritten 2026-09-22 after the fun track shipped. Nothing here is in anyone's head: if
it matters, it is in the repo or in this file.

## 1. Where things stand

Hisscore is a single-player retro Snake for Android (iOS untried), written in Flutter. Six modes, a
daily challenge with a weekly rule and a ghost to race, friend challenge codes, daily quests with XP
and levels, local milestones, unlockable themes and skins, music, haptics, and a global leaderboard
on Firebase.

- **Roadmap:** phases 1, 2 and 4 done. Phase 3 done except server-side verification. Phase 5 is
  three of five — Time Attack, the ghost race and async head-to-head have shipped; Battle Royale and
  local 2-player have not started. See ROADMAP.md.
- **Code:** `main` is green and **protected** (section 6). **551 tests in 41 files.** CI runs a
  format check, analyze, tests, an Android release build and a web build on every PR.
- **The fun track is complete.** All fifteen items of [FUN_PLAN.md](FUN_PLAN.md) shipped across PRs
  #42–#46. That plan is now a record, not a to-do list. Since then: docs and the handoff (#47, #49),
  the leaderboard opt-in and comparable all-time boards (#48), golden coverage for the newer
  painting (#50), challenge links (#51) and racing a friend (commit `e89e00b`).
- **Nothing is released, and nothing releases from GitHub.** Version is still `1.0.1+2` — the whole
  fun track is meant to go out as one release, so the bumps were collected rather than taken per PR.
  `CHANGELOG.md` has 22 player-facing entries waiting under `Unreleased`. There are no tags and no
  GitHub Releases: that machinery was removed on 2026-09-20 because everything CI can build is
  debug-signed and Play rejects it. Releases are built locally and uploaded by hand (section 8).
- **Not verified by a person on a real phone:** sound, haptics, the rating prompt. Share,
  notifications and lifecycle were confirmed on the emulator. Three gameplay features are also
  unseen by anyone — the golden apple, poison and portals — because all three are too deep into a
  run to reach by hand through adb. They have engine tests; nobody has watched them move.

## 2. Set up

```bash
git clone https://github.com/Oasis-Forge/Hisscore.git
cd Hisscore/Hisscore                                        # the app lives in the Hisscore/ subfolder
flutter pub get
flutter analyze                                             # must be clean
dart format --output=none --set-exit-if-changed .           # CI's format check
flutter test                                                # all 551 should pass
```

- **Flutter 3.44.8, pinned in CI** (`FLUTTER_VERSION` in `.github/workflows/ci.yaml`). Use the same
  version locally.
- Everything is run **from `Hisscore/`**, not the repo root (CI does the same).
- The repo was developed on Windows with Git Bash. Line-ending warnings (`LF will be replaced by
  CRLF`) are normal there.

### Running the game: use the Android emulator, not web

Web is not a target any more (a decision, see the log in ROADMAP.md). Web hid a real bug (audio
focus) that only showed on Android, and it cannot exercise haptics or the share sheet at all.

```bash
bash tool/emu.sh start          # boots the AVD "Medium_Phone" (run as a background command)
bash tool/emu.sh ready          # wait for boot
bash tool/emu.sh save before-test   # snapshot before you touch the device's data
flutter run -d emulator-5554 --debug --no-resident
bash tool/emu.sh screen         # the UI as text: label @ x,y  (cheaper than screenshots)
bash tool/emu.sh tap "PLAY"     # tap by label; `tapxy X Y` for coordinates
bash tool/emu.sh shot out.png   # screenshot, for when the look matters
bash tool/emu.sh load before-test && bash tool/emu.sh forget before-test   # put it back
```

The emulator needs Google Play services (the `google_apis_playstore` image) for Firebase. The full
command list is at the top of `Hisscore/tool/emu.sh`.

## 3. Repo map

```
Hisscore/                       the Flutter app
  lib/game/                     game logic, no Flutter dependency where possible
    snake_engine.dart             the whole ruleset: movement, food, combos, power-ups, levels,
                                  modes, the grace tick, close calls, revive, portals, the run log
    game_session.dart             one playing session: engine lifecycle, ticker, persistence,
                                  quests, milestones, the daily, online submit, second chance, ghost
    run_log.dart                  a run as a seed plus its turns; replay, encode, decode
    weekly_modifier.dart          the six rules that bend the daily, one per ISO week (pure)
    milestones.dart               local firsts, their XP and ranks (pure)
    quests.dart                   quests, XP, levels (pure)
    challenge_code.dart           friend codes (pure)
    daily_challenge.dart          seed, streak, streak freezes, grid size, shareable result (pure)
    haptics.dart                  the vibration seam, with an impl you can silence in tests
    online_scores.dart            OnlineScoreBoard interface + no-op + in-memory + name rules
    firestore_score_board.dart    the real Firebase boards
    high_score_store.dart         everything persisted locally (interface + 2 implementations)
    sound_manager.dart            SFX and the layered music
  lib/ui/                       screens and painters
    game_page.dart                the page: measures the screen, routes input, picks a screen (598 lines)
    run_effects.dart              particles, popups, shake, flashes — none of it game state
    board.dart                    the board painter; backdrops.dart, snake_skin.dart, theme.dart
    game_board_view.dart, game_hud.dart, game_overlay.dart, end_of_run.dart, second_chance.dart
    ready_tabs.dart, intro_panel.dart, intro_cabinet.dart, quests_view.dart, online_board.dart
  test/                         unit, widget and golden tests (goldens in test/goldens/)
  tool/                         asset generators (icon, sfx, music) and emu.sh
  android/, ios/, web/          platform code
firebase/firestore.rules        the Firestore security rules (deploy by pasting in the console)
docs/                           this file, FUN_PLAN.md (done), LEADERBOARD.md, STACK_NOTES.md,
                                and the privacy policy page (index.html)
store/                          store listing text and graphics
.github/workflows/              ci.yaml -- the only workflow; nothing is released from GitHub
.claude/                        Claude Code settings, skills and a format hook (optional tooling)
RELEASE.md                      pre-launch checklist: read it before shipping
```

## 4. How it fits together (the parts you will trip over)

- **Three layers, on purpose.** `SnakeEngine` holds the rules and nothing else. `GameSession` runs
  a game: the ticker, persistence, progression, the daily, the online submit. `GamePage` draws it
  and routes input. `RunEffects` owns the noise a run makes on screen — particles, popups, shake —
  and the run plays out identically with all of it switched off. If you are adding a rule it goes in
  the engine; if you are adding a consequence of a finished run it goes in the session.
- **Determinism is a feature, and now a shipped one.** The engine's clock is `elapsedMs`, counted in
  ticks, never `DateTime.now()`. That is what lets `RunLog` record a run as a seed plus a list of
  turns and replay it exactly — which is what the ghost race is built on, and what server-side score
  verification would need. **Do not add unseeded randomness to the engine**, and do not read the wall
  clock in it.
- **`RunLog` records the turn that was *applied*, not the one that was asked for.** A refused
  reversal is not recorded; under a mirrored week the recorded turn is the one the snake actually
  took. Replays therefore set `engine.direction` directly rather than calling `queueTurn`, which
  would mirror a second time.
- **Fixed grids are declared, not guessed.** `SnakeEngine.fixedGrid` says whether a run is on a board
  that is the same everywhere — the daily, a challenge code, Time Attack — and the page letterboxes
  it. The page used to work this out by checking for a 20x30 grid, which quietly broke the moment the
  TINY BOARD weekly rule could change the daily's size.
- **Weekly rules come from the day number, not from "today".** `DailyChallenge.modifierForDay` keys
  the rule off the same single number everything else about a daily comes from, so the rule named on
  the card and the rule the run is played under cannot drift apart.
- **A daily does not reach its mode's all-time board.** Every week bends the rules now, so a daily
  score is never a plain Classic score. It has the daily's own per-day board, where everyone played
  the same strange game. See `GameSession.countsForAllTimeBoard`.
- **Themes and skins are globals.** `RetroColors.current` (a `GameTheme`) and `SnakeSkin.current` are
  read while painting. `RetroColors.phosphor` etc. are *getters*, so they cannot be used in `const`
  widgets. Changing a theme calls `_rebuildAll()` in `game_page.dart`. The board caches its static
  layers; the cache is keyed on size, theme and backdrop.
- **Storage seam.** `HighScoreStore` has two implementations, `SharedPreferencesHighScoreStore` and
  `InMemoryHighScoreStore` (tests). **When you add a persisted field, add it to both**, plus a test.
  The two had already started to drift over what a finished run counts for, which is why both now
  call `GameStats.record` instead of each doing the arithmetic.
- **Online seam.** The game only knows `OnlineScoreBoard`. `FirebaseScoreBoard` connects in the
  background and swaps itself in; until then (or offline, or with no `google-services.json`) the
  boards are simply hidden.
- **Milestones are not quests.** A quest is today's job and resets at UTC midnight; a milestone is
  something that happened to this player and stays happened. `milestonesEarned(before, after)` is
  pure and answers only "newly reached" — the caller keeps the ids it has already paid for, because
  a streak can fall back and climb again.
- **Crash reporting.** Local ring buffer always; Sentry only if built with
  `--dart-define=SENTRY_DSN=...`. See CLAUDE.md.

## 5. Firebase (live)

- Project **`oasisforge-hisscore`**, Android app **`com.oasisforge.hisscore`**. Console:
  console.firebase.google.com. Anonymous sign-in and Firestore are on.
- Config: `Hisscore/android/app/google-services.json` is **committed** (identifiers, not secrets).
  **The GitHub repo is public**, so that file, including its API key, is public. That is normal for
  Firebase and the security rules are what protect the data, but you should still restrict the key:
  Google Cloud console -> APIs & Services -> Credentials -> the Android key -> restrict to package
  `com.oasisforge.hisscore` (+ the release SHA-1), and consider Firebase App Check later. **Not done
  yet.** The Google services Gradle plugin is applied only when that file exists, so a checkout
  without it still builds and runs with no boards.
- Data: `boards/{boardId}/entries/{playerUid}` = `{name, score, updatedAt}`. `boardId` is `daily-<n>`
  or `alltime-<mode>`, lower-cased — `alltime-timeattack`, not `alltime-timeAttack`. **There is no
  board-id allowlist in the rules**, so a new board needs no rules change.
- Rules live in `firebase/firestore.rules` and are **deployed by pasting into Firestore -> Rules**
  (no CLI set up). Change the file and the console together, or they drift.
- The rules were checked against the live project by sending abusive writes with an anonymous test
  user (all refused, HTTP 403); details in `docs/LEADERBOARD.md`. They are **not** unit-tested: the
  fake Firestore cannot evaluate rule functions and would pass a test for the wrong reason.
- **Scores are client-reported.** The rules cap and validate but cannot detect a fake score. The
  real fix is a server that replays a recorded input log — and **that log now exists** (`RunLog`).
  The client half of server-side verification is done; the Cloud Function is not written.
- One anonymous test user (uid starts `SYpnMn`) was left in Firebase Authentication; delete it in
  the console.

## 6. Conventions

- **Package id:** `com.oasisforge.<appname>` for every app. Hisscore was renamed from
  `com.hisscore.hisscore` before it was ever published. Once an id is on Play it can never change.
- **`main` is protected: branch the moment you have pulled, not when you are ready to commit.**
  A pull request is required, the three CI checks must pass, and force pushes and deletions are
  refused — **including for admins**, deliberately, because the one direct push that got through
  (commit `e89e00b`, 2026-09-22) carried an owner token and nothing else would have stopped it. The gap
  between `git pull` on `main` and `git checkout -b` is where that happened, which is why the rule
  is "branch after the pull" rather than "branch before the PR". A direct push now fails with
  `protected branch hook declined`. To inspect or change it:
  `gh api repos/Oasis-Forge/Hisscore/branches/main/protection`.
- **One theme per PR, branched from a freshly pulled `main`.** Add files by path
  (`git add Hisscore/lib ...`) rather than `git add -A` when Flutter has rewritten
  `Hisscore/linux/flutter/generated_*` locally. `Hisscore/pubspec.lock` is *not* noise: if you
  touched `pubspec.yaml`, run `flutter pub get` on the pinned SDK and commit the regenerated lock in
  the same PR. Skipping it once already left the entire Firebase tree out of the lockfile.
- **Check the PR head before merging.** GitHub's PR ref can lag a push by minutes. A merge went in
  against a stale head once and left a commit behind on the branch; it had to be rescued onto its own
  PR (#43). `git ls-remote origin refs/heads/<branch>` against
  `gh api repos/Oasis-Forge/Hisscore/pulls/<n> -q .head.sha` will tell you.
- **Stacked PRs:** if PR B is based on PR A, change B's base to `main` *before* merging A, or GitHub
  merges B into A's branch and it never reaches `main`. This happened once (skins, #22 into #23).
- **Verify on the emulator, and say in the PR what was and was not verified.** Every device pass in
  the fun track found something the tests could not — a ragged legend, unlabelled switches, a
  progress bar with no track, a live pause card under the revive countdown, a ghost drawn a cell
  ahead of where it was. State plainly what you drove on a device and what you only compiled.
- Keep tool output small (CLAUDE.md "Working conventions"): it exists to save tokens when using
  Claude Code.
- Commit trailer used so far: `Co-Authored-By: Claude ...`; drop it if you are not using Claude Code.

## 7. Gotchas that cost time

- **`tester.pumpAndSettle()` never returns on the menu** (looping animations). Use
  `tester.pump(const Duration(milliseconds: 400))`.
- **A death takes 400 ms to become a card.** `RunEffects.deathPause` plays the last moment in slow
  motion first, so a widget test that expects `GAME OVER` immediately after the fatal tick will not
  find it. Pump `RunEffects.deathPause` and then a frame.
- **`primaryAction()` overwrites `engine.mode` with `selectedMode`.** A test that injects an engine
  in a particular mode and then presses PLAY silently gets Classic. Set `selectedMode` too. This bit
  twice.
- **audioplayers throws from its own unawaited init** and the failure lands on whichever test happens
  to be running. Call `TestWidgetsFlutterBinding.ensureInitialized()` and mock
  `MethodChannel('xyz.luan/audioplayers.global')` in `setUpAll`. Haptics needs the same treatment or
  a silent `HapticImpl`.
- **The engine puts a primary apple back the moment it notices there is none.** A test that replaces
  `engine.foods` with one bonus item will find an apple inserted at index 0 on the next tick, so
  `foods.first` is not the thing you put there. Select by type.
- **A dialog that owns a `TextEditingController` must dispose it in its own `State`**, not from the
  caller after `showDialog` returns. Doing it from the caller crashed the app on the device
  (`used after being disposed`) and *the widget tests did not catch it*. See `EnterCodeDialog`.
- **Goldens** use a small tolerance (`test/support/tolerant_goldens.dart`) so ones generated on
  Windows pass on Linux CI. Regenerate with
  `flutter test test/board_golden_test.dart --update-goldens`, then look at the PNGs. Three things
  about them are easy to get wrong, and #50 got all three:
  - **Capture a `RepaintBoundary` of your own**, keyed with `goldenBoundary`, under a `Center`.
    `find.byType(RepaintBoundary).first` is the framework's boundary around the whole 800x600 test
    view, so every golden comes out that size no matter what the widget under it asked for — the
    `SizedBox` in the old helper had never had any effect at all.
  - **The tolerance is a blind spot for small things.** It is a percentage, so anything under about
    half a percent of the image can change without failing. Six-point text is always under it: a
    golden with a number in it pins the picture, not the number. Pin the number in an ordinary test.
  - **But a small canvas is not the way out**, because the drift the tolerance exists for is
    *absolute*. The pixels antialiasing and font hinting move between Windows and Linux are a fixed
    handful — about 60 for a small widget. On 800x600 that is 0.01% and invisible; on 60x60 it is
    1.7% and CI goes red. **Goldens want a big canvas.** Anything too small to be worth a big one is
    better pinned by reading the widget tree: `hud_widgets_test.dart` asserts the timer ring's
    colour, number and fill straight off the widgets, which is platform-proof and sharper than a
    pixel count. A colour is not something only a golden can see.
- **Text in a golden needs `loadPixelFont()`** (`test/support/pixel_font.dart`). Without it the
  engine falls back to the test font, which draws every glyph as an identical box.
- **The pixel font `PressStart2P` has almost no glyphs beyond ASCII.** No check marks or emoji in UI
  text (the share text is separate and does use emoji). Use plain ASCII like `[X]`. **This is the
  first reason the app is English only** — see section 9 and the decisions log in ROADMAP.md.
- `0` and `O` look alike in that font, which is why challenge codes use Crockford base32.
- **A friend's run travels inside the link, not through a server.** `RivalRun` leaves out the seed,
  grid and mode because the challenge code already says all three, and delta-encodes the tick of each
  turn. Both together are what make a long run about 300 characters instead of thousands. If you add
  a field, check `rival_run_test.dart`'s length assertion — a link a messaging app truncates arrives
  looking fine and races wrong, which is why anything over `RivalRun.maxEncodedLength` is dropped and
  the link goes out as a plain challenge instead.
- **`ChallengeLink.read` prefers a race over a bare code**, wherever each sits in the text. The share
  message names the code in prose before it gives the link, so reading left to right finds the code
  and throws the run away. This was a real bug, caught by a test, not by review.
- **An https intent-filter without a verified `assetlinks.json` sends the link to the browser**, and
  on Android 12+ it does so silently — no "open with" dialog to hint that the app wanted it. This is
  not a bug in the filter; it is what unverified App Links do. Test a challenge link on a device
  with the scheme, which needs no verification:
  ```bash
  adb shell am start -a android.intent.action.VIEW -d "hisscore://c/C000-9RF8"
  ```
  The https form is worth testing too, precisely to watch it land in Chrome. See RELEASE.md
  section 4 for what finishing verification needs, and note that neither half can be done from
  this repo.
- **The first tap after a dialog closes is often eaten** on the emulator: `screen`, then retry. And
  do not send `key back` from the menu: it leaves the app.
- **A three-second window cannot be driven through adb.** A `uiautomator` dump takes about a second,
  so the second-chance offer expires before a dump-then-tap lands. Spam `input tap` at a known
  coordinate, or temporarily widen the window in a debug build and put it back.
- **Adding an Android permission** (including via a new plugin) fails CI's permission allow-list
  until you update `ALLOWED` in `.github/workflows/ci.yaml` (`build-android`) *and* the privacy
  policy / Data safety answers. That is the point of the check (it is called RUN-2 in the file).
- Plugin warnings about "Built-in Kotlin" during Android builds are from third-party plugins;
  harmless now, but they will need plugin upgrades eventually.

## 8. Release: nothing has shipped, and nothing releases from GitHub

- **Releasing from GitHub was dropped on 2026-09-20.** There is no `release.yml`, no tags and no
  GitHub Releases. Two draft releases had already been produced, both holding **debug-signed** APKs
  that Play would reject, which is exactly the trap: an artifact attached to something called a
  "release" invites someone to upload it. The keystore is deliberately kept off CI, so CI can only
  ever produce debug-signed builds.
- **A release is:** bump the version and changelog on the branch, merge, then build locally with
  `flutter build appbundle --release`, copy into `Hisscore/dist/`, and upload the AAB to Play by
  hand. Verify the signer first — `apksigner verify --print-certs` must not print `CN=Android
  Debug`. `jarsigner` cannot check an APK here: Flutter signs v2-only, which `jarsigner` does not
  read.
- **An upload keystore exists** (`~/hisscore-upload.jks`, alias `upload`, RSA 2048).
  `key.properties` is gitignored. Losing that file means never updating the app under the same
  listing, so confirm it is backed up somewhere off the machine before relying on it.
- Versions are read from `Hisscore/pubspec.yaml` by `scripts/version.sh`; `CHANGELOG.md` is the
  record of what shipped, since there are no tags to compare against. Note `scripts/version.sh
  check` is **not** wired into CI — nothing enforces a version bump automatically.
- `RELEASE.md` is the pre-launch checklist: real-phone verification, screenshots, iOS (never built),
  store listing, Data safety form.

## 9. What to do next (the agreed order)

The release is deliberately **last**: everything below lands first, then one version bump covers the
lot.

**The app is English only, decided 2026-09-22.** That is a decision, not a backlog item — the pixel
face has almost no glyphs beyond ASCII and the look is most of what the game is. Do not
half-extract strings into a bundle nobody will translate. See ROADMAP.md.

1. **The rest of the roadmap.** In rough order of value: an opt-out for score submission,
   restricting the Firebase API key, server-side score verification (the input log is done, the
   Cloud Function is not), tappable seed links, then phase 5's three multiplayer items.
2. **Ads** (decided): AdMob, `google_mobile_ads`, consent (UMP), and the privacy/store updates. The
   placement is already built — the second-chance card is a button with a countdown ring precisely
   so the ring can become the "watch an ad" wait without the card changing.
3. **Then the release.** `RELEASE.md` section by section. The parts nobody else can do: play it on a
   real phone (sound, haptics, the rating prompt), back up the keystore, take store screenshots,
   fill in the Data safety form, and decide whether iOS is a target at all.

Some of the above cannot be done from this repo alone: verification needs the Firebase Blaze plan,
the key restriction needs the Google Cloud console, and ads need an AdMob account.

## 10. Known issues and untested edges

- Scores on the leaderboard can be faked within the cap.
- First launch with no network: boards retry at 15 s, 60 s, 5 min, then stay off for that session.
- Two devices on one board, and a lost connection mid-run, were not tried.
- Web/PWA install and offline were never tried (and web is out of scope now).
- Daily quests roll over at UTC midnight (unit-tested only, never seen live).
- **Three shipped mechanics have never been seen running**: the golden apple (twelve apples into an
  Endless run), poison (a Hardcore spawn roll) and portals (Adventure level 7). Engine-tested only.
- **Music has never been heard by a person** — the loop, the mix levels, and whether the three
  layers stay in step are all unknown. Quest and level balance are guesses; so are the milestone
  thresholds.
- **Dying ends a Time Attack run**, the same as every other mode. That was a call, not an oversight:
  a wall at three seconds ends your minute. Worth revisiting after someone plays it.
- iOS has never been built (`RELEASE.md` section 5).

## 11. Working with Claude Code (optional)

`.claude/` holds project settings, a `dart format` hook, and skills (`verify`, `emulator`,
`coverage`, `release`, `ship`, `handoff`). They are conveniences, not requirements. **Claude's memory
is stored outside the repo, per user**, so a new developer's Claude will not have it. The
preferences it holds are already written down above: verify on the emulator (not web),
`com.oasisforge.<appname>` ids, no releases from GitHub, and keep tool output small.
