import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs.Commons
import "Core"
import "Activities"
import "Services"
import "Expanded"
import "Studio"
import "Core/Config.js" as Config
import "Core/Settings.js" as Settings
import "Core/Motion.js" as Motion
import "Core/OsdIcons.js" as OsdIcons

// Dynamic Island — an Omarchy `bar` plugin.
//
// Registering as a bar rather than a panel is what lets this replace the
// status bar outright: Omarchy runs exactly one bar plugin, chosen by
// `bar.id` in shell.json, and hands it the bar subtree on every save. So the
// island inherits the bar's config channel, its hot reload, and its place in
// the shell's lifecycle, and the user switches back to their old bar by
// putting the old id back.
Item {
    id: root

    // ----------------------------------------------- injected by the shell

    property string omarchyPath: ""
    property var barWidgetRegistry: null
    property var barConfig: null
    property var shell: null
    property var manifest: null

    // ------------------------------------------------- bar host contract
    //
    // Replacing the bar means inheriting the bar's role in the shell. Omarchy's
    // own panels and widgets reach into `shell.bar` for colours, metrics, and
    // a command runner — the audio, network, and bluetooth panels all render
    // against `bar.foreground` and `bar.fontFamily`, and simply break if the
    // active bar does not answer. So the island answers the whole contract,
    // even the parts it has no use for itself.
    //
    // Reporting the *resting* height as `barSize` is what keeps the rest of
    // the shell anchored correctly: notifications and panels position
    // themselves below the bar, and should sit below the collapsed pill rather
    // than below whatever the island momentarily grew to.

    readonly property bool vertical: false
    readonly property int barSize: {
        var resting = config.shape.collapsedHeight || 32;
        var capsule = config.behaviour.capsules === false ? 0 : ((config.shape.capsuleHeight || 0) > 0 ? config.shape.capsuleHeight : resting);
        return Math.round(Math.max(resting, capsule) + (config.shape.topInset || 0));
    }
    readonly property bool barHidden: false
    readonly property string position: barConfig && barConfig.position === "bottom" ? "bottom" : "top"

    readonly property string fontFamily: Style.font.family
    readonly property color background: islandBackground
    readonly property color barForeground: foreground
    readonly property color text: foreground
    readonly property color urgent: Color.urgent
    readonly property bool transparent: false
    readonly property bool active: true
    readonly property bool foregroundAnimationEnabled: false

    readonly property int sizeHorizontal: barSize
    readonly property int sizeVertical: barSize
    readonly property int iconSlot: Style.bar.iconSlot
    readonly property int iconCanvas: Style.bar.iconCanvas
    readonly property int iconFont: Style.bar.iconFont
    readonly property int statusSlot: Style.bar.statusSlot

    readonly property var layout: barConfig && barConfig.layout ? barConfig.layout : ({})
    readonly property var layoutConfig: layout
    readonly property var clickTargets: []

    // Popout bookkeeping. Panels ask before opening, and two of them — the
    // calendar and the weather panel — *write* `centerHoverRevealSuppressed`
    // while they are open, so it cannot be readonly or they throw on every
    // open.
    property var activePopout: null
    property bool centerHoverRevealSuppressed: false
    readonly property bool centerSectionRevealHeld: false

    function run(command) {
        if (command)
            Util.execDetached(command);
    }
    function shellQuote(value) {
        return Util.shellQuote(value);
    }
    function moduleWidgets(name) {
        var out = [];
        for (var i = 0; i < panelSlots.length; i++) {
            if (panelSlots[i].pluginId === String(name) && panelSlots[i].widget)
                out.push(panelSlots[i].widget);
        }
        return out;
    }
    function showTooltip(target, text) {}
    function hideTooltip(target) {}
    function requestPopout(target) {
        activePopout = target;
        return true;
    }
    function releasePopout(target) {
        if (activePopout === target)
            activePopout = null;
    }
    function switchPanelFrom(target) {
        return false;
    }
    function targetBelongsToWindow(target, window) {
        return false;
    }
    // ------------------------------------------------- hosted bar widgets
    //
    // Omarchy routes `shell summon/hide/toggle <id>` for every `bar-widget`
    // plugin through the active bar, because the panel belongs to a live
    // instance of the widget and only the bar knows where those are. A bar
    // that answers `false` here does not merely fail to show the panel
    // itself — it makes that panel unreachable from keybindings, from the
    // menu, and from any other plugin that tries to summon it.
    //
    // So the island keeps a register of the widgets it has mounted, and
    // answers the same three questions Omarchy's own bar answers.

    property var panelSlots: []

    function registerPanelSlot(slot) {
        if (!slot || panelSlots.indexOf(slot) !== -1)
            return;
        var next = panelSlots.slice();
        next.push(slot);
        panelSlots = next;
    }

    function unregisterPanelSlot(slot) {
        panelSlots = panelSlots.filter(function (entry) {
            return entry !== slot;
        });
    }

    // One slot per screen carries each plugin, so "which one" has to be
    // decided rather than guessed: the focused monitor's, falling back to
    // whichever exists. Opening the calendar on a monitor you are not
    // looking at is the failure mode this avoids.
    function panelSlotFor(id) {
        var wanted = String(id);
        var focused = focusedScreenName();
        var fallback = null;
        for (var i = 0; i < panelSlots.length; i++) {
            var slot = panelSlots[i];
            if (!slot || slot.pluginId !== wanted || !slot.available)
                continue;
            if (slot.screenName === focused)
                return slot;
            if (!fallback)
                fallback = slot;
        }
        return fallback;
    }

    function summonBarWidget(id) {
        var slot = panelSlotFor(id);
        if (!slot)
            return false;
        slot.open();
        return true;
    }

    function hideBarWidget(id) {
        var slot = panelSlotFor(id);
        if (!slot)
            return false;
        slot.close();
        return true;
    }

    function isBarWidgetOpen(id) {
        var slot = panelSlotFor(id);
        return slot !== null && slot.opened === true;
    }

    // ------------------------------------------------------------- config

    readonly property var config: Config.resolve(barConfig ? barConfig.island : null)

    onConfigChanged: Motion.clearCache()

    // ----------------------------------------------------------- settings
    //
    // Writing config back where it came from. `shell.mutateShellConfig` hands
    // us a clone of the whole shell config, persists whatever we leave in it,
    // and re-publishes it through `barConfig` — so a write lands on disk and
    // on screen from the same call, and a hand-edited shell.json and the
    // Studio cannot drift apart.
    //
    // Paths are dotted and relative to `bar.island`: "shape.collapsedHeight".

    readonly property bool settingsWritable: shell !== null && shell !== undefined && typeof shell.mutateShellConfig === "function"

    function setSetting(path, value) {
        if (!settingsWritable)
            return false;
        var ok = false;
        shell.mutateShellConfig(function (draft) {
            ok = Settings.set(draft, path, value);
        });
        return ok;
    }

    function resetSetting(path) {
        if (!settingsWritable)
            return false;
        var ok = false;
        shell.mutateShellConfig(function (draft) {
            ok = Settings.reset(draft, path);
        });
        return ok;
    }

    // Everything back to the plugin's own defaults, by removing the subtree
    // rather than by writing the defaults out. A config file full of values
    // identical to the defaults is a config file that cannot follow them when
    // they change.
    function resetAllSettings() {
        if (!settingsWritable)
            return false;
        shell.mutateShellConfig(function (draft) {
            if (draft.bar)
                delete draft.bar.island;
        });
        return true;
    }

    // What the user actually wrote, or undefined. The Studio shows the
    // resolved value but needs this to know whether "reset" means anything.
    function userSetting(path) {
        return Settings.userValue(barConfig, path);
    }

    function setting(path) {
        return Settings.resolvedValue(config, path);
    }

    // -------------------------------------------------------------- colour
    //
    // The island reads as hardware, so by default it darkens the theme's
    // background toward black rather than matching it. `style.darken` is the
    // fraction of the theme colour kept: 1.0 matches the theme exactly, 0.0 is
    // pure black.

    readonly property real darken: {
        var d = config.style.darken;
        return d === undefined || d === null ? 0.55 : Math.max(0, Math.min(1, d));
    }

    readonly property color islandBackground: {
        if (config.style.background)
            return config.style.background;
        var base = Color.background;
        var alpha = config.style.opacity === undefined ? 1.0 : Math.max(0, Math.min(1, config.style.opacity));
        return Qt.rgba(base.r * darken, base.g * darken, base.b * darken, alpha);
    }

    readonly property color islandBorder: {
        if (config.style.borderColor)
            return config.style.borderColor;
        return Qt.rgba(1, 1, 1, 0.06);
    }

    // The glass the side capsules are made of.
    //
    // Smoked black by default, so the capsules read as the same material as
    // the island between them rather than as two lighter panels beside it.
    // `capsuleBackground` takes a colour, or one of the two palette roles
    // worth naming — "foreground" gives the pale wash that suits a light
    // theme, where black glass reads as a hole.
    readonly property color capsuleTint: {
        var named = String(config.style.capsuleBackground || "").toLowerCase();
        if (named === "foreground")
            return Color.foreground;
        if (named === "background")
            return Color.background;
        if (named === "accent")
            return Color.accent;
        return Qt.rgba(0, 0, 0, 1);
    }

    readonly property color capsuleBackground: {
        var explicit = String(config.style.capsuleBackground || "");
        // Anything that is not one of the named roles is a literal colour,
        // and a literal colour carries its own alpha.
        if (explicit !== "" && ["foreground", "background", "accent"].indexOf(explicit.toLowerCase()) === -1)
            return explicit;
        var alpha = config.style.capsuleOpacity === undefined ? 0.55 : Math.max(0, Math.min(1, config.style.capsuleOpacity));
        var tint = capsuleTint;
        return Qt.rgba(tint.r, tint.g, tint.b, alpha);
    }

    readonly property color capsuleBorder: {
        if (config.style.capsuleBorderColor)
            return config.style.capsuleBorderColor;
        return Qt.rgba(1, 1, 1, 0.08);
    }

    readonly property color foreground: config.style.foreground ? config.style.foreground : Color.foreground
    readonly property color accent: config.style.accent ? config.style.accent : Color.accent

    // -------------------------------------------------------------- state

    // Which screen, if any, has the control centre open. Empty means none —
    // only one island is ever expanded at a time.
    property string expandedScreen: ""

    function setExpanded(screenName, open) {
        expandedScreen = open ? String(screenName) : "";
    }

    // Which screen, if any, has the Studio open. Same one-at-a-time rule as
    // the control centre, and for the same reason: it edits one config.
    property string studioScreen: ""

    function setStudio(screenName, open) {
        studioScreen = open ? String(screenName) : "";
        // The control centre and the Studio both want the middle of the
        // screen; opening one puts the other away.
        if (open)
            expandedScreen = "";
    }

    // ---------------------------------------------------------- activities
    //
    // Sources push events; the manager decides which one the island is
    // actually showing. Priorities are deliberate rather than first-come:
    //
    //   volume/brightness (60) — you just pressed a key and want to see the
    //                            result now, so these preempt anything else
    //   notification      (50) — the reason most people want an island
    //   power             (40) — plugging in is worth a glance
    //   media             (20) — a track change is ambient; it should never
    //                            bury something you asked for

    readonly property var activeActivity: activities.current

    ActivityManager {
        id: activities
    }

    function componentForActivity(activity) {
        if (!activity)
            return null;
        switch (activity.type) {
        case "notification":
            return notificationCardComponent;
        case "media":
            return mediaCardComponent;
        case "volume":
        case "brightness":
            return hudCardComponent;
        case "power":
            return powerCardComponent;
        case "live":
            return liveCardComponent;
        }
        return null;
    }

    function optionsForActivity(activity) {
        return activity ? Config.activityOptions(config, activity.type) : ({});
    }

    // Clicking a transient activity dismisses it rather than opening the
    // control centre — the click you make at a notification means "got it".
    function dismissActivity(activity) {
        return activity ? activities.dismiss(activity.type) : false;
    }

    // Holding the pointer over the island freezes the dismissal countdown, so
    // a notification cannot disappear mid-sentence.
    function setHoverHold(screenName, held) {
        var current = activities.current;
        if (held && current && current.type === "notification" && Config.activityOptions(config, "notification").pauseOnHover === false)
            return;
        activities.paused = held;
    }

    Component {
        id: notificationCardComponent
        NotificationCard {}
    }

    Component {
        id: mediaCardComponent
        MediaCard {}
    }

    Component {
        id: hudCardComponent
        HudCard {}
    }

    Component {
        id: powerCardComponent
        PowerCard {}
    }

    Component {
        id: liveCardComponent
        LiveCard {}
    }

    property Component expandedComponent: controlCentreComponent

    Component {
        id: controlCentreComponent
        ControlCenter {}
    }

    // ------------------------------------------------------------- sources

    readonly property var notificationSource: notifications

    NotificationSource {
        id: notifications
        shell: root.shell
        config: root.config
        activities: activities
    }

    readonly property var brightnessSource: brightness

    BrightnessSource {
        id: brightness
        config: root.config
        activities: activities
        // Force a re-read whenever the control centre opens. Binding this here
        // rather than from the panel avoids an ordering trap: the host is
        // injected into the panel in onLoaded, which runs after the panel's own
        // Component.onCompleted, so the panel cannot reliably reach back here
        // on startup.
        active: root.expandedScreen !== ""
    }

    AudioSource {
        config: root.config
        activities: activities
    }

    PowerSource {
        config: root.config
        activities: activities
    }

    // Shared playback state. Exposed on the root so the now-playing module and
    // the control centre read one MPRIS connection between them.
    readonly property var mediaSource: media

    MediaSource {
        id: media
        config: root.config
        activities: activities
    }

    // Long-running tasks. Exposed on the root because the compact ring and
    // icon read it straight from here — the card is only an announcement,
    // and the registry has to outlive it.
    readonly property var liveSource: live

    LiveActivitySource {
        id: live
        config: root.config
        activities: activities
    }

    // ------------------------------------------------------------ gestures

    readonly property real volumeStep: 0.05

    function stepVolume(direction) {
        var sink = Pipewire.defaultAudioSink;
        if (!sink || !sink.audio)
            return;
        // Unmute on the way up: nudging the volume of a muted sink and hearing
        // nothing is a worse outcome than the gesture being slightly eager.
        if (direction > 0 && sink.audio.muted)
            sink.audio.muted = false;
        sink.audio.volume = Math.max(0, Math.min(1, sink.audio.volume + direction * volumeStep));
    }

    function stepTrack(direction) {
        if (!mediaSource || !mediaSource.hasMedia)
            return;
        if (direction > 0)
            mediaSource.next();
        else
            mediaSource.previous();
    }

    // Keeps the default sink's properties bound so `stepVolume` reads a live
    // value rather than a stale one.
    PwObjectTracker {
        objects: Pipewire.defaultAudioSink ? [Pipewire.defaultAudioSink] : []
    }

    // ---------------------------------------------------------------- IPC
    //
    // So the island can be driven from a keybinding as well as the pointer:
    //
    //   omarchy-shell island toggle
    //
    // Bind that to anything in bindings.lua and the control centre opens
    // without reaching for the mouse — which also makes the island usable on a
    // setup where the pointer rarely goes near the top of the screen.

    function focusedScreenName() {
        var mon = Hyprland.focusedMonitor;
        if (mon && mon.name)
            return String(mon.name);
        var screens = root.targetScreens;
        return screens.length > 0 ? String(screens[0].name) : "";
    }

    // Omarchy's OSD, rendered by the island.
    //
    // The payload is Omarchy's own: { icon, message, value, max, duration }.
    // Loading this only when asked keeps the island from registering a second
    // handler for a target Omarchy's OSD plugin may still own.
    Loader {
        active: root.config.behaviour.captureOmarchyOsd === true
        sourceComponent: osdBridgeComponent
    }

    Component {
        id: osdBridgeComponent

        IpcHandler {
            target: "osd"

            function show(payloadJson: string): string {
                try {
                    var p = JSON.parse(payloadJson || "{}");
                    var max = Number(p.max);
                    if (!isFinite(max) || max <= 0)
                        max = 100;

                    var message = String(p.message || "");
                    var progress = OsdIcons.hasProgress(p.value, message);
                    var fraction = progress ? Math.max(0, Math.min(1, Number(p.value) / max)) : 0;

                    activities.push("volume", 60, {
                        glyph: OsdIcons.glyphFor(p.icon, progress ? Math.round(fraction * 100) : -1),
                        value: fraction,
                        hasProgress: progress,
                        message: message,
                        muted: false
                    }, Number(p.duration) || 1500);
                } catch (e) {
                    return "error";
                }
                return "ok";
            }

            function close(): string {
                activities.dismiss("volume");
                return "ok";
            }

            function state(): string {
                return activities.has("volume") ? "open" : "closed";
            }

            function ping(): string {
                return "ok";
            }
        }
    }

    IpcHandler {
        target: "island"

        function toggle(): string {
            var name = root.focusedScreenName();
            root.setExpanded(name, root.expandedScreen !== name);
            return root.expandedScreen === "" ? "collapsed" : "expanded";
        }

        function expand(): string {
            root.setExpanded(root.focusedScreenName(), true);
            return "expanded";
        }

        function collapse(): string {
            root.setExpanded("", false);
            return "collapsed";
        }

        function state(): string {
            if (root.studioScreen !== "")
                return "studio";
            if (root.expandedScreen !== "")
                return "expanded";
            return root.activeActivity ? "activity:" + root.activeActivity.type : "collapsed";
        }

        // Config from the command line, so the island can be reshaped from a
        // script or a keybinding as well as from the Studio:
        //
        //   omarchy-shell island set '{"shape.collapsedHeight":40}'
        //   omarchy-shell island set '{"right":["network","bluetooth","clock"]}'
        //   omarchy-shell island set '{"shape.topInset":8,"style.darken":0.2}'
        //
        // One JSON object of dotted path to value, rather than a path and a
        // value as two arguments. That is not a style choice: `qs ipc call`
        // splits its argument list on commas, so a multi-argument function
        // cannot be handed JSON containing one — `set right '["a","b"]'`
        // arrives as three arguments and is rejected. A single-argument
        // function gets the string back intact, which also makes batching
        // several keys into one write fall out for free.
        function set(assignmentsJson: string): string {
            if (!root.settingsWritable)
                return "unavailable";
            var assignments;
            try {
                assignments = JSON.parse(assignmentsJson || "");
            } catch (e) {
                return "error";
            }
            if (!assignments || typeof assignments !== "object" || Array.isArray(assignments))
                return "error";

            var wrote = 0;
            for (var path in assignments) {
                if (root.setSetting(path, assignments[path]))
                    wrote++;
            }
            return wrote > 0 ? "ok" : "error";
        }

        function unset(path: string): string {
            if (!root.settingsWritable)
                return "unavailable";
            return root.resetSetting(path) ? "ok" : "error";
        }

        function reset(): string {
            return root.resetAllSettings() ? "ok" : "unavailable";
        }

        function get(path: string): string {
            var value = root.setting(path);
            return value === undefined ? "" : JSON.stringify(value);
        }

        // Live activities — the island carrying something that is still
        // happening, rather than reporting something that did.
        //
        //   omarchy-shell island activity '{"id":"build","label":"Building","glyph":"","value":0.4}'
        //   omarchy-shell island activity '{"id":"build","value":37,"max":210}'
        //   omarchy-shell island activity '{"id":"build","done":true}'
        //   omarchy-shell island activity '{"id":"build","done":true,"ok":false}'
        //
        // `id` is the only required field. Everything else carries over from
        // the previous update for that id, so a progress loop can send just
        // the number.
        function activity(payloadJson: string): string {
            var payload;
            try {
                payload = JSON.parse(payloadJson || "{}");
            } catch (e) {
                return "error";
            }
            if (!payload || typeof payload !== "object" || !payload.id)
                return "error";
            return live.upsert(payload) ? "ok" : "ignored";
        }

        function activityDone(id: string): string {
            return live.finish(id, { ok: true }) ? "ok" : "unknown";
        }

        function activityDrop(id: string): string {
            return live.remove(id) ? "ok" : "unknown";
        }

        function activityClear(): string {
            live.clear();
            return "ok";
        }

        function activityList(): string {
            return JSON.stringify(live.snapshot());
        }

        // Every knob on one surface. Bound to a key it is one press from
        // anywhere; right-clicking the island opens it too.
        function studio(): string {
            var name = root.focusedScreenName();
            root.setStudio(name, root.studioScreen !== name);
            return root.studioScreen === "" ? "closed" : "open";
        }

        function ping(): string {
            return "ok";
        }
    }

    // ------------------------------------------------------------ screens
    //
    // "all" puts an island on every display — the default, because a second
    // monitor with no bar on it is a worse outcome than two clocks.
    // "focused" follows focus between monitors, the way a notch is only ever
    // on one display. A connector name pins it, and a list of them picks a
    // subset: ["eDP-1", "HDMI-A-1"].

    readonly property var monitorMode: config.behaviour.monitors === undefined || config.behaviour.monitors === null || config.behaviour.monitors === "" ? "all" : config.behaviour.monitors

    // The mode as a list of wanted connector names, or null for "every
    // screen". Resolving the name list separately from the screen lookup is
    // what lets one code path serve a string, a list, and focus-following.
    readonly property var wantedNames: {
        if (Array.isArray(monitorMode))
            return monitorMode.map(String);
        var mode = String(monitorMode);
        if (mode === "all")
            return null;
        if (mode === "focused") {
            var mon = Hyprland.focusedMonitor;
            return mon ? [String(mon.name)] : [];
        }
        return [mode];
    }

    readonly property var targetScreens: {
        var screens = Quickshell.screens;
        var wanted = root.wantedNames;
        if (wanted === null)
            return screens;

        var picked = [];
        for (var i = 0; i < screens.length; i++) {
            if (wanted.indexOf(String(screens[i].name)) !== -1)
                picked.push(screens[i]);
        }
        // An unknown or not-yet-resolved name would otherwise leave the user
        // with no bar at all, so fall back to every screen.
        return picked.length > 0 ? picked : screens;
    }

    Variants {
        model: root.targetScreens

        IslandWindow {
            config: root.config
            host: root
        }
    }

    // The Studio is its own surface rather than another island state: it is
    // a window you work in, not something the island momentarily became, and
    // it has to stay put while the thing it is editing reshapes behind it.
    Variants {
        model: root.targetScreens

        StudioWindow {
            config: root.config
            host: root
        }
    }
}
