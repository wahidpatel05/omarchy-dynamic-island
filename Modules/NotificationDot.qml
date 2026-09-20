import QtQuick
import Quickshell.Services.Notifications
import qs.Commons

// What a notification leaves behind.
//
// A live-activity module in the same sense as the waveform: nothing at all
// most of the time, and a small dot on the resting pill when a notification
// timed out while you were looking elsewhere. It goes away the moment you
// acknowledge it — clicking the island, or opening the control centre, which
// is where the message actually is.
//
// The point is that a notification you missed should cost you a glance at the
// bar rather than a trip to the history. It is the smallest possible amount
// of state: something happened, and you have not looked yet.
Item {
    id: root

    property var options: ({})
    property var host: null
    property color foreground: "white"
    property color accent: "white"
    property real fontSize: 0

    readonly property var source: host ? host.notificationSource : null
    readonly property bool present: source !== null && source !== undefined && source.residue === true

    // Presence is declared to the row through `shown`; see ModuleRow.
    readonly property bool shown: present

    readonly property real dotSize: {
        var explicit = Number(options.size);
        if (isFinite(explicit) && explicit > 0)
            return explicit;
        var base = fontSize > 0 ? fontSize : Style.font.body;
        return Math.max(4, Math.round(base * 0.42));
    }

    readonly property color dotColor: {
        if (source && source.residueUrgency === NotificationUrgency.Critical)
            return Color.urgent;
        return root.accent;
    }

    implicitWidth: present ? dotSize : 0
    implicitHeight: parent ? parent.height : dotSize

    Rectangle {
        anchors.centerIn: parent
        width: root.dotSize
        height: root.dotSize
        radius: height / 2
        color: root.dotColor
        visible: root.present

        // Arrives rather than appears. The island has just finished
        // collapsing when this shows up, and a dot that popped into
        // existence mid-animation reads as a rendering glitch.
        opacity: root.present ? 1 : 0
        scale: root.present ? 1 : 0.4

        Behavior on opacity {
            NumberAnimation {
                duration: 180
                easing.type: Easing.OutCubic
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: 220
                easing.type: Easing.OutBack
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.present
        cursorShape: Qt.PointingHandCursor
        onClicked: if (root.source)
            root.source.clearResidue()
    }
}
