import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.Commons
import "Core"
import "Activities"
import "Services"
import "Expanded"
import "Core/Config.js" as Config
import "Core/Motion.js" as Motion

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
    readonly property int barSize: Math.round((config.shape.collapsedHeight || 32) + (config.shape.topInset || 0))
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

    // Popout bookkeeping. The island has no bar widgets to own popouts, but
    // panels ask before opening, so the answers have to be well-formed.
    property var activePopout: null
    readonly property bool centerHoverRevealSuppressed: false
    readonly property bool centerSectionRevealHeld: false

    function run(command) {
        if (command)
            Util.execDetached(command);
    }
    function shellQuote(value) {
        return Util.shellQuote(value);
    }
    function moduleWidgets(name) {
        return [];
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
    function summonBarWidget(id) {
        return false;
    }

    // ------------------------------------------------------------- config

    readonly property var config: Config.resolve(barConfig ? barConfig.island : null)

    onConfigChanged: Motion.clearCache()

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

    readonly property color foreground: config.style.foreground ? config.style.foreground : Color.foreground
    readonly property color accent: config.style.accent ? config.style.accent : Color.accent

    // -------------------------------------------------------------- state

    // Which screen, if any, has the control centre open. Empty means none —
    // only one island is ever expanded at a time.
    property string expandedScreen: ""

    function setExpanded(screenName, open) {
        expandedScreen = open ? String(screenName) : "";
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
        // Read the backlight exactly while the control centre is open. Binding
        // this here rather than from the panel avoids an ordering trap: the
        // host is injected into the panel in onLoaded, which runs after the
        // panel's own Component.onCompleted, so the panel cannot reliably
        // reach back to this on startup.
        active: root.expandedScreen !== ""
    }

    // Shared playback state. Exposed on the root so the now-playing module and
    // the control centre read one MPRIS connection between them.
    readonly property var mediaSource: media

    MediaSource {
        id: media
        config: root.config
        activities: activities
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
            if (root.expandedScreen !== "")
                return "expanded";
            return root.activeActivity ? "activity:" + root.activeActivity.type : "collapsed";
        }

        function ping(): string {
            return "ok";
        }
    }

    // ------------------------------------------------------------ screens
    //
    // "focused" follows the pointer/focus between monitors, the way the notch
    // is only ever on one display. "all" mirrors it everywhere, and an
    // explicit connector name pins it.

    readonly property string monitorMode: config.behaviour.monitors || "focused"

    readonly property var targetScreens: {
        var screens = Quickshell.screens;
        if (monitorMode === "all")
            return screens;

        var wanted = "";
        if (monitorMode === "focused") {
            var mon = Hyprland.focusedMonitor;
            wanted = mon ? String(mon.name) : "";
        } else {
            wanted = String(monitorMode);
        }

        for (var i = 0; i < screens.length; i++) {
            if (String(screens[i].name) === wanted)
                return [screens[i]];
        }
        // An unknown or not-yet-resolved name would otherwise leave the user
        // with no bar at all, so fall back to every screen.
        return screens;
    }

    Variants {
        model: root.targetScreens

        IslandWindow {
            config: root.config
            host: root
        }
    }
}
