import QtQuick
import qs.Commons
import "../Core"

// A live activity announcing itself.
//
// Shown for a couple of seconds when a task starts and again when it ends,
// and not at all in between — the middle of a long task belongs on the
// resting pill, as a glyph and a ring, not in a card holding the island open.
// So this is the punctuation, and Modules/LiveRing is the sentence.
//
// Width is measured with TextMetrics rather than taken from the label's
// `implicitWidth`: an elided Text derives its implicit width from the width
// it was given, so reading it back to size the island closes a binding loop
// that the island's spring then recurses into until the stack gives out.
Item {
    id: root

    property var activity: null
    property var options: ({})
    property color foreground: "white"
    property color accent: "white"

    readonly property var payload: activity ? activity.data : null
    readonly property var task: payload ? payload.task : null
    readonly property int count: payload ? Number(payload.count) || 0 : 0

    readonly property string label: task ? String(task.label || task.id || "") : ""
    readonly property string state: task ? String(task.state || "running") : "running"
    readonly property real fraction: task && task.fraction >= 0 ? task.fraction : 0
    readonly property bool indeterminate: task !== null && task !== undefined && task.fraction < 0 && state === "running"

    readonly property string glyph: {
        if (!task)
            return "󰄉";
        if (task.glyph && task.glyph !== "")
            return task.glyph;
        if (state === "failed")
            return "󰅙";
        if (state === "done")
            return "󰄬";
        return "󰄉";
    }

    // The second line is whatever the task said, or a percentage if it said
    // nothing but knows how far along it is. A task that is neither is left
    // with one line rather than an empty one.
    readonly property string detail: {
        if (!task)
            return "";
        if (task.detail && task.detail !== "")
            return String(task.detail);
        if (state === "failed")
            return "failed";
        if (state === "done")
            return "done";
        if (task.fraction >= 0)
            return Math.round(task.fraction * 100) + "%";
        return "";
    }

    readonly property color tint: {
        if (state === "failed")
            return Color.urgent;
        if (task && task.accent && task.accent !== "")
            return task.accent;
        return root.accent;
    }

    readonly property int pad: Style.space(15)
    readonly property int gap: Style.space(12)
    readonly property int ringSize: Style.space(26)

    TextMetrics {
        id: labelMetrics
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        font.bold: true
        text: root.label
    }

    TextMetrics {
        id: detailMetrics
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        text: root.detail
    }

    readonly property int textWidth: Math.min(Style.space(230), Math.ceil(Math.max(labelMetrics.width, detailMetrics.width)))

    implicitWidth: pad * 2 + glyphSlot.width + gap + textWidth + gap + ringSize
    implicitHeight: Style.space(44)

    Item {
        id: glyphSlot
        x: root.pad
        anchors.verticalCenter: parent.verticalCenter
        width: Math.ceil(glyphMetrics.width)
        height: parent.height

        TextMetrics {
            id: glyphMetrics
            font.family: Style.font.family
            font.pixelSize: Style.font.iconLarge
            text: root.glyph
        }

        Text {
            anchors.centerIn: parent
            text: root.glyph
            color: root.state === "running" ? root.foreground : root.tint
            font.family: Style.font.family
            font.pixelSize: Style.font.iconLarge
            textFormat: Text.PlainText
        }
    }

    Column {
        anchors.left: glyphSlot.right
        anchors.leftMargin: root.gap
        anchors.verticalCenter: parent.verticalCenter
        width: root.textWidth
        spacing: Style.space(1)

        Text {
            width: parent.width
            text: root.label
            color: root.foreground
            font.family: Style.font.family
            font.pixelSize: Style.font.body
            font.bold: true
            elide: Text.ElideRight
            maximumLineCount: 1
            textFormat: Text.PlainText
        }

        Text {
            visible: root.detail !== ""
            width: parent.width
            // A second task running behind this one is worth knowing about,
            // and the ring only ever shows the one in front.
            text: root.count > 1 ? root.detail + "  ·  +" + (root.count - 1) : root.detail
            color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.6)
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            elide: Text.ElideRight
            maximumLineCount: 1
            textFormat: Text.PlainText
        }
    }

    ProgressRing {
        anchors.right: parent.right
        anchors.rightMargin: root.pad
        anchors.verticalCenter: parent.verticalCenter
        width: root.ringSize
        height: root.ringSize

        value: root.fraction
        indeterminate: root.indeterminate
        color: root.tint
        trackColor: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.18)
    }
}
