import QtQuick
import Quickshell.Services.UPower
import "../Core/Config.js" as Config

// Power events: plugged in, unplugged, and running low.
//
// Only transitions are announced, never the standing state — the island says
// "charging" at the moment the cable goes in, not for as long as it stays in.
Item {
    id: root

    property var config: null
    property var activities: null

    readonly property var options: Config.activityOptions(config, "power")
    readonly property bool enabled: options.enabled === true

    readonly property var device: UPower.displayDevice
    readonly property bool present: device !== null && device.isLaptopBattery === true
    readonly property bool charging: device !== null && device.state === UPowerDeviceState.Charging
    readonly property real fraction: device && device.percentage !== undefined ? Math.max(0, Math.min(1, device.percentage)) : 0
    readonly property int percent: Math.round(fraction * 100)

    readonly property int warnBelow: Number(options.warnBelow) || 20

    function push(label, glyph, urgent) {
        if (!enabled || !activities || !present)
            return;
        activities.push("power", 40, {
            label: label,
            glyph: glyph,
            percent: root.percent,
            urgent: urgent === true
        }, Number(options.duration) || 3000);
    }

    // As with volume, the state at startup is not an event.
    property bool primed: false
    property bool lastCharging: false
    property bool warned: false

    Component.onCompleted: primeTimer.start()

    Timer {
        id: primeTimer
        interval: 1500
        onTriggered: {
            root.lastCharging = root.charging;
            root.warned = !root.charging && root.percent <= root.warnBelow;
            root.primed = true;
        }
    }

    onChargingChanged: {
        if (!primed || charging === lastCharging)
            return;
        lastCharging = charging;
        if (charging) {
            // Plugging in clears the low-battery warning, so unplugging again
            // at a still-low level warns afresh rather than staying silent.
            warned = false;
            push("Charging", "󰂄", false);
        } else {
            push("On battery", "󰂃", false);
        }
    }

    onPercentChanged: {
        if (!primed || charging)
            return;
        if (percent <= warnBelow && !warned) {
            warned = true;
            push("Low battery", "󰂃", true);
        } else if (percent > warnBelow + 5) {
            // Hysteresis: without it a level hovering on the threshold would
            // re-warn every time it ticked across.
            warned = false;
        }
    }
}
