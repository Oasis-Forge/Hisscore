# Release checklist

What's left before Hisscore can go on the Play Store and App Store, and
what's deliberately parked. Everything here is something the repo cannot
do for itself — it needs a device, an account, or a decision.

Last reviewed: 2026-09-22.

**The release is deliberately last.** The rest of
[ROADMAP.md](ROADMAP.md), then this file. Everything below still has to
happen — it just happens after that work lands, so one version bump covers
the lot. `CHANGELOG.md` is holding 22 entries under `Unreleased` in the
meantime.

---

## Blocking submission

### 1. Play the APK on a real phone

**Three of these were checked on the Android emulator on 2026-09-20; three still
need real hardware.** The web preview can't exercise any of them, and an emulator
cannot settle the audio ones: this one has no working audio output and no
vibration motor.

- [ ] **Sound** — eat blip, bonus, level-up, game-over, and the mute toggle.
      *Still open: nobody has heard it. Not checkable on this emulator, where
      nothing — not even a system volume beep — ever reaches `state:started`
      in `dumpsys audio`.*
- [x] **Share** — SHARE SCORE on the game-over screen should open the
      Android share sheet. *Emulator: the sheet opened with the board PNG and
      the caption "HISSCORE — CLASSIC — Score 10 / Can you beat it?".*
- [x] **Notifications** — finish a Daily Challenge; it should ask for
      permission, then schedule a streak reminder ~20h out. *Emulator: the
      prompt fired, and `dumpsys alarm` showed the reminder at +19h50m on
      ScheduledNotificationReceiver.*
- [ ] **Rating prompt** — should fire once on a new high score, after a
      couple of games. *Still open: in_app_review needs the Play Store, so it
      cannot be triggered reliably on the emulator.*
- [x] **Lifecycle** — background the app mid-run and come back; the run
      must be paused, not dead. *Emulator: a Zen run held its score across 10s
      backgrounded and came back PAUSED, and the score did not advance while
      away, so the engine really stops.*
- [ ] **Haptics** — button presses should buzz. *Still open: the emulator has
      no vibration motor, so this cannot be felt or confirmed there.*

Build one with:

