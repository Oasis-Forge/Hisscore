---
name: release
description: Bump the app version (SemVer, plus a build number where the stores need one), add its CHANGELOG.md entry, build the release artifacts, and write the store's release notes, on the current feature branch, so merging the PR releases it. Use when finalizing a PR.
argument-hint: "[major|minor|patch]"
---

Version bump for this branch: $ARGUMENTS (default: choose from the changes).

Every PR merged to `main` is a release: `release.yml` tags `vX.Y.Z` and drafts a GitHub Release with the changelog entry and the artifacts. CI (`bash scripts/version.sh check`) fails a PR whose version isn't above the latest tag or has no changelog entry.

1. Stop if on `main`. Run `git fetch --tags --quiet`; the latest release is the first line of `git tag --list "v*" --sort=-v:refname`. Read the current version with `bash scripts/version.sh name` (it reads `Hisscore/pubspec.yaml`) and `build`. With no tag yet, keep the version and only write its entry. If the branch is already above the tag, adjust the level if needed and update its entry.
2. Bump the tag's version per SemVer and reset the lower parts (`1.4.2` → `1.5.0`):
   - `major`: breaks existing users, e.g. data or backups that older versions can't read, or a removed feature.
   - `minor`: new user-facing features or behavior.
   - `patch`: fixes, and changes users don't notice (dependencies, docs, CI, refactors).
   With a build number (`x.y.z+N`), set `N` to the tag's build number + 1. Update every place the stack keeps the version (`docs/STACK_NOTES.md`).
3. In `CHANGELOG.md`, add `## [x.y.z] - YYYY-MM-DD` right below `## [Unreleased]`, and move anything listed under Unreleased into it. Write it from `git log --oneline origin/main..HEAD`: Added / Changed / Fixed, short, in words a user would use. Say what they can now do, not which class changed.
4. Commit `chore(release): vX.Y.Z` with the message in a file (`git commit -F`), and put the version in the PR title or description.
5. Build the release artifacts in the background with `cd Hisscore; flutter build apk --release; flutter build appbundle --release`: the installable one for testing by hand, the one the store takes (an Android App Bundle for Play), and any mapping or symbol file the store's crash reports need. Copy them to `dist/hisscore-X.Y.Z.<ext>` (gitignored), check the built version matches, and give the user the paths. Rebuild them after any later app change on the branch.
6. Write the store's release notes to `store/<store>/release-notes/X.Y.Z.txt` (`store/` is gitignored; create it if missing): what changed for the user, from this version's `CHANGELOG.md` entry, in two to four short `•` lines, once per store listing language, naming screens and buttons with the app's own translations. For Google Play that's one `<code>`…`</code>` block per language (for example `<en-US>`…`</en-US>`), each at most 500 characters, in the same order as the previous file. Give the user the path: they paste the whole file into the release's notes box on each track.
