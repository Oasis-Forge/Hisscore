# Release checklist

What's left before Hisscore can go on the Play Store and App Store, and
what's deliberately parked. Everything here is something the repo cannot
do for itself — it needs a device, an account, or a decision.

Last reviewed: 2026-09-12.

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
states what actually leaves the device: at the end of every run scoring above
zero, the app submits a display name, the score, a server timestamp and an
anonymous Firebase Auth ID to Cloud Firestore, with no prompt and no opt-out.

Two things still follow from that:

- [ ] **Play Data safety form** must match this: collected and transmitted are
      a user-chosen name ("Personal info > Name", public), in-app score
      ("App activity"), and a pseudonymous device/user ID. Not encrypted at
      rest by us beyond Firestore's own defaults; no deletion request flow in
      the app, only by email.
- [ ] **Consider an opt-out before wider release.** Silent submission of a
      pseudonymous ID plus a display name is personal data under GDPR. The
      policy currently tells players to go offline to avoid it, which is a
      workaround, not a control.

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

### 4. Screenshots

Must come from a real device — Play down-ranks listings whose
screenshots aren't real gameplay. Shot list and required sizes are in
[`store/listing.md`](store/listing.md).

- [ ] Mid-run with a long snake (the one that sells it)
- [ ] Intro screen
- [ ] Hardcore, obstacles visible
- [ ] Game over with the score breakdown
- [ ] Daily challenge card showing a streak
- [ ] *(optional)* HOW tab with the pickup legend

### 5. iOS has never been built

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

**Daily challenge boards differ across devices.** The grid follows the
screen, so a taller phone gets a taller board from the same seed. Only
matters if daily scores are ever compared between players; fixing it
means either letterboxing daily runs or pinning a fixed grid, both of
which cost something.

**Global leaderboard.** Needs a backend — Firebase Firestore with
anonymous auth is the low-effort path. The biggest single lever for
making the game competitive, and the main reason the daily-board issue
above would start to matter.

**Real push notifications.** Today's reminders are local and on-device.
Server-initiated re-engagement needs FCM plus APNs credentials.

**`game_page.dart` is still ~1,000 lines.** The presentational half was
split out; what remains is orchestration (engine lifecycle, ticker,
persistence, sound, notifications, share, daily, demo). Extracting a
`GameSession` controller is the obvious next step, but it's a tax rather
than a crisis.

**Golden tests for the board painter.** The engine and flows are well
covered; the rendering isn't. Two of the visual bugs this project has
hit — the malformed lightning bolt and the jagged star — were caught by
eye, not by a test.
