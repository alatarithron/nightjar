# Architectural decision: dialog windows are themed at the document root

- Status: accepted
- Date: 2026-08-09
- Supersedes: none
- Superseded by: none

## Context

Every standalone window Thunderbird opens that is not the main one — message
filters, folder properties, the search window, the OpenPGP key manager, every
prompt — was drawn on the desktop's dialog color, measured at 32/35/38 under
Breeze Dark against Nightjar's 14/19/26.

The roadmap called this "toolkit dialogs — the `chrome://global/skin` half of
`--dialog-*`", and a note in `tokens/semantic.css` said the same: that a second
`--dialog-*` family lived in the toolkit and was out of the documented override
surface. **Both were wrong.** Grepping `omni.ja` for each name:

| Token | Actually declared in |
| --- | --- |
| `--dialog-background` | `chrome://messenger/content/messenger/aboutDialog.css` — the About box, not a family |
| `--dialog-bg-color`, `--dialog-shadow`, `--dialog-button-bg-color` | the bundled pdf.js viewer, reaching nothing in the mail interface |
| `--dialog-warning-text-color` | the toolkit, and the only `--dialog-*` there |

There was no toolkit family to bring in. The dialogs were grey for three
unrelated reasons, found by rendering one and sampling it:

1. **The window surface.** `chrome://global/skin/global-shared.css` has
   `:root { background-color: -moz-Dialog; color: -moz-DialogText; }`, applying
   to every chrome document. A system color keyword is the value; there is no
   token behind it. Nightjar's own rule named `#messengerWindow`, which is the
   one window that was already covered by everything else.
2. **The `themeableDialog.css` token family** — `--box-*`, `--field-*`,
   `--primary-focus-border`, `--richlist-button-background`, `--tab-*-background`.
   These *are* messenger-skin tokens, and they are declared as system keywords
   (`Menu`, `Field`, `-moz-Dialog`) and only mapped onto Thunderbird's
   primitives under `:root[lwtheme]`. The default theme is not a lightweight
   theme — the same gate decision 009 found on the top band.
3. **XUL trees and richlistboxes**, which the dialogs still use where the
   3-pane has moved to HTML. The toolkit styles them from `Field`,
   `-moz-ColHeader` and `ThreeDShadow`, with no token anywhere.

## Decision

The surface moves from `#messengerWindow` to `:root` in `layers/chrome.css`, so
it covers every chrome document rather than the one that needed it least:

```css
:root {
  background-color: var(--nj-ink-900) !important;
  color: var(--nj-slate-100) !important;
}
```

Ten `themeableDialog.css` tokens are mapped in `tokens/semantic.css`.
`--box-text-color` is deliberately left out: it belongs to the same family and
is on the reference's never-consumed list.

`tree`, `treecol` and `richlistbox` are styled by selector, because no token
exists for any of them. `richlistbox` additionally needs `appearance: none`.

## Alternatives considered

### Keep `#messengerWindow` and add one selector per dialog

- Advantages: no rule reaches a document that was not looked at.
- Disadvantages: there are dozens of these windows and they arrive with new
  Thunderbird versions. Each would be discovered by seeing it grey.
- Reason not chosen: the toolkit paints them from one rule, so one rule
  answers it.

### Override `-moz-Dialog` itself

- Not possible. It is a system color keyword resolved by the widget layer, not
  a custom property.

### Leave the XUL widgets alone

- Advantages: no selectors against toolkit internals, which is what decision
  009 warns about.
- Disadvantages: it leaves the filter list as a grey header band and a
  system-colored body in the middle of an otherwise themed dialog — visibly
  half-done.
- Reason not chosen: `tree` and `richlistbox` appear only in dialogs now, so
  the blast radius is small and the payoff is the whole widget.

## Consequences

### Positive

- One rule themes every dialog window Thunderbird has, including ones nobody
  has opened yet.
- A wrong premise that had been recorded in `tokens/semantic.css` and in the
  README roadmap is corrected, with the grep that settles it.

### Negative or trade-offs

- `:root` is the broadest selector in the project. It reaches every chrome
  document, including ones outside the mail interface, such as the Browser
  Toolbox. For a dark theme that is the intended direction, but it is no longer
  possible to leave a chrome window alone by not naming it.
- `tree`, `treecol` and `richlistbox` are toolkit widget names. They are stable
  in a way `--custom-properties` are not, but they are still not a contract.
- `appearance: none` on `richlistbox` gives up the platform listbox rendering,
  including its native focus ring. The `tree` keeps its appearance and did not
  need this.

## Verification

The message filters dialog, rendered and sampled before and after:

| Point | Before | After |
| --- | --- | --- |
| Dialog surface | `rgb(32, 35, 38)` | `rgb(14, 19, 26)` — `--nj-ink-900` |
| Column header | `rgb(41, 44, 48)` | `rgb(25, 33, 44)` — `--nj-ink-800` |
| List body | `rgb(20, 22, 24)` | `rgb(14, 19, 26)` |

No regression elsewhere: the compose window samples identically at all five
points measured before the change, and the main window differs by 3 pixels of
anti-aliasing on one toolbar icon, with no color changed.

The list body took three attempts and is the useful part of this record. The
`background-color` was correct, carried `!important`, and was in the sheet that
reaches the document — and did nothing, because the toolkit gives `richlistbox`
`appearance: auto` with `-moz-default-appearance: listbox`, and a natively
painted widget ignores `background-color` outright. That is a third distinct
way a rule can look like it failed, after a missing `!important` and the wrong
document.

`bin/check.sh`: all 15 checks pass.

## References

- `src/layers/chrome.css`, `src/tokens/semantic.css`.
- `chrome://global/skin/global-shared.css`, `global/tree/tree.css`,
  `global/richlistbox.css`, `chrome://messenger/skin/shared/themeableDialog.css`.
- [009 — the top band belongs to the theme](009-top-band-belongs-to-the-theme.md)
  — the same `:root[lwtheme]` gate, on a different surface.
- [011 — the window decoration is not ours](011-the-window-decoration-is-not-ours.md)
  — the titlebar above these same windows.
