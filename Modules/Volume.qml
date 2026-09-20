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
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(5)

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.glyph
            color: root.muted ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.45) : root.foreground
            font.family: Style.font.family
            font.pixelSize: Style.font.icon
            textFormat: Text.PlainText
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.showPercentage
            text: root.percent + "%"
            color: root.foreground
            font.family: Style.font.family
            font.pixelSize: Style.font.body
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
