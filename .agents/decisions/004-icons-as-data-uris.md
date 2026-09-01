# Architectural decision: icons are inlined as data URIs by a generation step

- Status: accepted
- Date: 2026-08-07
- Supersedes: none
- Superseded by: none
- Amends: [002 — no CSS framework or build step](002-no-css-framework.md)

## Context

Thunderbird resolves chrome icons through `--icon-<name>` custom properties, so
replacing artwork should be a one-line override:

```css
:root { --icon-archive: url("../icons/archive.svg") !important; }
```

This produced a **blank** icon — the archive folder rendered with no glyph at
all, while every other folder kept its own.

Blank rather than unchanged meant the override was winning the cascade and the
image was failing to load. A controlled test in Gecko isolated the cause. Three
stylesheets at different depths, one declaring a custom property containing a
relative `url()`, another consuming it with `content: var(...)`:

| Case | Path valid relative to | Renders |
| --- | --- | --- |
| `url()` written directly in the consuming sheet | consuming sheet | yes |
| `var()` indirection, path valid from the **declaring** sheet | declaring sheet | **no** |
| `var()` indirection, path valid from the **consuming** sheet | consuming sheet | yes |

**Gecko resolves a relative `url()` inside a custom property against the
stylesheet that uses the `var()`, not the one that declares it.** Thunderbird
consumes `--icon-*` from `chrome://messenger/skin/*.css`, so `../icons/…`
written in the theme resolved against `chrome://messenger/skin/` and could not
load.

A separate bug was found and fixed alongside this one: the first artwork was
painted with `context-fill` only, which Thunderbird supplies at 20% alpha. Even
with a working URL it would have been nearly invisible. The two failures looked
identical from the outside, which is why both were verified by rendering rather
than by inspection.

## Decision

Icon URLs must be absolute. `bin/build-icons.sh` reads `src/icons/*.svg` and
writes `src/layers/icons.generated.css`, inlining each file as a URL-encoded
`data:image/svg+xml,…` URI. A data URI carries no base, so it resolves
identically from any consuming stylesheet.

The generated file is committed, imported from `src/userChrome.css`, and checked
for staleness by `bin/check.sh`.

## Alternatives considered

### Absolute `file://` paths written by the installer

- Advantages: keeps the artwork in standalone `.svg` files that the browser loads directly; trivial to generate.
- Disadvantages: the absolute path is machine-specific, so the generated file cannot be committed and the repository stops being self-contained; still a generation step, with none of the portability.
- Reason not chosen: same cost as data URIs, strictly less portable.

### Overriding the consuming rules instead of the custom property

- Advantages: a `url()` written in our own sheet resolves against our own sheet, so no generation is needed at all.
- Disadvantages: requires reproducing every consumer's selector. `--icon-archive` alone is consumed in six stylesheets; across 223 icon properties this is unmaintainable and maximally fragile to Thunderbird upgrades.
- Reason not chosen: trades a build step for permanent selector maintenance.

### Hand-writing the data URIs

- Advantages: no script, decision 002 stays literally intact.
- Disadvantages: artwork becomes unreadable and uneditable in place.
- Reason not chosen: it preserves a rule by destroying what the rule was protecting.

## Consequences

### Positive

- Icons work, portably, on any machine and from any consuming stylesheet.
- Artwork stays authored as normal `.svg` files under version control.
- `bin/check.sh` fails when the generated file drifts from the sources, so a
  stale build cannot ship silently.

### Negative or trade-offs

- Decision 002's "no build step" no longer holds without qualification. It is
  now: no build step for CSS; one generation step for icons, which the platform
  forces. The working tree is still what Thunderbird loads, because the
  generated file is committed and imported directly.
- `python3` is now required to regenerate icons — the project's first tool
  dependency. It is not needed to *use* the theme.
- The encoded payload is larger than the source SVG and unreadable in the
  generated file. The source of truth is `src/icons/`.
- **A data URI does not receive `-moz-context-properties`.** Observed in
  Thunderbird after this decision shipped: the icon loads, confirming the URL
  fix, but renders as a solid black silhouette with no outline — `context-fill`
  falling back to its initial value and `context-stroke` painting nothing. Gecko
  grants context properties only to images from `chrome://`, `resource://`, or
  the document's own origin, and a data URI is none of those inside a
  `chrome://` document. So this decision fixes loading and costs theming. The
  unresolved consequence is tracked in
  [005](005-icon-color-reactivity.md).

## Verification

- The Gecko behavior is reproducible with the three-case test above.
- The generated data URI was verified to render through `var()` indirection from
  a different-depth stylesheet before being adopted.
- `bin/check.sh` regenerates the file and fails if the result differs from
  what is committed.
- `src/layers/icons.css` contains no `--icon-*` declaration; all of them live in
  the generated file.

## References

- `bin/build-icons.sh`
- `src/layers/icons.generated.css`
- `docs/development.md` — icon authoring rules, including the two-tone requirement.
