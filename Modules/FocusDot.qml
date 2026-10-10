import QtQuick
import qs.Commons

// Focus, on the resting pill.
//
// A crescent beside the clock while the island is holding notifications back,
// so a quiet bar reads as "quiet on purpose" rather than "nothing happened".
// Nothing at all when focus is off. Click to end it.
Item {
    id: root

    property var options: ({})
    property var host: null
    property color foreground: "white"
    property color accent: "white"
    property real fontSize: 0

    readonly property var source: host ? host.notificationSource : null
    readonly property bool present: source !== null && source !== undefined && source.focused === true

    // Presence is declared to the row through `shown`; see ModuleRow.
    readonly property bool shown: present

    readonly property color tint: options.color ? options.color : Qt.rgba(foreground.r, foreground.g, foreground.b, 0.75)

    implicitWidth: present ? glyph.implicitWidth : 0
    implicitHeight: parent ? parent.height : glyph.implicitHeight

    Text {
        id: glyph
        anchors.centerIn: parent
        text: "󰽥"
        color: root.tint
        font.family: Style.font.family
        font.pixelSize: root.fontSize > 0 ? Math.round(root.fontSize * 0.92) : Style.font.body
        visible: opacity > 0
        opacity: root.present ? 1 : 0

        // Slow, unhurried fade: focus is a mood, not an event.
        Behavior on opacity {
            NumberAnimation {
                duration: 420
                easing.type: Easing.InOutQuad
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.present
        cursorShape: Qt.PointingHandCursor
        onClicked: if (root.source)
            root.source.setFocus(0)
    }
}
