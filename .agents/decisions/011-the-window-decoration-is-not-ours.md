# Architectural decision: the window decoration is not ours, so it is met halfway

- Status: accepted
- Date: 2026-08-09
- Supersedes: none
- Superseded by: none

## Context

Decision 009 took the main window's top band off the desktop's color. The
compose window still wears one, because its titlebar is not the application's
to draw:

| Window | Reported by the window manager |
| --- | --- |
| Main | `_MOTIF_WM_HINTS` decorations `0` — no frame |
| Compose | `_NET_FRAME_EXTENTS = 0, 0, 28, 0` — 28px on top |

The asymmetry has a single cause. `CustomTitlebar`, which sets the
`customtitlebar` attribute that makes Gecko ask for client-side decoration,
lives in `messenger.js` and is loaded by `messenger.xhtml` alone.
`mail.tabs.drawInTitlebar` governs that window and nothing else. Every secondary
window is decorated by the window manager, in Breeze Dark's `rgb(39, 44, 49)`,
directly above Nightjar's `rgb(14, 19, 26)`.

A user stylesheet cannot change this. CSS sets no attributes, runs no script,
and the decoration is negotiated when the window is created. This is a wall, not
a gap — the same kind as the per-document CSP in decision 008.

## Decision

The theme does not try. It ships the other half of the fix as an **optional,
documented, desktop-specific** artifact:

- `contrib/kde/Nightjar.colors` — a KDE color scheme carrying `[WM]` colors
  only, drawn from the palette.
- `contrib/kde/nightjar.kwinrule` — the rule itself, importable through the
  Window Rules page so it merges with rules the user already has.
- `docs/kde.md` — how to install both, and how to undo them.

The rule matches the window class and nothing else, so it covers every
Thunderbird window rather than compose alone. On the main window it is a no-op:
Thunderbird draws that titlebar itself and the window manager draws nothing to
recolor. Verified on the OpenPGP key manager as well as compose — a second
window, opened without key injection through `thunderbird -keymanager`, whose
titlebar reads `rgb(14, 19, 26)`.

Nothing in `src/` changes and nothing is applied automatically. Running
`bin/install.sh` does not touch the desktop.

`contrib/` is a new directory, and its meaning is exactly this: things that make
Nightjar look right which are **not** the theme, cannot be, and belong to the
desktop instead. That boundary is the decision. The alternative readings — that
such things are out of scope entirely, or that the installer should apply them —
are both worse, for opposite reasons.

The scheme repeats four palette colors in KDE's decimal-triple format, because a
window manager cannot read CSS. That makes it the only duplicated color in the
project, so `bin/check.sh` gained a check that every `[WM]` triple converts to a
hex that exists in `tokens/palette.css`.

## Alternatives considered

### Remove the decoration with `noborder`

- Advantages: the 28 pixels go away entirely rather than being recolored.
- Disadvantages: Thunderbird draws no replacement on the compose window, so
  there is no close button, no minimize, and no drag area. Closing becomes
  Ctrl+W and moving becomes Meta+drag.
- Reason not chosen: it trades a cosmetic seam for lost function. Offered in
  `docs/kde.md` as a variant, not as the recipe.

### Set `customtitlebar` on the compose window from outside

- Advantages: would give compose the same client-side titlebar as the main
  window — the actually correct fix.
- Disadvantages: needs code running in the compose window, which means an
  autoconfig script or an add-on. Decision 001 chose a user stylesheet
  specifically to avoid that, and the machinery `customtitlebar` drives is not
  even loaded in that window.
- Reason not chosen: out of proportion, and it reverses decision 001 for one
  strip of chrome.

### Leave it, document nothing

- Advantages: keeps the project to CSS and one desktop-agnostic story.
- Disadvantages: the seam is real and visible every time a message is written,
  and "the theme cannot do this" is worth writing down once whether or not a
  workaround ships with it.
- Reason not chosen: the finding is the valuable part; the file is small.

### Ship it as `bin/install-kde.sh`

- Advantages: one command.
- Disadvantages: `kwinrulesrc` is a shared, hand-edited file with a `count`/
  `rules` index. A script that appends to it correctly, idempotently, and
  without clobbering rules the user already has is real work, and getting it
  wrong damages desktop configuration that has nothing to do with this project.
- Reason not chosen: the risk is on the wrong side. Shipping the rule as an
  importable `.kwinrule` gets the same convenience without the merge problem —
  KWin's own importer does the merging.

## Consequences

### Positive

- The compose window reads as one surface: titlebar `rgb(14, 19, 26)`,
  continuous with the window, buttons and drag intact.
- The project now has a stated place for desktop-level work, so the next
  question of this shape does not have to be re-litigated.
- The limit itself is documented, which is worth more than the workaround: it
  stops the next attempt to solve a window-manager problem in CSS.

### Negative or trade-offs

- `contrib/` is KDE-only, and will not help anyone on GNOME or a tiling WM. It
  is labelled as such rather than generalized on speculation.
- The rule matches the window class `org.mozilla.Thunderbird`, which is
  packaging-dependent and will need adjusting on some systems. Narrowing it to
  one window means adding a caption condition, and captions are
  locale-dependent.
- One color is now written twice, in two formats. The new check bounds the
  drift; it does not remove the duplication.

## Verification

Rendered on Wayland with `spectacle`, sampling the same pixel column through the
titlebar into the client area:

| y | Before | After |
| --- | --- | --- |
| 145 | `rgb(41, 44, 48)` | `rgb(14, 19, 26)` |
| 156 | `rgb(41, 44, 48)` | `rgb(14, 19, 26)` |
| 168 | `rgb(41, 44, 48)` | `rgb(14, 19, 26)` |
| 172 (client) | `rgb(14, 19, 26)` | `rgb(14, 19, 26)` |

Three earlier attempts failed silently and are the reason `docs/kde.md` has a
section on them:

1. Matching `WM_WINDOW_ROLE=Msgcompose`. Correct on X11, and the property does
   not exist on Wayland, which is how Thunderbird actually runs here.
2. Matching `wmclass=thunderbird`. KWin reports the class as
   `org.mozilla.Thunderbird`, and substring matching is case-sensitive, so the
   lowercase name does not match even as a substring.
3. Verifying over XWayland. `import -window root` captures nothing there,
   because the decoration is drawn on the Wayland side.

The second was isolated by bisecting with `noborder`: it did not apply either,
which proved the failure was in matching rather than in the color, and led to
asking KWin directly through a scripting dump.

`bin/check.sh`: all 15 checks pass. The new one was confirmed to bite by moving
`activeBackground` one step off the palette and reverting it.

## References

- `contrib/kde/Nightjar.colors`, `contrib/kde/nightjar.kwinrule`, `docs/kde.md`.
- [001 — user stylesheet instead of a static theme add-on](001-user-stylesheet-over-static-theme.md)
- [008 — how far icons reach](008-icon-reach-and-the-add-on-question.md) — the
  other documented wall.
- [009 — the top band belongs to the theme](009-top-band-belongs-to-the-theme.md)
  — the same seam, on the window that could be fixed in CSS.
