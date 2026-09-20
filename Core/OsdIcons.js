.pragma library

// Translation from Omarchy's OSD icon names to glyphs.
//
// Omarchy's OSD callers pass a *name* — "volume-high", "brightness",
// "microphone-muted" — not a glyph, because its own OSD resolves the name at
// render time. An island capturing that stream has to do the same resolution,
// or it draws the literal string "volume-high" where the icon should be.
//
// The vocabulary is Omarchy's, so this list tracks the names its scripts emit
// rather than inventing its own.

var GLYPHS = {
    "volume-muted": "󰝟",
    "volume-mute": "󰝟",
    "muted": "󰝟",
    "mute": "󰝟",
    "volume-low": "󰕿",
    "volume-medium": "󰖀",
    "volume-high": "󰕾",
    "volume": "󰕾",

    "microphone-muted": "󰍭",
    "microphone-off": "󰍭",
    "mic-muted": "󰍭",
    "mic-off": "󰍭",
    "microphone": "󰍬",
    "mic": "󰍬",

    "keyboard": "󰌌",
    "brightness": "󰃠",
    "display": "󰃠",
    "touchpad": "󰟸",
    "touch": "󰝁",
    "touchscreen": "󰝁",

    "reboot": "󰜉",
    "restart": "󰜉",
    "shutdown": "󰐥",
    "power": "󰐥",
    "poweroff": "󰐥",
    "logout": "󰍃",
    "sign-out": "󰍃",
    "leave": "󰍃",

    "media": "󰝚",
    "player": "󰝚",
    "media-source": "󰝚",
    "player-source": "󰝚",
    "media-play": "󰐊",
    "player-play": "󰐊",
    "media-pause": "󰏤",
    "player-pause": "󰏤",
    "media-next": "󰒭",
    "player-next": "󰒭",
    "media-previous": "󰒮",
    "player-previous": "󰒮"
};

// `percent` is only consulted when there is no name to go on, so an unnamed
// level OSD still gets a sensible speaker.
function glyphFor(name, percent) {
    var key = String(name || "").toLowerCase().trim();
    if (GLYPHS.hasOwnProperty(key))
        return GLYPHS[key];

    // A caller that passed a glyph rather than a name gets it back untouched.
    // Anything longer is a name we do not know, and drawing it as a word in
    // the icon column is worse than drawing nothing.
    if (key.length > 0)
        return key.length <= 2 ? String(name) : "";

    if (percent === undefined || percent < 0)
        return "";
    if (percent <= 0)
        return GLYPHS["volume-muted"];
    if (percent <= 33)
        return GLYPHS["volume-low"];
    if (percent <= 66)
        return GLYPHS["volume-medium"];
    return GLYPHS["volume-high"];
}

// Whether a payload describes a level or a message. Mirrors Omarchy's rule:
// a message always wins, so "Muted" renders as a word rather than a bar
// pinned at zero.
function hasProgress(value, message) {
    if (String(message || "") !== "")
        return false;
    var n = Number(value);
    return value !== undefined && value !== null && value !== "" && isFinite(n);
}
