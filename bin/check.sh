#!/usr/bin/env bash
# Nightjar checks. Runs identically on a laptop and in GitHub Actions.
#
#   bin/check.sh
#
# No linter, no Node, no network. Every check below enforces an invariant from
# .agents/PROJECT_MEMORY.md that a generic CSS linter cannot see, because the
# rules are about Thunderbird's internals rather than about CSS syntax.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 1

REFERENCE="docs/thunderbird-tokens.md"
FAILED=0
CHECKS=0

pass() { printf '  ok    %s\n' "$1"; }
fail() { printf '  FAIL  %s\n' "$1"; FAILED=1; }
skip() { printf '  skip  %s\n' "$1"; }
head_() { CHECKS=$((CHECKS + 1)); printf '\n[%d] %s\n' "$CHECKS" "$1"; }

css_files() { find src -name '*.css' | sort; }

# Removes /* … */ from a stylesheet, including comments spanning several lines,
# and prints one output line per input line so that reported line numbers still
# match the file.
#
# Every content check below reads a stylesheet through this. Without it the
# checks see prose: a comment explaining why a color was wrong trips the
# raw-color check, a comment naming an id that was *removed* trips the selector
# check, and a commented-out @font-face demands a file that was deliberately not
# shipped. All three happened before this existed, and each was worked around by
# rewording the comment — which is the wrong direction, because it lets the
# checks dictate how the code is explained.
strip_comments() {
  awk '
    BEGIN { inside = 0 }
    {
      line = $0; out = ""
      while (length(line) > 0) {
        if (inside) {
          p = index(line, "*/")
          if (p == 0) { line = "" } else { line = substr(line, p + 2); inside = 0 }
        } else {
          p = index(line, "/*")
          if (p == 0) { out = out line; line = "" }
          else { out = out substr(line, 1, p - 1); line = substr(line, p + 2); inside = 1 }
        }
      }
      print out
    }
  ' "$1"
}

# Splits stylesheets into one declaration per line, so checks do not depend on
# how declarations happen to be wrapped in the source.
declarations() { strip_comments "$1" | tr ';{}' '\n'; }

# Custom properties *declared* in a file. The trailing colon is what separates a
# declaration from a `var(--x)` reference, which is followed by ')' or ','.
declared_tokens() {
  declarations "$1" | grep -oE '(^|[[:space:]])--[A-Za-z0-9-]+[[:space:]]*:' | tr -d ' \t:'
}

# Every custom property the theme declares, across every stylesheet. Callers
# split it: '--nj-*' is the theme's own palette, everything else is an override
# of a Thunderbird token.
theme_tokens() {
  while IFS= read -r f; do declared_tokens "$f"; done < <(css_files) | sort -u
}

# Every stylesheet, comments removed, as one stream. Read once into ALL_CSS
# below: strip_comments is an awk pass per file, and the checks that search the
# whole tree would otherwise repeat it per token.
stripped_css() {
  while IFS= read -r f; do strip_comments "$f"; done < <(css_files)
}
ALL_CSS="$(stripped_css)"

# ---------------------------------------------------------------------------
head_ "Overridden tokens exist in Thunderbird"
# The main rot mode: overriding a custom property Thunderbird does not declare.
# It fails silently at runtime, so it has to fail loudly here.
if [ ! -f "$REFERENCE" ]; then
  fail "$REFERENCE is missing — run bin/dump-tb-reference.sh"
else
  known="$(grep -oE '^--[A-Za-z0-9-]+' "$REFERENCE" | sort -u)"
  declared="$(theme_tokens | grep -v '^--nj-')"
  unknown="$(comm -23 <(printf '%s\n' "$declared") <(printf '%s\n' "$known"))"
  if [ -n "$unknown" ]; then
    while IFS= read -r token; do
      [ -n "$token" ] && fail "$token is not declared by Thunderbird"
    done <<< "$unknown"
  else
    pass "$(printf '%s\n' "$declared" | grep -c .) overrides, all present in $REFERENCE"
  fi
fi

# ---------------------------------------------------------------------------
head_ "Overridden tokens are wired to something"
# The subtler half of the previous check. A token can be declared by Thunderbird
# and read by nothing — --treeitem-background-hover is one — so it passes a
# spelling check and still does nothing at runtime. That is how a working
# selector gets traded for a token that quietly drops the styling.
if [ ! -f "$REFERENCE" ]; then
  skip "$REFERENCE is missing — run bin/dump-tb-reference.sh"
