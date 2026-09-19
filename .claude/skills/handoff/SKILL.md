---
name: handoff
description: Save where work stopped into the session-handoff memory, so the next session can resume from files after the chat is cleared. Use at the end of a session, before clearing the chat, or when the user says "handoff".
---

Update the `session-handoff` memory file in this project's memory directory; don't create a second one. If it's missing, create it (type `project`) and add its line to `MEMORY.md`.

Write the current state at the top, in at most 25 lines:
- **Branch and PR state:** what's open and merged, the version, and what the user still has to do (merge, test by hand, add secrets).
- **Shape of the current work:** key files, and any design choice someone might "simplify" back, with "don't" and why.
- **Decisions the user made**, dated.
- **Driven by hand vs only compiled**, and anything left changed on a device.
- **Known and not fixed.**
- **Next:** the next item and its first step. Front-load anything only a device or CI can prove.

Condense older entries to one line each. Drop what `git log`, `docs/ROADMAP.md`, or `CLAUDE.md` already record. A lesson that applies to every session goes in its own `feedback` memory, not here. Use absolute dates.

End the file with: **How to apply:** on "resume", run `gh pr list` and `git log --oneline -3` first. A green open PR is waiting for the user, so don't merge it. Otherwise take the next unticked item in `docs/ROADMAP.md` from a freshly pulled `main`.
