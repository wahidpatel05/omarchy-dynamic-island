.pragma library

// Configuration for the island, and the defaults every unset key falls back to.
//
// The island is a `bar` plugin, so its settings live in the `bar:` subtree of
// ~/.config/omarchy/shell.json under an `island` object. The shell hands that
// subtree to the plugin on load and again on every save, which is what makes
// the whole config hot-reload without a restart.
//
// Resolution is a shallow merge per section rather than a deep one. A user who
// writes `"collapsed": ["clock"]` means *only* the clock — deep-merging arrays
// would leave them fighting the defaults they were trying to replace. Objects
// keyed by name (`modules`, `activities`) do merge per key, because there the
// user is annotating a default rather than replacing the set.

var DEFAULTS = {
    shape: {
        // The resting pill. Sized to sit comfortably under a laptop bezel
        // without looking like a bar that forgot to be full width.
        collapsedWidth: 170,
        collapsedHeight: 30,
        // Corner radii. A radius of roughly 0.3x the height is the proportion
        // macOS uses for the notch and for the glass capsules beside it — a
        // rounded rectangle rather than a true capsule. Raise both to half the
        // height for a full capsule instead.
        radiusBottom: 9,
        radiusTop: 9,
        // Concave shoulders blending the island into the screen edge. Only
        // meaningful when the island is flush against it, so a floating island
        // ignores this.
        fillet: 15,
        // Superellipse exponent. 2 is a plain circular corner; ~5 gives the
        // continuous curvature of a squircle. Above ~8 it reads as a bevel.
        curvature: 2.6,
        // Gap between the island and the screen edge. Non-zero detaches the
        // island into a floating pill, which also disables the shoulders —
        // there is no longer an edge to blend into. Set to 0 to sit flush
        // against the bezel like a MacBook notch.
        topInset: 10,
        // How much wider the island grows on hover.
        hoverPadding: 22,
        // Ceiling for expanded states, so a pathological notification cannot
        // grow the island past the screen.
        maxWidth: 680,
        maxHeight: 560,
        paddingX: 14,
        paddingY: 0,

        // ------------------------------------------------ menu bar capsules
        //
        // The two glass capsules flanking the island. They share the island's
        // corner language and vertical centre line, so the three shapes read
        // as one bar rather than three unrelated widgets.

        // Distance from the screen edge to a capsule's outer edge.
        sideMargin: 22,
        // 0 follows `collapsedHeight`, so all three shapes stay the same
        // height without having to be kept in sync by hand.
        capsuleHeight: 0,
        // 0 derives the radius from the capsule height, matching the island.
        capsuleRadius: 0,
        capsulePaddingX: 11,
        // Type size inside the capsules. 0 derives it from the capsule
        // height, which is what keeps the status corner legible when the bar
        // is scaled up past what the theme's own font size was chosen for —
        // a 12px clock in a 42px capsule reads as a label that lost its
        // widget. Never goes below the theme's body size.
        capsuleFontSize: 0,
        // Gap between modules inside a capsule. Small on purpose: each module
        // already sits in a slot as wide as the capsule is tall, so the pitch
        // comes from the slots rather than from the gaps between them.
        capsuleSpacing: 2,
        // Smallest gap tolerated between a capsule and the island. Once the
        // island grows wide enough to breach it the capsules retract, so an
        // expanded island never collides with them.
        capsuleGap: 18
    },

    motion: {
        // Seconds to first reach the target. Lower is snappier.
        response: 0.42,
        // 1.0 settles dead; 0.72 gives a ~4% overshoot; below 0.5 bounces.
        damping: 0.72,
        // Collapsing wants less drama than expanding, so it gets its own,
        // stiffer spring.
        collapseResponse: 0.36,
        collapseDamping: 0.9,
        // Crossfade between two contents occupying the island.
        contentFade: 150,
        // How far content slides while fading, in pixels.
        contentSlide: 8,
        // Content waits this long before fading in, so the shape has visibly
        // started opening first. This ordering is most of the illusion.
        contentDelay: 60
    },

    // What the resting pill carries. Empty renders a bare capsule.
    //
    // `albumArt` and `waveform` are live-activity modules: they render nothing
    // at all unless something is playing, so the pill quietly grows a cover on
    // one side and a visualiser on the other when music starts, then shrinks
    // back when it stops. Nothing has to switch them on.
    collapsed: ["liveIcon", "albumArt", "media", "window", "waveform", "liveRing"],

    // The glass capsule to the left of the island. Empty hides it entirely.
    left: ["menu"],

    // The glass capsule to the right of the island — the status corner.
    right: ["network", "bluetooth", "clock", "battery"],

    // Revealed on hover, in place of the collapsed set.
    hover: ["albumArt", "media", "mediaControls", "volume", "battery"],

    // Sections stacked in the click-to-open control centre, top to bottom.
    expanded: ["media", "sliders", "notifications"],

    // Transient takeovers, highest priority first when several want the island
    // at once.
    activities: {
        notification: {
            enabled: true,
            // Where notifications come from:
            //   "omarchy" mirror Omarchy's notification service. The island
            //             shows the message *and* the usual corner toast.
            //   "own"     bind org.freedesktop.Notifications directly, so the
            //             island is the only place notifications appear.
            //             Requires `omarchy plugin disable omarchy.notifications`
            //             first — two servers cannot share the bus.
            source: "omarchy",
            // Hovering the island pauses its dismissal timer.
            pauseOnHover: true,
            // Leave a small dot on the pill after a notification collapses.
            residue: true,
            maxBodyLines: 2
        },
        // Volume and brightness HUDs. These replace the system overlay, so
        // turn Omarchy's own off to avoid two of them:
        //   omarchy plugin disable omarchy.osd
        volume: { enabled: true, duration: 1500 },
        brightness: { enabled: true, duration: 1500 },
        media: { enabled: true, duration: 2600 },
        power: { enabled: true, duration: 3000 },
        // Long-running tasks pushed in over IPC. Unlike everything else
        // here, a live activity is not an event that happened — it is a
        // thing that is still happening, so it announces itself for
        // `announce` milliseconds at each end and compacts to a glyph and a
        // ring on the resting pill in between.
        //
        //   omarchy-shell island activity '{"id":"build","label":"Building","value":0.4}'
        //   omarchy-shell island activity '{"id":"build","done":true}'
        //
        // `hold` is how long a finished task stays up before it is dropped.
        live: { enabled: true, announce: 2200, hold: 1600, priority: 35 }
    },

    // Per-module options, keyed by the names used in the arrays above.
    modules: {
        // `panel` names an Omarchy bar-widget plugin to open on click. The
        // island mounts it invisibly behind the module and the real panel
        // opens under the glyph you clicked — see Core/PanelSlot.qml. Set it
        // to "" for a module that only reports.
        clock: { format: "ddd d MMM  HH:mm", panel: "omarchy.clock" },
        workspaces: { style: "dots", showEmpty: true, max: 10 },
        media: { scrollTitle: true, maxTitleWidth: 180 },
        battery: { showPercentage: false, warnBelow: 20, panel: "omarchy.power" },
        audio: {},
        // Wi-Fi / ethernet state. Clicking opens Omarchy's network panel;
        // `command` is the fallback for when that plugin is disabled.
        network: { panel: "omarchy.network", command: "omarchy-menu toggle setup.network" },
        bluetooth: { panel: "omarchy.bluetooth", command: "" },
        // The focused window's title. Steps aside while something is
        // actually playing, so the island reads as "now playing, or else
        // what you are looking at".
        window: { maxWidth: 220, hideWhenPlaying: true },
        // The system logo. Defaults to Omarchy's own mark, in the `omarchy`
        // font that ships with it — set `glyph` and `font` for anything else
        // (an Apple logo, say: { "glyph": "\uf179", "font": "" }).
        menu: {
            glyph: "\ue900",
            font: "omarchy",
            // An image file drawn in place of the glyph, for a mark that does
            // not live in a font. Falls back to the glyph if it will not load.
            icon: "",
            size: 0,
            // The logo opens the agent dashboard — Claude's context and
            // weekly usage windows — rather than the Omarchy menu, which is
            // one right-click or one keybinding away. `panel: ""` puts
            // `command` back in charge.
            panel: "omarchy.agents",
            command: "omarchy-menu toggle root",
            rightCommand: "omarchy-menu toggle root"
        },
        // Opens the island's own control centre, the way the Control Centre
        // button does on the macOS menu bar.
        controlCentre: { glyph: "\uf1de" },
        tray: {},
        albumArt: {},
        waveform: { bars: 4 },
        // The compact form of a live activity. `glyph` is the fallback mark
        // for a task that did not send one.
        liveIcon: { glyph: "󰄉" },
        liveRing: { size: 0 }
    },

    // Behaviour
    behaviour: {
        // Reserve screen space so windows tile below the island, exactly as a
        // bar would. Turning this off makes the island a pure overlay.
        reserveSpace: true,
        // Which monitors get an island. "all", "focused", a single connector
        // name such as "DP-1", or a list of them: ["eDP-1", "HDMI-A-1"].
        //
        // "all" is the default because an island that follows focus leaves
        // whichever screen you are *not* looking at with no bar at all, and
        // the clock and status corner are exactly what you glance at on a
        // second display.
        monitors: "all",
        // Where transient activities — notifications, HUDs, track changes —
        // take the island over. "all" mirrors them onto every island;
        // "focused" plays them only on the monitor that currently has focus,
        // so a volume HUD does not flash on all three screens at once.
        activityMonitors: "all",
        // Draw the glass capsules flanking the island. False leaves the bare
        // pill on its own, the way earlier versions looked.
        capsules: true,
        expandOnHover: true,
        expandOnClick: true,
        // Scrolling over the island adjusts volume; holding Shift while
        // scrolling steps through tracks.
        scrollGestures: true,
        // Take over Omarchy's on-screen display, so *every* OSD it would have
        // shown — mute, keyboard backlight, touchpad, audio output switching —
        // is drawn by the island instead of only the volume and brightness it
        // watches itself.
        //
        // Enable this together with `omarchy plugin disable omarchy.osd`. Two
        // handlers cannot share the `osd` IPC target, and which one wins is
        // registration order, so turning this on while Omarchy's OSD is still
        // enabled is a coin flip rather than an upgrade.
        captureOmarchyOsd: false,
        // Close the control centre when the pointer leaves it.
        closeOnLeave: true,
        hoverDelay: 90
    },

    style: {
        // Empty string follows the Omarchy theme. Any CSS-style colour
        // overrides it.
        background: "",
        foreground: "",
        accent: "",
        // Island backgrounds are usually near-black regardless of theme, the
        // way a real bezel is. 1.0 uses the theme's own background colour;
        // 0.0 is pure black, which is what a notch actually looks like.
        darken: 0.0,
        opacity: 1.0,
        borderWidth: 0,
        borderColor: "",
        shadow: true,
        shadowOpacity: 0.45,
        shadowBlur: 24,

        // ------------------------------------------------------------ glass
        //
        // The side capsules are frosted rather than filled: smoked black
        // glass over whatever is behind them, matching the island they flank.
        // Set `capsuleBackground` to any colour to override the black, or
        // "foreground" to go back to a light wash that follows the theme.
        //
        // Real refraction is the compositor's job, not ours — see the
        // Hyprland layer-blur note in the README. Without it this is still
        // smoked glass, just not a lens.
        capsuleBackground: "",
        capsuleOpacity: 0.55,
        capsuleBorderWidth: 0,
        capsuleBorderColor: "",
        // Extra wash under a hovered module inside a capsule. Drawn in the
        // foreground colour, so it lightens the glass rather than darkening
        // it further.
        capsuleHoverOpacity: 0.12
    }
};

