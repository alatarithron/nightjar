# Architectural decision: IBM Plex, bundled

- Status: accepted
- Date: 2026-08-09
- Supersedes: none
- Superseded by: none

## Context

The project's one-line description is "a dark theme for Thunderbird that
changes more than the color", and typography is the second of the three things
it claims to change. Until now the interface used whatever sans the desktop
provided — on the development machine that resolved to Adwaita Sans, and
`src/fonts/` did not exist while `layers/typography.css` carried a commented-out
`@font-face` block waiting for a decision.

Four open-licensed variable candidates were rendered as specimens at UI sizes on
the theme's own background, and measured rather than judged by eye:

| Candidate | Size to match cap height | Line width at that size |
| --- | --- | --- |
| Inter | 17px | 429px |
| IBM Plex Sans | 18px | 427px |
| Public Sans | 17px | 404px |
| Atkinson Hyperlegible Next | 19px | 446px |

Two measurements mattered and neither was obvious. Adwaita Sans is a fork of
Inter with **identical metrics** — cap 147, x-height 110, 429px on the test
string — so bundling Inter would have changed nothing visible, making it a
reproducibility change rather than a design one. And comparing at equal point
size is misleading: it made Atkinson look like the most compact of the four,
when at equal cap height it is the widest.

## Decision

**IBM Plex Sans** for the interface, **IBM Plex Mono** for `pre` and `code`,
both bundled as WOFF2 in `src/fonts/` and declared in
`layers/typography.css`.

Plex was chosen for having a voice — a distinct `a`, `g` and `y`, a faintly
engineered tone that suits the rest of the theme — at no cost in layout: 427px
against the outgoing 429px, so nothing moves. Its mono is a designed companion
rather than an unrelated face.

Bundling, rather than naming a family and hoping: the theme then looks the same
on any machine and does not change under the user when a system font is
updated. It costs 308 KB of binaries in a repository that had none, and an OFL
notice.

The type scale moves up one step — 13, 14, 15, 17 at a 16px root, from 12, 13,
14, 16. That is a consequence of the typeface, not a change of mind: Plex's cap
height is 141 units against Adwaita's 147, so holding the old scale would have
shrunk the whole interface by about 6%.

Three details were read out of the font rather than assumed:

- `wght` runs **100–700**, not 100–900. `@font-face` declares the real range, so
  the browser refuses out-of-range weights instead of synthesizing them.
- Plex Mono ships no variable cut, so its two used weights are two files rather
  than one synthesized pair.
- `font-display: swap`, not `block`. The files are local so the swap is
  invisible, and a missing file degrades to a system family instead of three
  seconds of invisible text.

## Alternatives considered

### Inter

- Advantages: the reference UI face; already effectively in use through Adwaita
  Sans, so zero risk.
- Disadvantages: metrically identical to what was already on screen, so it
  changes nothing except where the file comes from.
- Reason not chosen: it makes the roadmap item true without making the theme
  different.

### Atkinson Hyperlegible Next

- Advantages: the strongest functional case. Slashed zero, unmistakable `I`/`l`/
  `1`, wide apertures, drawn for low vision — worth real money in a client full
  of addresses, document numbers and amounts.
- Disadvantages: 4% wider at equal cap height, which is spent in the message
  list, the narrowest column in the window.
- Reason not chosen: the width cost lands exactly where space is tightest. It
  remains the right answer if legibility ever outranks density.

### Public Sans

- Advantages: narrowest of the four, warmer, less ubiquitous than Inter.
- Disadvantages: x-height ratio 0.71 against Plex's 0.74, so it reads smaller
  and would want a size bump that gives the width back.
- Reason not chosen: no clear win once the size is equalized.

### Name the family, bundle nothing

- Advantages: no binaries in the repository.
- Disadvantages: none of the candidates is installed on the machine, so the
  choice would resolve to a fallback and the theme would look different
  wherever it is installed.
- Reason not chosen: it is not really the choice being made.

## Consequences

### Positive

- The interface has a typeface of its own, verified to be the bundled file
  rather than a fallback.
- The theme no longer depends on what the desktop has installed, which is one
  fewer way for it to look different on another machine.

### Negative or trade-offs

- 308 KB of binaries enter a repository that previously carried only text and
  SVG. They are unmodified upstream builds, so they can be re-derived, but they
  are opaque in a diff.
- The interface no longer follows the desktop font. That is the point, and it
  is also a loss for anyone who had set a system font deliberately.
- **The bundled mono reaches only chrome.** `layers/typography.css` is imported
  by `userChrome.css` alone, so `--nj-font-mono` applies to `pre` and `code` in
  *chrome* documents. The message source view is a content document and keeps
  the platform default.

  This is not a defect to fix in CSS, and an earlier draft of this record was
  wrong to frame it as one. Thunderbird already exposes the setting:
  *Settings → Language & Fonts → Advanced…* writes `font.name.monospace.*`,
  which is what content documents read. Installing IBM Plex system-wide
  (`ttf-ibm-plex` in Arch's `extra`) and choosing it there is the supported
  route, it covers message bodies as well as the source view, and it leaves the
  choice with the reader — which is the same reason this theme does not force
  fonts onto mail. The bundled files stay chrome-only on purpose.

## Verification

The bundled Sans is confirmed in a running Thunderbird by measurement, not by
eye — necessary, because the fallback at the new larger size would look similar.
A sender line in the message list, 26 characters of mixed case and punctuation:

| | Ink width |
| --- | --- |
| Before, Adwaita Sans at 14px | 191px |
| After | 194px (+1.6%) |
| Predicted, Adwaita Sans at 15px | +7.0% |
| Predicted, Plex Sans at 15px | +1.0% |

The measured change matches the bundled font and rules out the fallback.

`bin/check.sh` gained a check with both directions: every `@font-face` source
resolves to a file that exists, and every file in `src/fonts/` is referenced by
an `@font-face`. Confirmed to bite by removing a font and by adding an orphan,
reverting each.

The mono is wired and its files load through the identical mechanism, but it was
**not** confirmed on screen: the document that would show it, the message source
view, is outside the sheet's reach, as above. Confirmed by opening the source of
a synthetic `.eml` — it renders in the platform's monospace, not Plex.

`bin/check.sh`: all 16 checks pass.

## References

- `src/layers/typography.css`, `src/fonts/`, `NOTICE`.
- [004 — icons are inlined as data URIs](004-icons-as-data-uris.md) — why
  relative paths fail there and work here.
- [010 — content documents get the token layer too](010-content-documents-get-the-token-layer.md)
  — the chrome/content split that limits the mono's reach.
