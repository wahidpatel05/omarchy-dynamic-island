import QtQuick
import Quickshell.Wayland
import qs.Commons

// The focused window's title.
//
// This is the island's default resting content, and it yields: with music
// playing, the now-playing module has more to say than "Brave", so the window
// title steps aside rather than the two fighting over the pill's width. That
// is what makes "music, or else the window" one behaviour instead of two
// modules the user has to choose between.
//
// Width is measured with TextMetrics rather than taken from the label's
// `implicitWidth`. An elided Text derives its implicit width from the width it
// was given, so reading it back to size the island closes a binding loop —
// and with a spring on the far end, that loop recurses until the stack gives
// out.
Item {
    id: root

    property var options: ({})
    property var host: null
    property color foreground: "white"
    property color accent: "white"
    property real fontSize: 0

    readonly property real maxWidth: options.maxWidth === undefined ? 220 : options.maxWidth
    readonly property bool yieldToMedia: options.hideWhenPlaying !== false

    readonly property var toplevel: ToplevelManager.activeToplevel
    readonly property string title: toplevel ? String(toplevel.title || toplevel.appId || "") : ""

    // Yields to *playing* media, not to merely registered media. A browser
    // tab that played something an hour ago still advertises itself over
    // MPRIS, so keying this on `hasMedia` would hide the window title for as
    // long as the browser stays open — which is most of the time.
    readonly property bool mediaActive: yieldToMedia && host && host.mediaSource && host.mediaSource.playing === true

    // Presence is declared to the row through `shown`; see ModuleRow.
    readonly property bool shown: title !== "" && !mediaActive

    readonly property real textSize: fontSize > 0 ? fontSize : Style.font.body

    TextMetrics {
        id: metrics
        text: root.title
        font.family: Style.font.family
        font.pixelSize: root.textSize
    }

    // Deliberately unanimated. The island springs its own width from whatever
    // this row measures, so easing the measurement as well would put two
    // curves on one number and the pill would arrive twice.
    implicitWidth: shown ? Math.min(root.maxWidth, Math.ceil(metrics.advanceWidth)) : 0
    implicitHeight: parent ? parent.height : Style.font.body

    Text {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        text: root.title
        color: root.foreground
        opacity: 0.85
        font.family: Style.font.family
        font.pixelSize: root.textSize
        textFormat: Text.PlainText
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignHCenter
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        cursorShape: Qt.PointingHandCursor
        onClicked: if (root.toplevel)
            root.toplevel.activate()
    }
}
