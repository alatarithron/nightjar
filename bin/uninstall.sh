#!/usr/bin/env bash
# Removes the Nightjar link from a Thunderbird profile.
#
#   bin/uninstall.sh [profile-dir]
#
# Only removes a symlink that points at this working tree, and only removes the
# pref lines this project added. A real chrome/ directory is never touched.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$ROOT/src"

die() { printf 'error: %s\n' "$1" >&2; exit 1; }

PROFILE="${1:-}"
if [ -z "$PROFILE" ]; then
  base="${THUNDERBIRD_HOME:-$HOME/.thunderbird}"
  for candidate in "$base"/*/chrome; do
    if [ -L "$candidate" ] && [ "$(readlink -f "$candidate")" = "$SRC" ]; then
      PROFILE="$(dirname "$candidate")"
      break
    fi
  done
fi
[ -n "$PROFILE" ] || die "no profile found with a Nightjar link"

CHROME="$PROFILE/chrome"
if [ -L "$CHROME" ] && [ "$(readlink -f "$CHROME")" = "$SRC" ]; then
  rm "$CHROME"
  echo "unlinked: $CHROME"
else
  echo "nothing to unlink at $CHROME"
fi

USERJS="$PROFILE/user.js"
if [ -f "$USERJS" ] && grep -Fq 'Nightjar' "$USERJS"; then
  tmp="$(mktemp)"
  grep -v -e '// Nightjar: ' \
          -e 'toolkit.legacyUserProfileCustomizations.stylesheets' \
          -e 'svg.context-properties.content.enabled' \
          -e 'mailnews.start_page.url' "$USERJS" > "$tmp"
  mv "$tmp" "$USERJS"
  echo "prefs removed from $USERJS"
fi

echo "Restart Thunderbird to apply."