else
  dead="$(awk '/^## Declared but never consumed/{found=1} found' "$REFERENCE" \
          | grep -oE '^--[A-Za-z0-9-]+' | sort -u)"
  if [ -z "$dead" ]; then
    skip "$REFERENCE predates the unconsumed section — re-run bin/dump-tb-reference.sh"
  else
    ours="$(theme_tokens | grep -v '^--nj-')"
    inert="$(comm -12 <(printf '%s\n' "$ours") <(printf '%s\n' "$dead"))"
    if [ -n "$inert" ]; then
      while IFS= read -r token; do
        [ -n "$token" ] && fail "$token is declared by Thunderbird but read by nothing — the override is inert"
      done <<< "$inert"
    else
      pass "no override targets one of the $(printf '%s\n' "$dead" | grep -c .) inert properties"
    fi
  fi
fi

# ---------------------------------------------------------------------------
head_ "Selector targets exist in Thunderbird"
# The same failure as an invented token, one layer down. A selector is what the
# theme falls back to when no token expresses a change, and an id Thunderbird
# renamed — or never had — parses fine and styles nothing.
#
# The reference section this reads is the subset of names src/ uses that were
# found in omni.ja. It is filtered by Thunderbird, not by src/, so re-running
# bin/dump-tb-reference.sh cannot make a wrong name pass.
#
# Extraction mirrors nightjar_ids/nightjar_elements in bin/dump-tb-reference.sh.
# palette.css is excluded: a hex color has the shape of an id. Comments are
# stripped first, so prose about an id that no longer exists is prose.
used_selectors() {
  { while IFS= read -r f; do
      [ "$(basename "$f")" = "palette.css" ] && continue
      strip_comments "$f" | grep -oE '#[A-Za-z][A-Za-z0-9_-]*'
    done < <(css_files)
    while IFS= read -r f; do
      strip_comments "$f" \
        | grep -oE '^[a-z][a-z0-9]*(-[a-z0-9]+)+[^A-Za-z0-9-]' \
        | grep -oE '^[a-z0-9-]+'
    done < <(css_files)
  } | sort -u
}

if [ ! -f "$REFERENCE" ]; then
  skip "$REFERENCE is missing — run bin/dump-tb-reference.sh"
else
  real="$(awk '/^## Selector targets that exist/{found=1} found' "$REFERENCE" \
          | grep -oE '^(#[A-Za-z][A-Za-z0-9_-]*|[a-z0-9]+(-[a-z0-9]+)+)$' | sort -u)"
  if [ -z "$real" ]; then
    skip "$REFERENCE predates the selector section — re-run bin/dump-tb-reference.sh"
  else
    used="$(used_selectors)"
    missing="$(comm -23 <(printf '%s\n' "$used") <(printf '%s\n' "$real"))"
    if [ -n "$missing" ]; then
      while IFS= read -r sel; do
        [ -n "$sel" ] && fail "$sel is selected by the theme and does not exist in Thunderbird"
      done <<< "$missing"
    else
      pass "$(printf '%s\n' "$used" | grep -c .) selector targets, all present in Thunderbird"
    fi
  fi
fi

# ---------------------------------------------------------------------------
head_ "Raw colors only in tokens/palette.css"
offenders="$(while IFS= read -r f; do
               [ "$f" = "src/tokens/palette.css" ] && continue
               strip_comments "$f" \
                 | grep -nE '#[0-9a-fA-F]{3,8}\b|\brgba?\(|\bhsla?\(' \
                 | sed "s|^|$f:|"
             done < <(css_files))"
if [ -n "$offenders" ]; then
  while IFS= read -r line; do fail "$line"; done <<< "$offenders"
else
  pass "no literal color values outside the palette"
fi

# ---------------------------------------------------------------------------
head_ "Competing declarations carry !important"
# User stylesheets lose the cascade to Thunderbird's author stylesheets. A
# semantic override without !important is a no-op.
missing="$(declarations src/tokens/semantic.css \
           | grep -E '(^|[[:space:]])--[A-Za-z0-9-]+[[:space:]]*:' \
           | grep -v '!important' || true)"
