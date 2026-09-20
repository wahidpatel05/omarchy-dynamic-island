import QtQuick
import Quickshell
import Quickshell.Io

// Backlight level, via brightnessctl.
//
// Read on demand rather than polled: the value only matters while the control
// centre is open, and a timer ticking a subprocess every second for a slider
// nobody is looking at is a poor trade. Writes are throttled because dragging
// a slider generates far more updates than the backlight can act on, and
// firing a process per pixel of drag would swamp the session.
Item {
    id: root

    // 0..1, or -1 when no controllable backlight exists.
    property real value: -1
    readonly property bool available: value >= 0

    property bool active: false

    property real pendingValue: -1

    function refresh() {
        if (!readProc.running)
            readProc.running = true;
    }

    function set(fraction) {
        var next = Math.max(0.01, Math.min(1, fraction));
        // Show the new level immediately; the device catches up behind us.
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
        writeProc.command = ["brightnessctl", "-m", "set", percent + "%"];
        writeProc.running = true;
        writeThrottle.restart();
    }

    onActiveChanged: if (active)
        refresh()

    Process {
        id: readProc
        command: ["brightnessctl", "-m", "i"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                // device,class,current,percent%,max
                var parts = String(text).trim().split("\n")[0].split(",");
                if (parts.length < 5)
                    return;
                var current = Number(parts[2]);
                var max = Number(parts[4]);
                if (isFinite(current) && isFinite(max) && max > 0)
                    root.value = Math.max(0, Math.min(1, current / max));
            }
        }
    }

    Process {
        id: writeProc
        running: false
    }

    Timer {
        id: writeThrottle
        interval: 60
        onTriggered: root.flush()
    }
}
