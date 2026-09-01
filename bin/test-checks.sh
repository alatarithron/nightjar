#!/usr/bin/env bash
# Tests that bin/check.sh actually bites.
#
#   bin/test-checks.sh
#
# Every check in this project guards against a failure that is silent at
# runtime. That makes the checks themselves the last line, and a check that
# stops reading its input keeps printing `ok` — which is indistinguishable from
# a check that works. Two shipped that way in one afternoon: the token
# extractor matched `--[a-z0-9-]+` and so never saw a camelCase property, and
# the selector extractor demanded a brace right after an element name and so
# skipped `notification-message[type="warning"]`.
#
# So each case below introduces one real violation and asserts that check.sh
# reports it. The work happens in a copy of the tree, never in the working
# directory: a test that mutates the repository is a test nobody dares run.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 1

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

mkdir -p "$WORK/tree"
cp -r bin src docs contrib "$WORK/tree/" 2>/dev/null
cp -r "$WORK/tree" "$WORK/pristine"

FAILED=0
CASES=0

# The nested run skips the slow parts that are not under test here: this script
# itself (which would recurse) and the install regression suite.
run_checks() { (cd "$WORK/tree" && NIGHTJAR_NESTED=1 ./bin/check.sh 2>&1); }

restore() { rm -rf "$WORK/tree"; cp -r "$WORK/pristine" "$WORK/tree"; }

# expect_fail <name> <substring the report must contain>
# The mutation is applied by the caller, against $WORK/tree.
expect_fail() {
  local name="$1" want="$2" out
  CASES=$((CASES + 1))
  out="$(run_checks)"
  if printf '%s' "$out" | grep -qF -- "$want"; then
    printf '  ok    %s\n' "$name"
  else
    printf '  FAIL  %s — expected a report containing: %s\n' "$name" "$want"
    printf '%s\n' "$out" | grep -E '^\s+(FAIL|ok)' | sed 's/^/          /' | head -20
    FAILED=1
  fi
  restore
}

expect_clean() {
  local name="$1" out
  CASES=$((CASES + 1))
  out="$(run_checks)"
  if printf '%s' "$out" | grep -q 'FAIL'; then
    printf '  FAIL  %s — expected no findings, got:\n' "$name"
    printf '%s\n' "$out" | grep -E '^\s+FAIL' | sed 's/^/          /'
    FAILED=1
  else
    printf '  ok    %s\n' "$name"
  fi
  restore
}

T="$WORK/tree"

# --- the tree as committed -------------------------------------------------
expect_clean "an unmodified tree reports nothing"

# --- tokens ----------------------------------------------------------------
printf '\n:root { --totally-invented-token: var(--nj-ink-900) !important; }\n' >> "$T/src/tokens/semantic.css"
expect_fail "a token Thunderbird does not declare" "--totally-invented-token is not declared"

# Guards the lowercase-only character class. Thunderbird's calendar declares a
# camelCase --view* family; an extractor that misses it lets anything through.
printf '\n:root { --viewNotARealToken: var(--nj-ink-900) !important; }\n' >> "$T/src/tokens/semantic.css"
expect_fail "a camelCase token Thunderbird does not declare" "--viewNotARealToken is not declared"

printf '\n:root { --treeitem-background-hover: var(--nj-ink-900) !important; }\n' >> "$T/src/tokens/semantic.css"
expect_fail "a token Thunderbird declares and never reads" "read by nothing"

sed -i '0,/ !important;/s/ !important;/;/' "$T/src/tokens/semantic.css"
expect_fail "a semantic override without !important" "missing !important"

printf '\n:root { background-color: var(--nj-ink-900) !important; }\n' >> "$T/src/tokens/semantic.css"
expect_fail "an ordinary declaration in semantic.css" "is not a custom property"

printf '\n:root { --nj-never-read: #123456; }\n' >> "$T/src/tokens/palette.css"
expect_fail "an own token nothing reads" "--nj-never-read is declared by the theme"

# --- selectors -------------------------------------------------------------
printf '\n#nightjarNoSuchId { color: var(--nj-slate-100) !important; }\n' >> "$T/src/layers/chrome.css"
expect_fail "an id Thunderbird does not have" "#nightjarNoSuchId is selected by the theme"

# Guards the extractor that required a brace directly after the element name.
printf '\nnightjar-fake-element[type="x"] { color: var(--nj-slate-100) !important; }\n' >> "$T/src/layers/chrome.css"
expect_fail "a custom element behind an attribute selector" "nightjar-fake-element is selected by the theme"

# --- colors ----------------------------------------------------------------
printf '\n.nightjar-test { color: #abcdef !important; }\n' >> "$T/src/layers/chrome.css"
expect_fail "a raw color outside the palette" "src/layers/chrome.css"

sed -i 's/^activeBackground=.*/activeBackground=1,2,3/' "$T/contrib/kde/Nightjar.colors"
expect_fail "a KDE decoration color off the palette" "is not a color in tokens/palette.css"

# --- fonts -----------------------------------------------------------------
rm -f "$T/src/fonts/IBMPlexMono.woff2"
expect_fail "an @font-face pointing at a missing file" "does not exist: ../fonts/IBMPlexMono.woff2"

cp "$T/src/fonts/IBMPlexMono.woff2" "$T/src/fonts/Unreferenced.woff2"
expect_fail "a font file no @font-face references" "Unreferenced.woff2 is committed"

# --- comments are prose, not code ------------------------------------------
# All three of these were reworded in the source at some point to appease a
# check that was reading comments. They must be inert now.
cat >> "$T/src/layers/chrome.css" <<'CSS'

/* Prose mentioning #someRemovedId, a color rgb(1, 2, 3), the hex #abcdef and
 * a url("../fonts/Gone.woff2") that was never shipped. */
CSS
expect_clean "prose in a comment is not read as code"

printf '\n'
if [ "$FAILED" -eq 0 ]; then
  printf 'all %d check-behaviour cases passed\n' "$CASES"
else
  printf 'check-behaviour cases failed\n'
fi
exit "$FAILED"
