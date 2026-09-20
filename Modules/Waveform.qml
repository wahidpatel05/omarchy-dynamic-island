import QtQuick
import qs.Commons
import "../Core"

// The playback visualiser on the pill's trailing edge.
//
// The partner to the album art: nothing exists here until something plays.
// Bars keep moving while playing and settle flat when paused, so the pill
// shows playback state without a glyph for it.
Item {
    id: root

    property var options: ({})
    property var host: null
    property color foreground: "white"
    property color accent: "white"

    readonly property var media: host ? host.mediaSource : null
    readonly property bool hasMedia: media ? media.hasMedia : false

    // Presence is declared to the row through `shown`; see ModuleRow.
    readonly property bool shown: hasMedia
    implicitWidth: hasMedia ? bars.width : 0
    implicitHeight: parent ? parent.height : Style.space(16)

    Equalizer {
        id: bars
        anchors.verticalCenter: parent.verticalCenter
        color: root.accent
        active: root.media ? root.media.playing : false
        bars: Math.max(2, Math.min(8, options.bars || 4))
        maxHeight: Math.max(Style.space(10), root.height - Style.space(12))
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.hasMedia
        cursorShape: Qt.PointingHandCursor
        onClicked: if (root.media)
            root.media.next()
    }
}
