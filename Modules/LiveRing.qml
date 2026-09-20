import QtQuick
import qs.Commons
import "../Core"

// The progress ring on the island's trailing edge.
//
// A live-activity module in the same sense as the waveform: it renders
// nothing at all unless something is running, so the pill quietly grows a
// ring when a task starts and shrinks back when it ends. Nothing has to
// switch it on, and an idle island is not carrying a widget waiting for
// work.
Item {
    id: root

    property var options: ({})
    property var host: null
    property color foreground: "white"
    property color accent: "white"
    property real fontSize: 0

    readonly property var source: host ? host.liveSource : null
    readonly property var task: source ? source.primary : null

    // Presence is declared to the row through `shown`; see ModuleRow.
    readonly property bool shown: task !== null && task !== undefined

    readonly property real ringSize: {
        var explicit = Number(options.size);
        if (isFinite(explicit) && explicit > 0)
            return explicit;
        var base = fontSize > 0 ? fontSize : Style.font.body;
        return Math.round(base * 1.25);
    }

    // A failed task goes urgent, a finished one goes accent, and a running
    // one takes whatever the caller asked for — so a script can colour its
    // own ring without the island having opinions about what a build is.
    readonly property color ringColor: {
        if (!task)
            return root.accent;
        if (task.state === "failed")
            return Color.urgent;
        if (task.accent && task.accent !== "")
            return task.accent;
        return root.accent;
    }

    implicitWidth: shown ? ringSize : 0
    implicitHeight: parent ? parent.height : ringSize

    ProgressRing {
        anchors.centerIn: parent
        width: root.ringSize
        height: root.ringSize
        visible: root.shown

        value: root.task && root.task.fraction >= 0 ? root.task.fraction : 0
        indeterminate: root.task !== null && root.task !== undefined && root.task.fraction < 0 && root.task.state === "running"
        color: root.ringColor
        trackColor: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.18)
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.shown
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor
        // Middle-click drops a task the island is still carrying — the escape
        // hatch for a script that died without saying it was done.
        onClicked: function (mouse) {
            if (!root.source || !root.task)
                return;
            if (mouse.button === Qt.MiddleButton)
                root.source.remove(root.task.id);
        }
    }
}
