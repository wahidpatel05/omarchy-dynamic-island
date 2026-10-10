import QtQuick
import qs.Commons
import "../Core"

// What's playing, at rest: a round thumbnail inside a thin progress ring.
//
// The quiet version of now-playing. The island barely widens when a track
// starts, and the only thing that moves is the ring creeping round as the
// track plays. Title and controls are the hover row's job.
//
// Paused holds the ring and dims the thumbnail; a player that cannot report
// its position draws the track without a sweep rather than a ring stuck at 0.
Item {
    id: root

    property var options: ({})
    property var host: null
    property color foreground: "white"
    property color accent: "white"

    readonly property var media: host ? host.mediaSource : null
    readonly property bool hasMedia: media ? media.hasMedia : false
    readonly property bool playing: media ? media.playing : false
    readonly property real progress: media && media.positionSupported && media.length > 0 ? media.position / media.length : 0

    readonly property real size: Math.max(Style.space(18), (parent ? parent.height : Style.space(22)) - Style.space(2))
    readonly property real thickness: Math.max(1.5, Math.round(size * 0.09))

    readonly property bool shown: hasMedia
    implicitWidth: hasMedia ? size : 0
    implicitHeight: parent ? parent.height : size

    ProgressRing {
        anchors.centerIn: parent
        width: root.size
        height: root.size
        value: root.progress
        thickness: root.thickness
        color: root.accent
        trackColor: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.14)
    }

    AlbumArt {
        anchors.centerIn: parent
        width: root.size - root.thickness * 2 - Style.space(3)
        height: width
        radius: width / 2
        source: root.media ? root.media.artUrl : ""
        foreground: root.foreground
        accent: root.accent
        opacity: root.playing ? 1 : 0.55
        Behavior on opacity {
            NumberAnimation {
                duration: 320
                easing.type: Easing.InOutQuad
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.hasMedia
        cursorShape: Qt.PointingHandCursor
        onClicked: if (root.media)
            root.media.toggle()
    }
}
