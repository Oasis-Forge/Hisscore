#!/usr/bin/env bash
# Drives the app on the Android emulator with text instead of screenshots:
# `screen` lists what is showing, `tap` presses an element by its label.
#
#   bash tool/emu.sh <command> [args]
#
#   start              run the emulator (as a background command: it lasts as
#                      long as the emulator does)
#   ready              wait until it has booted
#   save <name>        snapshot the whole emulator: data, language, theme,
#                      dark mode, Downloads
#   load <name>        go back to a snapshot
#   snapshots          list snapshots
#   forget <name>      delete a snapshot
#   install <apk>      install over the app, keeping its data
#   launch             restart the app
#   screen             one line per element: label @ x,y (flags)
#   tap <label> [n]    tap the nth element (default 1st) labelled <label>
#                      exactly, or else containing it, ignoring case
#   hold <label> [n]   long-press it the same way
#   tapxy <x> <y>      tap a point, in device pixels as `screen` prints them
#   type <text>        type ASCII text into the focused field
#   key <name>         press a key: back, enter, del, tab, home
#   scroll <up|down>   swipe the middle of the screen
#   push <file>        copy a file into Downloads, for the file picker
#   shot <file.png>    save a screenshot, for when the look matters
set -euo pipefail
export MSYS_NO_PATHCONV=1 # stops Git Bash rewriting /sdcard into a Windows path

app=com.hisscore.hisscore
sdk=${ANDROID_HOME:-${LOCALAPPDATA:-$HOME}/Android/Sdk}
if command -v cygpath >/dev/null; then sdk=$(cygpath -u "$sdk"); fi

usage() {
  sed -n '3,25s/^# \{0,1\}//p' "$0" >&2
  exit 64
}

start() {
  if [[ $(adb devices) == *emulator-* ]]; then
    echo "An emulator is already running."
    return
  fi
  local emulator=$sdk/emulator/emulator
  if [ -f "$emulator.exe" ]; then emulator=$emulator.exe; fi
  exec "$emulator" -avd "${AVD:-Medium_Phone}" >/dev/null 2>&1
}

ready() {
  adb wait-for-device
  until [ "$(adb shell getprop sys.boot_completed | tr -d '\r')" = 1 ]; do
    sleep 2
  done
  echo "Booted."
}

