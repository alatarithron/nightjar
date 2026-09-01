# Architectural decision: how replaced icons take color

- Status: accepted
- Date: 2026-08-07
- Supersedes: none
- Superseded by: none

## Context

Decision 004 made replaced icons load by inlining them as data URIs. They now
render — but without theme color. In Thunderbird the archive folder shows a
solid black silhouette with no outline.

The cause is in Gecko's own gate on context paint,
`SVGContextPaint::IsAllowedForImageFromURI` (`layout/svg/SVGContextPaint.cpp`):

```cpp
if (StaticPrefs::svg_context_properties_content_enabled()) {
  return true;
}
// then: scheme is chrome / resource / page-icon / cached-favicon
// then: a WebExtension holding the svgContextProperties permission
// then: the principal's host is in svg.context-properties.content.allowed-domains
return false;
```

A `data:` URI matches none of those, so `context-fill` falls back to its initial
value (black) and `context-stroke` paints nothing.

This left the two requirements in tension:

- The URL must be **absolute**, or it resolves against `chrome://messenger/skin/`
  and loads nothing (decision 004).
- The URL must satisfy the gate above, or the artwork cannot read the theme
  color.

Both prefs named in that function exist in the Thunderbird 153 build on the
development machine, so this is the code path in force.

## Decision

**Option C.** Enable `svg.context-properties.content.enabled` from the profile's `user.js`,
written by `bin/install.sh` alongside the pref that loads user stylesheets.

The first branch of the gate is the only one the theme can reach: a user
stylesheet has no chrome package to register a `chrome://` URL under, and the
allowed-domains list matches on host, which `data:` does not have.

Nothing else changes. The artwork keeps both context tones, the generated
stylesheet keeps its portable `data:` URIs and stays committed, and the icons
keep reacting to hover, selection, and Thunderbird's per-folder colors.

The cost is that the pref is global. It grants context paint to every image in
the profile, including images in received HTML message bodies, where the feature
is otherwise off because it is non-standard rather than because it is unsafe: an
SVG loaded as an image runs no script, so a sender cannot read back the value it
inherits. Accepted as the smaller price against option B, which trades a working
platform feature for a permanent loss of icon behavior.

## Alternatives considered

### Option A — absolute `file://` URL

- Rejected: refuted by test. `file` is not in the allowed scheme list, and the
  image is not same-origin with a `chrome://` document.
- The artwork loads — the silhouette has the right shape — but receives no
  context paint, rendering exactly as the `data:` URI does.
- Would also have cost a machine-specific absolute path, making the generated
  icon stylesheet uncommittable.

### Option B — bake palette colors into the artwork

- Advantages: depends on no context at all, so it cannot break.
- Disadvantages: icons stop reacting. One fixed color through hover and
  selection, and no per-folder coloring. Requires reversing the artwork rule in
  `AGENTS.md` and the `context-stroke` guard in `bin/check.sh`.
- Reason not chosen: a real loss of behavior, to avoid a pref that costs
  nothing the theme cares about.

### Option D — `svg.context-properties.content.allowed-domains`

- Rejected: the check runs against the image principal's host. A `data:` URI has
  no host, so no list entry can ever match it.

### Ship as an add-on to obtain chrome:// URLs

- Advantages: satisfies the gate the way Thunderbird itself does.
- Disadvantages: reopens decision 001 — a `theme_experiment` add-on is
  version-locked with `strict_max_version` and breaks on each release.
- Reason not chosen: a pref achieves the same result at no structural cost.

## Consequences

- `bin/install.sh` now writes two prefs, and `bin/uninstall.sh` removes both.
- Installing the theme changes how SVG images render in message bodies. This is
  documented in `README.md` so it is not a surprise.
- The three icon failure appearances documented in `.agents/PROJECT_MEMORY.md`
  drop to two. A solid black icon now means the pref is missing, not that the
  approach is wrong.

## Verification

Measured in a throwaway profile (`thunderbird -no-remote -profile …`), painting
three 64×64 swatches on one element under the same
`-moz-context-properties: fill, stroke` contract Thunderbird's own consumers
use, with `chrome://` artwork as a positive control:

| Image URL | pref off | pref on |
| --- | --- | --- |
| `chrome://messenger/skin/icons/new/compact/archive.svg` | themed | themed |
| `data:` — `src/icons/archive.svg` | solid black | themed |
| `file://` — `src/icons/archive.svg` | solid black | themed |

The control renders themed in both runs, so the black results are the gate
rejecting the image rather than a fault in the test. The shape is present in
every cell, so loading was never the failing step.

## References

- [001 — user stylesheet instead of a static theme add-on](001-user-stylesheet-over-static-theme.md)
- [004 — icons are inlined as data URIs](004-icons-as-data-uris.md)
- `layout/svg/SVGContextPaint.cpp` — `SVGContextPaint::IsAllowedForImageFromURI`.
- `docs/development.md` — icon authoring rules.