if [ -n "$missing" ]; then
  while IFS= read -r decl; do
    fail "semantic.css: missing !important on${decl%%:*}"
  done <<< "$missing"
else
  pass "every override in tokens/semantic.css is important"
fi

# ---------------------------------------------------------------------------
head_ "tokens/semantic.css declares custom properties and nothing else"
# userContent.css imports this file at the top level, so it lands on every
# content document — including message bodies, which the theme does not style.
# That is only safe while the file sets custom properties, which are inert until
# something reads them. One ordinary declaration in here would start painting
# other people's mail.
stray="$(declarations src/tokens/semantic.css \
         | grep -E '^[[:space:]]*[A-Za-z-]+[[:space:]]*:' \
         | grep -vE '^[[:space:]]*--' || true)"
if [ -n "$stray" ]; then
  while IFS= read -r decl; do
    [ -n "$decl" ] && fail "semantic.css: ${decl%%:*} is not a custom property"
  done <<< "$stray"
else
  pass "no ordinary declarations to leak into message bodies"
fi

# ---------------------------------------------------------------------------
head_ "Every --nj-* token is consumed"
# The project has two checks for Thunderbird tokens that do nothing and had none
# for its own. It was carrying seven: three palette entries, three steps of a
# type scale, and a line height — dead colors nobody had ever looked at, in a
# file whose whole job is to be the one place colors are decided.
own_dead=0
own_count=0
while IFS= read -r token; do
  [ -n "$token" ] || continue
  own_count=$((own_count + 1))
  uses="$(printf '%s\n' "$ALL_CSS" | grep -c "var(${token}[,)]")"
  if [ "$uses" -eq 0 ]; then
    fail "$token is declared by the theme and read by nothing"
    own_dead=1
  fi
done <<< "$(theme_tokens | grep '^--nj-')"
[ "$own_dead" -eq 0 ] && pass "$own_count own tokens, all read somewhere"

# ---------------------------------------------------------------------------
head_ "Bundled fonts exist and are reachable"
# A missing font file is the quietest failure in the project: `font-display:
# swap` means the interface simply keeps the fallback family and looks almost
# right. Nothing in the cascade reports it.
#
# The path is resolved the way Gecko resolves an @font-face src — against the
# stylesheet that declares it, not against the entry point.
font_problem=0
font_count=0
while IFS= read -r line; do
  [ -n "$line" ] || continue
  sheet="${line%%:*}"
  url="$(printf '%s' "$line" | grep -oE 'url\("[^"]+"\)' | sed -E 's/url\("([^"]+)"\)/\1/')"
  [ -n "$url" ] || continue
  case "$url" in
    data:*|http:*|https:*|chrome:*)
      fail "$sheet: @font-face src is not a bundled file: $url"; font_problem=1; continue ;;
  esac
  resolved="$(cd "$(dirname "$sheet")" && printf '%s' "$(realpath -m "$url")")"
  font_count=$((font_count + 1))
  if [ ! -f "$resolved" ]; then
    fail "$sheet: @font-face src does not exist: $url"
    font_problem=1
  fi
done <<< "$(while IFS= read -r f; do
              strip_comments "$f" | grep -n 'url("[^"]*\.woff2\?"' | sed "s|^|$f:|"
            done < <(css_files))"

# The reverse direction: a font committed and wired to nothing is dead weight
# in a repository that otherwise carries no binaries.
#
# Matched against one pre-built string rather than a `grep -q` pipeline: under
# `set -o pipefail`, grep exiting early on a match sends SIGPIPE to the left
# side, and the pipeline then reports 141 even though the match succeeded.
while IFS= read -r f; do
  [ -n "$f" ] || continue
  case "$ALL_CSS" in
    *"$(basename "$f")"*) ;;
    *)
      fail "src/fonts/$(basename "$f") is committed but no @font-face references it"
      font_problem=1 ;;
  esac
done <<< "$(find src/fonts -type f 2>/dev/null | sort)"

[ "$font_problem" -eq 0 ] && pass "$font_count @font-face sources, all present"

