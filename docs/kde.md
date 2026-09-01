# The window decoration, on KDE

Optional, and not part of the theme. Skip it unless the titlebar on
Thunderbird's secondary windows bothers you.

## The problem

Thunderbird draws its own titlebar on the main window. It does not on any
other. The code that asks for it, `CustomTitlebar` in
`chrome://messenger/content/messenger.js`, is loaded by `messenger.xhtml` alone,
and `mail.tabs.drawInTitlebar` only governs that window. Every secondary window
— compose above all — is decorated by the window manager instead.

Measured on the development machine, before any of this:

| Window | What the window manager reports |
| --- | --- |
| Main | `_MOTIF_WM_HINTS` decorations `0` — no frame drawn |
| Compose | `_NET_FRAME_EXTENTS = 0, 0, 28, 0` — a 28px bar on top |

So the compose window wears 28 pixels of the desktop's color, `rgb(39, 44, 49)`
under Breeze Dark, directly above a window whose own top band is
`rgb(14, 19, 26)`.

**A user stylesheet cannot fix this.** CSS sets no attributes, runs no script,
and the decoration is negotiated between the toolkit and the window manager when
the window is created. It is the same class of wall as the per-document CSP in
[decision 008](../.agents/decisions/008-icon-reach-and-the-add-on-question.md):
real, and outside what a stylesheet can reach.

It can be closed from the other side, by telling the window manager to paint
those windows' decorations in the theme's colors.

## The recipe

Install the color scheme, which is `[WM]` colors only and leaves the rest of
your desktop alone:

```bash
mkdir -p ~/.local/share/color-schemes
cp contrib/kde/Nightjar.colors ~/.local/share/color-schemes/
```

Add the KWin rule that points Thunderbird's windows at it. Importing is the
safe route, because it merges with any rules you already have:

*System Settings → Window Management → Window Rules → Import…* and pick
`contrib/kde/nightjar.kwinrule`, then:

```bash
qdbus6 org.kde.KWin /KWin reconfigure
```

If you have no rules of your own, the same thing from the shell:

```bash
kwriteconfig6 --file kwinrulesrc --group 1 --key Description "Nightjar — Thunderbird window decoration"
kwriteconfig6 --file kwinrulesrc --group 1 --key wmclass "org.mozilla.Thunderbird"
kwriteconfig6 --file kwinrulesrc --group 1 --key wmclassmatch 1
kwriteconfig6 --file kwinrulesrc --group 1 --key wmclasscomplete false
kwriteconfig6 --file kwinrulesrc --group 1 --key decocolor "Nightjar"
kwriteconfig6 --file kwinrulesrc --group 1 --key decocolorrule 2
kwriteconfig6 --file kwinrulesrc --group General --key count 1
kwriteconfig6 --file kwinrulesrc --group General --key rules 1

qdbus6 org.kde.KWin /KWin reconfigure
```

Do not append the `.kwinrule` file to `~/.config/kwinrulesrc` by hand: its group
name and the `[General]` index would collide with a rule you already have.

Open a compose window. The titlebar should be `rgb(14, 19, 26)` — the same ink
as the window under it — with the buttons and the drag area still there. The
same goes for every other window Thunderbird opens: the key manager, message
filters, folder properties, prompts.

The rule deliberately does not filter by title. The main window is matched too
and the rule is a no-op there, because Thunderbird draws that titlebar itself
and the window manager draws nothing to recolor.

To remove it: delete `~/.local/share/color-schemes/Nightjar.colors`, delete the
rule in the same Window Rules page, and reconfigure.

## Two things that will waste your afternoon

**The window class is not `thunderbird`.** On Wayland, KWin sees the app id from
the desktop file:

```
class=org.mozilla.Thunderbird   name=thunderbird   caption=Write: … - Thunderbird
```

and `wmclass` is matched against the *class*. Worse, substring matching is
case-sensitive, so a rule for `thunderbird` does not match
`org.mozilla.Thunderbird` even as a substring — the capital T is the whole
difference. A rule that does not match fails silently and looks exactly like a
rule that matched and did nothing.

If you need to see what KWin actually thinks a window is, ask it:

```bash
cat > /tmp/dump.js <<'EOF'
workspace.windowList().forEach(w =>
  print("DUMP|class=" + w.resourceClass + "|caption=" + w.caption));
EOF
id=$(qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.loadScript /tmp/dump.js dump)
qdbus6 org.kde.KWin "/Scripting/Script$id" org.kde.kwin.Script.run
journalctl --user -b -n 100 --no-pager | grep DUMP
```

**Do not test this over XWayland.** Thunderbird runs Wayland-native here, and
that is the only configuration that matters for the rule: `WM_WINDOW_ROLE`, the
obvious thing to match on (`Msgcompose`), is an X11 property that does not exist
under Wayland. A rule built and verified against
`GDK_BACKEND=x11 thunderbird` matches nothing in the real session. For the same
reason `import -window root` captures nothing useful — the decoration is drawn
on the Wayland side. Use `spectacle -b -n -f -o shot.png`, which sees it, and
open the window with `thunderbird -compose` rather than injecting a keystroke
with `xdotool`, which cannot reach a Wayland window either.

## Scope

The rule covers every Thunderbird window, which is what you want once more than
the compose window is themed inside. To narrow it to one window instead, add a
*Window title* condition — `Write:` (substring) for compose — bearing in mind
that captions are locale-dependent.

It does not cover anything else on the desktop, and it does not change your
global color scheme: the file sets `[WM]` only, and the rule applies it to one
window class.
