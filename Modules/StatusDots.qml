import QtQuick
import Quickshell.Networking
import Quickshell.Bluetooth
import Quickshell.Services.UPower
import qs.Commons
import "../Core"

// Three dots for Wi-Fi, Bluetooth and battery, in that order.
//
// The status corner in a dozen pixels: it says "all fine" at a glance and
// asks for attention only by colour. The details live one click away in the
// control sheet, which is why a dot carries no glyph of its own.
//
//   Wi-Fi      foreground when online, faded when off or disconnected
//   Bluetooth  accent with a device connected, foreground when on, faded off
//   Battery    green, yellow under 30%, red under 15%; accent while charging
Item {
    id: root

    property var options: ({})
    property var host: null
    property color foreground: "white"
    property color accent: "white"

    readonly property real dotSize: options.size === undefined ? Math.max(5, Math.round(Style.font.body * 0.42)) : Number(options.size)
    readonly property real gap: options.gap === undefined ? Math.round(dotSize * 0.75) : Number(options.gap)

    // ---------------------------------------------------------------- state

    readonly property var devices: Networking.devices ? Networking.devices.values : []
    readonly property bool online: {
        for (var i = 0; i < devices.length; i++) {
            var d = devices[i];
            if ((d.type === DeviceType.Wired || d.type === DeviceType.Wifi) && d.connected)
                return true;
        }
        return false;
    }

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool btOn: adapter !== null && adapter !== undefined && adapter.enabled === true
    readonly property bool btConnected: {
        if (!btOn || !Bluetooth.devices)
            return false;
        var list = Bluetooth.devices.values;
        for (var i = 0; i < list.length; i++)
            if (list[i].connected)
                return true;
        return false;
    }

    readonly property var battery: UPower.displayDevice
    readonly property bool hasBattery: battery !== null && battery.isLaptopBattery === true
    readonly property real level: hasBattery ? Math.max(0, Math.min(1, battery.percentage)) : 1
    readonly property bool charging: hasBattery && (battery.state === UPowerDeviceState.Charging || battery.state === UPowerDeviceState.FullyCharged)

    readonly property color faded: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.28)

    readonly property var colours: [
        online ? foreground : faded,
        btConnected ? accent : (btOn ? foreground : faded),
        !hasBattery ? faded : charging ? accent : level < 0.15 ? "#f38ba8" : level < 0.3 ? "#f9e2af" : "#a6e3a1"
    ]

    readonly property bool shown: true
    implicitWidth: dotSize * 3 + gap * 2 + Style.space(4)
    implicitHeight: parent ? parent.height : dotSize

    Row {
        anchors.centerIn: parent
        spacing: root.gap

        Repeater {
            model: 3
            Rectangle {
                required property int index
                width: root.dotSize
                height: root.dotSize
                radius: width / 2
                color: root.colours[index]
                Behavior on color {
                    ColorAnimation {
                        duration: 320
                        easing.type: Easing.InOutQuad
                    }
                }
            }
        }
    }
}
