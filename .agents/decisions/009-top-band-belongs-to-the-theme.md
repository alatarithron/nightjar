# Architectural decision: the top band belongs to the theme, not to the desktop

- Status: accepted
- Date: 2026-08-09
- Supersedes: none
- Superseded by: none
- Amends: [003 — checks live in a script, not in a linter](003-checks-as-a-script.md)

## Context

The row carrying the global search field, the app-menu button and the window
buttons was the one surface in the main window that ignored the theme. On the
development machine it rendered `rgb(41, 44, 48)` — a warm neutral grey — while
every surface under it was cool ink (`#0e131a`, `#131922`). Sampled from a
screenshot, not estimated. It read as a strip of the desktop laid over the
application.

Three separate things paint that band, and none of them is Nightjar:

1. **The toolbox is unpainted.** `#navigation-toolbox` gets a background from
   `shared/messenger.css` only under `:root[lwtheme]`, and the built-in default
   theme is not a lightweight theme, so the rule never runs. The second rule
   that could reach it, `:root[lwtheme]:not([customtitlebar])`, is excluded
   twice over: Thunderbird draws its own window buttons, so `customtitlebar` is
   set. `--toolbar-background-color`, the obvious token, is consumed by those
   two rules and by the selected tab — so overriding it recolors the tab and
   leaves the band alone.
2. **XUL `toolbar` defaults to the desktop.** `toolkit/…/toolbar.css` sets
   `background-color: -moz-headerbar` under `@media (-moz-platform: linux)`.
   That is `#tabs-toolbar`, and it is why the grey survives even where the
   toolbox is painted.
3. **Thunderbird lightens the strip on purpose.**
   `--tabs-toolbar-background-color` is `rgba(255, 255, 255, 0.15)` in dark
   mode, with `--tabs-toolbar-box-shadow` as an inset black gradient over it.
   The pair exists to lift the tab strip out of a titlebar. Over ink it only
   greys it.

An existing rule in `layers/chrome.css` was aimed at this and never matched:

```css
#messengerWindow,
#messengerWindow > toolbox { … }      /* the toolbox is a grandchild */
```

`#messengerWindow` is the `<html>` element of `messenger.xhtml`; the toolbox is
a child of `<html:body>`. The `>` never held. The rule had been silently doing
half of what it claimed since it was written — the exact failure mode
decision 003 exists to catch, and one no check in `bin/check.sh` can see.

## Decision

The band is painted as part of the application, at `--nj-ink-900` — the app
background, the same surface as the message pane — and every seam around it is
removed:

```css
:is(#navigation-toolbox, #compose-toolbox),
:is(#navigation-toolbox, #compose-toolbox) toolbar {
  background-color: var(--nj-ink-900) !important;
  color: var(--nj-slate-100) !important;
}

unified-toolbar { border-block-end-color: transparent !important; }
```

with four tokens in `tokens/semantic.css` covering what is layered on top:

- `--tabs-toolbar-background-color: var(--nj-ink-950)` and
  `--tabs-toolbar-box-shadow: none` — the strip steps *down* instead of being
  washed lighter.
- `--toolbox-background-color` / `--toolbox-text-color` and their `-inactive`
  twins — the only consumer is the titlebar-button hover under a Breeze GTK
  theme, which inverts them into a filled pill. Left alone that pill is the
  system headerbar grey, the one color this change removes.

**ink-900, not a step of its own, is the decision.** The band is not being
restyled, it is being dissolved: at ink-900 it is the surface the message pane
is already drawn on, and the two meet with nothing between them. The folder
pane (ink-850) and the search field (ink-800) still read as raised because they
are lighter than it, so nothing is lost by giving the band no edge of its own.

That leaves the tab strip, which is why it is recessed rather than left
transparent. A selected tab is painted with `--toolbar-background-color`, also
ink-900. Against an ink-900 strip the tab would disappear; against ink-950 it
rises out of the strip and runs into the content below — the shape a tab is
supposed to have.

The compose window is included in the same rule. Its `#compose-toolbox` has the
same two `toolbar` children and the identical `-moz-headerbar` default;
`#MsgHeadersToolbar` is outside that toolbox and is untouched.

## Alternatives considered

### `--nj-ink-950` for the band

- Advantages: it is the palette's declared frame step, and the spaces rail is
  already ink-950, so the two would meet as one continuous edge when the rail
  is shown; the tab strip would need no override at all.
- Disadvantages: it replaces a grey band with a dark band. Rendered and
  compared side by side against ink-900, it still reads as a separate slab.
- Reason not chosen: the request was to stop the bar reading as separate, and
  ink-950 keeps it separate — better matched, but separate.

### Overriding `--toolbar-background-color`

