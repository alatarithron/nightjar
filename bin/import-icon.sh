#!/usr/bin/env bash
# Imports one icon from Bootstrap Icons into src/icons/.
#
#   bin/import-icon.sh [--single] <bootstrap-name> <icon-token> [size]
#
#   bin/import-icon.sh trash trash                -> src/icons/trash.svg
#   bin/import-icon.sh archive archive            -> src/icons/archive.svg
#
# <bootstrap-name>  the icon's base name in Bootstrap Icons, without the `-fill`
#                   suffix. Browse them at https://icons.getbootstrap.com/.
# <icon-token>      the Thunderbird property to replace, without the --icon-
#                   prefix. It must exist in docs/thunderbird-tokens.md;
#                   inventing one is a silent no-op at runtime, so it is
#                   refused here.
# [size]            override the pixel size. Normally inferred from the token
#                   suffix, which Thunderbird's own artwork defines as:
#                   -xs 12, -sm 16, -md 20, -lg 24, no suffix 16.
# --single          ignore the `-fill` twin and ship one tone. Use it when the
#                   twin is a solid silhouette of the whole glyph — `calendar`
#                   and `chat` are both like this — because then the 20% wash
#                   fills the icon's entire area and it reads as a grey block
#                   instead of a shape. The two-tone port is for artwork whose
#                   fill is an *interior*, the way the folder icons are.
#
# Bootstrap ships single-tone filled artwork, and Thunderbird's own set is two
# filled tones. The port assembles the pair Thunderbird expects:
#
#     <name>-fill.svg  ->  <g fill="context-fill">   interior wash, 20% alpha
#     <name>.svg       ->  <g fill="context-stroke"> the readable shape
#
# The wash is drawn first so the outline sits on top. Both tones derive from the
# context paint, so the icon follows hover, selection and per-folder colors.
# Bootstrap has no strokes, so there is no stroke width to normalize: the shapes
# are filled outlines on a native 16 grid, exactly like Thunderbird's compact
# set. An icon without a `-fill` twin ships single-tone, which is legible on its
# own because context-stroke arrives at full alpha.
# See .agents/decisions/007-bootstrap-icon-set.md.
#
# Requires network access: this is an authoring step, not part of the build.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 1

API="https://api.iconify.design/bi"
REFERENCE="docs/thunderbird-tokens.md"

die() { printf 'error: %s\n' "$1" >&2; exit 1; }

SINGLE=0
if [ "${1:-}" = "--single" ]; then SINGLE=1; shift; fi

[ $# -ge 2 ] || die "usage: bin/import-icon.sh [--single] <bootstrap-name> <icon-token> [size]"
NAME="$1"
TOKEN="$2"
SIZE="${3:-}"

command -v curl >/dev/null 2>&1 || die "curl is required"
command -v python3 >/dev/null 2>&1 || die "python3 is required"

# The project's central rule, enforced where the mistake is made rather than
# three steps later in bin/check.sh.
[ -f "$REFERENCE" ] || die "$REFERENCE is missing — run bin/dump-tb-reference.sh"
grep -qx -- "--icon-$TOKEN" "$REFERENCE" \
  || die "--icon-$TOKEN is not declared by Thunderbird (checked $REFERENCE)"

case "$NAME" in
  *-fill) die "pass the base name, not the -fill twin: ${NAME%-fill}" ;;
esac

if [ -z "$SIZE" ]; then
  case "$TOKEN" in
    *-xs) SIZE=12 ;;
    *-md) SIZE=20 ;;
    *-lg) SIZE=24 ;;
    *)    SIZE=16 ;;
  esac
fi

OUT="src/icons/$TOKEN.svg"
[ -f "$OUT" ] && action=replaced || action=created

outline="$(mktemp)"
wash="$(mktemp)"
trap 'rm -f "$outline" "$wash"' EXIT

fetch() {
  local url="$1" dest="$2" status
  status="$(curl -sS --max-time 30 -w '%{http_code}' -o "$dest" "$url" || true)"
  [ "$status" = 200 ] || return 1
  head -c 4 "$dest" | grep -q '<svg' || die "$url did not return an SVG"
}

fetch "$API/$NAME.svg" "$outline" \
  || die "$NAME not found in Bootstrap Icons — check https://icons.getbootstrap.com/"

# The wash is optional: a fair number of Bootstrap icons have no filled twin,
# and --single declines the one that exists.
if [ "$SINGLE" = "1" ] || ! fetch "$API/$NAME-fill.svg" "$wash"; then
  : > "$wash"
fi

python3 - "$outline" "$wash" "$OUT" "$SIZE" "$NAME" <<'PY'
import re, sys

outline_path, wash_path, out, size, name = sys.argv[1:6]


def inner(path):
    """The markup between <svg> and </svg>, or None for an absent file."""
    raw = open(path, encoding="utf-8").read().strip()
    if not raw:
        return None
    match = re.search(r"<svg\b([^>]*)>(.*)</svg>\s*$", raw, re.S)
    if not match:
        sys.exit(f"error: {path} is not a single <svg> element")
    attrs, body = match.group(1), match.group(2).strip()
    box = re.search(r'viewBox="([^"]*)"', attrs)
    if not box or box.group(1).split() != ["0", "0", "16", "16"]:
        sys.exit(f"error: {path} is not on Bootstrap's 16 grid "
                 f"(viewBox {box.group(1) if box else 'missing'})")
    return body


shape = inner(outline_path)
if shape is None:
    sys.exit(f"error: {name} returned an empty outline")
wash = inner(wash_path)

layers = []
if wash is not None:
    # Drawn first, so the full-alpha outline sits on top of the 20% wash.
    layers.append(f'<g fill="context-fill">{wash.replace("currentColor", "context-fill")}</g>')
layers.append(f'<g fill="context-stroke">{shape.replace("currentColor", "context-stroke")}</g>')

credit = (f'<!-- {name} from Bootstrap Icons, MIT. Ported: currentColor -> '
          f'context-stroke for the shape'
          + (', context-fill for the wash' if wash is not None else '')
          + '. See NOTICE. -->')

svg = (f'<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}" '
       f'viewBox="0 0 16 16">\n  {credit}\n  ' + "\n  ".join(layers) + "\n</svg>\n")

open(out, "w", encoding="utf-8").write(svg)
print("  two tones" if wash is not None else "  single tone")
PY

echo "$action $OUT (${SIZE}px, --icon-$TOKEN)"
./bin/build-icons.sh
