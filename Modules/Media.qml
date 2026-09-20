import QtQuick
import qs.Commons
import "../Core"

// Compact now-playing, for the resting pill or the hover row.
//
// Renders nothing at all when there is no media. A module that collapses to
// zero width lets the island shrink back to its resting size instead of
// holding a gap open for a player that is not running.
Item {
    id: root

    property var options: ({})
    property var host: null
    property color foreground: "white"
    property color accent: "white"

    readonly property var media: host ? host.mediaSource : null
    readonly property bool hasMedia: media ? media.hasMedia : false
    readonly property int maxWidth: Style.space(options.maxTitleWidth || 150)

    visible: hasMedia
    implicitWidth: hasMedia ? row.implicitWidth : 0
    implicitHeight: parent ? parent.height : Style.font.body

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(7)

        Equalizer {
            anchors.verticalCenter: parent.verticalCenter
            color: root.accent
            active: root.media ? root.media.playing : false
            bars: 3
            maxHeight: Style.space(11)
        }

        TextMetrics {
            id: metrics
            font.family: Style.font.family
            font.pixelSize: Style.font.body
            text: root.media ? root.media.title : ""
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(root.maxWidth, metrics.width)
            text: metrics.text
            color: root.foreground
            font: metrics.font
            elide: Text.ElideRight
            maximumLineCount: 1
            textFormat: Text.PlainText
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.hasMedia
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor
        onClicked: function (mouse) {
            if (!root.media)
                return;
            if (mouse.button === Qt.MiddleButton)
                root.media.next();
            else
                root.media.toggle();
        }
    }
}
