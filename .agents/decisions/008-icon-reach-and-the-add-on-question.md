# Architectural decision: how far icons reach, and whether that justifies an add-on

- Status: accepted
- Date: 2026-08-09
- Supersedes: none
- Superseded by: none
- Amends: [001 — user stylesheet instead of a static theme add-on](001-user-stylesheet-over-static-theme.md),
  [004 — icons are inlined as data URIs](004-icons-as-data-uris.md)

## Context

The compose window's Send button rendered no icon. The cause is not the artwork,
the cascade, the context paint or the CSS property: **Thunderbird sets a
Content-Security-Policy per document, and `img-src` decides whether a `data:`
URI loads at all.**

```
messenger.xhtml         img-src chrome: data: moz-icon: https://addons.thunderbird.net
messengercompose.xhtml  img-src chrome: moz-icon:
```

Decision 004 chose `data:` URIs to escape Gecko resolving a relative `url()`
against the consuming stylesheet. It solves that, and it was verified in the
folder pane — which is `about3Pane.xhtml`, a document whose policy happens to
allow `data:`. The assumption that this generalised was never tested. It does
not.

### How it was established

By substitution, against a running Thunderbird, not by reading CSS:

| Test | Result |
| --- | --- |
| `list-style-image` with a Nightjar data URI, compose | blank |
| the same, with `chrome://…/sent.svg` | renders |
| a plain square painted a literal colour, `data:`, compose | blank |
| the same square via `background-image`, compose | blank |
| a `data:` background on `#unifiedToolbar`, main window | renders |
| theme uninstalled, compose | renders |

The literal-colour square is what rules out context paint: no context value is
involved and it still does not load. The main window rendering the same kind of
URI is what rules out "privileged chrome documents block `data:`", which was the
working theory until it was tested.

Thunderbird's own `sent.svg` uses the same two-tone context paint as Nightjar's.
Only the URI scheme differs.

## Measurement, and why it was withdrawn

A first attempt mapped every `--icon-*` to the documents that consume it, by
resolving the `@import` graph from each document's linked stylesheets, then
classifying each document by whether its CSP admits `data:`. It reported 35
properties as safe, 124 as partial and 12 as unreachable.

**Those numbers were wrong and are withdrawn.** Consumption through the import
graph is not display. Nearly every document imports a shared base stylesheet
that references many icons, so the method attributed the whole icon vocabulary
to dialogs that never draw one — `EdColorPicker.xhtml` was credited with the
inbox icon. Restricting the analysis to directly linked stylesheets did not fix
it either: every document links `icons.css`, which is where the properties are
declared.

A sound under-approximation was tried next: an `#id` rule referencing an icon,
in a stylesheet the document links, where that id exists in the document's
markup. It never over-reports, and it found two properties — missing
`--icon-sent`, which had already been observed blank on screen. So it
under-reports badly enough to be useless as a gate.

The honest conclusion is that **whether a replaced icon is actually displayed in
a given window is not decidable from the static sources** with the effort this
project can justify. It needs the running application, which is what
`docs/development.md` already says about visual validation.

What is established, and is enough to decide:

- The mechanism is a per-document CSP `img-src`. Verified by substitution.
- At least one icon consumed by a refusing document is a prominent control —
  `--icon-sent` on the compose window's Send button. Observed directly.
- The refusing documents include `messengercompose.xhtml`, and the admitting
  ones include `messenger.xhtml` and `about3Pane.xhtml`. Read from the policies.

## Decision

**Stay a user stylesheet. Add an icon only after seeing it render in the
windows that use it, and drop one found blank in a window that matters.**

There is no automated gate for this. Two were attempted and both are recorded
above as failures; shipping either would have rejected correct work or granted
false confidence, and a check that is wrong is worse than no check.

The add-on was the reason to revisit decision 001, and it does not survive
contact with the evidence. A MailExtension's assets are served from
`moz-extension://`, and `img-src chrome: moz-icon:` admits that no more than it
admits `data:`. Migrating would buy nothing for the 124 unless the add-on also
registered a `chrome://` package through an Experiment API — a much deeper
mechanism, reviewed as an experiment and version-locked with
`strict_max_version`, for a benefit that is now measured rather than assumed.

Decision 001 stands. Its reasoning is amended, not reversed: the user stylesheet
does not in fact reach everything, and that limit is a CSP, which an add-on does
not lift either.

## Consequences

- **The icon roadmap has no number.** 223 is what Thunderbird declares, and it
  was never the count of what this project can replace. How many are actually
  replaceable is unknown, and each one is answered by looking.
- **`--icon-sent` is dropped.** It was correct in the folder pane and empty on
  the compose window's Send button, which is a control the user looks at every
  time they write mail. A missing icon there reads as a broken theme, so the
  artwork is removed and Thunderbird's own is left in place.
- **The trap stays invisible to CI.** Nothing mechanical will catch the next
  icon that lands in a refusing document; only opening the window will. That is
  a real weakness of this decision and is stated rather than papered over.
- **Decision 004 keeps its reasoning and loses its scope.** Data URIs remain the
  right answer to relative-URL resolution. They are not a way to reach every
  document.

## Alternatives considered

- **Ship the artwork under `chrome://`.** Allowed by every policy observed, and
  unavailable to a user stylesheet: registering a chrome package needs an add-on,
  and `chrome.manifest` in the profile no longer exists.
- **Accept blanks in the refusing documents.** Rejected. It converts a theme with
  fewer icons into a theme that looks defective.
- **Override the CSP.** A user stylesheet cannot, and a pref that disabled
  document CSP globally would be a security control turned off for cosmetics.

## Verification

The substitution table above, each row observed in a running Thunderbird 153.0
and captured. The counts come from resolving the stylesheet import graph across
the 197 documents and 647 stylesheets in `omni.ja` and classifying each by its
declared policy; documents without a CSP are counted as permitting `data:`.

## References

- [001 — user stylesheet instead of a static theme add-on](001-user-stylesheet-over-static-theme.md)
- [004 — icons are inlined as data URIs](004-icons-as-data-uris.md)
- [005 — how replaced icons take color](005-icon-color-reactivity.md)
