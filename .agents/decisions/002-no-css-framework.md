# Architectural decision: no CSS framework and no build step

- Status: accepted
- Date: 2026-08-07
- Supersedes: none
- Superseded by: none
- Amended by: [004 — icons are inlined as data URIs by a generation step](004-icons-as-data-uris.md)

> **Amendment (004).** "No build step" holds for CSS but not for icons. Gecko
> resolves a relative `url()` inside a custom property against the *consuming*
> stylesheet, which for `--icon-*` is `chrome://messenger/skin/`, so icon paths
> must be absolute. `bin/build-icons.sh` inlines the artwork as data URIs. The
> generated file is committed and imported directly, so the working tree is
> still exactly what Thunderbird loads.

## Context

The obvious question at the start of a CSS project is which framework or
preprocessor to use. For a Thunderbird theme the usual answers do not apply:

- **Utility frameworks (Tailwind, Bootstrap, Open Props' class layer)** work by
  putting classes on elements you author. Nightjar authors no markup. It styles
  a DOM built by Thunderbird, reachable only through Thunderbird's own selectors
  and custom properties. There is nowhere to put a utility class.
- **Autoprefixing and browser-compat tooling** target multiple engines. The only
  engine here is the Gecko build shipped with Thunderbird — a single, known
  version. Prefixing is dead weight.
- **Preprocessors (Sass, Less)** are bought mainly for variables, nesting, and
  partials. Gecko 153 has native custom properties, native nesting, and native
  `@import`. Thunderbird itself is built on custom properties, so its tokens are
  the integration surface: a Sass variable cannot override
  `--sidebar-background`, only a CSS custom property can.
- **A bundler** would add a compile step between the working tree and the
  running application, which is exactly the drift the symlink install avoids.

## Decision

Plain CSS, no dependencies, no build step. Structure comes from `@import` in
`src/userChrome.css`: `tokens/` define values, `layers/` consume them.

## Alternatives considered

### Sass with a watch task

- Advantages: partials and nesting for authors who prefer the syntax; can emit a single concatenated file.
- Disadvantages: introduces Node and a watch process; compiled output must be written somewhere Thunderbird reads, so the working tree stops being the installed theme; buys features CSS already has.
- Reason not chosen: cost without benefit.

### PostCSS with an import-inlining plugin

- Advantages: one flat `userChrome.css`, marginally fewer file reads at startup.
- Disadvantages: a dependency tree and a build step to save a handful of local file reads at startup.
- Reason not chosen: the optimization is not measurable here.

## Consequences

### Positive

- Zero dependencies. Nothing to audit, update, or break.
- The file Thunderbird reads is the file in the editor, which makes the
  Browser Toolbox's Rules panel point at real source lines.
- Anyone who knows CSS can contribute; there is nothing else to learn.

### Negative or trade-offs

- No linting or automated checks. Style discipline is enforced by review and by
  the rules in `AGENTS.md`.
- No dead-code detection: a rule whose selector Thunderbird has renamed simply
  stops applying, silently.
- `@import` chains are resolved at load time and their order is load-bearing.

## Verification

- No `package.json`, lockfile, or `node_modules` in the repository.
- `src/userChrome.css` contains only `@import` statements and a `color-scheme` declaration.
- Every stylesheet under `src/` is valid CSS with no preprocessor syntax.

## References

- `src/userChrome.css` — the import order that replaces a build.
- `docs/development.md` — the edit loop this decision makes possible.
