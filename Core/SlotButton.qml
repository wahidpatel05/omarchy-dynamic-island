import QtQuick
import qs.Commons

// The interaction chrome a capsule slot gets: a wash on hover, and a click.
//
// Separate from what is drawn in the slot, because the things that want to be
// clickable in the status corner are not all glyphs — the clock is text, the
// battery is a glyph and a percentage. Whatever goes inside is laid over the
// wash and under the pointer handling, so a module only has to say what it
// looks like.
Item {
    id: root

    property color foreground: "white"
    property real hoverOpacity: 0.1
    property bool interactive: true

    // Emitted with the Qt mouse button that produced it, so a caller can give
    // right-click its own meaning without a second handler.
    signal activated(int button)

    readonly property bool hovered: interactive && mouse.containsMouse

    default property alias content: holder.data

    Rectangle {
        anchors.fill: parent
        anchors.topMargin: Style.space(3)
        anchors.bottomMargin: Style.space(3)
        radius: Math.min(width, height) * 0.34
        color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, root.hoverOpacity)
        opacity: root.hovered ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: 130
                easing.type: Easing.OutCubic
            }
        }
    }

    Item {
        id: holder
        anchors.fill: parent
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: root.interactive
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor
        onClicked: function (event) {
            root.activated(event.button);
        }
    }
}
