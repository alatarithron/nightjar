# Architectural decision: user stylesheet instead of a static theme add-on

- Status: accepted
- Date: 2026-08-07
- Supersedes: none
- Superseded by: none

## Context

Nightjar must change colors, icon artwork, and UI typography.

Thunderbird offers three ways to restyle the application, verified against the
installation on this machine (Thunderbird 153.0, `/usr/lib/thunderbird/omni.ja`):

1. **Static theme add-on** — `manifest.json` with a `theme` key. The theme
   schema at `chrome/messenger/content/messenger/schemas/theme.json` defines
   exactly 42 color keys, 3 image keys, and 4 properties (`color_scheme`,
   `content_color_scheme`, and background alignment/tiling). Nothing in that
   surface addresses icons or fonts. The shipping "Dark" theme
   (`thunderbird-compact-dark@mozilla.org`) declares only
   `properties.color_scheme: "dark"`.
2. **`theme_experiment`** — present in the same schema. Maps additional keys
   onto internal CSS variables and can load a stylesheet, so it does reach
   icons and fonts. Add-ons using it are reviewed as experiments and pinned
   with `strict_max_version`, breaking on each Thunderbird release.
3. **User stylesheet** — `<profile>/chrome/userChrome.css`, enabled by
   `toolkit.legacyUserProfileCustomizations.stylesheets` (default `false`,
   confirmed in `greprefs.js`). Full CSS access to the chrome document.

Option 1 cannot express the requirement at all. The choice is between 2 and 3.

## Decision

Develop Nightjar as a user stylesheet: `src/` is symlinked to the profile's
`chrome/` directory, `src/userChrome.css` is the entry point.

## Alternatives considered

### Static theme add-on

- Advantages: installable from addons.thunderbird.net; survives upgrades; no pref to flip.
- Disadvantages: 42 color keys and nothing else. No icons, no fonts.
- Reason not chosen: cannot do what the project is for.

### `theme_experiment` add-on

- Advantages: reaches icons and fonts; distributable; keeps the add-on packaging model.
- Disadvantages: version-locked via `strict_max_version`, so every Thunderbird release breaks it until repackaged; reviewed as an experiment on ATN; the extra indirection buys nothing while the audience is one machine.
- Reason not chosen: same maintenance cost as a user stylesheet, plus packaging overhead, for a distribution benefit that is not needed yet.

## Consequences

### Positive

- Unrestricted access to the chrome: colors, icon artwork, typography, layout.
- No build, no packaging, no add-on ID. Edit a file, restart Thunderbird.
- The working tree *is* the installed theme, so there is no way for the two to drift.

### Negative or trade-offs

- Requires flipping `toolkit.legacyUserProfileCustomizations.stylesheets`, which
  Thunderbird treats as an unsupported customization path.
- Not installable by anyone else without cloning the repository and running a script.
- Every declaration that competes with Thunderbird's own stylesheets needs
  `!important`, because user sheets lose the cascade to author sheets.
- Thunderbird's internal selectors and custom properties are not API. Upgrades
  can and will break rules silently.

## Verification

- `src/userChrome.css` exists and is the only entry point referenced by `bin/install.sh`.
- `bin/install.sh` symlinks `src/` to `<profile>/chrome` and writes the pref to `user.js`.
- No `manifest.json` exists in the repository.
- The 42-key limit is reproducible: extract
  `chrome/messenger/content/messenger/schemas/theme.json` from `omni.ja` and read
  the `ThemeType` definition.

## References

- `docs/thunderbird-tokens.md` — generated from the installed Thunderbird.
- `bin/dump-tb-reference.sh` — the generator.
- `docs/development.md` — cascade and `!important` rationale.
