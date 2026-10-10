import QtQuick
import qs.Commons
import "../Core"

// Art, title and source in one line, for the hover row.
//
// The title fades out at its edge instead of ending in "…", so a long
// episode name reads as "there is more" rather than as a cut. The source is
// the player's own name ("Netflix - Pixel 9", "Spotify"), dimmed after the
// title. No running clock: the island already shows the time once.
Item {
    id: root

    property var options: ({})
    property var host: null
    property color foreground: "white"
    property color accent: "white"

    readonly property var media: host ? host.mediaSource : null
    readonly property bool hasMedia: media ? media.hasMedia : false
    readonly property int maxTitle: Style.space(options.maxTitleWidth || 170)
    readonly property bool showSource: options.showSource !== false && source !== ""
    readonly property string source: media ? (media.identity || "") : ""

    readonly property real artSize: Math.max(Style.space(16), (parent ? parent.height : Style.space(22)) - Style.space(4))

    readonly property bool shown: hasMedia
    implicitWidth: hasMedia ? row.implicitWidth : 0
    implicitHeight: parent ? parent.height : artSize

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(8)

        AlbumArt {
            anchors.verticalCenter: parent.verticalCenter
            width: root.artSize
            height: width
            radius: width * 0.28
            source: root.media ? root.media.artUrl : ""
            foreground: root.foreground
            accent: root.accent
        }

        Item {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(titleMetrics.width, root.maxTitle)
            height: title.implicitHeight
            clip: true

            TextMetrics {
                id: titleMetrics
                font: title.font
                text: title.text
            }
            Text {
                id: title
                text: root.media ? root.media.title : ""
                color: root.foreground
                font.family: Style.font.family
                font.pixelSize: Style.font.body
                font.weight: Font.Medium
            }
            // Fade the last stretch when the title is longer than the slot.
            Rectangle {
                visible: titleMetrics.width > root.maxTitle
                anchors.right: parent.right
                width: Style.space(24)
                height: parent.height
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: "transparent" }
                    GradientStop { position: 1; color: root.host ? root.host.islandBackground : "black" }
                }
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.showSource
            text: "· " + root.source
            color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.45)
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            elide: Text.ElideRight
            width: Math.min(implicitWidth, Style.space(130))
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
