# Project memory

> This file is the version-controlled source of truth for durable project context. Keep it concise, current, and free of secrets.

## Project purpose

- Primary goal: Nightjar, a dark theme for Thunderbird that changes colors, icon artwork, and typography — not colors alone.
- Explicit non-goals: rewriting received HTML message bodies into dark mode; supporting light mode; supporting Windows or macOS profile layouts; distribution on addons.thunderbird.net for now (see decision 001).
- Intended users: the author, on Linux. Anyone else is a bonus.

## Architecture

- Main components:
  - `src/userChrome.css` — entry point Thunderbird loads for the application chrome.
  - `src/userContent.css` — entry point for documents rendered inside Thunderbird.
  - `src/tokens/` — `palette.css` holds every raw color; `semantic.css` maps Thunderbird's tokens onto it.
  - `src/layers/` — `typography.css`, `icons.css`, `chrome.css`. Consume tokens, never raw values.
  - `src/icons/` — SVG artwork, ported from Bootstrap Icons (decision 007). Never referenced by path: `bin/build-icons.sh` inlines each file as a data URI (decision 004). `src/fonts/` holds the bundled typefaces — IBM Plex Sans variable and IBM Plex Mono in two weights, as WOFF2, declared by `layers/typography.css` (decision 013). Unlike the icons, these are referenced by relative path, because an `@font-face` `src` resolves against the stylesheet that declares it.
  - `src/start/` — the start page `mailnews.start_page.url` points at. Loaded over `file://` from the profile's `chrome/`, so it links `../tokens/palette.css` by relative path: an ordinary document, not the custom-property case decision 004 covers.
  - `contrib/` — things that make Nightjar look right and are **not** the theme, because they belong to the desktop rather than to Thunderbird. Currently `contrib/kde/Nightjar.colors` and `contrib/kde/nightjar.kwinrule` (decision 011). Never applied by `bin/install.sh`.
  - `bin/` — install/uninstall into a profile, invariant checks, regression tests for the install scripts, and regeneration of the token reference.
  - `.github/workflows/ci.yml` — runs `bin/check.sh` and nothing else, so local and remote CI cannot diverge.
  - `docs/thunderbird-tokens.md` — generated; the allowed override surface. Covers `chrome://messenger/skin/` **and** `chrome://messenger/content/`; the second half was added after the About dialog turned out to declare its colors there.
- Component responsibilities: values are defined in `tokens/`, consumed in `layers/`. A layer that hardcodes a color is a bug.
- Important boundaries: the theme owns Thunderbird's own interface. It does not own message content authored by a sender.
- Data flow: Thunderbird reads `<profile>/chrome/userChrome.css`, which is a symlink to `src/`. `@import` order in the entry point is the cascade order.

## Domain language

| Term | Meaning |
| --- | --- |
| Chrome | Thunderbird's own interface, as opposed to message content. |
| Author sheet | A stylesheet shipped by Thunderbird. Wins over user sheets unless the user declaration is `!important`. |
| User sheet | `userChrome.css` / `userContent.css`, loaded from the profile. |
| Token | A `--custom-property` Thunderbird declares and consumes internally. |
| `context-fill` / `context-stroke` | SVG paint values that pull color from the consuming CSS through `-moz-context-properties`. In Thunderbird these are not equivalent: `fill` arrives at 20% alpha (interior wash), `stroke` at full alpha (the readable outline). |
| omni.ja | The zip archive inside a Thunderbird installation holding its stylesheets, schemas, and icons. |

## Invariants

- The profile carries the three prefs `bin/install.sh` writes. Without `toolkit.legacyUserProfileCustomizations.stylesheets` nothing loads; without `svg.context-properties.content.enabled` the replaced icons render black; `mailnews.start_page.url` is the one that is a substitution rather than a requirement — dropping it restores Thunderbird's remote start page without breaking anything.
- Raw color values exist only in `src/tokens/palette.css`.
- Every Thunderbird custom property overridden by this theme appears in `docs/thunderbird-tokens.md`, and none of them appears in that file's `## Declared but never consumed` section.
- `tokens/semantic.css` declares custom properties and nothing else. `userContent.css` imports it globally, so an ordinary declaration in there would paint message bodies.
- Every `#id` and every dashed custom-element name `src/` selects on appears in that file's `## Selector targets that exist` section. That section is filtered by `omni.ja`, not by `src/`, so regenerating the reference cannot make a wrong name pass.
- Declarations that compete with Thunderbird's stylesheets carry `!important`; the `--nj-*` palette does not.
- Every icon carries `context-stroke`; `context-fill` is optional.
- Every `@font-face` source in `src/` resolves to a file that exists, and every file in `src/fonts/` is referenced by an `@font-face`.
- Third-party artwork is credited in `NOTICE`.
- Nothing read from a Thunderbird profile is ever committed.

