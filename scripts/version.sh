#!/usr/bin/env bash
# One version tool for CI, the release workflow, and /release.
#
#   scripts/version.sh name    print x.y.z
#   scripts/version.sh build   print the build number N (0 when there is none)
#   scripts/version.sh check   fail unless the version is above the latest vX.Y.Z tag
#                              and CHANGELOG.md has a "## [x.y.z] - YYYY-MM-DD" entry
#   scripts/version.sh notes   print the CHANGELOG.md entry for the current version
#
# The version lives in the first file found of pubspec.yaml (x.y.z+N),
# package.json ("version": "x.y.z"), or VERSION (x.y.z or x.y.z+N).
# Set VERSION_FILE to choose one explicitly.
set -euo pipefail
VERSION_FILE=${VERSION_FILE:-Hisscore/pubspec.yaml}

fail() { echo "::error::$1" >&2; exit 1; }

version_file() {
  if [ -n "${VERSION_FILE:-}" ]; then echo "$VERSION_FILE"; return; fi
  for f in pubspec.yaml package.json VERSION; do
    if [ -f "$f" ]; then echo "$f"; return; fi
  done
  fail "no pubspec.yaml, package.json, or VERSION file found"
}

# Reads a version file's content on stdin and prints "x.y.z N".
parse() {
  case "$(basename "$1")" in
    pubspec.yaml) sed -nE 's/^version: *([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)[[:space:]]*$/\1 \2/p' ;;
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

file=$(version_file)
read -r name build < <(parse "$file" < "$file") || true
[ -n "${name:-}" ] || fail "$file: the version must look like x.y.z (x.y.z+N in pubspec.yaml)"
build=${build:-0}

case "${1:-}" in
  name) echo "$name" ;;
  build) echo "$build" ;;
  notes) changelog_entry "$name" || fail "CHANGELOG.md has no '## [$name] - ' entry" ;;
  check)
    last_tag=$(git ls-remote --tags --refs origin 'v*' | sed -n 's|.*refs/tags/||p' | sort -V | tail -n 1)
    if [ -n "$last_tag" ]; then
      git fetch --quiet --depth=1 origin "+refs/tags/$last_tag:refs/tags/$last_tag"
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
  *) sed -n '4,8p' "$0" >&2; exit 2 ;;
esac
