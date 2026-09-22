# AGENTS.md

## Product

Hisscore is a single Flutter app (retro Snake) in `Hisscore/`. Core play is entirely local: move, eat, score, game over, local high score, and all progression. The one server-side piece is a global leaderboard on Firebase (anonymous auth + Firestore) — see [CLAUDE.md](CLAUDE.md) and [docs/LEADERBOARD.md](docs/LEADERBOARD.md). It is absent and harmless in a checkout without `google-services.json`, which is the usual case on a Cloud Agent.

## Cursor Cloud specific instructions

Flutter SDK is a system toolchain, not a repo package. On this Cloud Agent image it is expected at `/opt/flutter` (Dockerfile) or `$HOME/sdk/flutter` if installed in the session. `flutter` must already be on `PATH` before `flutter pub get`.

Chrome/web is the supported E2E target here. Android SDK and iOS simulators are not required. Do not start Docker, databases, or Appwrite for this app.

Standard commands (also in `Hisscore/README.md`):

```bash
cd Hisscore
flutter pub get
flutter analyze
flutter test
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080
```

The web-server process is a long-running `terminals` job, not an install step. After `flutter pub get`, a running web-server does not always pick up new packages until it is restarted.

`flutter run -d chrome` needs a display. Prefer `web-server` plus a browser against port 8080 in this environment.

Widget tests use Flutter's fake clock: `tester.pump(Duration)` advances Snake ticks (**190ms** each by default, not 240 — the tick was shortened in #26). The first apple is 4 cells ahead of the starting snake, so a score of `00010` appears after about 760ms of pumped time. A death then takes a further `RunEffects.deathPause` (400ms) of slow motion before the game-over card appears.

Note that web is **not** a supported target for the product any more (see the decisions log in [ROADMAP.md](ROADMAP.md)); it remains the only practical way to run the app in this environment, but anything to do with audio, haptics, the share sheet or notifications cannot be judged here, and neither can a release build. Say in the PR what was only compiled.
