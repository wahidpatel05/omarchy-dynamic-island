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
        collapsedWidth: 210,
        collapsedHeight: 34,
        // Corner radii. At rest these match half the height, so the pill is a
        // true capsule; taller states round off at a fixed maximum instead of
        // staying proportionally round.
        radiusBottom: 17,
        radiusTop: 17,
        // Concave shoulders blending the island into the screen edge. Only
        // meaningful when the island is flush against it, so a floating island
        // ignores this.
        fillet: 15,
        // Superellipse exponent. 2 is a plain circular corner; ~5 matches the
        // continuous curvature Apple uses. Above ~8 it reads as a bevel.
        curvature: 5,
        // Gap between the island and the screen edge. Non-zero detaches the
        // island into a floating pill, which also disables the shoulders —
        // there is no longer an edge to blend into. Set to 0 to sit flush
        // against the bezel like a MacBook notch.
        topInset: 9,
        // How much wider the island grows on hover.
        hoverPadding: 22,
        // Ceiling for expanded states, so a pathological notification cannot
        // grow the island past the screen.
        maxWidth: 680,
        maxHeight: 560,
        paddingX: 14,
        paddingY: 0
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
    collapsed: ["albumArt", "clock", "workspaces", "waveform"],

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
        power: { enabled: true, duration: 3000 }
    },

    // Per-module options, keyed by the names used in the arrays above.
    modules: {
        clock: { format: "h:mm AP" },
        workspaces: { style: "dots", showEmpty: true, max: 10 },
        media: { scrollTitle: true, maxTitleWidth: 180 },
        battery: { showPercentage: true, warnBelow: 20 },
        audio: {},
        network: {},
        tray: {},
        window: { maxWidth: 200 },
        albumArt: {},
        waveform: { bars: 4 }
    },

    // Behaviour
    behaviour: {
        // Reserve screen space so windows tile below the island, exactly as a
        // bar would. Turning this off makes the island a pure overlay.
        reserveSpace: true,
        // Which monitor gets the island. "focused", "all", or a connector name
        // such as "DP-1".
        monitors: "focused",
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
        // way a real bezel is. 1.0 uses the theme's own background colour.
        darken: 0.55,
        opacity: 1.0,
        borderWidth: 0,
        borderColor: "",
        shadow: true,
        shadowOpacity: 0.45,
        shadowBlur: 24
    }
};

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
