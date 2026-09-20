import QtQuick
import Quickshell.Bluetooth
import qs.Commons
import "../Core"

// Bluetooth state, in the status corner.
//
// Three states worth distinguishing, because they need three different
// reactions from you: off (you turned the radio off), on but idle, and
// connected to something. A machine with no adapter at all hides the module
// rather than showing a permanently dead icon.
//
// Clicking does nothing by default. `omarchy bluetooth power toggle` is the
// obvious thing to put in `command`, but a stray click killing the headphones
// you are listening through is a worse default than an inert icon.
Item {
    id: root

    property var options: ({})
    property var host: null
    property string screenName: ""
    property color foreground: "white"
    property color accent: "white"
    property real hoverOpacity: 0.1
    // 0 follows the theme; the glass capsule passes its own size down.
    property real fontSize: 0

    // An Omarchy bar-widget plugin to open on click; `command` is the
    // fallback. See Network.
    readonly property string panelPlugin: options.panel === undefined ? "" : String(options.panel)
    readonly property string command: options.command === undefined ? "" : String(options.command)

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool powered: adapter !== null && adapter !== undefined && adapter.enabled === true

    readonly property int connectedCount: {
        if (!powered || !Bluetooth.devices)
            return 0;
        var devices = Bluetooth.devices.values;
        var count = 0;
        for (var i = 0; i < devices.length; i++) {
            if (devices[i].connected)
                count++;
        }
        return count;
    }

    readonly property string glyph: {
        if (!powered)
            return "󰂲";
        return connectedCount > 0 ? "󰂱" : "󰂯";
    }

    readonly property string tooltip: {
        if (!powered)
            return "Bluetooth off";
        if (connectedCount === 0)
            return "Bluetooth on";
        var names = [];
        var devices = Bluetooth.devices ? Bluetooth.devices.values : [];
        for (var i = 0; i < devices.length; i++) {
            if (!devices[i].connected)
                continue;
            var name = String(devices[i].deviceName || devices[i].name || "");
            // Battery is the reason to look at a headphone icon at all.
            if (devices[i].batteryAvailable && devices[i].battery > 0)
                name += "  ·  " + Math.round(devices[i].battery * 100) + "%";
            names.push(name);
        }
        return names.join("\n");
    }

    // Presence is declared to the row through `shown`; see ModuleRow.
    readonly property bool shown: adapter !== null && adapter !== undefined
    implicitWidth: shown ? button.implicitWidth : 0
    implicitHeight: parent ? parent.height : Style.font.icon

    PanelSlot {
        id: panelSlot
        anchors.fill: parent
        host: root.host
        screenName: root.screenName
        pluginId: root.panelPlugin
    }

    GlyphButton {
        id: button
        anchors.fill: parent

        glyph: root.glyph
        host: root.host
        tooltipText: root.tooltip
        fontSize: root.fontSize > 0 ? Math.round(root.fontSize * 1.17) : 0
        // Off reads as dimmed rather than as a different colour, so the row
        // keeps one accent — the one that means "something is connected".
        foreground: root.connectedCount > 0 ? root.accent : (root.powered ? root.foreground : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.45))
        hoverOpacity: root.hoverOpacity
        interactive: panelSlot.available || root.command !== ""

        onActivated: function () {
            if (panelSlot.available)
                panelSlot.toggle();
            else if (root.host)
                root.host.run(root.command);
        }
    }
}
