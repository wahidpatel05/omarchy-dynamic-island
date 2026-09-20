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
        collapsedHeight: 32,
        // Corner radii. The bottom is the one you actually read as "the
        // island"; the top is only visible when the island floats.
        radiusBottom: 17,
        radiusTop: 0,
        // Concave shoulders blending the island into the screen edge. Set to 0
        // for a detached pill.
        fillet: 15,
        // Superellipse exponent. 2 is a plain circular corner; ~5 matches the
        // continuous curvature Apple uses. Above ~8 it reads as a bevel.
        curvature: 5,
        // Gap between the island and the screen edge. Non-zero detaches it,
        // which also disables the shoulders — there is no edge left to blend.
        topInset: 0,
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
    collapsed: ["clock", "workspaces"],

    // Revealed on hover, in place of the collapsed set.
    hover: ["clock", "workspaces", "media", "volume", "battery"],

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
        volume: { enabled: true, duration: 1400 },
        brightness: { enabled: true, duration: 1400 },
        media: { enabled: true, duration: 2600 },
        power: { enabled: true, duration: 2600 }
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
        window: { maxWidth: 200 }
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