// Every module the island can draw, with the wording the Studio shows. Kept
// here rather than in ModuleRow because a name needs a label and a sentence
// before a human can choose it from a list, and ModuleRow only needs to turn
// a string into a component.
var MODULES = [
    { id: "menu", label: "Logo", hint: "System logo. Opens the agent dashboard" },
    { id: "clock", label: "Clock", hint: "Time and date. Opens the calendar" },
    { id: "battery", label: "Battery", hint: "Charge. Hidden on desktops" },
    { id: "network", label: "Network", hint: "Wi-Fi or ethernet. Opens the network panel" },
    { id: "bluetooth", label: "Bluetooth", hint: "Radio state. Opens the device list" },
    { id: "volume", label: "Volume", hint: "Output level. Click to mute" },
    { id: "controlCentre", label: "Control Centre", hint: "Opens the island's own panel" },
    { id: "workspaces", label: "Workspaces", hint: "Hyprland workspaces as dots" },
    { id: "window", label: "Window", hint: "Focused window's title" },
    { id: "media", label: "Now Playing", hint: "Track title. Hidden with nothing playing" },
    { id: "albumArt", label: "Album Art", hint: "Cover. Hidden with nothing playing" },
    { id: "waveform", label: "Waveform", hint: "Visualiser. Hidden with nothing playing" },
    { id: "mediaControls", label: "Transport", hint: "Previous, play/pause, next" },
    { id: "liveIcon", label: "Task Icon", hint: "Running task's mark. Hidden when idle" },
    { id: "liveRing", label: "Task Ring", hint: "Running task's progress. Hidden when idle" }
];