# ---------------------------------------------------------------------------
head_ "The KDE scheme in contrib/ uses palette colors"
# contrib/kde/Nightjar.colors repeats the palette in KDE's decimal-triple
# format, because a window manager cannot read CSS. That makes it the one place
# in the project where a color is duplicated, so it is also the one place a
# color can silently drift out of step with the palette.
SCHEME="contrib/kde/Nightjar.colors"
if [ ! -f "$SCHEME" ]; then
  skip "$SCHEME is not present"
else
  palette_hex="$(grep -oE '#[0-9a-fA-F]{6}' src/tokens/palette.css | tr 'A-F' 'a-f' | sort -u)"
  drift=0
  count=0
  while IFS='=' read -r key value; do
    case "$value" in
      *,*,*) ;;
      *) continue ;;
    esac
    r="${value%%,*}"; rest="${value#*,}"; g="${rest%%,*}"; b="${rest##*,}"
    hex="$(printf '#%02x%02x%02x' "$r" "$g" "$b" 2>/dev/null)"
    count=$((count + 1))
    if ! printf '%s\n' "$palette_hex" | grep -Fxq "$hex"; then
      fail "$SCHEME: $key is $value ($hex), which is not a color in tokens/palette.css"
      drift=1
    fi
  done <<< "$(awk '/^\[WM\]/{f=1;next} /^\[/{f=0} f' "$SCHEME")"
  [ "$drift" -eq 0 ] && pass "$count decoration colors, all drawn from the palette"
fi

# ---------------------------------------------------------------------------
head_ "Icon artwork is renderable as a chrome image"
# Chrome SVGs render as images: scripts and external references never load, and
# a hardcoded fill ignores hover and selection states.
svg_problem=0
while IFS= read -r svg; do
  [ -n "$svg" ] || continue
  if grep -qE '<script|xlink:href|href[[:space:]]*=|url\([[:space:]]*["'"'"']?https?:' "$svg"; then
    fail "$svg contains a script or external reference"; svg_problem=1
  fi
  if grep -qE '(fill|stroke)[[:space:]]*=[[:space:]]*"#' "$svg"; then
    fail "$svg hardcodes a color — use context-stroke"; svg_problem=1
  fi
  # Thunderbird delivers context-fill at 20% alpha and context-stroke at full
  # alpha, so context-stroke is the tone that carries the shape. Artwork without
  # it renders at 20% and vanishes on a dark surface.
  #
  # context-fill is deliberately not required. Not every Bootstrap icon has a
  # `-fill` twin to supply the wash, and one that ships single-tone is still
  # fully legible — see decision 007.
  if ! grep -q 'context-stroke' "$svg"; then
    fail "$svg has no context-stroke — it will not carry the theme color"; svg_problem=1
  fi
  # Bootstrap's native grid, and the reason the shapes land on whole pixels at
  # 16px. Artwork arriving on another grid is what decision 007 moved away from.
  if ! grep -q 'viewBox="0 0 16 16"' "$svg"; then
    fail "$svg is not on the 16 grid — see decision 007"; svg_problem=1
  fi
done <<< "$(find src/icons -name '*.svg' 2>/dev/null | sort)"
[ "$svg_problem" -eq 0 ] && pass "$(find src/icons -name '*.svg' 2>/dev/null | wc -l) icons clean"

# ---------------------------------------------------------------------------
head_ "Generated icon stylesheet is in sync with the artwork"
# A stale generated file is invisible: the theme keeps shipping the previous
# artwork and nothing reports it.
GENERATED="src/layers/icons.generated.css"
if [ ! -f "$GENERATED" ]; then
  fail "$GENERATED is missing — run bin/build-icons.sh"
elif ! command -v python3 >/dev/null 2>&1; then
  skip "python3 not available, cannot verify"
else
  before="$(cat "$GENERATED")"
  if ./bin/build-icons.sh >/dev/null 2>&1; then
    if [ "$before" = "$(cat "$GENERATED")" ]; then
      pass "in sync with $(find src/icons -name '*.svg' | wc -l) source icons"
    else
      printf '%s' "$before" > "$GENERATED"
      fail "$GENERATED is stale — run bin/build-icons.sh and commit the result"
    fi
  else
    fail "bin/build-icons.sh failed"
  fi
fi

# ---------------------------------------------------------------------------
head_ "Every stylesheet is reachable from an entry point"
imported="$(css_files | xargs grep -hoE '@import url\("[^"]+"\)' \
            | sed -E 's/@import url\("([^"]+)"\)/\1/' | sort -u)"
