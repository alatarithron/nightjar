# Architectural decision: where the icon artwork comes from

- Status: superseded
- Date: 2026-08-08
- Supersedes: none
- Superseded by: [007 — Bootstrap Icons replace Solar](007-bootstrap-icon-set.md)

> Superseded on 2026-08-08. The fallback clause under "Alternatives considered →
> Bootstrap Icons" is the one that fired: Solar's softness at 16px did not hold
> up in daily use. The comparison table below is still the record of how the five
> candidate sets were measured, which is why this file is kept.

## Context

Decisions 004 and 005 made a replaced icon load and take theme color. What was
still missing is the artwork itself: one icon existed against 223 properties, and
drawing them by hand is not a plan.

Thunderbird's own `compact` set defines the house style, and it is specific:
`viewBox="0 0 16 16"` on a native 16px grid, two **filled** paths per icon, zero
strokes. One path is painted `context-fill`, the other `context-stroke`. Since
Thunderbird hands `fill` over at 20% alpha and `stroke` at full alpha, that is a
wash plus a readable shape.

Five candidate sets were measured against that, and rendered at a true 16px on
the Nightjar pane background with the context values substituted:

| Set | License | Grid | Paint | Two tones |
| --- | --- | --- | --- | --- |
| Bootstrap Icons | MIT | 16 native | filled | outline + `-fill` pair |
| Fluent UI System Icons | MIT | 16 native | filled | Regular + Filled pair |
| Solar | CC BY 4.0 | 24 | stroke or filled, by style | designed in, per style |
| Iconoir | MIT | 24 | stroke | none — every icon is `fill="none"` |
| Tabler / Phosphor | MIT | 24 | stroke | none / duotone weight |

## Decision

**Solar, `line-duotone` style, with the secondary tone at 50%.**

Conversion is mechanical, and both tones stay theme-reactive because both derive
from the same context paint:

```
opacity=".5"   →  stroke-opacity=".5"
currentColor   →  context-stroke
wrap in viewBox="0 0 24 24" width="16" height="16"
```

Solar is the only candidate whose two tones are *designed* rather than assembled
by us. Bootstrap requires pairing two files to fabricate a wash; Iconoir has no
wash to pair. Here the designer already decided which strokes carry the shape and
which recede, and that decision survives the port.

### Why 50% and not the platform's own 20%

The obvious port paints the secondary strokes with `context-fill`, which
Thunderbird delivers at 20% alpha. It uses both context tones and needs no rule
changes. It also does not survive the downscale: rendered at a true 16px the
secondary strokes disappear, and `archive` reads as a bare lid over an empty box.

`stroke-opacity=".5"` on `context-stroke` keeps Solar's own ratio, stays fully
reactive, and reads correctly at 16px. Verified by rendering both.

## Alternatives considered

### Bootstrap Icons

- Advantages: MIT, native 16px grid, filled paths — structurally identical to
  Thunderbird's own set, so it is the only candidate with no geometric cost. Fill
  twins exist for nearly the whole mail vocabulary.
- Disadvantages: generic. The `draft` icon is a plain pencil against
  Thunderbird's document, and there is no junk icon, so `fire` stands in.
- Reason not chosen: correctness of grid lost to the look. Recorded because it
  remains the fallback if Solar's softness proves unacceptable in daily use.

### Solar `broken` and `bold-duotone`

- `broken`: the deliberate gaps read as charm at 4x and as damage at 16px.
- `bold-duotone`: ports cleanly but is a filled style, so it lands far heavier
  than the rest of Thunderbird's chrome.

### Iconoir

- Rejected: every icon is `fill="none"`, so the theme loses the second tone
  entirely. A pure-outline language is defensible, but it is a different decision
  from the one taken here.

## Consequences

- **Attribution is required.** CC BY 4.0 is the only non-MIT license in the set.
  `NOTICE` credits 480 Design, and it must ship with any distribution of the
  artwork.
- **The artwork rule in `bin/check.sh` changes.** It required `context-fill` in
  every icon. Solar's port paints both tones from `context-stroke`, so the rule
  becomes: `context-stroke` required, `context-fill` optional. The intent —
  guarantee a full-alpha tone that carries the shape — is unchanged, and is what
  `context-stroke` provides.
- **Icons are drawn on a 24 grid and rendered at 16.** A 1.5 stroke lands at
  exactly 1.0px, so the weight is right, but the coordinates do not fall on the
  pixel grid and the edges are softer than Thunderbird's. Visible on a 1x
  display, irrelevant on HiDPI. This is the price of the style and it was paid
  knowingly.

## Verification

Seven folder-pane icons — inbox, archive, draft, sent, spam, trash, folder —
rendered at a true 16px from every candidate, on `--nj-ink-850`, with the context
values substituted as `docs/development.md` describes, then point-upscaled so the
comparison shows real antialiasing rather than a fresh render.

The 20%-versus-50% question was settled the same way, at real size rather than
zoomed: at 20% the secondary tone is not legible at 16px.

## References

- [004 — icons are inlined as data URIs](004-icons-as-data-uris.md)
- [005 — how replaced icons take color](005-icon-color-reactivity.md)
- Solar, by 480 Design — https://www.figma.com/community/file/1166831539721848736
- `NOTICE` — the attribution this decision requires.
