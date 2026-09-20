import QtQuick
import qs.Commons

// A horizontal slider sized for the control centre.
//
// The fill follows the pointer immediately while dragging and animates only
// when the value changes from underneath — turning the volume up with the
// keyboard should glide, but dragging the handle should feel nailed to the
// cursor, and animating that would read as lag.
Item {
    id: root

    property real value: 0
    property real minimum: 0
    property real maximum: 1
    property color foreground: "white"
    property color accent: "white"
    property string glyph: ""
    property bool enabled: true

    signal moved(real value)

    readonly property bool dragging: handler.pressed
    readonly property real fraction: maximum > minimum ? Math.max(0, Math.min(1, (value - minimum) / (maximum - minimum))) : 0

    implicitHeight: Math.max(Style.space(22), Style.font.icon)

    function valueAt(x) {
        var usable = track.width;
        if (usable <= 0)
            return minimum;
        var f = Math.max(0, Math.min(1, (x - track.x) / usable));
        return minimum + f * (maximum - minimum);
    }

    Text {
        id: icon
        anchors.verticalCenter: parent.verticalCenter
        visible: root.glyph !== ""
        width: visible ? Style.space(22) : 0
        text: root.glyph
        color: root.foreground
        font.family: Style.font.family
        font.pixelSize: Style.font.icon
        horizontalAlignment: Text.AlignLeft
        textFormat: Text.PlainText
    }

    Item {
        id: track

        anchors.verticalCenter: parent.verticalCenter
        x: icon.visible ? icon.width + Style.space(6) : 0
        width: root.width - x
        height: Style.space(6)

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.18)
        }

        Rectangle {
            id: fill
            height: parent.height
            width: parent.width * root.fraction
            radius: height / 2
            color: root.accent
            opacity: root.enabled ? 1 : 0.4

            Behavior on width {
                enabled: !root.dragging
                NumberAnimation {
                    duration: 160
                    easing.type: Easing.OutCubic
                }
            }
        }

        Rectangle {
            id: knob
            width: Style.space(12)
            height: width
            radius: width / 2
            color: root.accent
            anchors.verticalCenter: parent.verticalCenter
            x: Math.max(0, Math.min(parent.width - width, fill.width - width / 2))
            scale: root.dragging ? 1.15 : 1

            Behavior on scale {
                NumberAnimation {
                    duration: 120
                    easing.type: Easing.OutCubic
                }
            }
        }
    }

    MouseArea {
        id: handler
        anchors.fill: parent
        // A thin track is hard to hit; the whole row is the target.
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
        preventStealing: true

        onPressed: function (mouse) {
            root.moved(root.valueAt(mouse.x));
        }
        onPositionChanged: function (mouse) {
            if (pressed)
                root.moved(root.valueAt(mouse.x));
        }
    }
}
