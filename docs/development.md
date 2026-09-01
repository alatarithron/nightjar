# Development

## Loop

1. Edit a file under `src/`.
2. Fully quit Thunderbird and start it again.
3. Look at the result.

There is no build step and no watch mode — the profile's `chrome/` is a symlink
to `src/`, so the files Thunderbird reads are the files in the repository.

Step 3 can be scripted, which is worth it when a change comes down to a color
choice and the honest way to decide is to render both. Under a Wayland session,
start Thunderbird on XWayland so an X11 screenshot tool can reach it:

```bash
MOZ_ENABLE_WAYLAND=0 GDK_BACKEND=x11 thunderbird &
win=$(xdotool search --onlyvisible --name "Mozilla Thunderbird" | tail -1)
import -window "$win" shot.png
```

`--onlyvisible` matters: searching by `--class thunderbird` also returns a 10×10
hidden window, and `import` fails on it. Give the 3-pane ten seconds or so to
finish laying out before the shutter, and drive the pointer with
`xdotool mousemove` first if a hover state is what you need to see.

Sample the result rather than trusting your eye — `magick shot.png -format
'%[pixel:p{300,22}]' info:` answers "did this token actually land" in a way a
screenshot does not.

A capture of a real profile contains real mail. Keep them out of the
repository.

## Inspecting the chrome DOM

Selector work is guesswork without the Browser Toolbox. Enable it once:

`Settings > General > Config Editor`, then set:

```
devtools.chrome.enabled            true
devtools.debugger.remote-enabled   true
```

Open it with **Ctrl+Shift+Alt+I** (or `Tools > Developer Tools > Browser
Toolbox`) and accept the incoming-connection prompt. The element picker then
works on Thunderbird's own interface, and the Rules panel shows exactly which
stylesheet wins — including whether a Nightjar rule is being overridden.

The Style Editor lets you try a declaration live before writing it to a file.
Those edits are lost on restart; treat it as a scratchpad.

## Which sheet reaches which document

`userChrome.css` applies to chrome documents — the 3-pane, the compose window,
dialogs. `userContent.css` applies to documents rendered *as content*, and that
includes Thunderbird's own `about:` pages. `about:addressbook` is the one that
makes the distinction obvious: it is Thunderbird's own interface by every other
measure, and a rule in `layers/chrome.css` does not touch it.

Both entry points import `tokens/palette.css` and `tokens/semantic.css`, so
**tokens** reach either kind of document. **Selectors** do not: a selector only
works in the sheet whose documents it is in.

When a rule appears to do nothing, settle which sheet is in play before editing
the rule. Put the same declaration in both, with different colors, and look:

```css
/* layers/chrome.css */    #someElement { background-color: var(--nj-green-400) !important; }
/* userContent.css  */     #someElement { background-color: var(--nj-rose-500)  !important; }
```

Whichever color appears is your answer. Delete both afterwards.

One rule follows from the shared import: `tokens/semantic.css` may contain
custom properties and nothing else, because it lands on message bodies too. A
custom property is inert until something reads it; an ordinary declaration would
repaint other people's mail. `bin/check.sh` enforces that.

## Why `!important` is everywhere

`userChrome.css` is loaded as a **user** stylesheet. In the CSS cascade, user
declarations lose to author declarations — and every one of Thunderbird's own
stylesheets is author-level. `!important` inverts that: an important user
declaration beats an important author one.

The exceptions are declarations with no competitor, such as the `--nj-*`
palette. Those are plain, and should stay plain: `!important` on a value nothing
contests only makes the next override harder.

## Why tokens are preferred over selectors

Overriding `--sidebar-background` survives a refactor of the folder pane's
markup. Overriding `#folderTree li > .container` does not. Reach for a selector
only when no token expresses the change, and keep those in `layers/chrome.css`
so the blast radius of a Thunderbird upgrade is one file.

