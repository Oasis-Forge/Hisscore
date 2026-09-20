---
name: release
description: Bump the app version (SemVer, plus a build number where the stores need one), add its CHANGELOG.md entry, build the release artifacts locally, and write the store's release notes, on the current feature branch. Use when finalizing a PR.
argument-hint: "[major|minor|patch]"
---

Version bump for this branch: $ARGUMENTS (default: choose from the changes).

**Nothing is released from GitHub, by decision (2026-09-20).** There is no release
workflow, no tags, and no GitHub Releases. The upload keystore is deliberately kept
off CI, so anything CI builds is debug-signed and Play would reject it. A release is:
bump the version, write the changelog entry, merge the PR, then **build the artifacts
locally (step 5) and upload the AAB to Play by hand**. Do not add tagging or a release
workflow back without being asked.

1. Stop if on `main`. `CHANGELOG.md` is the record of what shipped -- the newest
   `## [x.y.z]` heading below `## [Unreleased]` is the last released version. (Do not
   look for git tags; this repo has none.) Read the current version with
   `bash scripts/version.sh name` (it reads `Hisscore/pubspec.yaml`) and `build`. If
   the branch is already above the last changelog entry, adjust the level if needed
   and update that entry rather than adding another.
2. Bump per SemVer from the last released version and reset the lower parts
   (`1.4.2` → `1.5.0`):
   - `major`: breaks existing users, e.g. data or backups that older versions can't read, or a removed feature.
   - `minor`: new user-facing features or behavior.
   - `patch`: fixes, and changes users don't notice (dependencies, docs, CI, refactors).
   With a build number (`x.y.z+N`), raise `N` above the last uploaded build -- Play
   rejects a reused one. Update every place the stack keeps the version
   (`docs/STACK_NOTES.md`).
3. In `CHANGELOG.md`, add `## [x.y.z] - YYYY-MM-DD` right below `## [Unreleased]`, and move anything listed under Unreleased into it. Write it from `git log --oneline origin/main..HEAD`: Added / Changed / Fixed, short, in words a user would use. Say what they can now do, not which class changed.
4. Commit `chore(release): vX.Y.Z` with the message in a file (`git commit -F`), and put the version in the PR title or description.
5. Build the release artifacts in the background with `cd Hisscore; flutter build apk --release; flutter build appbundle --release`: the installable one for testing by hand, the one the store takes (an Android App Bundle for Play), and any mapping or symbol file the store's crash reports need. Copy them to `Hisscore/dist/hisscore-X.Y.Z.<ext>` (gitignored; the dist folder lives under the app, not the repo root), check the built version matches, and give the user the paths. Rebuild them after any later app change on the branch.

   **Verify the signer before handing over the AAB.** A missing
   `Hisscore/android/key.properties` makes Gradle fall back to debug keys silently,
   and Play rejects that: `apksigner verify --print-certs Hisscore/dist/hisscore-X.Y.Z.apk`
   must not print `CN=Android Debug`. Note `jarsigner` cannot check an APK here --
   Flutter signs with APK Signature Scheme v2 only, which `jarsigner` does not read.
6. Write the store's release notes to `store/<store>/release-notes/X.Y.Z.txt` (`store/` is gitignored; create it if missing): what changed for the user, from this version's `CHANGELOG.md` entry, in two to four short `•` lines, once per store listing language, naming screens and buttons with the app's own translations. For Google Play that's one `<code>`…`</code>` block per language (for example `<en-US>`…`</en-US>`), each at most 500 characters, in the same order as the previous file. Give the user the path: they paste the whole file into the release's notes box on each track.
