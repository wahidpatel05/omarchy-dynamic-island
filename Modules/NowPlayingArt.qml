import QtQuick
import qs.Commons
import "../Core"

// Album art in the resting pill.
//
// A live-activity module: invisible with nothing playing, so the pill has no
// idea it exists until music starts and then simply grows a cover on its
// leading edge. Clicking toggles playback, which makes the art the pill's
// play/pause button without needing one.
Item {
    id: root

    property var options: ({})
    property var host: null
    property color foreground: "white"
    property color accent: "white"

    readonly property var media: host ? host.mediaSource : null
    readonly property bool hasMedia: media ? media.hasMedia : false

    // Fills the pill's height with a hair of breathing room, the way a cover
    // sits inside the notch on a Mac.
    readonly property real size: Math.max(Style.space(16), (parent ? parent.height : Style.space(22)) - Style.space(4))

    // Presence is declared to the row through `shown`; see ModuleRow.
    readonly property bool shown: hasMedia
    implicitWidth: hasMedia ? size : 0
    implicitHeight: parent ? parent.height : size

    AlbumArt {
        anchors.verticalCenter: parent.verticalCenter
        width: root.size
        height: root.size
        radius: width * 0.3
        source: root.media ? root.media.artUrl : ""
        foreground: root.foreground
        accent: root.accent
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.hasMedia
        cursorShape: Qt.PointingHandCursor
        onClicked: if (root.media)
            root.media.toggle()
    }
}
