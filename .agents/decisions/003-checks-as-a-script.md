# Architectural decision: checks live in a script, not in a linter

- Status: accepted
- Date: 2026-08-07
- Supersedes: none
- Superseded by: none

## Context

The project has no test suite — a theme is validated by looking at it. That
leaves a gap: the failure mode of this codebase is not a crash, it is a rule
that silently stops applying. A typo in a custom property name, a missing
`!important`, an icon with a hardcoded fill: all three parse as valid CSS and
all three do nothing at runtime.

Stylelint, the obvious candidate, checks CSS *syntax*. It cannot know that
`--sidebar-backgrund` is not a property Thunderbird declares, and it costs a
Node toolchain and a dependency tree in a project that otherwise has neither.

## Decision

Checks are a dependency-free Bash script, `bin/check.sh`. GitHub Actions runs
that same script and nothing else, so local and remote CI cannot diverge.

The script enforces the invariants in `.agents/PROJECT_MEMORY.md`:

1. Every overridden custom property exists in `docs/thunderbird-tokens.md`.
2. Every id and custom element `src/` selects on exists in Thunderbird
   (added by [decision 009](009-top-band-belongs-to-the-theme.md), which found a
   selector that had never matched anything).
3. Raw color values appear only in `tokens/palette.css`.
4. Every override in `tokens/semantic.css` carries `!important`.
5. Icon artwork uses `context-fill` and carries no script or external reference.
6. No stylesheet is orphaned from the import graph.
7. Braces balance; whitespace is clean.
8. `shellcheck` passes, when installed.
9. No Thunderbird profile artifacts are in the repository.

## Alternatives considered

### Stylelint

- Advantages: mature; catches genuine syntax errors; editor integration.
- Disadvantages: adds Node, a lockfile, and a dependency tree to a project with none; cannot check any of the nine rules above, which are about Thunderbird's internals rather than CSS grammar.
- Reason not chosen: it does not cover the failures this project actually has.

### No CI at all

- Advantages: nothing to maintain.
- Disadvantages: the invariants exist either way; unenforced, they decay quietly, and the symptom appears weeks later as "that rule stopped working".
- Reason not chosen: the checks are cheap and the failure mode is silent.

### Rendering screenshots in CI

- Advantages: would catch visual regressions, the thing that actually matters.
- Disadvantages: requires a Thunderbird install, a display server, a real profile, and stable pixel output across versions; profiles hold personal mail.
- Reason not chosen: cost and privacy risk far exceed the benefit at this size.

## Consequences

### Positive

- One command, `bin/check.sh`, is the whole quality gate, locally and in CI.
- Rules that only make sense for a Thunderbird theme are actually enforced.
- No dependencies, so the checks cannot rot independently of the project.

### Negative or trade-offs

- Bash grep-based checks are approximations. They read declarations after
  stripping comments and splitting on `;{}`, which is not a CSS parser, and they
  will not catch every malformed construct. The comment stripper is an `awk`
  state machine over `/*` and `*/`; it would mangle those sequences inside a CSS
  string, which this project has none of.
- The token check is only as current as `docs/thunderbird-tokens.md`. A stale
  reference approves overrides that a newer Thunderbird has since removed.
- CI cannot verify anything visual. A theme that passes every check can still
  look wrong.

Comments are removed before any of the content checks read a stylesheet. That
was not true at first, and the cost showed up quickly: three separate comments
had to be reworded — an id spelled without its `#`, color channels written
without `rgb()`, a commented-out `@font-face` demanding a file — because the
checks were reading prose as code. Checks that dictate how the code is explained
are checks that will eventually be worked around instead of fixed.

## Verification

- `bin/check.sh` exits non-zero on a violation. Verified by introducing a
  misspelled token and a declaration without `!important`, confirming each is
  reported, and confirming a clean tree passes all checks.
- `.github/workflows/ci.yml` invokes `bin/check.sh` and defines no checks of its own.
- No `package.json` or lockfile exists in the repository.

## References

- `bin/check.sh`
- `.github/workflows/ci.yml`
- `.agents/PROJECT_MEMORY.md` — the invariants being enforced.

## Amendment, 2026-08-09: a check that skips is a check that passes

Two extraction bugs, found within an hour of each other, had the same shape:
the check reported success on input it had silently declined to read.

`--[a-z0-9-]+` matched no camelCase property, so the calendar's thirty-strong
`--view*` family — and 95 names besides — never entered the generated reference
and could never be overridden. And the selector extractor required a `{` or `,`
directly after an element name, so `notification-message[type="warning"]` was
skipped: a real selector against a real element, unverified, while check 3
printed `ok`.

Neither produced a wrong answer. Both produced a narrower question than the one
the check claims to ask, which is worse, because the output is indistinguishable
from the check working. When a check passes on a construct that is new to the
codebase, confirm it was actually read before believing it.
