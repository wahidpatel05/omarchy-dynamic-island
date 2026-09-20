import QtQuick
import qs.Commons
import "../Core"

// The track-change takeover: art on the left, title and artist in the middle,
// dancing bars on the right.
//
// This is the lowest-priority activity in the island precisely because it is
// unsolicited — nobody asked to see it, the track just changed. So it stays
// brief and never grows past a single line of each field.
Item {
    id: root

    property var activity: null
    property var options: ({})
    property color foreground: "white"
    property color accent: "white"
    readonly property color muted: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.55)

    readonly property var payload: activity ? activity.data : null

    readonly property int pad: Style.space(14)
    readonly property int artSize: Style.space(36)
    readonly property int gap: Style.space(12)
    readonly property int maxTextWidth: Style.space(options.maxTitleWidth || 210)

    implicitWidth: pad * 2 + artSize + gap + textColumn.width + gap + equalizer.width
    implicitHeight: Math.max(artSize, textColumn.implicitHeight) + pad * 2

    AlbumArt {
        id: art
        x: root.pad
        anchors.verticalCenter: parent.verticalCenter
        width: root.artSize
        height: root.artSize
        source: root.payload ? String(root.payload.artUrl || "") : ""
        foreground: root.foreground
        accent: root.accent
    }

    Column {
        id: textColumn

        x: root.pad + root.artSize + root.gap
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(2)

        // Both labels are measured unwrapped. A Text that wraps reports an
        // implicitWidth derived from the width it was handed, which would close
        // a loop through the island's animated size.
        width: Math.min(root.maxTextWidth, Math.max(titleMetrics.width, artistMetrics.width))

        TextMetrics {
            id: titleMetrics
            font.family: Style.font.family
            font.pixelSize: Style.font.body
            font.bold: true
            text: root.payload ? String(root.payload.title || "") : ""
        }

        TextMetrics {
            id: artistMetrics
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            text: root.payload ? String(root.payload.artist || "") : ""
        }

        Text {
            width: parent.width
            text: titleMetrics.text
            visible: text.length > 0
            color: root.foreground
            font: titleMetrics.font
            elide: Text.ElideRight
            maximumLineCount: 1
            textFormat: Text.PlainText
        }

        Text {
            width: parent.width
            text: artistMetrics.text
            visible: text.length > 0
            color: root.muted
            font: artistMetrics.font
            elide: Text.ElideRight
            maximumLineCount: 1
            textFormat: Text.PlainText
        }
    }

    Equalizer {
        id: equalizer
        x: root.pad + root.artSize + root.gap + textColumn.width + root.gap
        anchors.verticalCenter: parent.verticalCenter
        color: root.accent
        active: true
        maxHeight: Style.space(16)
    }
}
