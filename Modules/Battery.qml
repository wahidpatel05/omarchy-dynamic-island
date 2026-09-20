import QtQuick
import Quickshell.Services.UPower
import qs.Commons

// Battery level, as a glyph plus optional percentage.
//
// Hidden entirely on machines with no battery, so a desktop does not carry a
// permanently full icon around.
Item {
    id: root

    property var options: ({})
    property color foreground: "white"
    property color accent: "white"

    readonly property var device: UPower.displayDevice
    readonly property bool present: device !== null && device.isLaptopBattery === true
    readonly property real fraction: device && device.percentage !== undefined ? Math.max(0, Math.min(1, device.percentage)) : 0
    readonly property int percent: Math.round(fraction * 100)
    readonly property bool charging: device !== null && device.state === UPowerDeviceState.Charging
    readonly property bool low: !charging && percent <= (options.warnBelow === undefined ? 20 : options.warnBelow)
    readonly property bool showPercentage: options.showPercentage !== false

    // Nerd Font battery glyphs run from empty to full in ten steps.
    readonly property string glyph: {
        if (charging)
            return "󰂄";
        var steps = ["󰂎", "󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"];
        return steps[Math.max(0, Math.min(steps.length - 1, Math.round(fraction * 10)))];
    }

    visible: present
    implicitWidth: present ? row.implicitWidth : 0
    implicitHeight: parent ? parent.height : Style.font.body

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(5)

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.glyph
            color: root.charging ? root.accent : (root.low ? Color.urgent : root.foreground)
            font.family: Style.font.family
            font.pixelSize: Style.font.icon
            textFormat: Text.PlainText
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.showPercentage
            text: root.percent + "%"
            color: root.low ? Color.urgent : root.foreground
            font.family: Style.font.family
            font.pixelSize: Style.font.body
            textFormat: Text.PlainText
        }
    }
}