- Advantages: a token, which the project prefers over a selector.
- Disadvantages: it does not reach the toolbox in this configuration — both
  consuming rules require `[lwtheme]`, one of them additionally
  `:not([customtitlebar])`. What it does reach is the selected tab.
- Reason not chosen: it is inert for this purpose. The token exists, is
  consumed, and is consumed somewhere else — a case the `bin/check.sh` token
  checks cannot detect, since both of them stop at "is it read anywhere".

### Forcing a lightweight theme

- Advantages: `:root[lwtheme]` would switch on Thunderbird's own painting path
  and `--lwt-accent-color` would then own the band.
- Disadvantages: a user stylesheet cannot set that attribute; it takes an
  installed theme add-on, which is decision 001 reversed for one strip.
- Reason not chosen: out of all proportion to the change.

### Leaving the compose window out

- Advantages: strictly smaller diff.
- Disadvantages: the defect is the same defect, in a window the user opens
  constantly, and would surface as the next bug report.
- Reason not chosen: same rule, same line, verified in the same pass.

## Consequences

### Positive

- No surface in the main window is left to the desktop theme; the result no
  longer depends on which GTK theme is installed.
- A dead selector that had been shipping since the first commit is gone, and
  `bin/check.sh` gained a check for the class of failure it belongs to:
  every `#id` and dashed custom element `src/` selects on is now verified
  against `omni.ja`, the way tokens already were. It found a second one on its
  first run — `raw-message-display` in `layers/typography.css`, an id
  Thunderbird 153 has nowhere. Removed; the `pre` selector beside it already
  covered message source, which renders as a `view-source:` document.
- The reference section behind that check lists only the names `src/` uses,
  because Thunderbird defines around eight thousand ids. It is still sound:
  the filter runs against `omni.ja`, so re-running the generator can never
  turn a wrong name green.
- The tab strip now has a deliberate relationship to the tabs in it rather than
  an inherited one.

### Negative or trade-offs

- Four of the six new declarations are tokens, but the band itself is a
  selector, and `#navigation-toolbox` / `#compose-toolbox` / `unified-toolbar`
  are element and id names Thunderbird can rename. This is the case
  `AGENTS.md` allows: no token expresses it.
- `-moz-headerbar` was doing one useful thing — following the desktop's light
  and dark switch. Nightjar is a dark theme by decision, so nothing is lost
  today; it would matter if light mode ever stopped being a non-goal.
- `:is(…) toolbar` paints `#toolbar-menubar` too, which Thunderbird deliberately
  leaves transparent. Same result here, since what shows through is the band,
  but it is one more declaration than strictly needed.

## Verification

Screenshots of a running Thunderbird 153.0, captured through XWayland and
sampled pixel by pixel, before and after:

| Point | Before | After |
| --- | --- | --- |
| Band, left of the search field | `rgb(41, 44, 48)` | `rgb(14, 19, 26)` — `--nj-ink-900` |
| Band, right of the window buttons | `rgb(41, 44, 48)` | `rgb(14, 19, 26)` |
| Message pane | `rgb(14, 19, 26)` | `rgb(14, 19, 26)` — unchanged, and now continuous with the band |
| Folder pane | `rgb(19, 25, 34)` | `rgb(19, 25, 34)` — unchanged |

The ink-950 alternative was rendered the same way and compared against ink-900
before ink-900 was chosen.

The tab strip was verified with a second tab open (the address book), which is
the only way to see it: Thunderbird collapses the strip at one tab, so the whole
band is the unified toolbar in the default session. With two tabs the strip
reads `rgb(9, 12, 17)`, an unselected tab the same, and the selected tab
`rgb(14, 19, 26)` — one step up, running into the content.

The compose window's menu bar and toolbar read `rgb(14, 19, 26)` after the
change, against the same grey before it. The titlebar-button hover pill was
captured by driving the pointer onto the minimize button: it fills with
`--toolbox-text-color` and draws the glyph in `--toolbox-background-color`, so
the Breeze inversion is confirmed on the real widget rather than only in the
source.

`bin/check.sh`: all 13 checks pass. The new selector check was confirmed to
bite on both paths it covers — it reported the real `raw-message-display` before
that rule was removed, and a deliberately invented custom element was rejected
and then reverted.

## References

- `src/layers/chrome.css` — the band.
- `src/tokens/semantic.css` — the tab strip and the titlebar buttons.
- [003 — checks live in a script, not in a linter](003-checks-as-a-script.md) —
  the silent-failure mode this decision found an instance of.
- `chrome://messenger/skin/shared/messenger.css`, `shared/tabmail.css`,
  `shared/unifiedToolbar.css`, `messenger.css`, `variables.css`, and
  `chrome://global/skin/toolbar.css`, all read out of `omni.ja`.
