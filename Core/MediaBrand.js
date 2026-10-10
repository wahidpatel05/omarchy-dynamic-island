.pragma library

// Who is playing, as a mark and a colour.
//
// MPRIS hands over three names for every player — its identity, its desktop
// entry, and its bus address — and between them there is nearly always enough
// to recognise the app. That recognition is the difference between "something
// is playing" and "Spotify is playing", which is most of what a glance at the
// island is asking.
//
// The colour is the brand's rather than the theme's, and deliberately so: a
// green circle is read as Spotify before it is read as a shape. Themes still
// win where it matters — an unrecognised player reports `known: false` and
// the island falls back to its own accent, so the default is never a guess at
// a brand.
//
// Marks are Nerd Font glyphs, drawn in whatever family the theme uses. A font
// without them draws a box instead, which is what `showSource` is for.

var BRANDS = [
    // Longest names first: "youtube music" has to be tested before "youtube",
    // or every YouTube Music track comes up as plain YouTube.
    { keys: ["youtube music", "youtube-music", "ytmusic", "ytmdesktop"], glyph: "󰗃", color: "#FF0033" },
    { keys: ["apple music", "cider"], glyph: "", color: "#FC3C44" },
    { keys: ["spotify"], glyph: "󰓇", color: "#1ED760" },
    { keys: ["youtube"], glyph: "󰗃", color: "#FF0033" },
    { keys: ["soundcloud"], glyph: "󰓀", color: "#FF5500" },
    { keys: ["tidal"], glyph: "󰝚", color: "#00FFFF" },
    { keys: ["deezer"], glyph: "󰝚", color: "#A238FF" },
    { keys: ["firefox", "librewolf", "zen"], glyph: "󰈹", color: "#FF7139" },
    { keys: ["chromium", "chrome"], glyph: "󰊯", color: "#4285F4" },
    { keys: ["brave"], glyph: "󰖟", color: "#FB542B" },
    { keys: ["vlc"], glyph: "󰕼", color: "#FF8800" },
    { keys: ["mpv"], glyph: "󰐊", color: "#8D4E9E" }
];

var UNKNOWN = "󰝚";

// `identity`, `desktopEntry` and `dbusName` all come straight off the MPRIS
// player and any of them may be empty, so they are matched as one haystack
// rather than in turn — a browser that reports no identity still names itself
// in its bus address.
function brandFor(identity, desktopEntry, dbusName) {
    var hay = [String(identity || ""), String(desktopEntry || ""), String(dbusName || "")].join(" ").toLowerCase();

    for (var i = 0; i < BRANDS.length; i++) {
        var keys = BRANDS[i].keys;
        for (var k = 0; k < keys.length; k++) {
            if (hay.indexOf(keys[k]) !== -1)
                return { glyph: BRANDS[i].glyph, color: BRANDS[i].color, known: true };
        }
    }

    return { glyph: UNKNOWN, color: "", known: false };
}
