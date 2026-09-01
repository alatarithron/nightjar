# Architectural decision: Bootstrap Icons replace Solar

- Status: accepted
- Date: 2026-08-08
- Supersedes: [006 — where the icon artwork comes from](006-icon-source-set.md)
- Superseded by: none

## Context

Decision 006 chose Solar `line-duotone` and recorded Bootstrap Icons as the
runner-up, kept explicitly as "the fallback if Solar's softness proves
unacceptable in daily use". After using the seven folder-pane icons in the
running client, it did: Solar reads as soft and rounded beside Thunderbird's own
chrome, which is drawn as crisp filled outlines on a native 16 grid.

The geometric cost 006 accepted knowingly is the cause. Solar is drawn on a 24
grid and rendered at 16, so no coordinate lands on a pixel boundary and every
edge is antialiased. That is the "softness" the fallback clause anticipated.

## Decision

**Bootstrap Icons, outline style, with the `-fill` twin layered underneath as
the wash.**

Bootstrap is drawn on a native 16 grid with filled paths and no strokes —
structurally identical to Thunderbird's own `compact` set. The port assembles
the two tones Thunderbird's consumers expect, instead of relying on a duotone
the designer drew:

```
<name>-fill.svg  →  <g fill="context-fill">    interior wash, delivered at 20%
<name>.svg       →  <g fill="context-stroke">  the shape, delivered at full alpha
```

The wash is emitted first so the outline composites on top of it. Both tones
still derive from the same context paint, so hover, selection and the per-folder
colors keep working exactly as under 006.

This is what 006 called "pairing two files to fabricate a wash" and counted
against Bootstrap. In practice the pairing is mechanical and lives in one script,
while the grid mismatch it was traded for is visible on every icon at 1x.

### Icons without a `-fill` twin

Not every Bootstrap icon has one — `fire`, which stands in for junk, does not.
Those ship single-tone. This is legible on its own: `context-stroke` arrives at
full alpha and carries the whole shape. The wash is an enhancement, which is why
`bin/check.sh` requires `context-stroke` and treats `context-fill` as optional.

## Consequences

- **The license changes, and it gets simpler.** Bootstrap Icons is MIT, the same
  license as Nightjar's own code. CC BY 4.0's attribution obligation is gone.
  `NOTICE` still credits the set, which MIT requires, and decision 006's warning
  that attribution must travel with the artwork no longer applies.
- **There is no stroke width to normalize.** 006 introduced `STROKE=1.75` to
  thicken Solar's hairlines. Bootstrap has no strokes at all; the constant is
  removed from `bin/import-icon.sh` rather than set to a new value.
- **`viewBox` becomes `0 0 16 16`.** The importer asserts it, so an icon fetched
  from a differently-gridded set fails at import instead of rendering blurry.
  `width`/`height` still follow the token suffix: `-xs` 12, `-sm` 16, `-md` 20,
  `-lg` 24, no suffix 16. Only `-md` and `-lg` upscale, and they upscale from a
  grid that divides evenly.
- **`stroke-opacity` disappears from the artwork.** 006's 50%-not-20% finding was
  a property of Solar's duotone and does not carry over: Bootstrap's second tone
  is a separate silhouette, so it takes Thunderbird's own 20% and reads correctly,
  because a wash behind a full-alpha outline is what 20% was designed for.
- **The vocabulary is more generic.** 006's objection stands: Bootstrap's draft
  is `file-earmark-text` rather than a document with a pencil. Accepted as the
  price of matching the grid.

## Verification

The seven folder-pane icons — inbox, archive, draft, sent, spam, trash, folder —
were re-imported and rendered as a specimen sheet: each one at a true 16px on the
three surfaces it appears against (`--nj-ink-950`, `--nj-ink-850`,
`--nj-ink-800`), with the context values substituted as `docs/development.md`
describes, and again point-upscaled 4× beside the Solar icon it replaces. The
upscale is a rasterization at 16px scaled with smoothing off, so it shows the
antialiasing at working size rather than a fresh render.

Six icons resolve to two tones. `spam` (`fire`) has no `-fill` twin and ships
single-tone.

`bin/check.sh` passes all 11 checks, including the artwork rule and the
generated-stylesheet sync check.

The specimen is what the grid claim rests on, and reading it is a human
judgement: it is regenerated, not committed, because it is a review aid rather
than part of the theme.

## References

- [004 — icons are inlined as data URIs](004-icons-as-data-uris.md)
- [005 — how replaced icons take color](005-icon-color-reactivity.md)
- [006 — the superseded choice, and the comparison table that ranked the five
  candidate sets](006-icon-source-set.md)
- Bootstrap Icons — https://icons.getbootstrap.com/
- `NOTICE` — the attribution that ships with the artwork.

## Amendment, 2026-08-09: when the second tone hurts

The two-tone port assumed Bootstrap's `-fill` twin is an interior, the way it is
for the folder icons this decision was written against. It is not always. For
`calendar` and `chat` the twin is a solid silhouette of the whole glyph, so the
20% wash covers the icon's entire area and it renders as a grey block with a
faint edge — measured on the spaces rail, which delivers exactly the same 20%
fill and full-alpha stroke as the folder pane.

`bin/import-icon.sh --single` declines the twin and ships one tone. The rule is
about the artwork, not the consumer: use two tones when the fill sits *inside*
the shape, one when the fill *is* the shape.