## Development environment

- Supported operating systems: Linux.
- Runtime and required versions: Thunderbird 153.0 (the version this was built and verified against). Bash for `bin/`. No language runtime, no package manager.
- Package manager: none.
- External services: none.

## Commands

```text
Install:  bin/install.sh [profile-dir]
Run:      restart Thunderbird
Test existing suite:  bin/check.sh   (calls bin/test-install.sh; visual validation remains manual)
Lint:     bin/check.sh   (runs shellcheck --severity=style on bin/ when installed)
Type-check: not applicable
Build:    bin/build-icons.sh   (icons only; no CSS build — see decision 004)
Reference regeneration: bin/dump-tb-reference.sh [path/to/omni.ja]
```

## Conventions

- Project-specific naming: own palette entries are `--nj-<hue>-<step>`, mirroring Thunderbird's `--color-<hue>-<step>` scale so both systems read alike.
- Error-handling conventions: `bin/` scripts use `set -euo pipefail`, refuse to overwrite a real `chrome/` directory, and only remove what they added.
- API or database conventions: not applicable.
- Compatibility requirements: Thunderbird custom properties are internal API, and so are the element ids the theme selects on. After every Thunderbird upgrade, regenerate `docs/thunderbird-tokens.md` and read the diff — removed lines are the breakage list, in both the token sections and `## Selector targets that exist`. Adding a new selector also requires a regeneration before `bin/check.sh` accepts it.

## External integrations

None. The theme has no network access and no dependencies.

## Active architectural decisions

- [User stylesheet instead of a static theme add-on](decisions/001-user-stylesheet-over-static-theme.md)
- [No CSS framework or build step](decisions/002-no-css-framework.md)
- [Checks live in a script, not in a linter](decisions/003-checks-as-a-script.md)
- [Icons are inlined as data URIs by a generation step](decisions/004-icons-as-data-uris.md)
- [How replaced icons take color](decisions/005-icon-color-reactivity.md)
- [Bootstrap Icons replace Solar](decisions/007-bootstrap-icon-set.md) — supersedes [006](decisions/006-icon-source-set.md), kept for its comparison of the five candidate sets
- [How far icons reach, and why the add-on was rejected](decisions/008-icon-reach-and-the-add-on-question.md)
- [The top band belongs to the theme, not to the desktop](decisions/009-top-band-belongs-to-the-theme.md)
- [Content documents get the token layer too](decisions/010-content-documents-get-the-token-layer.md)
- [The window decoration is not ours, so it is met halfway](decisions/011-the-window-decoration-is-not-ours.md)
- [Dialog windows are themed at the document root](decisions/012-dialog-windows-are-themed-at-the-root.md)
- [IBM Plex, bundled](decisions/013-bundled-typeface.md)
- [The roles in colors.css are overridden; the scale is not](decisions/014-roles-in-the-primitives-file.md)

## Known constraints and pitfalls

