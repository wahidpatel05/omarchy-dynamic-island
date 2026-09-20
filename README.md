# Dynamic Island for Omarchy

A macOS-style Dynamic Island that **replaces** the Omarchy bar. A floating pill
at the top of the screen that grows album art and a waveform when music plays,
springs open for notifications, takes over the system volume and brightness
HUDs, and expands into a control centre on click.

![The island at rest](docs/island-rest.png)

![A notification](docs/island-notification.png)

![A volume HUD](docs/island-hud.png)

![The control centre](docs/island-control-centre.png)

Everything in it is optional. You choose which modules sit in the pill, which
appear on hover, which events are allowed to take the island over, and what the
control centre contains.

---

## Requirements

- **Omarchy 4.0+** (needs the shell plugin system and `kind: "bar"` plugins)
- Hyprland, Quickshell 0.3+, Qt 6.6+
- A Nerd Font for the glyphs — Omarchy ships one by default
- `brightnessctl`, optionally, for the brightness slider

## Install

```bash
omarchy plugin add https://github.com/wahidpatel05/omarchy-dynamic-island.git
omarchy bar use wahidpatel.dynamic-island
```

`omarchy plugin add` clones the repo into `~/.config/omarchy/plugins/` and
leaves it disabled so you can read the code first. `omarchy bar use` is what
actually swaps your bar for the island.

> Plugins run unsandboxed inside `omarchy-shell`, with your user account. Read
> the source of anything you install, including this.

### Going back

The island is just the active bar option, so reverting is one command:

```bash
omarchy bar use omarchy.bar     # or your own bar's id
```

Your previous layout is untouched — it stays in `bar.layout` in
`~/.config/omarchy/shell.json` and comes straight back.

### Updating

```bash
omarchy plugin update wahidpatel.dynamic-island
```

---

## Configuring

Everything lives under `bar.island` in `~/.config/omarchy/shell.json`, and
**hot-reloads on save** — no restart.

```jsonc
{
  "bar": {
    "id": "wahidpatel.dynamic-island",
    "position": "top",
    "island": {
      "collapsed": ["albumArt", "clock", "workspaces", "waveform"],
      "hover": ["albumArt", "media", "mediaControls", "volume", "battery"],
      "expanded": ["media", "sliders", "notifications"]
    }
  }
}
```

Anything you leave out keeps its default. Arrays replace wholesale — writing
`"collapsed": ["clock"]` means *only* the clock.

There are ready-made configs in [`examples/`](examples/).

### Modules

Used in `collapsed` and `hover`.

| Name | Shows | Options |
|---|---|---|
| `albumArt` | Album art, on the pill's leading edge. Invisible with nothing playing. Click toggles playback | — |
| `waveform` | Playback visualiser. Moves while playing, settles flat when paused. Click skips | `bars` |
| `mediaControls` | Previous / play-pause / next | — |
| `clock` | Time | `format` (Qt date format, default `h:mm AP`) |
| `workspaces` | Hyprland workspaces as dots; focused one stretches | `showEmpty`, `max` |
| `media` | Now-playing title with dancing bars. Hidden when nothing plays. Click toggles, middle-click skips | `maxTitleWidth` |
| `volume` / `audio` | Output volume glyph. Click mutes | `showPercentage` |
| `battery` | Charge glyph and percentage. Hidden on desktops | `showPercentage`, `warnBelow` |

Per-module options go in `modules`:

```jsonc
"modules": {
  "clock": { "format": "HH:mm" },
  "battery": { "warnBelow": 15, "showPercentage": false }
}
```

### Activities

Transient events that take the island over. Highest priority wins when several
arrive at once.

| Name | Priority | Trigger |
|---|---|---|
| `volume` | 60 | Output volume or mute changes |
| `brightness` | 60 | Backlight changes |
| `notification` | 50 | A notification arrives |
| `power` | 40 | Charger plugged or unplugged, or battery runs low |
| `media` | 20 | The track changes while playing |

Volume and brightness sit above notifications on purpose: you just pressed a
key and want to see the result, so the HUD preempts rather than queues.

```jsonc
"activities": {
  "notification": { "enabled": true, "maxBodyLines": 2, "pauseOnHover": true },
  "volume":       { "enabled": true, "duration": 1500 },
  "brightness":   { "enabled": true, "duration": 1500 },
  "power":        { "enabled": true, "warnBelow": 20 },
  "media":        { "enabled": true, "duration": 2600 }
}
```

Hovering the island pauses a notification's dismissal countdown. Clicking it
dismisses it.

### Control centre

Click the island — or bind the IPC call below — to open it. Sections are listed
in `expanded`, top to bottom:

- `media` — album art, title, scrubber, transport
- `sliders` — volume, and brightness where a backlight exists
- `notifications` — the recent few

### Shape and motion

```jsonc
"shape": {
  "collapsedWidth": 210,
  "collapsedHeight": 34,
  "radiusBottom": 17,
  "radiusTop": 17,
  "fillet": 15,
  "curvature": 5,
  "topInset": 9
},
"motion": {
  "response": 0.42,
  "damping": 0.72
}
```

`curvature` is the superellipse exponent for the corners. `2` gives ordinary
circular corners; `5` is the continuous-curvature shape Apple uses; past `8` it
starts to read as a bevel.

`topInset` is the gap between the island and the screen edge. It defaults to
`9`, so the island **floats**. Set it to `0` to sit flush against the bezel like
a MacBook notch — at which point `fillet` kicks in, drawing concave shoulders
that blend the island into the top edge. Floating ignores `fillet`, because
there is no edge left to blend into. See [`examples/notch.json`](examples/notch.json).