```bash
cd Hisscore
flutter build apk --release --split-per-abi
# build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

Or grab the artifact from any green CI run.

### 2. Privacy policy at a public URL

Both stores require a reachable policy. The page is written
([`docs/index.html`](docs/index.html)), hosted, and now describes the
leaderboard.

- [x] Put a real support email in it. Done 2026-09-20: `oasisforge.support@gmail.com`.
- [x] Turn on GitHub Pages. Done: live at
      <https://oasis-forge.github.io/Hisscore/>, serving `main` / `/docs`.
- [ ] Paste the resulting URL into Play Console and App Store Connect

**The old wording was wrong and was briefly published.** It said the app
collects "Nothing" and that "There is no backend for it to send data to",
which stopped being true when the Firebase leaderboard shipped. The page now
states what actually leaves the device: with the player's agreement, at the end
of each run scoring above zero, the app submits a display name, the score, a
server timestamp and an anonymous Firebase Auth ID to Cloud Firestore.

- [x] **An opt-out.** Done 2026-09-22 (#48), and it is an opt-*in*: nothing is
      sent until the player answers the question the game asks once, on the
      first game-over card worth submitting. "Not asked" behaves as no. It can
      be changed any time under SENDING YOUR SCORES on the STATS tab. This was
      the GDPR gap — silent submission of a pseudonymous id plus a display name
      is personal data, and "play offline" was a workaround, not a control.
- [ ] **Play Data safety form** must match this: collected and transmitted are
      a user-chosen name ("Personal info > Name", public), in-app score
      ("App activity"), and a pseudonymous device/user ID. Not encrypted at
      rest by us beyond Firestore's own defaults; no deletion request flow in
      the app, only by email. Data safety has a field for whether collection is
      optional — it now is, and the answer should say so.

Accurate as of this version: no ads, no analytics, no tracking SDKs, and crash
reports stay on-device because no `SENTRY_DSN` is set in any shipped build. The
only runtime permission is `POST_NOTIFICATIONS`, for the on-device streak
reminder.

### 3. Upload keystore

`android/app/build.gradle.kts` already reads `android/key.properties`
when it exists and falls back to debug keys when it doesn't — so builds
work today but **cannot be published**.

- [x] Create the keystore. Done 2026-09-20: `~/hisscore-upload.jks`, RSA 2048,
      alias `upload`, valid 10,000 days. Note that `keytool` is not on PATH on
      the Windows box; it ships inside Android Studio's JDK:
      ```bash
      "/c/Program Files/Android/Android Studio/jbr/bin/keytool.exe" -genkeypair -v \
        -keystore ~/hisscore-upload.jks -alias upload \
        -keyalg RSA -keysize 2048 -validity 10000
      ```
- [x] Write `android/key.properties` (gitignored — never commit it). Done, and
      confirmed ignored by `git check-ignore` and absent from `git status`.
- [ ] **Back the keystore up somewhere you won't lose it.** Lose this
      file and you can never update the app under the same listing.
- [x] Build with `flutter build appbundle` for Play. Done: `app-release.aab`
      (53.6 MB). `jarsigner -verify` reports "jar verified" and the signer is
      `CN=Hassan Kalash, O=Oasis Forge, C=LB`, not the debug key.

**Nothing is released from GitHub, by decision (2026-09-20).** The release
workflow is gone, along with its tags and draft GitHub Releases. The upload
keystore is deliberately kept off CI, so anything CI builds is debug-signed and
Play would reject it -- attaching such a build to a "release" only invites someone
to upload it. `ci.yaml` still builds a debug-signed APK on every PR to catch
Gradle breakage, and still runs the RUN-2 permission check, but it publishes
nothing. Build the real artifacts locally and upload the AAB to Play by hand:

```bash
cd Hisscore
flutter build appbundle --release
flutter build apk --release
mkdir -p dist
cp build/app/outputs/bundle/release/app-release.aab dist/hisscore-X.Y.Z.aab   # goes to Play
cp build/app/outputs/flutter-apk/app-release.apk dist/hisscore-X.Y.Z.apk    # sideload to test
```

Check the signer before uploading; it must not say `CN=Android Debug`:

```bash
apksigner verify --print-certs Hisscore/dist/hisscore-X.Y.Z.apk
```

### 4. Finish the App Link verification

Challenge links ship (#51), but the https one is **not** a verified Android
App Link, so tapping it opens the browser rather than the game. The page
there shows the code and offers a `hisscore://` link, which does open the
app — a working fallback, not the real thing.

Two pieces are missing, and both need an account:

- [ ] **`assetlinks.json` at the domain root.** It must be served from
      `https://oasis-forge.github.io/.well-known/assetlinks.json`, which is
      the *organisation* Pages site — a repo named `oasis-forge.github.io`,
      not this one. Serving it under `/Hisscore/` does nothing; Android only
      reads the root.
- [ ] **The signing fingerprint that goes in it.** With Play App Signing the
      one that matters is Google's, from Play Console → Setup → App signing,
      not the local upload key. So this cannot be finished before the first
      upload.

Then add `android:autoVerify="true"` to the https intent-filter in
`AndroidManifest.xml` (the filter is already there, with a comment saying
this) and check it with:

```bash
adb shell pm verify-app-links --re-verify com.oasisforge.hisscore
adb shell pm get-app-links com.oasisforge.hisscore
```

Until then, a player can get the same result by hand: Settings → Apps →
Hisscore → Open by default → Open supported links.

### 5. Screenshots

Must come from a real device — Play down-ranks listings whose
screenshots aren't real gameplay. Shot list and required sizes are in
[`store/listing.md`](store/listing.md).

