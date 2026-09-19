---
name: ship
description: Pre-merge gate for a feature branch. Checks coverage of the changed files, adds missing tests, updates docs, bumps the release, drives the built app by hand, and opens the PR. Use when a branch's work is done, before asking the user to merge.
---

Stop if on `main`.

1. **Checks:** `/verify` passes.
2. **Coverage:** run `cd Hisscore; flutter test --coverage`. For each file changed on the branch (`git diff --name-only origin/main...HEAD`, ignoring generated files), find untested logic and UI paths and add tests. A test must assert what the user would see, meaning the text on screen or inside the file. "Output exists" or "has N bytes" proves nothing.
3. **Docs in the same PR:** tick the finished `docs/ROADMAP.md` items; update `CLAUDE.md` Architecture if the structure changed, `docs/privacy-policy.md` if user data, permissions, or sharing changed, and `docs/RELEASING.md` if setup changed. Every English message has its translations.
4. **Release:** `/release` at the level the changes call for. It builds the artifact into `dist/`.
5. **Drive it by hand:** install and launch the built artifact (device drill in `docs/STACK_NOTES.md`). Walk every rule the branch claims, in one right-to-left language and one theme if the app has them, with a screenshot after each navigation step. Fix what you find, then go back to step 1. Put back any user data or setting you changed.
6. **Platform proof:** if the branch touches native code, plugins, or permissions, check the release build's permissions against RUN-2. Run the platform CI builds on the branch: `gh workflow run ci.yml --ref <branch>`, after `git ls-remote origin refs/heads/<branch>` matches `HEAD`.
7. **PR:** push, fill `.github/pull_request_template.md` into a scratchpad file, and run `gh pr create --body-file <file>`. Use a Conventional Commits title with the version. State exactly what was driven by hand and what was only compiled.
8. Report in at most 5 lines: PR URL, version, `dist/` path, and what the user should try. Then stop: the user tests and merges. Don't merge.
