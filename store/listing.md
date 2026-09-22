# Store listing

Copy and metadata for Play Console / App Store Connect. Character
limits are noted where the stores enforce them.

## Title

**Play (30 chars max):**

```
Hisscore: Retro Snake
```

**App Store (30 chars max):**

```
Hisscore: Retro Snake
```

## Subtitle / short description

**Play — short description (80 chars max):**

```
Swipe to steer a neon snake. Six modes, a new daily board, and no ads.
```

**App Store — subtitle (30 chars max):**

```
Neon snake, six ways
```

## Full description

```
A snake game that plays like the arcade cabinet you remember, built for
a phone you steer with your thumb.

Swipe anywhere to turn. No buttons crowding the board, no menus in the
way — the whole screen is the game.

SIX WAYS TO PLAY
• Classic — walls kill. The original, and it stays the original.
• Adventure — clear apples to climb levels, each with its own obstacles,
  and portals from level seven.
• Endless — walls wrap, so the only thing that can stop you is you.
• Hardcore — obstacles from the start, faster, double points, shields
  won't save you, and one apple in the bunch is poison.
• Zen — nothing kills you. Just the snake, the board, and no pressure.
• Time Attack — sixty seconds on the same board as everybody else. Eat
  fast and apples are worth double.

A NEW BOARD EVERY DAY, AND A NEW RULE EVERY WEEK
The daily challenge gives everyone the same seeded board and tracks your
streak. Every week it bends one rule for all of us: everything twice as
fast, no walls, mirrored steering, fog that lights only the ground near
your head, a smaller board, or food that comes to you.

Miss a day and you don't lose the streak straight away — seven days in a
row banks a freeze, and it's spent for you the next time you play.

RACE YOURSELF
Your best run of the day comes back as a ghost snake running the board
alongside you. Beat it.

PICKUPS WORTH CHASING
Apples grow you and score. Stars ripen — worth 50 the moment they appear
and 150 in the last second before they go. Shields survive one crash.
Speed bursts, shrink potions and magnets change the run while they last.
And in Adventure and Endless, a golden apple that runs away from you.
String apples together quickly and the combo multiplier climbs.

A REASON TO COME BACK
Three quests a day, XP and levels that unlock four looks and four snake
skins, and twenty-one one-off milestones — some of which give you a title
to wear on the menu.

LEADERBOARDS, IF YOU WANT THEM — AND ONLY IF YOU DO
A board for each mode and one for each day's challenge. Pick a name; no
account, no sign-up, no email. The game asks before it sends anything,
and if you say no it never does. Everything else works either way.

NO ADS. NO ACCOUNTS. Plays offline.
```

## Keywords (App Store, 100 chars max, comma separated)

```
snake,retro,arcade,classic,neon,offline,casual,highscore,daily,crt,pixel,80s,no ads,one hand
```

## Category and rating

- **Play category:** Games → Arcade
- **App Store category:** Games → Arcade (secondary: Casual)
- **Content rating:** suitable for all ages. No violence, no purchases,
  no ads. **There is user-generated content in one narrow sense** — the
  display name a player types appears on a public leaderboard. Answer the
  questionnaire accordingly rather than claiming none.

## Play Data safety answers

> **This section was wrong and had to be rewritten (2026-09-22).** It
> previously said the app "collects and transmits nothing", which stopped
> being true the day the Firebase leaderboard shipped. Submitting that
> would have been a false declaration. Match this to
> [`docs/index.html`](../docs/index.html), which was corrected on
> 2026-09-20 and is the published policy.

**What actually leaves the device.** Nothing, unless the player has said
it may. The game asks once, on the first game-over card worth
submitting; until then, and if the answer is no, nothing about them is
sent at all, and it can be turned off again at any time under SENDING
YOUR SCORES on the STATS tab.

With that agreement, at the end of each run scoring above zero the app
writes to Cloud Firestore: the display name the player chose, the score,
a server timestamp, and an anonymous Firebase Auth user id. Nothing else
is sent — no analytics, no ads SDK, no crash reports (crash traces stay
on-device unless a build supplies a `SENTRY_DSN`, and no shipped build
does).

- Does your app collect or share any user data? **Yes**
- **Personal info → Name.** Collected and transmitted. Purpose: app
  functionality. **Shared publicly** — it is shown on a leaderboard.
  **Optional** — the player is asked before anything is sent and can
  withdraw at any time.
- **App activity → In-app score.** Collected and transmitted. Purpose:
  app functionality. Shown publicly alongside the name. **Optional**, on
  the same switch.
- **Device or other IDs.** A pseudonymous Firebase Auth id, collected and
  transmitted, used to keep one row per player. **Optional**, on the same
  switch.
- Is all user data encrypted in transit? **Yes** — Firestore is HTTPS.
  At rest it has Google's defaults and nothing of ours on top.
- Do you provide a way for users to request deletion? **Yes, by email**
  (`oasisforge.support@gmail.com`). There is no in-app deletion flow:
  the switch stops future submissions but does not remove a row already
  on a board. Clearing app storage removes the local copy only.

Everything else — stats, quests, XP, milestones, the daily streak and the
saved ghost run — is stored locally via the platform's standard app
storage and never leaves the phone. The release build requests no runtime
permissions other than `POST_NOTIFICATIONS`, used solely for the local
daily-streak reminder scheduled on-device.

**Still worth having:** an in-app way to delete a board row that has
already been set, rather than only stopping future ones. Removal is by
email today. Tracked in RELEASE.md.

## Screenshots — still to capture

**These have to come from a real device — do not ship anything I could
generate.** You have the APK; screenshots take two minutes and are the
single biggest driver of install conversion on the store page.

Requirements:

| Store | Needed | Size |
| --- | --- | --- |
| Play | 2–8 phone shots | 16:9 or 9:16, min 1080px on the short side |
| App Store | up to 10, 6.7" required | 1290×2796 |

Shot list, in the order they should appear:

1. **Mid-run, snake reasonably long** — Classic or Endless, showing the
   full-bleed board and HUD. This is the one that sells it.
2. **The intro screen** — cabinet, title, mode chips.
3. **Hardcore with obstacles on the board** — shows it isn't just one mode.
4. **Game over with a high score, the score breakdown, the XP bar and a
   milestone line** — shows there is progression behind the run.
5. **The daily challenge card showing a streak and the week's rule** —
   shows the reason to come back.
6. **Time Attack mid-run with the timer ring red** — the newest mode, and
   the clearest "one more go".
7. *(optional)* A FOG week mid-run. It is the most striking thing the
   game does and looks like nothing else on the store page.
8. *(optional)* The HOW tab, showing the pickup legend.

Play down-ranks listings whose screenshots are just the app icon or
marketing text, so keep these as actual gameplay.

## Feature graphic

`store/feature-graphic.png` — 1024×500, generated by
`dart run tool/generate_store_graphics.dart`. Required by Play; not used
by the App Store.

## Still required before submitting

Tracked in [RELEASE.md](../RELEASE.md) — privacy policy URL, upload
keystore, screenshots, and the iOS build.
