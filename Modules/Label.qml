import QtQuick
import qs.Commons

// A word of your own on the resting pill.
//
// The island spends most of its life with nothing to say — no music, no
// task, no notification — and an empty black pill reads as something that
// has not loaded yet. A wordmark gives it a resting state that looks
// deliberate.
//
// It steps aside the moment there is something real to show, which is the
// whole point: this is what occupies the pill when nothing else does, not
// another thing competing for it.
//
// Width comes from TextMetrics rather than the label's own `implicitWidth`.
// An elided Text derives its implicit width from the width it was given, so
// reading it back to size the island closes a binding loop, and the island's
// spring recurses into that until the stack gives out.
Item {
    id: root

    property var options: ({})
    property var host: null
    property color foreground: "white"
    property color accent: "white"
    property real fontSize: 0

    readonly property string text: options.text === undefined ? "" : String(options.text)
    readonly property bool yieldToMedia: options.hideWhenPlaying !== false
    readonly property real maxWidth: options.maxWidth === undefined ? 240 : options.maxWidth

    // Yields to *playing* media, not to merely registered media. A browser
    // tab that played something an hour ago still advertises itself over
    // MPRIS; keying this on "is there a player" would hide the wordmark for
    // as long as the browser stayed open.
    readonly property bool mediaActive: yieldToMedia && host && host.mediaSource && host.mediaSource.playing === true

    // Presence is declared to the row through `shown`; see ModuleRow.
    readonly property bool shown: text !== "" && !mediaActive

    readonly property real textSize: {
        var explicit = Number(options.size);
        if (isFinite(explicit) && explicit > 0)
            return explicit;
        return fontSize > 0 ? fontSize : Style.font.body;
    }

    readonly property real spacing: {
        var explicit = Number(options.letterSpacing);
        return isFinite(explicit) ? explicit : 0.8;
    }

    TextMetrics {
        id: metrics
        text: root.text
        font.family: Style.font.family
        font.pixelSize: root.textSize
        font.bold: options.bold !== false
        font.letterSpacing: root.spacing
    }

    implicitWidth: shown ? Math.min(root.maxWidth, Math.ceil(metrics.advanceWidth)) : 0
    implicitHeight: parent ? parent.height : Style.font.body

    Text {
        anchors.centerIn: parent
        width: parent.width
        visible: root.shown
        text: root.text
        color: root.foreground
        opacity: options.opacity === undefined ? 0.92 : Number(options.opacity)
        font: metrics.font
        textFormat: Text.PlainText
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignHCenter
    }
}
