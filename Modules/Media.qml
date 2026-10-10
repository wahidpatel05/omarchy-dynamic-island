import QtQuick
import qs.Commons
import "../Core"
import "../Core/MediaBrand.js" as MediaBrand

// Compact now-playing, for the resting pill or the hover row.
//
// Dancing bars, a running clock, and the mark of whatever is playing — the
// three things that survive being read at a glance from across the desk. The
// title is off by default and available through `showTitle`: the resting pill
// is narrow, a title is the one field that grows without limit, and the
// island already says it in full the moment the track changes.
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

    // The title is off by default — but the pill must never come down to a
    // row of bars and nothing else, so a player the island can neither
    // recognise nor time gets its title back rather than saying nothing.
    readonly property bool showTitle: options.showTitle === true || (!showElapsed && !showSource)
    // A clock nothing reports is worse than no clock: a stream that does not
    // support seeking would sit at 00:00 for as long as it played.
    readonly property bool showElapsed: options.showElapsed !== false && (media ? media.positionSupported : false)
    // Only for a player the island actually recognises. A generic note beside
    // the bars says nothing the bars have not already said.
    readonly property bool showSource: options.showSource !== false && brand.known

    readonly property var brand: MediaBrand.brandFor(media ? media.identity : "", media ? media.desktopEntry : "", media ? media.dbusName : "")
    // The bars take the player's colour, so the pill reads as Spotify green
    // or YouTube red rather than as the theme's accent with a logo stuck on
    // the end. Unrecognised players, and `sourceTint: false`, keep the accent.
    readonly property color sourceColor: options.sourceTint !== false && brand.known ? brand.color : accent

    // Presence is declared to the row through `shown`; see ModuleRow.
    readonly property bool shown: hasMedia
    implicitWidth: hasMedia ? row.implicitWidth : 0
    implicitHeight: parent ? parent.height : Style.font.body

    // Gaps measured off the reference pill (404x56): the bars and the clock
    // sit close together as one statement, then a wide run of nothing, then
    // the player's mark against the trailing edge. The void is the design —
    // packed tight against each other the three read as a label, spread apart
    // they read as a status bar.
    readonly property int barHeight: Style.space(11)
    readonly property int gapClock: Math.round(barHeight * 0.48)
    // The title needs real air after the clock. At the clock's own gap the
    // two run together into one string — "02:51 36" reads as a single number
    // before it reads as a time and a track. Taken from the reference card's
    // clock-to-title gap, scaled to the bar height.
    readonly property int gapTitle: Math.round(barHeight * 1.2)
    readonly property int gapMark: Math.round(barHeight * 1.9)

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0

        Equalizer {
            anchors.verticalCenter: parent.verticalCenter
            color: root.sourceColor
            active: root.media ? root.media.playing : false
            maxHeight: root.barHeight
        }

        Item {
            width: root.showElapsed ? root.gapClock : 0
            height: 1
        }

        Text {
            id: clock

            anchors.verticalCenter: parent.verticalCenter
            visible: root.showElapsed
            // Measured against its own digits replaced by zeros, which in
            // nearly every family is the widest digit. The clock then holds
            // one width for a whole minute instead of nudging the island's
            // animated width on every tick.
            width: Math.max(implicitWidth, clockMetrics.width)
            horizontalAlignment: Text.AlignHCenter

            text: root.media ? root.media.elapsed : ""
            color: root.foreground
            font.family: Style.font.family
            font.pixelSize: Style.font.body
            textFormat: Text.PlainText
        }

        TextMetrics {
            id: clockMetrics
            font.family: Style.font.family
            font.pixelSize: Style.font.body
            text: clock.text.replace(/\d/g, "0")
        }

        Item {
            width: root.showTitle ? root.gapTitle : 0
            height: 1
        }

        TextMetrics {
            id: metrics
            font.family: Style.font.family
            font.pixelSize: Style.font.body
            text: root.media ? root.media.title : ""
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.showTitle && metrics.text.length > 0
            width: Math.min(root.maxWidth, Math.ceil(metrics.width) + 1)
            text: metrics.text
            color: root.foreground
            font: metrics.font
            elide: Text.ElideRight
            maximumLineCount: 1
            textFormat: Text.PlainText
        }

        Item {
            width: root.showSource ? root.gapMark : 0
            height: 1
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.showSource
            text: root.brand.glyph
            color: root.sourceColor
            font.family: Style.font.family
            font.pixelSize: Math.round(root.barHeight * 1.28)
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
