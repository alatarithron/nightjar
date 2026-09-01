<div align="center">

```
       ▄▄▄                                          
     ▄█████▄     N I G H T J A R                    
   ▄███▀ ▀███▄                                      
  ████  ●  ████   a dark theme for Thunderbird      
   ▀███▄ ▄███▀    that changes more than the color  
     ▀█████▀                                        
       ▀▀▀                                          
```

**colors · icons · typography** — no framework, no build step, no dependencies

</div>

---

The nightjar hunts at dusk. It is the color of bark, invisible until it opens
its eyes — which are amber.

That is the whole design brief. Deep cool near-blacks carry the interface;
a single warm amber marks the one thing you should be looking at. Everything
else gets out of the way.

## Why this exists

Thunderbird ships a dark theme, and the add-on API for themes exposes **42
color keys**. Not one of them touches an icon or a font. Nightjar is not an
add-on — it is a user stylesheet, which means it can reach all of it:

| | Static theme add-on | Nightjar |
|---|---|---|
| Colors | 42 keys | every token Thunderbird declares |
| Icons | — | the `--icon-*` properties a `data:` URI can reach (decision 008) |
| Typography | — | full control |
| Layout | — | full control |
| Install | one click | one script |

The full reasoning, including why the `theme_experiment` middle ground was
rejected, is in [decision 001](.agents/decisions/001-user-stylesheet-over-static-theme.md).

## Install

```bash
git clone <this repo> nightjar
cd nightjar
bin/install.sh
```

That symlinks `src/` to your profile's `chrome/` directory and writes three prefs
to `user.js`. Restart Thunderbird — fully quit, not just close the window.

| Pref | Why |
|---|---|
| `toolkit.legacyUserProfileCustomizations.stylesheets` | Without it Thunderbird ignores the profile's user stylesheets entirely. |
| `svg.context-properties.content.enabled` | Without it the replaced icons load but render as solid black silhouettes. |
| `mailnews.start_page.url` | Points the start page at Nightjar's own instead of the one Thunderbird fetches from `live.thunderbird.net` on every launch. |

The second one is worth a moment. Gecko lets an SVG read its color from the
consuming CSS only for a short list of URL schemes, and the theme's inlined
`data:` icons are not on it; the pref lifts that restriction. It lifts it
everywhere, though, including for images in received HTML mail. An SVG loaded as
an image runs no script, so a sender cannot read back what it inherits — but it
is a global change, and [decision 005](.agents/decisions/005-icon-color-reactivity.md)
argues the trade in full. Drop the pref and the theme still works; the icons just
turn into silhouettes.

To back out completely: `bin/uninstall.sh`. It only removes what it added and
never touches a real `chrome/` directory.

> Requires Thunderbird on Linux. Built and verified against **153.0**.

## The palette

| | Token | Role |
|---|---|---|
| ⬛ `#0e131a` | `--nj-ink-900` | app background |
| ⬛ `#19212c` | `--nj-ink-800` | raised surface, rows |
| ⬛ `#222c3a` | `--nj-ink-700` | hover |
| ◻️ `#dde4ee` | `--nj-slate-100` | primary text |
| ◻️ `#b3bfcf` | `--nj-slate-200` | secondary text, idle icons |
| 🟨 `#dd9c34` | `--nj-amber-500` | **the eye** — selection, focus, accent |
| 🟩 `#63c98a` · 🟥 `#ef7f7f` · 🟦 `#4cc9c4` | support | status only, never decoration |

Every raw color in the project lives in
[`src/tokens/palette.css`](src/tokens/palette.css). Nothing else is allowed to
write a hex value, and a check enforces it.

## How it is laid out

```
src/                    ← this directory IS the profile's chrome/
├── userChrome.css        entry point: @imports, in cascade order
├── userContent.css       Thunderbird's own pages + plain-text mail
├── tokens/
│   ├── palette.css       the only raw color values in the project
│   └── semantic.css      Thunderbird's tokens → Nightjar's palette
├── layers/
│   ├── typography.css    UI typeface, scale, unread weight
│   ├── icons.css         --icon-* overrides + icon color states
│   └── chrome.css        the few things no token can express
├── icons/                SVG artwork, imported from Bootstrap Icons
├── start/                the start page, replacing Thunderbird's remote one
└── fonts/                bundled IBM Plex Sans + Mono (.woff2)

bin/     install · uninstall · check · test-install · import-icon · build-icons
         regenerate token reference
contrib/ optional desktop-level extras that are not the theme (KDE color
         scheme + window rule for the decoration)
docs/    development guide + generated token reference
```

Values are defined in `tokens/`, consumed in `layers/`. A layer that hardcodes
a color is a bug, and CI says so.

## Three things worth knowing before you edit

**`!important` is not sloppiness here.** `userChrome.css` is a *user*
stylesheet, and in the CSS cascade user declarations lose to author
declarations — which is what every one of Thunderbird's own stylesheets is.
A rule that "does nothing" is almost always a missing `!important`.

**Prefer tokens over selectors.** Overriding `--sidebar-background` survives a
refactor of the folder pane's markup. Overriding `#folderTree li > .container`
does not. Selectors are quarantined in `layers/chrome.css` so an upgrade breaks
exactly one file.

**Chrome and content are different documents.** `userChrome.css` styles the
application; `userContent.css` styles what is rendered inside it — including
Thunderbird's own `about:` pages, which is not obvious until a rule in
`layers/chrome.css` silently fails to reach the address book. Both sheets import
both token files, so tokens reach everywhere and selectors do not
([decision 010](.agents/decisions/010-content-documents-get-the-token-layer.md)).

## Swapping an icon