orphan=0
while IFS= read -r file; do
  case "$file" in
    src/userChrome.css|src/userContent.css) continue ;;
  esac
  rel="${file#src/}"
  if ! printf '%s\n' "$imported" | grep -Fxq "$rel"; then
    fail "$file is imported by nothing"; orphan=1
  fi
done <<< "$(css_files)"
[ "$orphan" -eq 0 ] && pass "no orphaned stylesheets"

# ---------------------------------------------------------------------------
head_ "Braces balance"
unbalanced=0
while IFS= read -r file; do
  [ -n "$file" ] || continue
  stripped="$(strip_comments "$file")"
  open=$(printf '%s' "$stripped" | tr -cd '{' | wc -c)
  close=$(printf '%s' "$stripped" | tr -cd '}' | wc -c)
  if [ "$open" -ne "$close" ]; then
    fail "$file: $open '{' vs $close '}'"; unbalanced=1
  fi
done <<< "$(css_files)"
[ "$unbalanced" -eq 0 ] && pass "all stylesheets balanced"

# ---------------------------------------------------------------------------
head_ "Whitespace hygiene"
ws=0
while IFS= read -r file; do
  [ -n "$file" ] || continue
  if grep -qE '[[:space:]]+$' "$file"; then fail "$file has trailing whitespace"; ws=1; fi
  if [ -n "$(tail -c 1 "$file")" ]; then fail "$file has no final newline"; ws=1; fi
done <<< "$(find src bin docs -type f \( -name '*.css' -o -name '*.svg' -o -name '*.sh' \) | sort)"
[ "$ws" -eq 0 ] && pass "clean"

# ---------------------------------------------------------------------------
head_ "Shell scripts"
if command -v shellcheck >/dev/null 2>&1; then
  # Pin the severity: the default threshold varies between shellcheck versions,
  # which made CI reject a script that passed locally. 'style' reports
  # everything, so a stricter runner cannot surprise us.
  if shellcheck --severity=style bin/*.sh; then pass "shellcheck clean"; else fail "shellcheck reported issues"; fi
else
  skip "shellcheck not installed"
fi

for script in bin/*.sh; do
  [ -x "$script" ] || fail "$script is not executable"
done

# ---------------------------------------------------------------------------
head_ "The checks above actually bite"
# A check that stops reading its input keeps printing ok, which is
# indistinguishable from a check that works — it has happened twice. Each case
# introduces one real violation in a copy of the tree and asserts it is
# reported. Skipped inside that copy, or it would recurse.
if [ -n "${NIGHTJAR_NESTED:-}" ]; then
  skip "nested run"
elif behaviour_out="$(./bin/test-checks.sh 2>&1)"; then
  printf '%s\n' "$behaviour_out"
else
  printf '%s\n' "$behaviour_out"
  FAILED=1
fi

# ---------------------------------------------------------------------------
head_ "Install and uninstall behave"
# The one part of this project that touches a Thunderbird profile, so the one
# part that can damage something or silently install into nowhere. The cases run
# against synthetic profiles under a throwaway THUNDERBIRD_HOME.
if [ -n "${NIGHTJAR_NESTED:-}" ]; then
  skip "nested run"
elif install_out="$(./bin/test-install.sh 2>&1)"; then
  printf '%s\n' "$install_out"
else
  printf '%s\n' "$install_out"
  FAILED=1
fi

# ---------------------------------------------------------------------------
head_ "No profile data committed"
# Thunderbird profiles hold mail and credentials. Nothing from one belongs here.
leak="$(find . -path ./.git -prune -o \
        \( -name 'prefs.js' -o -name 'logins.json' -o -name 'key4.db' \
           -o -name '*.msf' -o -name 'profiles.ini' \) -print 2>/dev/null)"
if [ -n "$leak" ]; then
  while IFS= read -r f; do fail "profile artifact in repository: $f"; done <<< "$leak"
else
  pass "no profile artifacts"
fi

# ---------------------------------------------------------------------------
printf '\n'
if [ "$FAILED" -eq 0 ]; then
  printf 'all %d checks passed\n' "$CHECKS"
else
  printf 'checks failed\n'
fi
exit "$FAILED"