- The static theme add-on API (`manifest.json` → `theme.colors`) exposes 42 color keys and cannot touch icons or fonts. Verified against the theme schema shipping in Thunderbird 153. This is why the project is a user stylesheet.
- `theme_experiment` can map extra keys to internal CSS variables and exists in Thunderbird 153, but add-ons using it are reviewed as experiments and version-locked with `strict_max_version`. Kept as a possible distribution path, not the development path.
- User stylesheets lose the cascade to Thunderbird's own stylesheets. A rule that "does nothing" is usually a missing `!important`, not a wrong selector.
- Thunderbird 153 declares 223 `--icon-*` properties on `:root`, so icon replacement needs no selector work — redefining the property is enough.
- Icon SVGs are rendered as images: scripts, external references, and host-dependent `<style>` blocks do not run.
- Thunderbird's icon consumers declare `-moz-context-properties: fill, stroke` with `fill` mixed to 20% alpha and `stroke` at full alpha (verified in `about3Pane.css`, folder pane `.icon` rule). Artwork must use both: `context-stroke` for the outline, `context-fill` for the wash. An icon using only `context-fill` renders at 20% opacity and is invisible on dark surfaces — it looks like the override failed when it actually succeeded.
- Gecko resolves a relative `url()` inside a custom property against the stylesheet that **uses** the `var()`, not the one that declares it. Verified with a three-case controlled test. Since `--icon-*` is consumed from `chrome://messenger/skin/`, icon URLs must be absolute — hence the data URIs generated by `bin/build-icons.sh` (decision 004). A relative icon path produces a completely blank icon, not a fallback.
- Gecko gates context paint in `SVGContextPaint::IsAllowedForImageFromURI`: the `svg.context-properties.content.enabled` pref, else the `chrome` / `resource` / `page-icon` / `cached-favicon` schemes, else a WebExtension permission, else a host in `svg.context-properties.content.allowed-domains`. A `data:` URI matches none of them, which is why the theme sets the pref (decision 005). `file://` was tested and is rejected the same way — it loads, but paints black.
- Icons therefore have three distinct failure appearances, and they are diagnostic: **blank** means the URL did not resolve; **faint** means the artwork lacks its `context-stroke` tone; **solid black** means context paint was denied, which for an installed profile means the pref is missing. Render the SVG under a simulated context (`docs/development.md`) to tell them apart before touching CSS.
- Folder icon colors come from the 14 `--folder-color-*` tokens in `folderColors.css`, which the folder pane feeds into `--icon-color` and from there into both context tones. Those are defaults only: a user-chosen folder color and a tag color are set by `about3Pane.js` as an inline style on the row, and inline beats any stylesheet, so overriding the tokens restyles the defaults without taking the choice away. The inbox prefers `--account-color` first.
- `--layout-background-0..4`, `--layout-color-0..3` and `--layout-border-0..2` are the base surface ramp everything else derives from — tree cards, dialogs, boxes, the message pane. In dark mode the ramp runs 0 darkest to 4 lightest. Overriding these twelve reaches more of the interface than any selector, and it is why `layers/chrome.css` no longer paints the panes directly.
- A token being declared does not mean it is consumed. Thunderbird 153 declares 83 custom properties that nothing — no stylesheet, script or document — ever reads, `--treeitem-background-hover` and `--treeitem-background-selected` among them, which is why the folder pane's hover and selected rows still need selectors. Overriding one is as inert as inventing a name, and it passes a spelling check. `bin/dump-tb-reference.sh` lists them under `## Declared but never consumed` and `bin/check.sh` refuses them. Measure consumption over the whole `omni.ja`, never the messenger skin alone: the skin declares plenty that the toolkit is what consumes.
- Compare icon artwork offline, against Thunderbird's own file for the same token, not by diffing screenshots. Two ways the screenshot route lied: magnifying a 16px icon with the default smooth resize turns thin shapes into blobs, so use `-filter point`; and a live mailbox changes between captures, so whole rows shift and the diff is meaningless. Thunderbird's originals are in `omni.ja` under `icons/new/compact/`; render both to the same box and look.
- Card view reads the `-sm` variants — `--icon-star-sm`, `--icon-attachment-sm` — while the table view and the quick filter bar read the base names. Replacing only the base names leaves the list that is actually on screen untouched.
- A token family can shadow another one that looks like the obvious target. The spaces rail does not read `--icon-mail`; it reads `--spaces-icon-mail`, pointed at a larger "normal" artwork set, and `--icon-*` only reaches the spaces *popup menu*. Replacing the wrong family measured zero pixels of change. `tokens/semantic.css` now aliases one onto the other, which is what Thunderbird itself does under `:root[uidensity="compact"]`. Grep for the consumer of the exact element, not for the token name appearing somewhere in the component's stylesheet.
- The two-tone icon port only suits artwork whose fill is an *interior*. When Bootstrap's `-fill` twin is a solid silhouette of the whole glyph — `calendar`, `chat` — the 20% wash covers the icon's entire area and it reads as a grey block. `bin/import-icon.sh --single` declines the twin for those.
- Thunderbird sets a Content-Security-Policy per document, and `img-src` decides whether a `data:` URI loads. `messenger.xhtml` admits `data:`; `messengercompose.xhtml` does not. So a replaced icon renders in some windows and is simply absent in others — not faint, not black, absent. Which windows actually draw a given icon is **not** decidable from the static sources: two analyses were attempted and both are recorded as failures in decision 008, one wildly over-reporting and one missing a case observed on screen. Verify a new icon by opening the windows that use it. `--icon-sent` was dropped for exactly this — correct in the folder pane, absent on the compose window's Send button.
- The top band — global search, window buttons, tab strip — is not painted by Thunderbird under the default theme, and XUL `toolbar` falls back to `-moz-headerbar` on Linux, so it arrives in the desktop's grey. It has no token: `--toolbar-background-color` only reaches `#navigation-toolbox` under `:root[lwtheme]`, and the second rule additionally needs `:not([customtitlebar])`, which never holds because Thunderbird draws its own window buttons. Decision 009 paints it with a selector. That token *is* consumed — by the selected tab — so it passes both `bin/check.sh` token checks while doing nothing for the band. "Read somewhere" is not "read here".
- A selector can be dead without any check noticing. `#messengerWindow > toolbox` shipped for weeks and never matched: `#messengerWindow` is the `<html>` element of `messenger.xhtml` and the toolbox is a child of `<html:body>`. Confirm the DOM path in the window's source before writing a combinator.
- `userChrome.css` styles chrome documents; `userContent.css` styles content documents, and Thunderbird's own about: pages are content. `about:addressbook` is the clearest case: its **New Contact** button read `--selected-item-color`, which Nightjar sets, and still came out in the desktop accent because the semantic layer stopped at the chrome boundary. Both token files are imported from `userContent.css` since decision 010. When a rule mysteriously does not apply, settle which sheet reaches the document before touching the rule — put the same declaration in both with different colors and look.
- `layers/typography.css` is imported by `userChrome.css` alone, so the bundled fonts reach **chrome documents only**. Deliberate for message bodies; the side effect is that Thunderbird's own content-rendered pages, message source included, keep the platform's default families. Content-document fonts are not the theme's job: *Settings → Language & Fonts → Advanced…* writes `font.name.*`, which is what those documents read. Point a user at that instead of reaching into `userContent.css`; it covers message bodies too and leaves the choice with the reader. `ttf-ibm-plex` in Arch's `extra` installs the matching family system-wide.
- A bundled font that fails to load looks almost right, because `font-display: swap` falls back to a system family. Prove a font is really in use by measuring a string in a screenshot against rendered predictions for both candidates; do not judge by eye. `bin/check.sh` covers the file's existence, not its use.
- Swapping a typeface changes apparent size even at the same rem: cap heights differ (Plex 141 against Adwaita 147). Compare typefaces at equal cap height, never at equal point size — at equal point size the ranking of widths comes out wrong.
- Density needs nothing from this theme. Thunderbird's three `uidensity` modes change padding and row heights; Nightjar decides colour, typeface, one line height and a few 1px borders. The spaces rail is not an exception — it sizes icons through `--spaces-icon-size` (16/20/24) and SVG scales. A density-varying `--nj-leading-normal` was written and removed: set to 3 under `[uidensity="compact"]` it changed nothing, because list rows carry their own line height.
- Screenshot diffing against the live mailbox is worthless for anything subtle, and it fooled three separate density measurements in one sitting: mail arrives between captures and whole rows shift, the spaces rail is sometimes hidden and sometimes not, and both swamp the effect being measured. Isolate the change instead — exaggerate the value until the answer is unmistakable, or compare artwork offline.
- Thunderbird applies `mail.uifontsize` as an inline `font-size` on the root element, and a user stylesheet's `!important` beats an author's inline style — so a `font-size` on `:root` in this theme disables the size control in Settings entirely, at every setting. The theme sets no root font size for that reason. Beware the general shape: overriding a property the application exposes a control for takes the control away, and the symptom is a setting that does nothing rather than anything visibly broken.
- Every `--nj-*` the theme declares must be read somewhere; `bin/check.sh` enforces it. Seven were not, including a four-step type scale with a single consumer.
- `colors.css` holds two kinds of thing. The raw scale (`--color-blue-50`, `--color-gray-70`) is never overridden — components pick from it for meaning. The roles (`--color-primary-*`, `--color-surface-*`) are, since decision 014: they are the primary action color and the surface ramp, read across 18 and 10 stylesheets, and they behave like semantic tokens that merely live in the wrong file. Judge a token by what it is, not by which file declares it.
- The account hub cannot be reached from a script through the menus — XWayland does not capture menu popups, so driving them blind is guesswork. It opens by itself in a profile with no accounts: `thunderbird --profile <tmp> --new-instance`, with `chrome` symlinked to `src/` and the two stylesheet prefs written. Do not set `mail.provider.suppress_dialog_on_startup`, which is what suppresses it. Real mail stays out of the test.
- The token reference covers three chrome packages: `messenger/skin`, `messenger/content` and `calendar/skin`. Each was added only after a surface could not be themed because its names were refused as invented. Assume a fourth exists before assuming a name is fake.
- Thunderbird is not consistent about case. The messenger skin is kebab-case throughout; the calendar declares a camelCase `--view*` family. The tooling matched `--[a-z0-9-]+` and silently dropped all thirty of them, along with 95 other names — a lowercase-only character class is the kind of bug that makes a generated reference quietly incomplete rather than wrong.
- The calendar's `--view*` family mostly derives from `--layout-*` and `--selected-item-color`, so the grid follows the theme for free. What does not: the selected day column mixes the accent at 25% and paints the whole column with it, and the drag feedback is a fixed `--color-blue-50`.
- Thunderbird declares custom properties outside the skin. `chrome://messenger/content/messenger/aboutDialog.css` holds `--dialog-background`, `--client-box-background` and `--dialog-box-color`, which is why the About dialog stayed grey while every other dialog was themed — the reference had scoped itself to the skin, so those names were refused as invented. Six properties across six files, now covered.
- Thunderbird's dark-friendly values are consistently gated behind `:root[lwtheme]` or `:root[lwt-tree]`, and the built-in default theme sets neither. Wherever a stylesheet reads "system keyword, with a nice alternative under `[lwtheme]`", the system keyword is what the theme actually gets. Seen on the top band (009), the dialog windows (012) and the compose address rows — assume it rather than rediscovering it.
- `bin/check.sh` strips CSS comments before every content check, so comments may name a removed id, quote a raw color or show a disabled `@font-face` without tripping anything. Do not reword a comment to satisfy a check — that inverts the relationship.
- `set -o pipefail` plus `grep -q` is a trap in these scripts: grep exits on the first match, the left side of the pipe takes SIGPIPE, and the pipeline reports 141 even though the match succeeded. Build the haystack into a variable and use a `case` match instead.
- A rule can be correct, important, and in the right document, and still do nothing: a natively painted widget ignores `background-color`. The toolkit gives `richlistbox` `appearance: auto` with `-moz-default-appearance: listbox`, and only `appearance: none` lets a background through. `tree` does not need it. That is the third failure mode, alongside a missing `!important` and the wrong sheet.
- The standalone dialog windows — filters, folder properties, search, key manager, prompts — are painted by one toolkit rule, `:root { background-color: -moz-Dialog }` in `global-shared.css`, with no token behind it. `layers/chrome.css` answers it at `:root`, which is the broadest selector in the project and reaches every chrome document. The `themeableDialog.css` token family (`--box-*`, `--field-*`, `--primary-focus-border`, `--richlist-button-background`, `--tab-*-background`) is real and consumed, but declared as system keywords and only mapped to Thunderbird's primitives under `:root[lwtheme]` — the same gate as the top band.
- Thunderbird draws its own titlebar on the main window only: `CustomTitlebar` lives in `messenger.js`, loaded by `messenger.xhtml` alone, and `mail.tabs.drawInTitlebar` governs nothing else. Every secondary window gets a window-manager decoration, and no stylesheet can reach it — CSS sets no attributes and the decoration is negotiated at window creation. Decision 011 meets it from the desktop side instead.
- Thunderbird runs **Wayland-native** on the development machine. This matters far beyond screenshots: `WM_WINDOW_ROLE` and the rest of the X11 property surface do not exist, `xdotool` cannot send keys or read windows, and `import -window root` captures nothing because the decoration is composited on the Wayland side. Use `spectacle -b -n -f`, open windows through command-line flags (`thunderbird -compose`) instead of key injection, and ask KWin what it sees with a scripting dump rather than `xprop`. Forcing `GDK_BACKEND=x11` is fine for capturing the *client area*, and actively misleading for anything the window manager owns.
- KWin identifies Thunderbird as `org.mozilla.Thunderbird`, not `thunderbird`, and its substring matching is case-sensitive — so a rule written for the lowercase name matches nothing, silently. A KWin rule that does not match looks exactly like one that matched and did nothing; bisect with `noborder`, whose effect is unmistakable, before suspecting the property you actually want.
- Thunderbird 153 has its own dark message mode, a toggle in the message header, and it rewrites a sender's colors on its own. Do not read that as the theme repainting mail: verified identical with and without Nightjar's tokens present.
- Editing requires a full Thunderbird quit, not just closing the window. The look-at-it step can be scripted rather than done by hand — see `docs/development.md` — which is what makes a before/after comparison of two candidate colors cheap enough to be worth doing.

## Canonical documentation

- `README.md`: what Nightjar is, how to install it, how it is laid out.
- `AGENTS.md`: rules for AI agents working in this repository.
- `docs/development.md`: the edit loop, the Browser Toolbox, why `!important` is everywhere, icon and font rules.
- `docs/thunderbird-tokens.md`: generated list of overridable custom properties.

## Maintenance

Update this file whenever a code or configuration change makes it inaccurate. Remove obsolete information instead of preserving an informal changelog; Git already stores the history.
