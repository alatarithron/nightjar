# Architectural decision: the roles in `colors.css` are overridden; the scale is not

- Status: accepted
- Date: 2026-08-09
- Supersedes: none
- Superseded by: none
- Amends: the "Color primitives" rule recorded in `docs/thunderbird-tokens.md`
  and `.agents/PROJECT_MEMORY.md`

## Context

The account hub's sign-in button was `#58c9ff` and the dialog sat on a cyan
glow, while everything around it was ink. The obvious target was the
`--hub-*` family: 113 properties, 90 of them live. Almost all of those are
spacing and sizing, and the twenty that carry color derive from somewhere else:

```css
--hub-account-primary-button-background: var(--color-primary-default);
--hub-account-secondary-button-background: var(--color-surface-subtle);
--hub-border-color: light-dark(var(--color-primary-soft), var(--color-primary-default));
```

`--color-primary-*` and `--color-surface-*` are declared in
`chrome://messenger/skin/colors.css`, which this project had a standing rule
against touching, recorded in the generated reference itself: *"Nightjar does
not override these — it replaces the semantic layer that consumes them, so
Thunderbird's own components keep working if a primitive is renamed."*

That rule is right, and it was written as if `colors.css` held one kind of
thing. It holds two.

## Decision

The **raw scale** is still not overridden: `--color-blue-50`,
`--color-gray-70`, `--color-ink-40` and the rest of the rungs. Thunderbird's
components pick from the scale for meaning, and repainting a rung changes
things that were never about the theme.

The **roles** are: `--color-primary-default`, `-hover`, `-pressed`, `-soft`,
and `--color-surface-base`, `-subtle`, `-lower`, `-deep`, `-border`,
`-border-intense`. These are not rungs. They are the primary action color and
the surface ramp — semantic tokens that behave exactly like the ones in
`variables.css` and merely live in the wrong file.

Ten declarations, because the reach is the argument: the surface roles are read
in 18 stylesheets and the primary roles in 10 — the account hub, account
settings, downloads, import, the calendar dialogs, extensions. A hundred
`--hub-*` overrides would not have done as much, and would have fixed one
screen.

`--color-surface-raised` is left out; the reference lists it as never consumed.

The hub's glow keeps a selector, because it has no token at all: it is a
literal teal-to-blue gradient on `.account-hub-dialog::after`.

## Alternatives considered

### Override the `--hub-*` colors instead

- Advantages: obeys the existing rule without amending it; blast radius is one
  screen.
- Disadvantages: twenty declarations to fix one screen, and every other surface
  reading the same roles — account settings, downloads, import, the calendar
  dialogs — stays blue. The rule would then have to be argued about again the
  next time one of them came up.
- Reason not chosen: it treats the leaf and leaves the root.

### Override the raw scale as well

- Advantages: nothing would ever arrive in a Thunderbird hue again.
- Disadvantages: the scale carries meaning. `--color-red-60` on an error bar is
  correct in any palette, and flattening the scale into the Nightjar ramp would
  erase distinctions the application relies on.
- Reason not chosen: this is exactly what the original rule protects, and it
  still holds.

## Consequences

### Positive

- Ten declarations theme the account hub and, unverified but by construction,
  every other surface reading the same roles.
- The rule is now stated in terms of what a token *is* rather than which file it
  is in, which is the distinction that actually matters.

### Negative or trade-offs

- The boundary is now a judgement rather than a filename, and judgement rots.
  A future Thunderbird could add a role to `colors.css` that is really a rung,
  or vice versa, and nothing mechanical will notice.
- Only the account hub was rendered. The other consumers are reached by
  construction, not by observation.

## Verification

The account hub, opened in a throwaway profile with no accounts — the hub
appears by itself there, which is the only reliable way to reach it without a
menu, and it keeps real mail out of the test:

| Point | Before | After |
| --- | --- | --- |
| Sign-in button border | `rgb(88, 201, 255)` — `#58c9ff` | `rgb(221, 156, 52)` — `--nj-amber-500` |
| Glow under the dialog | `rgb(11, 64, 76)` | `rgb(122, 95, 51)` |

`bin/check.sh`: all 16 checks pass.

## References

- `src/tokens/semantic.css`, `src/layers/chrome.css`.
- `chrome://messenger/skin/colors.css`, `accountHub.css`.
