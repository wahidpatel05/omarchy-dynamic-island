import QtQuick
import Quickshell.Networking
import qs.Commons
import "../Core"

// Wi-Fi / ethernet state, in the status corner.
//
// Signal strength comes off the connected `WifiNetwork` rather than off the
// device, because a device stays "connected" through a roam while the access
// point behind it changes — reading the network keeps the arcs honest.
//
// A machine with no NetworkManager at all reports no devices, which is
// indistinguishable from "everything is down". Both draw the disconnected
// glyph, which is the truthful answer either way.
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

    // An Omarchy bar-widget plugin to open on click. Mounted invisibly behind
    // the glyph, so the real Wi-Fi list opens under it. `command` is the
    // fallback for when that plugin is disabled or missing.
    readonly property string panelPlugin: options.panel === undefined ? "" : String(options.panel)
    readonly property string command: options.command === undefined ? "" : String(options.command)

    readonly property var devices: Networking.devices ? Networking.devices.values : []

    readonly property var wiredDevice: {
        for (var i = 0; i < devices.length; i++) {
            if (devices[i].type === DeviceType.Wired && devices[i].connected)
                return devices[i];
        }
        return null;
    }

    // A machine can carry several Wi-Fi devices — a p2p interface sits
    // alongside the real radio on most of them — and the first one is not
    // reliably the one that is up. Prefer a connected radio and only fall
    // back to the first.
    readonly property var wifiDevice: {
        var first = null;
        for (var i = 0; i < devices.length; i++) {
            if (devices[i].type !== DeviceType.Wifi)
                continue;
            if (devices[i].connected)
                return devices[i];
            if (!first)
                first = devices[i];
        }
        return first;
    }

    readonly property var activeNetwork: {
        var device = root.wifiDevice;
        if (!device || !device.connected || !device.networks)
            return null;
        var networks = device.networks.values;
        for (var i = 0; i < networks.length; i++) {
            if (networks[i].connected)
                return networks[i];
        }
        return null;
    }

    // `signalStrength` is a 0..1 fraction, not a percentage — reading it as
    // one puts every connection on the empty-arcs glyph.
    readonly property int strength: activeNetwork && activeNetwork.signalStrength !== undefined ? Math.max(0, Math.min(100, Math.round(activeNetwork.signalStrength * 100))) : -1

    readonly property string glyph: {
        if (root.wiredDevice)
            return "󰈀";
        if (root.wifiDevice && root.wifiDevice.connected) {
            if (root.strength < 0)
                return "󰤨";
            var arcs = ["󰤯", "󰤟", "󰤢", "󰤥", "󰤨"];
            return arcs[Math.max(0, Math.min(4, Math.ceil(root.strength / 20) - 1))];
        }
        if (Networking.wifiEnabled === false)
            return "󰤮";
        return "󰤯";
    }

    readonly property bool online: wiredDevice !== null || (wifiDevice !== null && wifiDevice.connected === true)

    readonly property string tooltip: {
        if (root.wiredDevice)
            return "Ethernet";
        if (root.activeNetwork)
            return String(root.activeNetwork.name || "Wi-Fi") + (root.strength >= 0 ? "  ·  " + root.strength + "%" : "");
        if (Networking.wifiEnabled === false)
            return "Wi-Fi off";
        return "Not connected";
    }

    implicitWidth: button.implicitWidth
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
        foreground: root.online ? root.foreground : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.5)
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