function moduleCatalogue() {
    return clone(MODULES);
}

function moduleLabel(id) {
    for (var i = 0; i < MODULES.length; i++) {
        if (MODULES[i].id === String(id))
            return MODULES[i].label;
    }
    return String(id);
}

function isPlainObject(value) {
    return !!value && typeof value === "object" && !Array.isArray(value);
}

function clone(value) {
    return JSON.parse(JSON.stringify(value));
}

// Merge one section. Arrays and scalars replace wholesale; nested objects
// merge one key at a time so `modules.clock.format` can be set without
// restating every other module.
function mergeSection(base, override, deep) {
    var out = clone(base);
    if (!isPlainObject(override))
        return out;
    for (var key in override) {
        var value = override[key];
        if (value === undefined || value === null)
            continue;
        if (deep && isPlainObject(value) && isPlainObject(out[key]))
            out[key] = mergeSection(out[key], value, true);
        else
            out[key] = isPlainObject(value) || Array.isArray(value) ? clone(value) : value;
    }
    return out;
}

// Resolve the user's `bar.island` object against the defaults.
function resolve(raw) {
    var user = isPlainObject(raw) ? raw : {};
    return {
        shape: mergeSection(DEFAULTS.shape, user.shape, false),
        motion: mergeSection(DEFAULTS.motion, user.motion, false),
        collapsed: Array.isArray(user.collapsed) ? clone(user.collapsed) : clone(DEFAULTS.collapsed),
        left: Array.isArray(user.left) ? clone(user.left) : clone(DEFAULTS.left),
        right: Array.isArray(user.right) ? clone(user.right) : clone(DEFAULTS.right),
        hover: Array.isArray(user.hover) ? clone(user.hover) : clone(DEFAULTS.hover),
        expanded: Array.isArray(user.expanded) ? clone(user.expanded) : clone(DEFAULTS.expanded),
        activities: mergeSection(DEFAULTS.activities, user.activities, true),
        modules: mergeSection(DEFAULTS.modules, user.modules, true),
        behaviour: mergeSection(DEFAULTS.behaviour, user.behaviour, false),
        style: mergeSection(DEFAULTS.style, user.style, false)
    };
}

// Options for one module by name, with its defaults applied.
function moduleOptions(config, name) {
    var all = config && config.modules ? config.modules : {};
    var fallback = DEFAULTS.modules[name] || {};
    return mergeSection(fallback, all[name], true);
}

function activityOptions(config, name) {
    var all = config && config.activities ? config.activities : {};
    var fallback = DEFAULTS.activities[name] || { enabled: false };
    return mergeSection(fallback, all[name], true);
}

function activityEnabled(config, name) {
    return activityOptions(config, name).enabled === true;
}