Thunderbird resolves every chrome icon through a `--icon-<name>` custom
property, so replacing artwork needs no selector archaeology — the file name is
the whole wiring. `src/icons/archive.svg` becomes `--icon-archive`.

The generation step is not a preference. Gecko resolves a relative `url()`
inside a custom property against the stylesheet that *uses* the `var()`, which
for `--icon-*` is `chrome://messenger/skin/` — so a relative path here silently
loads nothing. `bin/build-icons.sh` inlines each SVG as a base-independent
`data:` URI into `src/layers/icons.generated.css`, which is committed and
checked for staleness by CI. Details in
[decision 004](.agents/decisions/004-icons-as-data-uris.md).

The artwork comes from [Bootstrap Icons](https://icons.getbootstrap.com/), which
is drawn on the same native 16 grid with the same filled outlines as
Thunderbird's own set. Each icon is assembled from Bootstrap's two files:

```
<name>-fill.svg  →  <g fill="context-fill">    drawn first, the 20% wash
<name>.svg       →  <g fill="context-stroke">  drawn on top, the shape
```

Both tones derive from the context paint, so the icons keep reacting to hover,
selection and Thunderbird's per-folder colors. An icon with no `-fill` twin ships
single-tone and stays legible, because `context-stroke` arrives at full alpha.

You do not apply that by hand. `bin/import-icon.sh` does it, and refuses a token
Thunderbird does not declare — so a typo fails at import instead of becoming a
silent no-op at runtime:

```bash
bin/import-icon.sh trash trash    # -> src/icons/trash.svg
```

Every icon must carry `context-stroke`, the full-alpha tone that makes the shape
readable; `context-fill` is optional. No scripts or external references — chrome
SVGs render as images. The artwork keeps Bootstrap's `viewBox="0 0 16 16"` and
takes the intrinsic size the property implies: `-xs` 12, `-sm` 16, `-md` 20,
`-lg` 24, unsuffixed 16. There is no stroke width, because there are no strokes —
which is also why the shapes land on whole pixels at 16px. Reasoning in
[decision 007](.agents/decisions/007-bootstrap-icon-set.md); attribution in
[`NOTICE`](NOTICE), which the MIT license requires you to keep.

**21 of Thunderbird's 223 `--icon-*` properties are replaced so far — about
9%.** The number is lower than it sounds: most of the 223 belong to windows and
menus a given person may never open, and the set was chosen by looking at what
is actually on screen — the spaces rail, the folder pane, the message list and
the quick filter bar are done.

Not every icon property can actually be replaced. Thunderbird declares a
Content-Security-Policy per document, and its `img-src` directive decides
whether a `data:` URI loads at all — `messenger.xhtml` admits it,
`messengercompose.xhtml` does not, so the same replacement renders in one window
and is simply absent in the other. Which windows draw a given icon is not
decidable from the sources, so **verify a new icon by opening the windows that
use it**. [Decision 008](.agents/decisions/008-icon-reach-and-the-add-on-question.md)
records the mechanism, the two measurement attempts that failed, and why an
add-on does not lift the limit.

The complete list of 223 icon properties, plus every semantic token, is in
[`docs/thunderbird-tokens.md`](docs/thunderbird-tokens.md) — generated from
your installed Thunderbird, never hand-written.

## Checks

```bash
bin/check.sh
```

No linter, no Node, no network. It enforces what a CSS linter structurally
cannot: that every overridden property actually exists in Thunderbird, that
`!important` is present where the cascade requires it, that icons are
renderable, and that nothing from a mail profile ever lands in the repository.
GitHub Actions runs this exact script, so local and remote cannot disagree.

## After a Thunderbird upgrade

Thunderbird's custom properties are internal API. They get renamed.

```bash
bin/dump-tb-reference.sh
git diff docs/thunderbird-tokens.md
```

Removed lines are your breakage list.

## Roadmap

- [x] Token architecture and semantic mapping
- [x] Install / uninstall, checks, generated token reference
- [x] Layout surface ramp, spaces toolbar, message list, folder colors
- [x] Dialogs, modals and close buttons
- [x] Top band — search row, tab strip and window buttons, off the desktop grey
- [x] Content-rendered pages — the token layer reaches `about:addressbook` and friends
- [x] Dialog windows — surface, `themeableDialog` tokens, XUL trees and lists
- [x] Window decoration on KDE — every window, optional, `contrib/` + [`docs/kde.md`](docs/kde.md)
- [x] Compose window — address rows and subject; the format bar was already themed, and its toolbar icons cannot be replaced ([decision 008](.agents/decisions/008-icon-reach-and-the-add-on-question.md))
- [x] Bundled variable UI font — IBM Plex Sans + Mono ([decision 013](.agents/decisions/013-bundled-typeface.md))
- [x] Calendar pass — the `--view*` family, drag feedback, and the warning bar
- [x] Account hub — reached through `--color-primary-*` / `--color-surface-*` ([decision 014](.agents/decisions/014-roles-in-the-primitives-file.md))
- [ ] Icon set — **21 of 223 (9%)**; each new one verified in the window that uses it
- [x] Density variants — investigated and found unnecessary; the theme decides nothing density touches ([`docs/development.md`](docs/development.md))

## Documentation

- [`docs/development.md`](docs/development.md) — the edit loop, the Browser Toolbox, the cascade
- [`docs/thunderbird-tokens.md`](docs/thunderbird-tokens.md) — generated reference
- [`docs/kde.md`](docs/kde.md) — the compose window's titlebar, and why CSS cannot reach it
- [`AGENTS.md`](AGENTS.md) — rules for AI agents in this repository
- [`.agents/decisions/`](.agents/decisions/) — why it is built this way

## License

MIT. See [LICENSE](LICENSE).
