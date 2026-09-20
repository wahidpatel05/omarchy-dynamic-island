import QtQuick
import qs.Commons

// The running task's glyph, on the island's leading edge.
//
// Paired with LiveRing at the other end: a mark saying *what* is running and
// a ring saying *how far*, with the pill's own content in between. Both
// vanish when nothing is running.
//
// A task that sends no glyph gets a generic one rather than an empty slot,
// because the leading mark is what makes the ring legible — a ring on its own
// is a progress bar for an unnamed thing.
Item {
    id: root

    property var options: ({})
    property var host: null
    property color foreground: "white"
    property color accent: "white"
    property real fontSize: 0

    readonly property var source: host ? host.liveSource : null
    readonly property var task: source ? source.primary : null

    readonly property string glyph: {
        if (!task)
            return "";
        if (task.glyph && task.glyph !== "")
            return task.glyph;
        if (task.state === "failed")
            return "󰅙";
        if (task.state === "done")
            return "󰄬";
        return options.glyph === undefined ? "󰄉" : String(options.glyph);
    }

    readonly property bool shown: task !== null && task !== undefined && glyph !== ""

    readonly property color glyphColor: {
        if (task && task.state === "failed")
            return Color.urgent;
        if (task && task.state === "done")
            return root.accent;
        return root.foreground;
    }

    implicitWidth: shown ? label.implicitWidth : 0
    implicitHeight: parent ? parent.height : Style.font.icon

    Text {
        id: label
        anchors.centerIn: parent
        visible: root.shown
        text: root.glyph
        color: root.glyphColor
        font.family: Style.font.family
        font.pixelSize: root.fontSize > 0 ? Math.round(root.fontSize * 1.17) : Style.font.icon
        textFormat: Text.PlainText
    }
}
