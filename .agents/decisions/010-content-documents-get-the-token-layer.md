# Architectural decision: content documents get the token layer too

- Status: accepted
- Date: 2026-08-09
- Supersedes: none
- Superseded by: none
- Amends: [003 — checks live in a script, not in a linter](003-checks-as-a-script.md)

## Context

The address book's **New Contact** button was `rgb(61, 174, 233)`. That is
`#3daee9`, the Breeze highlight — the desktop's accent color, arriving through
`AccentColor`:

```css
/* chrome://messenger/skin/shared/variables.css */
--selected-item-color: var(--sidebar-highlight-background-color, AccentColor);
--button-primary-background-color: var(--selected-item-color);
```

`tokens/semantic.css` already sets `--selected-item-color` to `--nj-amber-500`,
and the button is an ordinary `class="button button-primary"` reading it through
`widgets.css`. Every link in the chain was already Nightjar's. The button was
blue anyway.

The reason is the document, not the cascade. `about:addressbook` is a **content**
document, and `userChrome.css` does not apply to content. `userContent.css`
does — and it imported `tokens/palette.css` alone. The whole semantic layer, 150
overrides, stopped at the chrome boundary, so every one of those tokens fell
back to Thunderbird's default inside that page.

That was measured rather than reasoned about. The same rule was put in both
sheets with different colors and the page was rendered:

| Sheet | Declaration | Result |
| --- | --- | --- |
| `layers/chrome.css` | `#booksPaneCreateContact { background-color: var(--nj-green-400) }` | not applied |
| `userContent.css` | `#booksPaneCreateContact { background-color: var(--nj-rose-500) }` | **applied** — `rgb(220, 95, 95)` on screen |

So the button was never the problem. It was the visible end of an entire page
outside the theme, which is also why the contact list behind it was toolkit
grey (`#18181b`, `#38383d`) rather than ink.

## Decision

`userContent.css` imports `tokens/semantic.css` as well as `tokens/palette.css`.

```css
@import url("tokens/palette.css");
@import url("tokens/semantic.css");
```

Two lines, no selector, and it reaches every Thunderbird page rendered as
content rather than only the one button that prompted it.

The import is at the top level, so the tokens land on **every** content
document, message bodies included. CSS gives no way to scope an `@import` to a
URL — `@import` must precede other rules, and `@-moz-document` is a block — so
the choice was a global import or a hand-maintained copy of 150 declarations
inside the `about:` block. The copy was rejected: two lists that must agree and
no check that they do is precisely the divergence this project avoids.

The global import is safe because of what is being imported. `semantic.css`
declares nothing but custom properties, and a custom property is inert until
something reads it. Thunderbird's own pages read these names; a sender's HTML
does not. That is the same reasoning under which `palette.css` has been imported
globally since the first commit — this extends an accepted boundary rather than
crossing a new one.

To keep that property from lapsing, `bin/check.sh` gains a check: any ordinary
declaration in `tokens/semantic.css` is a failure. The safety argument is now
enforced instead of asserted.

## Alternatives considered

### Override the button's tokens inside the `about:` block

- Advantages: smallest possible diff; touches nothing but the address book.
- Disadvantages: fixes one button. The contact list, the search field's focus
  ring, the selected row and the pane surfaces were wrong for the same reason
  and would each need their own line, forever.
- Reason not chosen: it treats the symptom. The page was not partly themed, it
  was entirely untouched.

### Copy the token block into the `about:` block

- Advantages: the tokens would reach Thunderbird's pages and provably nothing
  else.
- Disadvantages: 150 declarations in two places, kept in step by hand.
- Reason not chosen: the divergence risk is worse than the risk it removes,
  which the check now bounds anyway.

### Style the button with a selector in `userContent.css`

- Advantages: no new import at all.
- Disadvantages: `#booksPaneCreateContact` is markup, not a token, and decision
  009 has just finished recording what selectors cost across upgrades. The token
  it should have been reading already exists and is already correct.
- Reason not chosen: the token was right; only its reach was wrong.

## Consequences

### Positive

- Thunderbird's content-rendered pages inherit the whole semantic layer, so they
  follow the theme by default instead of one fix at a time. The address book
  went from a blue button on toolkit grey to the theme, in two lines.
- The chrome/content split is now written down and enforced, rather than being
  something the theme discovered one page at a time.

### Negative or trade-offs

- Every content document, including mail, now carries 150 inert custom
  properties. Measured as no visual change (below), but it is a larger surface
  than before and the new check is what keeps it inert.
- The import gives no way to treat Thunderbird's pages differently from a
  sender's. If the theme ever needs a token that is *not* safe in a mail body,
  this decision has to be revisited rather than extended.
- `userChrome.css` and `userContent.css` now both pull the token files, so the
  tokens are parsed twice. Irrelevant at this size, worth knowing.

## Verification

The address book, rendered before and after and sampled:

| Point | Before | After |
| --- | --- | --- |
| New Contact button | `rgb(61, 174, 233)` — Breeze accent | `rgb(221, 156, 52)` — `--nj-amber-500` |
| Contact card | `rgb(56, 56, 61)` | `rgb(21, 28, 38)` |
| List pane | `rgb(24, 24, 27)` | `rgb(19, 25, 34)` |

The search field's focus ring turned amber in the same pass, from
`--focus-outline-color`, which had also never reached the page.

**Message bodies are unaffected, measured rather than argued.** A synthetic
`.eml` was written with a white background, a magenta block and green text, and
opened directly from disk — no profile mail was touched. It was rendered with
the import and without it: **0 pixels differ** between the two captures.

That test also settled something that is not Nightjar's doing and could easily
be blamed on it: the sender's colors are not shown in either capture. That is
Thunderbird 153's own dark message mode, the toggle in the message header, and
it behaves identically with the theme's tokens present or absent.

`bin/check.sh`: all 14 checks pass. The new one was confirmed to bite by adding
an ordinary `background-color` declaration to `semantic.css` and reverting it.

## References

- `src/userContent.css` — the import and the reasoning behind its scope.
- `bin/check.sh` — the check that keeps `semantic.css` inert in mail.
- `chrome://messenger/skin/shared/variables.css`, `widgets.css` — the token
  chain behind `.button-primary`.
- [009 — the top band belongs to the theme](009-top-band-belongs-to-the-theme.md)
  — the other half of "the token was right, its reach was wrong".
