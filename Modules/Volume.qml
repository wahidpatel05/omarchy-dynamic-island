import QtQuick
import Quickshell.Services.Pipewire
import qs.Commons

// Output volume, as a speaker glyph plus optional percentage.
//
// The PwObjectTracker is not optional: PipeWire node properties are only bound
// while something is tracking the node, and without it `audio.volume` reads
// zero forever.
Item {
    id: root

    property var options: ({})
    property color foreground: "white"
    property color accent: "white"
    // 0 follows the theme; see Clock.
    property real fontSize: 0
    readonly property real glyphSize: fontSize > 0 ? Math.round(fontSize * 1.17) : Style.font.icon

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property real volume: sink && sink.audio ? sink.audio.volume : 0
    readonly property bool muted: sink && sink.audio ? sink.audio.muted : false
    readonly property int percent: Math.round(volume * 100)
    readonly property bool showPercentage: options.showPercentage === true

    PwObjectTracker {
        objects: root.sink ? [root.sink] : []
    }

    readonly property string glyph: {
        if (muted || percent === 0)
            return "󰝟";
        if (percent < 34)
            return "󰕿";
        if (percent < 67)
            return "󰖀";
        return "󰕾";
    }

    implicitWidth: row.implicitWidth
    implicitHeight: parent ? parent.height : Style.font.body

    Row {
        id: row
        // Centred rather than left-anchored: a glass capsule hands every
        // module a slot as wide as the row is tall, and content pinned to the
        // left edge of that slot would break the corner's pitch.
        anchors.centerIn: parent
        spacing: Style.space(5)

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.glyph
            color: root.muted ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.45) : root.foreground
            font.family: Style.font.family
            font.pixelSize: root.glyphSize
            textFormat: Text.PlainText
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.showPercentage
            text: root.percent + "%"
            color: root.foreground
            font.family: Style.font.family
            font.pixelSize: root.fontSize > 0 ? root.fontSize : Style.font.body
            textFormat: Text.PlainText
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        cursorShape: Qt.PointingHandCursor
        onClicked: if (root.sink && root.sink.audio)
            root.sink.audio.muted = !root.sink.audio.muted
    }
}
