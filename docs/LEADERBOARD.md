# Global leaderboard (Firebase)

**Status: live.** The Firebase project is `oasisforge-hisscore` (Android app `com.oasisforge.hisscore`).
`Hisscore/android/app/google-services.json` is committed: it holds identifiers, not secrets. The
rules are what protect the data, and they have been checked against the live project (see below).
`FirebaseScoreBoard` connects in the background, so the game never waits on it.
Without that file the Google services Gradle plugin is skipped and the app builds and runs
with no boards.

The game talks to boards through `OnlineScoreBoard` (`lib/game/online_scores.dart`).
Without a backend it uses `NoopOnlineScoreBoard`, the boards are hidden, and the
game is exactly the local, offline game it was. Nothing below is required to run it.

## What is stored

One document per player per board:

```
boards/{boardId}/entries/{playerUid}  { name, score, updatedAt }
```

- `boardId` is `daily-<dayNumber>` (one challenge day, same seed and 20x30 grid
  for everyone) or `alltime-<mode>` (best ever in that mode).
- `playerUid` is a Firebase **anonymous** user id: no email, no account.
- `name` is a handle the player chose (2-12 of A-Z, 0-9, space, `_`, `-`).

Security rules are in `firebase/firestore.rules`. They stop writing as someone
else, lowering or deleting a score, junk names, out-of-range values, and flooding
(one write per 5 s). They **cannot** stop someone submitting a made-up score under
the cap: the client reports its own score. Real verification means a server that
replays the run (the engine is deterministic, so it is possible). That needs Cloud
Functions and the Blaze plan, and an input log recorded per run. Not built yet.

Also note: all-time boards compare scores from differently shaped screens (normal
runs fit the screen). Only the daily and challenge codes use the fixed grid.

## Rules checked against the live project

With an anonymous test user, these were each sent as an otherwise well-formed write and all
returned HTTP 403: someone else's row, signed out, a lower-case name, a one-letter name, a
name with markup, a score over 100000, a negative score, a score as a string, an extra field,
and a path outside `boards/`. Reading a board while signed out returns 200; reading anything
else is refused. The app's own create and rename (same score, new name) were accepted.
The rules are not unit-tested in the repo: the fake Firestore does not support rule functions.

## One-time setup (you)

1. Firebase console -> **Add project** (Analytics off is fine).
2. **Build -> Authentication -> Sign-in method -> Anonymous -> Enable.**
3. **Build -> Firestore Database -> Create database** (production mode, pick a region).
4. Paste `firebase/firestore.rules` into **Firestore -> Rules** and publish (or
   `firebase deploy --only firestore`).
5. **Project settings -> Add app -> Android**, package name
   `com.oasisforge.hisscore`. Download **`google-services.json`** and put it in
   `Hisscore/android/app/`. (Add the iOS app too if you ship iOS.)
6. Tell me the project is ready. The Firebase-backed `OnlineScoreBoard`,
   the Gradle plugin and `firebase_core` / `firebase_auth` / `cloud_firestore`
   get added then, and verified against your project.

`google-services.json` is not a secret in the password sense, but keep it out of
public forks if you want to limit abuse of your project; the rules are what protect
the data.

## Privacy and store forms (must change when this ships)

This is the first time the app sends anything off the device. Before release:

- Update the privacy policy (`docs/index.html`): an anonymous id, the chosen
  handle and scores are stored on Google's servers for the boards.
- Play Console **Data safety**: declare User IDs and (optional) name/handle,
  collected, not shared, and that it can be deleted on request.
- `store/listing.md` and `RELEASE.md`: they currently say no data leaves the device.
- Decide how a player deletes their entry (a "delete my data" path). The rules
  currently forbid deletes; a Cloud Function or a manual console delete would do it.
