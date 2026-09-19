#!/usr/bin/env bash
# One version tool for CI, the release workflow, and /release.
#
#   scripts/version.sh name    print x.y.z
#   scripts/version.sh build   print the build number N (0 when there is none)
#   scripts/version.sh check   fail unless the version is above the latest vX.Y.Z tag
#                              and CHANGELOG.md has a "## [x.y.z] - YYYY-MM-DD" entry
#   scripts/version.sh notes   print the CHANGELOG.md entry for the current version
#
# The version lives in the first file found of pubspec.yaml (x.y.z, +N optional),
# package.json ("version": "x.y.z"), or VERSION (x.y.z or x.y.z+N).
# Set VERSION_FILE to choose one explicitly.
set -euo pipefail

# This app lives in a subdirectory, so point the version lookup at it. Kept across
# kit updates: without it every command here looks for a pubspec.yaml at the root.
VERSION_FILE=${VERSION_FILE:-Hisscore/pubspec.yaml}

fail() { echo "::error::$1" >&2; exit 1; }

usage() {
  sed -n '3,8p' "$0" | sed 's/^# \{0,1\}//' >&2
  exit 2
}

version_file() {
  if [ -n "${VERSION_FILE:-}" ]; then echo "$VERSION_FILE"; return; fi
  for f in pubspec.yaml package.json VERSION; do
    if [ -f "$f" ]; then echo "$f"; return; fi
  done
  fail "no pubspec.yaml, package.json, or VERSION file found"
}

# Reads a version file's content on stdin and prints "x.y.z N".
# The build number is optional everywhere: `build` reports 0 when there is none.
parse() {
  case "$(basename "$1")" in
    pubspec.yaml) sed -nE 's/^version: *([0-9]+\.[0-9]+\.[0-9]+)(\+([0-9]+))?[[:space:]]*$/\1 \3/p' | head -n 1 ;;
    package.json) sed -nE 's/^[[:space:]]*"version": *"([0-9]+\.[0-9]+\.[0-9]+)".*$/\1 0/p' | head -n 1 ;;
    *) sed -nE 's/^([0-9]+\.[0-9]+\.[0-9]+)(\+([0-9]+))?[[:space:]]*$/\1 \3/p' | head -n 1 ;;
  esac
}

changelog_entry() {
  awk -v heading="## [$1] - " '
    index($0, heading) == 1 { found = 1; next }
    found && /^## \[/ { exit }
    found { print }
    END { exit !found }
  ' CHANGELOG.md
}

# The newest vX.Y.Z on origin, or empty when nothing is released yet. An origin that
# is configured but unreachable is an error worth naming: without this, set -e killed
# the script on the command substitution and printed git's raw "fatal:" with exit 128,
# so the ::error:: annotation this script exists to produce never appeared.
latest_remote_tag() {
  local tags
  if ! git remote get-url origin > /dev/null 2>&1; then
    echo "No origin remote yet, so nothing is released." >&2
    return 0
  fi
  if ! tags=$(git ls-remote --tags --refs origin 'v*' 2>&1); then
    fail "can't reach origin to find the last release tag: $(printf '%s' "$tags" | head -n 1)"
  fi
  printf '%s\n' "$tags" | sed -n 's|.*refs/tags/||p' | sort -V | tail -n 1
}

file=$(version_file)
read -r name build < <(parse "$file" < "$file") || true
[ -n "${name:-}" ] || fail "$file: the version must look like x.y.z (x.y.z+N where the stores need a build number)"
build=${build:-0}

case "${1:-}" in
  name) echo "$name" ;;
  build) echo "$build" ;;
  notes) changelog_entry "$name" || fail "CHANGELOG.md has no '## [$name] - ' entry" ;;
  check)
    last_tag=$(latest_remote_tag)
    if [ -n "$last_tag" ]; then
      # --depth=1 is a property of the fetch, not of the refspec: run against a full
      # local clone it writes .git/shallow and truncates the repository, silently, so
      # a later `git log origin/main..HEAD` reads across the cut. CI is already shallow
      # (actions/checkout defaults to fetch-depth 1), which is the only case that wants it.
      if [ "$(git rev-parse --is-shallow-repository)" = true ]; then
        git fetch --quiet --depth=1 origin "+refs/tags/$last_tag:refs/tags/$last_tag"
      else
        git fetch --quiet origin "+refs/tags/$last_tag:refs/tags/$last_tag"
      fi
      read -r last_name last_build < <(git show "$last_tag:$file" 2>/dev/null | parse "$file") || true
      last_name=${last_name:-${last_tag#v}}
      last_build=${last_build:-0}
      highest=$(printf '%s\n%s\n' "$last_name" "$name" | sort -V | tail -n 1)
      if [ "$name" = "$last_name" ] || [ "$highest" != "$name" ]; then
        fail "$last_tag is released: raise the version above $last_name (major, minor, or patch)"
      fi
      if [ "$build" != 0 ] && [ "$build" -le "$last_build" ]; then
        fail "$last_tag is released: raise the build number above $last_build"
      fi
    fi
    changelog_entry "$name" > /dev/null || fail "CHANGELOG.md needs a '## [$name] - YYYY-MM-DD' entry"
    echo "Merging releases $name+$build (previous release: ${last_tag:-none})."
    ;;
  *) usage ;;
esac
