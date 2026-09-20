import QtQuick
import Quickshell.Services.UPower
import qs.Commons
import "../Core"

// Battery level, as a glyph plus optional percentage.
//
// Hidden entirely on machines with no battery, so a desktop does not carry a
// permanently full icon around.
Item {
    id: root

    property var options: ({})
    property var host: null
    property string screenName: ""
    property color foreground: "white"
    property color accent: "white"
    property real hoverOpacity: 0.1
    // 0 follows the theme; see Clock.
    property real fontSize: 0
    readonly property real glyphSize: fontSize > 0 ? Math.round(fontSize * 1.17) : Style.font.icon

    readonly property var device: UPower.displayDevice
    readonly property bool present: device !== null && device.isLaptopBattery === true
    readonly property real fraction: device && device.percentage !== undefined ? Math.max(0, Math.min(1, device.percentage)) : 0
    readonly property int percent: Math.round(fraction * 100)
    readonly property bool charging: device !== null && device.state === UPowerDeviceState.Charging
    readonly property bool low: !charging && percent <= (options.warnBelow === undefined ? 20 : options.warnBelow)
    readonly property bool showPercentage: options.showPercentage !== false

    // An Omarchy bar-widget plugin to open on click — `omarchy.power` is the
    // one that knows about batteries. Mounted invisibly behind the glyph; see
    // Core/PanelSlot.qml.
    readonly property string panelPlugin: options.panel === undefined ? "" : String(options.panel)

    // Nerd Font battery glyphs run from empty to full in ten steps.
    readonly property string glyph: {
        if (charging)
            return "󰂄";
        var steps = ["󰂎", "󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"];
        return steps[Math.max(0, Math.min(steps.length - 1, Math.round(fraction * 10)))];
    }

    // Presence is declared to the row through `shown`; see ModuleRow.
    readonly property bool shown: present
    implicitWidth: present ? row.implicitWidth : 0
    implicitHeight: parent ? parent.height : Style.font.body

    PanelSlot {
        id: panelSlot
        anchors.fill: parent
        host: root.host
        screenName: root.screenName
        pluginId: root.panelPlugin
    }

    SlotButton {
        anchors.fill: parent
        foreground: root.foreground
        hoverOpacity: root.hoverOpacity
        interactive: panelSlot.available
        onActivated: panelSlot.toggle()

        Row {
            id: row
            // Centred rather than left-anchored: a glass capsule hands every
            // module a slot as wide as the row is tall, and content pinned to
            // the left edge of that slot would break the corner's pitch.
            anchors.centerIn: parent
            spacing: Style.space(5)

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.glyph
                color: root.charging ? root.accent : (root.low ? Color.urgent : root.foreground)
                font.family: Style.font.family
                font.pixelSize: root.glyphSize
                textFormat: Text.PlainText
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.showPercentage
                text: root.percent + "%"
                color: root.low ? Color.urgent : root.foreground
                font.family: Style.font.family
                font.pixelSize: root.fontSize > 0 ? root.fontSize : Style.font.body
                textFormat: Text.PlainText
            }
        }
    }
}