# Elements on screen, tab separated: label, x, y, flags. The status and
# navigation bars are left out; so is anything with no label that can't be
# tapped, typed into, or scrolled.
elements() {
  local try
  for try in 1 2 3; do
    # Fails with "could not get idle state" while something animates.
    adb shell uiautomator dump /sdcard/ui.xml >/dev/null 2>&1 && break
    sleep 1
  done
  adb exec-out cat /sdcard/ui.xml | tr '>' '\n' | awk '
    function attr(name) {
      if (!match($0, " " name "=\"[^\"]*\"")) return ""
      s = substr($0, RSTART + length(name) + 3, RLENGTH - length(name) - 4)
      # Lines become " / "; emoji (category icons) are dropped.
      gsub(/&#10;/, " / ", s); gsub(/&#[0-9]+;|\xef\xb8\x8f/, "", s)
      gsub(/( \/ )+/, " / ", s); sub(/^ \/ /, "", s); sub(/ \/ $/, "", s)
      gsub(/  +/, " ", s); gsub(/^ +| +$/, "", s)
      gsub(/&quot;/, "\"", s)
      gsub(/&apos;/, "'"'"'", s); gsub(/&lt;/, "<", s); gsub(/&gt;/, ">", s)
      gsub(/&amp;/, "\\&", s)
      return s
    }
    /<node / {
      if (attr("package") == "com.android.systemui") next
      text = attr("text"); desc = attr("content-desc")
      if (desc == "") label = text
      else if (text == "" || text == desc) label = desc
      else label = desc " | " text
      # A text field has its label as a hint; the typed text follows it.
      # (No apostrophes anywhere in this awk program: it is single-quoted.)
      hint = attr("hint")
      if (hint != "") label = label == "" ? hint : hint " | " label
      flags = ""
      if (attr("class") == "android.widget.EditText") flags = flags " field"
      if (attr("checked") == "true") flags = flags " checked"
      if (attr("selected") == "true") flags = flags " selected"
      if (attr("focused") == "true") flags = flags " focused"
      if (attr("enabled") == "false") flags = flags " disabled"
      if (attr("scrollable") == "true") flags = flags " scrollable"
      if (label == "") {
        if (attr("clickable") != "true" && flags !~ /field|scrollable/) next
        label = "(no label)"
      }
      b = attr("bounds"); gsub(/[^0-9]+/, " ", b); split(b, n, " ")
      printf "%s\t%d\t%d\t%s\n", label, (n[1] + n[3]) / 2, (n[2] + n[4]) / 2,
        substr(flags, 2)
    }'
}

screen() {
  elements | awk -F'\t' '{
    printf "%s @ %d,%d%s\n", $1, $2, $3, ($4 == "" ? "" : "  (" $4 ")")
  }'
}

# "x y" of the nth element labelled $1 exactly, or else containing it.
locate() {
  local label=${1:?needs a label} n=${2:-1} all hit
  all=$(elements)
  hit=$(awk -F'\t' -v want="$label" -v n="$n" '
    $1 == want { exact[++e] = $2 " " $3 }
    index(tolower($1), tolower(want)) { loose[++l] = $2 " " $3 }
    END { if (e >= n) print exact[n]; else if (l >= n) print loose[n] }
  ' <<<"$all")
  if [ -z "$hit" ]; then
    echo "No element $n labelled \"$label\". On screen:" >&2
    awk -F'\t' '{ printf "  %s @ %d,%d\n", $1, $2, $3 }' <<<"$all" >&2
    exit 1
  fi
  echo "$hit"
}

tap() {
  local pos
  pos=$(locate "$@")
  adb shell input tap $pos
  echo "Tapped \"$1\" @ ${pos/ /,}."
}

hold() {
  local pos
  pos=$(locate "$@")
  adb shell input swipe $pos $pos 800
  echo "Held \"$1\" @ ${pos/ /,}."
}

type_text() {
  local text=${1:?needs text}
  if [[ $text == *"'"* ]]; then
    echo "Typing a ' isn't supported." >&2
    exit 1
  fi
  adb shell "input text '${text// /%s}'"
}

scroll() {
  local size w h
  size=$(adb shell wm size | tr -d '\r' | awk 'END { print $NF }')
  w=${size%x*} h=${size#*x}
  case ${1:-} in
  down) adb shell input swipe $((w / 2)) $((h * 7 / 10)) $((w / 2)) $((h * 3 / 10)) 300 ;;
  up) adb shell input swipe $((w / 2)) $((h * 3 / 10)) $((w / 2)) $((h * 7 / 10)) 300 ;;
  *) usage ;;
  esac
}

command=${1:-}
if [ $# -gt 0 ]; then shift; fi
case $command in
start) start ;;
ready) ready ;;
save) adb emu avd snapshot save "${1:?needs a name}" ;;
load) adb emu avd snapshot load "${1:?needs a name}" && adb wait-for-device ;;
snapshots) adb emu avd snapshot list ;;
forget) adb emu avd snapshot delete "${1:?needs a name}" ;;
install) adb install -r "${1:?needs an apk}" | tail -1 ;;
launch) adb shell am start -S -n "$app/.MainActivity" >/dev/null && echo "Launched." ;;
screen) screen ;;
tap) tap "$@" ;;
hold) hold "$@" ;;
tapxy) adb shell input tap "${1:?needs x}" "${2:?needs y}" ;;
type) type_text "$@" ;;
key) adb shell input keyevent "KEYCODE_${1^^}" ;;
scroll) scroll "$@" ;;
push) adb push "${1:?needs a file}" /storage/emulated/0/Download/ | tail -1 ;;
shot) adb exec-out screencap -p >"${1:?needs a file}" && echo "Saved $1." ;;
*) usage ;;
esac
