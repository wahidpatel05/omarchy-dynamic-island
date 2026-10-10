import QtQuick
import qs.Commons
import "../Core"
import "../Core/Config.js" as Config
import "../Core/MediaBrand.js" as MediaBrand

// The track-change takeover: art on the left, the track in the middle, the
// controls and the player's own mark on the right.
//
// This is the lowest-priority activity in the island precisely because it is
// unsolicited — nobody asked to see it, the track just changed. So it stays
// brief and never grows past a single line of each field.
//
// Text comes from the payload, everything else from the live source. The
// split matters: the payload is a record of the track that *changed*, and if
// the next one lands while this card is still up it should finish saying what
// it was saying — but the clock and the play button describe right now, and a
// frozen clock beside a running track reads as a bug.
Item {
    id: root

    property var activity: null
    property var options: ({})
    property var host: null
    property color foreground: "white"
    property color accent: "white"
    readonly property color muted: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.55)

    readonly property var payload: activity ? activity.data : null
    readonly property var media: host ? host.mediaSource : null

    // Presentation follows the `media` module rather than this activity's own
    // options, so the clock and the mark are one decision for the whole
    // island instead of two that can disagree between the pill and the card.
    readonly property var display: host ? Config.moduleOptions(host.config, "media") : ({})

    readonly property var brand: MediaBrand.brandFor(payload ? payload.identity : "", payload ? payload.desktopEntry : "", payload ? payload.dbusName : "")
    readonly property color sourceColor: display.sourceTint !== false && brand.known ? brand.color : accent

    readonly property bool showElapsed: display.showElapsed !== false && (media ? media.positionSupported : false)
    readonly property bool showSource: display.showSource !== false && brand.known
    readonly property bool showToggle: media ? media.canToggle : false

    // Proportions lifted off the reference rather than guessed. Measured on a
    // 560x113 card: art 0.60 of the height, padding 0.34 of the art, and a
    // gap rhythm that tightens toward the clock and opens up again before the
    // controls. Everything is expressed against `artSize` so the whole card
    // scales from one number.
    readonly property int artSize: Style.space(42)
    readonly property int padY: Math.round(artSize * 0.34)
    readonly property int padX: Math.round(artSize * 0.42)

    readonly property int gapArt: Math.round(artSize * 0.37)
    readonly property int gapClock: Math.round(artSize * 0.16)
    readonly property int gapText: Math.round(artSize * 0.40)
    // The one deliberate void on the card. It is what separates "this is what
    // is playing" from "this is what you can do about it"; without it the
    // artist name and the pause button read as one run of things.
    readonly property int gapControls: Math.round(artSize * 0.75)
    readonly property int gapMark: Math.round(artSize * 0.22)

    readonly property int toggleSize: Math.round(artSize * 0.70)
    readonly property int markSize: Math.round(artSize * 0.76)

    readonly property int maxTextWidth: Style.space(options.maxTitleWidth || 210)

    implicitWidth: padX * 2 + row.implicitWidth
    implicitHeight: Math.max(artSize, row.implicitHeight) + padY * 2

    Row {
        id: row

        x: root.padX
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0

        AlbumArt {
            anchors.verticalCenter: parent.verticalCenter
            width: root.artSize
            height: root.artSize
            source: root.payload ? String(root.payload.artUrl || "") : ""
            foreground: root.foreground
            accent: root.accent
        }

        Gap {
            size: root.gapArt
        }

        // Bars and clock travel together: they are one statement about
        // playback, and the gap between them is tighter than the gaps
        // separating the card's parts.
        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: root.gapClock

            Equalizer {
                anchors.verticalCenter: parent.verticalCenter
                color: root.sourceColor
                active: root.media ? root.media.playing : true
                maxHeight: Math.round(root.artSize * 0.34)
            }

            Text {
                id: clock

                anchors.verticalCenter: parent.verticalCenter
                visible: root.showElapsed
                // Held at the width of its own digits as zeros, so a ticking
                // second cannot re-run the island's width spring.
                width: Math.max(implicitWidth, clockMetrics.width)
                horizontalAlignment: Text.AlignHCenter

                text: root.media ? root.media.elapsed : ""
                color: root.foreground
                font.family: Style.font.family
                font.pixelSize: Style.font.subtitle
                textFormat: Text.PlainText
            }

            TextMetrics {
                id: clockMetrics
                font: clock.font
                text: clock.text.replace(/\d/g, "0")
            }
        }

        Gap {
            size: root.gapText
        }

        Column {
            id: textColumn

            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)

            // Both labels are measured unwrapped. A Text that wraps reports an
            // implicitWidth derived from the width it was handed, which would close
            // a loop through the island's animated size.
            //
            // Rounded up with a pixel to spare, because a box set to exactly
            // the text's own advance width elides on the rounding: Qt lays
            // the glyphs out in float and compares against an integer width,
            // so "Blinding Lights" in a box measured at "Blinding Lights"
            // comes out "Blinding Ligh…".
            width: Math.min(root.maxTextWidth, Math.ceil(Math.max(titleMetrics.width, artistMetrics.width)) + 1)

            TextMetrics {
                id: titleMetrics
                font.family: Style.font.family
                font.pixelSize: Style.font.title
                font.bold: true
                text: root.payload ? String(root.payload.title || "") : ""
            }

            TextMetrics {
                id: artistMetrics
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
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

        Gap {
            // Collapses entirely when there is nothing on the right to
            // separate from, so a card with no controls does not carry a
            // hole where they would have been.
            size: root.showToggle || root.showSource ? root.gapControls : 0
        }

        // Play/pause, on a card that is only up for a couple of seconds.
        //
        // Worth having anyway, because hovering the island freezes the
        // dismissal countdown — so a track you did not want is one reach
        // away from stopped, without opening anything.
        Rectangle {
            id: toggle

            anchors.verticalCenter: parent.verticalCenter
            visible: root.showToggle
            width: root.toggleSize
            height: width
            radius: width / 2
            color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, press.containsMouse ? 0.28 : 0.18)

            Behavior on color {
                ColorAnimation {
                    duration: 110
                }
            }

            Text {
                anchors.centerIn: parent
                text: root.media && root.media.playing ? "󰏤" : "󰐊"
                color: root.foreground
                font.family: Style.font.family
                font.pixelSize: Math.round(toggle.width * 0.5)
                textFormat: Text.PlainText
            }

            MouseArea {
                id: press
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                // Takes the press before the island's own tap handler sees
                // it, so reaching for pause does not dismiss the card out
                // from under the pointer instead.
                onClicked: if (root.media)
                    root.media.toggle()
            }
        }

        Gap {
            size: root.showToggle && root.showSource ? root.gapMark : 0
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.showSource
            text: root.brand.glyph
            color: root.sourceColor
            font.family: Style.font.family
            font.pixelSize: root.markSize
            textFormat: Text.PlainText
        }
    }

    // A spacer with a name. The card's gaps are all different sizes, so the
    // Row carries no spacing of its own and every gap is stated where it
    // happens — which is also what lets one collapse to nothing when the
    // thing beside it is hidden.
    component Gap: Item {
        property int size: 0
        width: size
        height: 1
    }
}
