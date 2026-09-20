import QtQuick
import qs.Commons

// Album art with a graceful absence.
//
// Art goes missing constantly — a stream with no metadata, a local file with no
// embedded cover, art that has not downloaded yet. So the fallback is not an
// error state but the normal one: a tinted tile carrying a note glyph, the same
// size and shape as real art, so the layout never shifts when art arrives late.
Item {
    id: root

    property string source: ""
    property color foreground: "white"
    property color accent: "white"
    property real radius: width * 0.2

    readonly property bool ready: image.status === Image.Ready && root.source !== ""

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.08)
        visible: !root.ready

        Text {
            anchors.centerIn: parent
            text: "󰝚"
            color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.7)
            font.family: Style.font.family
            font.pixelSize: Math.max(Style.font.body, root.height * 0.42)
            textFormat: Text.PlainText
        }
    }

    // Measured but not drawn; the visible copy is the clipped one below.
    Image {
        id: image
        source: root.source
        visible: false
        asynchronous: true
        cache: true
        sourceSize.width: Math.max(64, root.width * 2)
        sourceSize.height: Math.max(64, root.height * 2)
    }

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        clip: true
        color: "transparent"
        visible: root.ready

        Image {
            anchors.fill: parent
            source: root.source
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            smooth: true
            sourceSize.width: Math.max(64, root.width * 2)
            sourceSize.height: Math.max(64, root.height * 2)
        }
    }
}