`motion` is a real spring, not an easing preset. `response` is roughly the time
in seconds to first reach the target, and `damping` controls overshoot: `1.0`
settles dead, `0.72` gives a ~4% pop, below `0.5` visibly bounces.

### Appearance

```jsonc
"style": {
  "darken": 0.55,
  "opacity": 1.0,
  "accent": ""
}
```

Colours follow the active Omarchy theme. `darken` is how much of the theme
background to keep — the island defaults to darkening toward black so it reads
as hardware rather than as a panel. Set any colour explicitly to override.

### Behaviour

```jsonc
"behaviour": {
  "reserveSpace": true,
  "monitors": "focused",
  "expandOnHover": true,
  "closeOnLeave": true,
  "scrollGestures": true,
  "captureOmarchyOsd": false
}
```

`reserveSpace` reserves screen space for the *resting* height only, so windows
tile below the pill and the island expands over them — a notification never
reflows your desktop. Set it `false` to make the island a pure overlay.

`monitors` takes `"focused"`, `"all"`, or a connector name like `"DP-1"`.

---

## HUDs: replacing the system OSD

Out of the box the island watches PipeWire and the backlight directly, so
volume and brightness changes appear in the island however they were made — a
media key, `wpctl`, a mixer, another app. Omarchy's own OSD is still running
though, so you will see **both**.

To make the island the only HUD, hand it Omarchy's OSD stream:

```bash
omarchy plugin disable omarchy.osd
```

```jsonc
"behaviour": { "captureOmarchyOsd": true }
```

This is better than simply disabling Omarchy's OSD and leaving it at that.
Omarchy's OSD serves more than volume and brightness — microphone mute,
keyboard backlight, touchpad toggle, audio output switching — and the island
only watches the first two on its own. Capturing the stream means *every* OSD
Omarchy would have shown is drawn by the island instead, so nothing is lost.

Turn both on together. Two handlers cannot share the `osd` IPC target and the
winner is decided by registration order, so enabling capture while Omarchy's
OSD is still running is a coin flip rather than an upgrade. When capture is on,
the island's own volume and brightness watchers stand down, since the captured
stream already carries them.

---

## Gestures

With the pointer over the island:

| Gesture | Does |
|---|---|
| Scroll up / down | Volume up / down |
| Shift-scroll, or horizontal scroll | Next / previous track |
| Click | Open the control centre |
| Click during a notification | Dismiss it |
| Click the album art | Play / pause |
| Click the waveform | Next track |

Turn the wheel bindings off with `"behaviour": { "scrollGestures": false }`.

---

## Notifications

By default the island **mirrors** Omarchy's notification service. You get the
island card *and* the usual corner toast, and history, do-not-disturb and the
notification panel all keep working.

For island-only notifications, hand it the bus:

```bash
omarchy plugin disable omarchy.notifications
```

```jsonc
"activities": { "notification": { "source": "own" } }
```

Only one process on the session can own `org.freedesktop.Notifications`, so do
both or neither. There is deliberately no auto-detect: the shell mounts plugin
services several seconds after the bar, which makes "is Omarchy's service
running?" unanswerable at startup, and guessing wrong means two servers racing
for the bus on every login.

Note that `source: "own"` gives up Omarchy's notification history and DND.

---

## Keybinding

The island exposes an IPC target:

```bash
omarchy-shell island toggle     # open/close the control centre
omarchy-shell island expand
omarchy-shell island collapse
omarchy-shell island state
```

Bind it in `~/.config/hypr/bindings.lua`:

```lua
o.bind("SUPER", "I", "omarchy-shell island toggle")
```

---

## Troubleshooting

**The bar disappeared and nothing came back.** Omarchy falls back to the
built-in bar if a bar plugin fails to load. Check for errors:

```bash
journalctl --user -t omarchy-shell -n 50 | grep dynamic-island
```

**Changes to `shell.json` do nothing.** The island hot-reloads config, but
editing the plugin's own QML needs `omarchy restart shell`. Note that
`.pragma library` JavaScript is cached by the QML engine, so a rescan is not
always enough.

**Glyphs render as boxes.** The modules use Nerd Font glyphs; make sure your
terminal/system font is a Nerd Font variant.

---

## Development

```bash
git clone https://github.com/wahidpatel05/omarchy-dynamic-island.git
ln -s "$PWD/omarchy-dynamic-island" ~/.config/omarchy/plugins/wahidpatel.dynamic-island
omarchy-shell shell rescanPlugins
omarchy bar use wahidpatel.dynamic-island
```

Layout:

```
Island.qml          plugin root: config, colours, activity routing, IPC
Core/               geometry, motion, OSD icon names, the morphing window, shared widgets
Modules/            things that sit in the pill
Activities/         things that take the island over
Expanded/           the control centre
Services/           notification, media and brightness sources
```

Two things worth knowing before you touch the animation code:

- **Qt's bezier easing corrupts the heap above 10 cubic segments.**
  `BezierEase` preallocates exactly 10 slots and never bounds-checks them, so a
  longer spline smears over adjacent allocations and the process dies later,
  somewhere unrelated. `Core/Motion.js` caps at 10 deliberately.
- **Never size anything from a word-wrapped `Text`'s `implicitWidth`.** It is
  derived from the width you gave it, so it closes a binding loop — and with a
  `Behavior` on the far end, that loop recurses until the stack gives out. Use
  `TextMetrics` to measure instead.

## License

MIT — see [LICENSE](LICENSE).