When a selector is the only option, `bin/check.sh` verifies that every `#id` and
every dashed custom-element name in `src/` is one Thunderbird actually has, the
same way it verifies token names. A new selector therefore needs
`bin/dump-tb-reference.sh` re-run before the checks pass. Two limits are worth
knowing: the check greps whole files, comments included, so a note about an id
that was *removed* has to spell it without its `#`; and it proves the name
exists, never that the selector matches. `#messengerWindow > toolbox` passed
every name test it could and still matched nothing, because the toolbox is a
grandchild of `#messengerWindow`, not a child. Confirm depth in the Browser
Toolbox.

After every Thunderbird upgrade, run:

```bash
bin/dump-tb-reference.sh
git diff docs/thunderbird-tokens.md
```

Removed lines are the theme's breakage list.

## Icons

Thunderbird resolves icons through `--icon-<name>` properties. To replace one,
add artwork to `src/icons/<name>.svg` and run:

```bash
bin/build-icons.sh
```

That regenerates `src/layers/icons.generated.css`, inlining each SVG as a data
URI. **Do not write the override by hand**, and do not edit the generated file.

The reason is a Gecko behavior worth knowing before you lose an evening to it:
a relative `url()` inside a custom property is resolved against the stylesheet
that *uses* the `var()`, not the one that declares it. Thunderbird consumes
`--icon-*` from `chrome://messenger/skin/*.css`, so `url("../icons/x.svg")`
written in the theme resolves against `chrome://messenger/skin/` and loads
nothing — producing a completely blank icon, with no error anywhere. A data URI
carries no base and sidesteps the whole question.

How a broken icon looks tells you which step failed:

| Appearance | Cause |
|---|---|
| Blank | The URL did not resolve. |
| Faint | The artwork is missing its `context-stroke` tone. |
| Solid black | Context paint was denied — in an installed profile that means `svg.context-properties.content.enabled` is missing from `user.js`. See [decision 005](../.agents/decisions/005-icon-color-reactivity.md). |

Artwork constraints, all enforced by the renderer rather than by us:

- Chrome SVGs render as images. No scripts, no external references, no `<style>`
  blocks that depend on the host document.
- **Always paint with `context-stroke`.** Thunderbird hands the icon color to the
  SVG through `-moz-context-properties: fill, stroke`, and the two are not
  interchangeable. The folder pane, for example, declares:

  ```css
  -moz-context-properties: fill, stroke;
  fill: color-mix(in srgb, var(--icon-color, …) 20%, transparent);
  stroke: var(--icon-color, …);
  ```

  So `context-fill` is the icon color at **20% alpha** — a wash — and
  `context-stroke` is the same color at full alpha, which is what makes the shape
  readable. An icon painted only with `context-fill` is not broken; it renders at
  20% opacity and disappears against a dark surface. This is exactly how the
  first version of `archive.svg` failed.
- **The second tone is a second silhouette, not a reduced opacity.** Bootstrap
  ships an outline file and a `-fill` twin. The port stacks them, which is the
  same two-filled-path structure Thunderbird's own `compact` set uses:

  ```
  <name>-fill.svg  →  <g fill="context-fill">    drawn first, the 20% wash
  <name>.svg       →  <g fill="context-stroke">  drawn on top, the shape
  ```

  Here Thunderbird's own 20% is correct, because a wash sitting *behind* a
  full-alpha outline is exactly what that alpha was designed for. An icon with no
  `-fill` twin — `fire`, standing in for junk, is one — ships single-tone and is
  legible on its own. See
  [decision 007](../.agents/decisions/007-bootstrap-icon-set.md).
- A hardcoded color ignores the theme and will look correct in exactly one state.
- Bootstrap is drawn on a native 16 grid. Keep `viewBox="0 0 16 16"` and set
  `width`/`height` to the size the property implies. Thunderbird's own artwork
  defines those: `-xs` is 12, `-sm` is 16, `-md` is 20, `-lg` is 24, no suffix is
  16.