- [ ] Mid-run with a long snake (the one that sells it)
- [ ] Intro screen
- [ ] Hardcore, obstacles visible
- [ ] Game over with the score breakdown, XP bar and a milestone line
- [ ] Daily challenge card showing a streak and the week's rule
- [ ] Time Attack mid-run, timer ring red
- [ ] *(optional)* a FOG week, which is the most striking thing the game does
- [ ] *(optional)* HOW tab with the pickup legend

### 6. iOS has never been built

Not once, on any machine. The icons and launch screens were generated
and the bundle ID is set (`com.oasisforge.hisscore`), but **nothing has
ever compiled**, so the whole platform is unverified.

- [ ] Build on a Mac and fix whatever falls out
- [ ] Check the plugin setup: `audioplayers`,
      `flutter_local_notifications` (needs push capability and permission
      strings), `in_app_review`
- [ ] Provisioning profile and App Store Connect record
- [ ] Capture 6.7" screenshots (1290×2796)

If iOS isn't actually a target, say so — the repo currently generates
iOS assets on every icon run for nothing.

---

## Worth doing, not blocking

### Pick a real crash reporter

`lib/game/crash_reporter.dart` is a seam with a local implementation:
errors are captured and the last 20 kept on-device, but **nothing is
sent anywhere**. You'll still be blind to crashes in the wild.

`SentryCrashReporter` (`lib/game/sentry_crash_reporter.dart`) is wired
up and used in `main.dart` when a DSN is supplied at build time — it
falls back to the local-only reporter otherwise, so this ships as a
no-op until a Sentry project exists.

- [ ] Create a Sentry project, get its DSN
- [ ] Build/run with
      `--dart-define=SENTRY_DSN=<your dsn>` (see `README`/`AGENTS.md`)
- [ ] Consider passing it through CI as a repo secret for release builds

### Store listing content

- [x] Title, descriptions, keywords, category, Data safety answers —
      [`store/listing.md`](store/listing.md)
- [x] Feature graphic 1024×500 — `store/feature-graphic.png`
- [x] Play listing icon 512×512 — `store/play-icon-512.png`
- [ ] Paste it all into Play Console / App Store Connect
- [ ] Content rating questionnaire
- [ ] Play Console Data safety form

---

## Parked deliberately

Not bugs — decisions with a reason to wait.

**Real push notifications.** Today's reminders are local and on-device.
Server-initiated re-engagement needs FCM plus APNs credentials.

**Server-side score verification.** Scores are client-reported and the
Firestore rules can only cap them. The client half is now done — `RunLog`
records a run as a seed plus its turns and a replay recomputes the score —
so what is left is a Cloud Function that replays it. Needs the Blaze plan.
Tracked in ROADMAP.md phase 3.

**A way to delete your own board entry.** Removal is by email today. An
in-app "take me off the boards" that actually deletes the row — rather
than just stopping future ones, which is what the STATS toggle does —
would be better, and the Data safety form asks about it.

### Done since this list was written

- **Golden coverage for the newer painting** — done 2026-09-22 (#50). The
  fog, portals, the ghost, the golden apple, poison and the ripening
  star's price all have one now. The ghost goldens fail by 1.3-1.5% with
  its slide removed, so the bug that shipped would now be caught before a
  phone saw it. Seven visual bugs had been found by eye and none by a
  test; that was the argument for doing this first. Time Attack's timer
  ring is covered by `hud_widgets_test.dart` instead — it is too small for
  a golden to be both sensitive and portable.
- **Daily boards differ across devices** — fixed. The daily, challenge
  codes and Time Attack declare `SnakeEngine.fixedGrid` and are
  letterboxed, so the same seed gives the same board everywhere.
- **Global leaderboard** — shipped (Firebase anonymous auth + Firestore).
- **`game_page.dart` is ~1,000 lines** — it is 598. `GameSession` was
  extracted in #42.
