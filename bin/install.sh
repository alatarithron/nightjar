#!/usr/bin/env bash
# Links Nightjar into a Thunderbird profile and enables user stylesheets.
#
#   bin/install.sh [profile-dir]
#
# Without an argument the profile is read from profiles.ini. The link points at
# the working tree, so edits are live after a Thunderbird restart.
# Idempotent, and never overwrites a real chrome/ directory.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$ROOT/src"

# Prefs the theme needs, as "name|value|why". The first two are required:
# without the first, Thunderbird ignores the profile's user stylesheets
# entirely; without the second, the replaced icons load but render as solid
# black silhouettes.
#
# The third is a substitution rather than a requirement. Thunderbird's default
# start page is fetched from live.thunderbird.net on every launch, carrying the
# version, channel, OS and build ID with it. Pointing the pref at the local page
# themes that surface and stops the request. Values are written verbatim, so a
# string pref supplies its own quotes.
PREFS=(
  'toolkit.legacyUserProfileCustomizations.stylesheets|true|load userChrome.css / userContent.css from the profile'
  'svg.context-properties.content.enabled|true|let the replaced icons take their color from the theme (decision 005)'
  "mailnews.start_page.url|\"file://$SRC/start/index.html\"|show the Nightjar start page instead of fetching Thunderbird's remote one"
)

die() { printf 'error: %s\n' "$1" >&2; exit 1; }

find_profile() {
  local base ini path
  base="${THUNDERBIRD_HOME:-$HOME/.thunderbird}"
  ini="$base/profiles.ini"
  [ -f "$ini" ] || die "profiles.ini not found at $ini"

  # Which profile Thunderbird actually opens is named by the [Install...]
  # section for this installation. The legacy Default=1 flag on a [Profile...]
  # section is only the fallback, and the two routinely disagree — reading just
  # the flag links the theme into a profile that never runs, which looks exactly
  # like the theme being broken.
  path="$(awk -F= '
    function flush() {
      if (in_profile && p != "") {
        if (first == "") first = p
        if (is_default) legacy = p
      }
    }
    /^[[:space:]]*\[/ {
      flush()
      in_profile = ($0 ~ /^\[Profile/); in_install = ($0 ~ /^\[Install/)
      p = ""; is_default = 0
      next
    }
    in_profile && $1 == "Path"                 { p = $2 }
    in_profile && $1 == "Default" && $2 == "1" { is_default = 1 }
    in_install && $1 == "Default"              { chosen = $2 }
    END {
      flush()
      print (chosen != "" ? chosen : (legacy != "" ? legacy : first))
    }
  ' "$ini")"

  [ -n "$path" ] || return 0
  case "$path" in /*) printf '%s\n' "$path" ;; *) printf '%s\n' "$base/$path" ;; esac
}

PROFILE="${1:-$(find_profile)}"
[ -n "$PROFILE" ] || die "could not determine a Thunderbird profile"
[ -d "$PROFILE" ] || die "profile directory does not exist: $PROFILE"

CHROME="$PROFILE/chrome"

if [ -L "$CHROME" ]; then
  current="$(readlink -f "$CHROME")"
  if [ "$current" = "$SRC" ]; then
    echo "already linked: $CHROME -> $SRC"
  else
    die "$CHROME is a symlink to $current — remove it first"
  fi
elif [ -e "$CHROME" ]; then
  die "$CHROME already exists as a real directory — back it up and remove it first"
else
  ln -s "$SRC" "$CHROME"
  echo "linked:  $CHROME -> $SRC"
fi

USERJS="$PROFILE/user.js"
for entry in "${PREFS[@]}"; do
  IFS='|' read -r name value why <<< "$entry"
  if [ -f "$USERJS" ] && grep -Fq "$name" "$USERJS"; then
    echo "pref already present: $name"
  else
    printf '\n// Nightjar: %s\nuser_pref("%s", %s);\n' "$why" "$name" "$value" >> "$USERJS"
    echo "pref added:  $name"
  fi
done

cat <<EOF

Profile: $PROFILE

Next:
  1. Restart Thunderbird (fully quit, not just close the window).
  2. Verify at about:support -> Profile Directory.

Editing: change any file under src/ and restart Thunderbird. For live inspection
of the chrome DOM, enable the Browser Toolbox — see docs/development.md.
EOF