- There is no stroke width. Bootstrap's shapes are filled outlines with zero
  strokes, which is why the coordinates land on whole pixels at 16px — the thing
  Solar could not do, and the reason for decision 007.

None of this is applied by hand. `bin/import-icon.sh` does the port:

```bash
bin/import-icon.sh trash trash             # -> src/icons/trash.svg
bin/import-icon.sh --single chat chat      # one tone, no -fill twin used
```

`--single` matters more than it sounds. The two-tone port only suits artwork
whose fill is an *interior*; when Bootstrap's `-fill` twin is a solid silhouette
of the whole glyph, the 20% wash covers the icon's entire area and it reads as a
grey block. `calendar` and `chat` are both like that.

Check which token the element you are looking at actually reads, rather than
grepping the component's stylesheet for a plausible name. The spaces rail reads
`--spaces-icon-mail`, not `--icon-mail` — the latter appears in the same file,
for the popup menu — so replacing it changed nothing on the rail and the
difference measured zero pixels.

It refuses a token absent from `docs/thunderbird-tokens.md`, so a typo fails at
import instead of turning into a silent no-op at runtime, and it regenerates the
stylesheet when it is done.

To check artwork without restarting Thunderbird, render it under a simulated
context — substitute the two paint values and put it on a real surface color:

```bash
sed 's/"context-fill"/"#b3bfcf" fill-opacity="0.2"/; s/"context-stroke"/"#b3bfcf"/' \
  src/icons/archive.svg > /tmp/probe.svg
rsvg-convert -w 160 -h 160 -b '#131922' /tmp/probe.svg -o /tmp/probe.png
```

`src/icons/archive.svg` is the reference implementation.

## Fonts

The typeface is bundled: IBM Plex Sans for the interface and IBM Plex Mono for
`pre` and `code`, as `.woff2` in `src/fonts/`, declared in
`src/layers/typography.css` ([decision 013](../.agents/decisions/013-bundled-typeface.md)).

To swap it, replace the file, update the `@font-face` block and put the new
family first in `--nj-font-ui`. Three things are easy to get wrong:

- **The weight range must match the font.** Plex Sans's `fvar` declares
  `wght` 100–700; writing `100 900` makes the browser synthesize the top of the
  range instead of refusing it. Read the axis rather than assuming:
  `fonttools ttx -t fvar -o - Font.ttf`.
- **Relative paths work here**, unlike in the `--icon-*` properties. An
  `@font-face` `src` resolves against the stylesheet that declares it, so
  `../fonts/` from `layers/` is `src/fonts/`. The data-URI workaround in
  [decision 004](../.agents/decisions/004-icons-as-data-uris.md) is about
  custom properties and does not apply.
- **Changing the typeface changes the apparent size.** Cap heights differ —
  Plex is 141 units against Adwaita Sans's 147 — so keeping the old scale would
  have shrunk the whole interface by about 6%. Compare with a cap-height
  measurement, not by eye:

  ```bash
  magick -background white -fill black -font Font.ttf -pointsize 200 \
         label:"H" -trim -format "%h" info:
  ```

To confirm a bundled font is actually being used rather than a fallback, measure
a string in a screenshot and compare against both candidates. `font-display:
swap` means a font that fails to load looks almost right, which is why
`bin/check.sh` checks that every `@font-face` source exists.

### How far the typeface reaches

`layers/typography.css` is imported by `userChrome.css` alone, so the fonts
apply to **chrome documents only**. That is deliberate for message bodies — a
received message is someone else's document — but it also means Thunderbird's
own content-rendered pages, the message source view among them, keep the
platform's default families.

That is a setting, not a gap. *Settings → Language & Fonts → Advanced…* writes
`font.name.*`, which content documents read, so installing the family
system-wide (`ttf-ibm-plex` on Arch) and choosing it there covers the source
view and message bodies alike — and leaves the choice with the reader, which is
why the theme does not force it.

Message *body* fonts are deliberately not forced.
