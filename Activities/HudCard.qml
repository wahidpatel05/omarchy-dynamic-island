import QtQuick
import qs.Commons

// The volume / brightness heads-up display.
//
// Replaces the system overlay rather than duplicating it: the same gesture
// that used to throw a panel into the middle of the screen now widens the
// island you are already looking at. Deliberately the highest-priority
// activity — you just pressed a key and want to see the result, so this
// preempts a notification rather than queueing behind it.
Item {
    id: root

    property var activity: null
    property var options: ({})
    property color foreground: "white"
    property color accent: "white"

    readonly property var payload: activity ? activity.data : null
    readonly property real fraction: payload ? Math.max(0, Math.min(1, Number(payload.value) || 0)) : 0
    readonly property string glyph: payload ? String(payload.glyph || "") : ""
    readonly property bool muted: payload ? payload.muted === true : false
    // Not every HUD is a level. Mute, keyboard backlight and touchpad toggles
    // carry a word instead of a bar, and the card has to size to either.
    readonly property bool hasProgress: payload ? payload.hasProgress !== false : true
    readonly property string message: payload ? String(payload.message || "") : ""

    readonly property int pad: Style.space(16)
    readonly property int gap: Style.space(12)
    readonly property int barWidth: Style.space(128)

    implicitWidth: hasProgress ? pad * 2 + iconSlot.width + gap + barWidth + gap + readout.width : pad * 2 + iconSlot.width + (message === "" ? 0 : gap + Math.ceil(messageMetrics.width))
    implicitHeight: Style.space(38)

    TextMetrics {
        id: messageMetrics
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        font.bold: true
        text: root.message
    }

    Item {
        id: iconSlot
        x: root.pad
        anchors.verticalCenter: parent.verticalCenter
        // Pinned to the widest glyph the HUD can show, so the bar does not
        // shuffle sideways as the level crosses an icon threshold.
        width: Math.ceil(widest.width)
        height: parent.height

        TextMetrics {
            id: widest
            font.family: Style.font.family
            font.pixelSize: Style.font.iconLarge
            text: "󰕾"
        }

        Text {
            anchors.centerIn: parent
            text: root.glyph
            color: root.muted ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.5) : root.foreground
            font.family: Style.font.family
            font.pixelSize: Style.font.iconLarge
            textFormat: Text.PlainText
        }
    }

    Text {
        visible: !root.hasProgress && root.message !== ""
        x: root.pad + iconSlot.width + root.gap
        anchors.verticalCenter: parent.verticalCenter
        text: root.message
        color: root.foreground
        font: messageMetrics.font
        textFormat: Text.PlainText
    }

    Rectangle {
        id: track
        visible: root.hasProgress
        x: root.pad + iconSlot.width + root.gap
        anchors.verticalCenter: parent.verticalCenter
        width: root.barWidth
        height: Style.space(6)
        radius: height / 2
        color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.18)

        Rectangle {
            width: parent.width * root.fraction
            height: parent.height
            radius: height / 2
            color: root.muted ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.4) : root.accent

            // Repeated key presses update an already-open HUD, so the fill
            // slides between levels instead of jumping.
            Behavior on width {
                NumberAnimation {
                    duration: 130
                    easing.type: Easing.OutCubic
                }
            }
        }
    }

    Text {
        id: readout
        visible: root.hasProgress
        x: root.pad + iconSlot.width + root.gap + root.barWidth + root.gap
        anchors.verticalCenter: parent.verticalCenter
        // Sized to the widest reading so 9% and 100% do not shift the layout.
        width: Math.ceil(readoutWidest.width)
        horizontalAlignment: Text.AlignRight
        text: Math.round(root.fraction * 100) + "%"
        color: root.foreground
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        font.bold: true
        textFormat: Text.PlainText

        TextMetrics {
            id: readoutWidest
            font: readout.font
            text: "100%"
        }
    }
}
