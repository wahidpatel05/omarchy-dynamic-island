import QtQuick
import Quickshell
import Quickshell.Io
import "../Core/Config.js" as Config

// Backlight level: the control-centre slider, and the brightness HUD.
//
// The level is read from sysfs rather than polled through brightnessctl,
// because sysfs can be *watched*. That is what lets the island react to the
// brightness keys at all: nothing broadcasts a brightness change on the
// session bus, so the only way to know the keys were pressed is to notice the
// file move. Writes still go through brightnessctl, which handles the
// permissions that writing sysfs directly would not.
Item {
    id: root

    property var config: null
    property var activities: null

    readonly property var options: Config.activityOptions(config, "brightness")
    readonly property bool hudEnabled: options.enabled === true && !capturingOsd

    // When the island is rendering Omarchy's OSD stream, that stream already
    // carries volume and brightness — watching them here as well would push
    // the same event twice on every keypress.
    readonly property bool capturingOsd: config && config.behaviour ? config.behaviour.captureOmarchyOsd === true : false

    // 0..1, or -1 when no controllable backlight exists.
    property real value: -1
    readonly property bool available: value >= 0

    // Set while the control centre is open. Only used to force a re-read; the
    // file watch keeps the value fresh regardless.
    property bool active: false

    property string device: ""
    property real maxValue: 0

    readonly property string glyph: {
        if (value < 0.34)
            return "󰃞";
        if (value < 0.67)
            return "󰃟";
        return "󰃠";
    }

    // ------------------------------------------------------------- reading

    function applyRaw(raw) {
        var current = Number(String(raw).trim());
        if (!isFinite(current) || maxValue <= 0)
            return;
        var next = Math.max(0, Math.min(1, current / maxValue));
        if (Math.abs(next - value) < 0.001)
            return;

        var hadValue = value >= 0;
        value = next;

        // A change we made ourselves is already visible on the slider the user
        // is dragging; throwing a HUD for it would fight the gesture.
        if (hadValue && primed && !selfWrite && hudEnabled && activities) {
            activities.push("brightness", 60, {
                value: value,
                glyph: root.glyph,
                muted: false
            }, Number(options.duration) || 1500);
        }
        selfWrite = false;
    }

    function refresh() {
        if (device !== "")
            levelFile.reload();
    }

    onActiveChanged: if (active)
        refresh()

    // The level at startup is not an event.
    property bool primed: false
    property bool selfWrite: false

    Component.onCompleted: discover.running = true

    Timer {
        id: primeTimer
        interval: 800
        onTriggered: root.primed = true
    }

    // Which backlight to drive. Machines have zero, one, or several; the first
    // is the conventional choice and matches what brightnessctl picks.
    Process {
        id: discover
        command: ["sh", "-c", "ls -1 /sys/class/backlight 2>/dev/null | head -n 1"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                var name = String(text).trim();
                if (name === "")
                    return;
                root.device = name;
                maxFile.reload();
                primeTimer.start();
            }
        }
    }

    FileView {
        id: maxFile
        path: root.device === "" ? "" : "/sys/class/backlight/" + root.device + "/max_brightness"
        printErrors: false
        onLoaded: {
            var max = Number(String(text()).trim());
            if (isFinite(max) && max > 0) {
                root.maxValue = max;
                levelFile.reload();
            }
        }
    }

    FileView {
        id: levelFile
        path: root.device === "" ? "" : "/sys/class/backlight/" + root.device + "/brightness"
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.applyRaw(text())
    }

    // ------------------------------------------------------------- writing

    property real pendingValue: -1

    function set(fraction) {
        var next = Math.max(0.01, Math.min(1, fraction));
        // Move the slider immediately; the device catches up behind us.
        selfWrite = true;
        value = next;
        pendingValue = next;
        if (!writeThrottle.running)
            flush();
    }

    function flush() {
        if (pendingValue < 0)
            return;
        var percent = Math.round(pendingValue * 100);
        pendingValue = -1;
        selfWrite = true;
        writeProc.command = ["brightnessctl", "-m", "set", percent + "%"];
        writeProc.running = true;
        writeThrottle.restart();
    }

    Process {
        id: writeProc
        running: false
    }

    Timer {
        id: writeThrottle
        // Dragging a slider produces far more updates than a backlight can
        // act on; one process per pixel of travel would swamp the session.
        interval: 60
        onTriggered: root.flush()
    }
}
