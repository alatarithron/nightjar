#!/usr/bin/env bash
# Regression tests for bin/install.sh and bin/uninstall.sh.
#
#   bin/test-install.sh
#
# Runs the real scripts against synthetic profile layouts under a throwaway
# THUNDERBIRD_HOME. Nothing here reads or writes an actual Thunderbird profile.
#
# Why these two behaviors and no others:
#
#   Which profile Thunderbird opens is named by the [Install...] section of
#   profiles.ini. install.sh once read only the legacy Default=1 flag on a
#   [Profile...] section, so on a machine where the two disagree the theme was
#   linked into a profile that never runs — and a theme installed nowhere looks
#   exactly like a theme that does not work. The prefs have the same property:
#   miss one and the failure is silent, or a screen full of black icons.
#
# Prints one `ok` / `FAIL` line per case, so bin/check.sh can forward the output
# as one of its own checks. Exits non-zero if any case failed.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 1

FAILED=0
pass() { printf '  ok    %s\n' "$1"; }
fail() { printf '  FAIL  %s\n' "$1"; FAILED=1; }

BASE="$(mktemp -d)"
case "$BASE" in
  /tmp/*|/var/tmp/*) ;;
  *) printf 'refusing to run outside a temp directory: %s\n' "$BASE" >&2; exit 1 ;;
esac
trap 'rm -rf "$BASE"' EXIT

# make_home <name> <profiles.ini contents> [profile-dir...] -> path
make_home() {
  local name="$1" ini="$2" home dir
  shift 2
  home="$BASE/$name"
  mkdir -p "$home"
  printf '%s' "$ini" > "$home/profiles.ini"
  for dir in "$@"; do mkdir -p "$home/$dir"; done
  printf '%s\n' "$home"
}

# selects <name> <expected-profile-dir> <profiles.ini> [profile-dir...]
selects() {
  local name="$1" expect="$2" ini="$3" home got
  shift 3
  home="$(make_home "$name" "$ini" "$@")"
  got="$(THUNDERBIRD_HOME="$home" ./bin/install.sh 2>/dev/null | sed -n 's/^Profile: //p')"
  THUNDERBIRD_HOME="$home" ./bin/uninstall.sh >/dev/null 2>&1
  if [ "$got" = "$home/$expect" ]; then
    pass "profile selection: $name -> $expect"
  else
    got="${got#"$home/"}"
    fail "profile selection: $name expected $expect, got ${got:-nothing}"
  fi
}

# ---------------------------------------------------------------------------
# The layout that motivated the fix: the [Install...] section and the legacy
# flag name different profiles.
selects install-section-wins 0zlva32b.default-release \
  '[Profile1]
Name=default
IsRelative=1
Path=wmvy4z8h.default
Default=1

[InstallFDC34C9F024745EB]
Default=0zlva32b.default-release
Locked=1

[Profile0]
Name=default-release
IsRelative=1
Path=0zlva32b.default-release

[General]
StartWithLastProfile=1
Version=2
' wmvy4z8h.default 0zlva32b.default-release

selects legacy-default-flag bbb.other \
  '[Profile0]
Path=aaa.first

[Profile1]
Path=bbb.other
Default=1
' aaa.first bbb.other

selects first-profile-fallback aaa.first \
  '[Profile0]
Path=aaa.first

[Profile1]
Path=bbb.other
' aaa.first bbb.other

# Key order inside a section is not guaranteed by the file format.
selects default-before-path bbb.other \
  '[Profile0]
Path=aaa.first

[Profile1]
Default=1
Path=bbb.other
' aaa.first bbb.other

# ---------------------------------------------------------------------------
# Full install/uninstall round trip: all three prefs land, a second run does not
# duplicate them, and uninstall leaves nothing behind.
HOME_DIR="$(make_home round-trip '[Profile0]
Path=aaa.first
' aaa.first)"
PROFILE_DIR="$HOME_DIR/aaa.first"
USERJS="$PROFILE_DIR/user.js"

THUNDERBIRD_HOME="$HOME_DIR" ./bin/install.sh >/dev/null 2>&1
THUNDERBIRD_HOME="$HOME_DIR" ./bin/install.sh >/dev/null 2>&1

for pref in toolkit.legacyUserProfileCustomizations.stylesheets \
            svg.context-properties.content.enabled \
            mailnews.start_page.url; do
  count="$(grep -cF "$pref" "$USERJS" 2>/dev/null)"
  if [ "${count:-0}" = 1 ]; then
    pass "pref written exactly once: $pref"
  else
    fail "pref written ${count:-0} time(s), expected 1: $pref"
  fi
done

if [ -L "$PROFILE_DIR/chrome" ] && [ "$(readlink -f "$PROFILE_DIR/chrome")" = "$ROOT/src" ]; then
  pass "chrome/ links to the working tree"
else
  fail "chrome/ is not a link to $ROOT/src"
fi

THUNDERBIRD_HOME="$HOME_DIR" ./bin/uninstall.sh >/dev/null 2>&1

if [ -e "$PROFILE_DIR/chrome" ] || [ -L "$PROFILE_DIR/chrome" ]; then
  fail "chrome/ survived uninstall"
else
  pass "uninstall removes chrome/"
fi

left="$(grep -cE 'Nightjar|legacyUserProfileCustomizations|svg\.context-properties|mailnews\.start_page' \
        "$USERJS" 2>/dev/null)"
if [ "${left:-0}" = 0 ]; then
  pass "uninstall removes all three prefs"
else
  fail "${left} pref line(s) left in user.js after uninstall"
fi

# A real chrome/ directory belongs to the user, not to this project.
REAL="$(make_home real-chrome '[Profile0]
Path=aaa.first
' aaa.first/chrome)"
printf 'keep me\n' > "$REAL/aaa.first/chrome/userChrome.css"
if THUNDERBIRD_HOME="$REAL" ./bin/install.sh >/dev/null 2>&1; then
  fail "install.sh overwrote a real chrome/ directory"
elif [ -f "$REAL/aaa.first/chrome/userChrome.css" ]; then
  pass "install.sh refuses a real chrome/ directory"
else
  fail "a real chrome/ directory lost its contents"
fi

exit "$FAILED"
