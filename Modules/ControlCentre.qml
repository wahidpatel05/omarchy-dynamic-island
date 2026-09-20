import QtQuick
import qs.Commons
import "../Core"

// The Control Centre button, in the status corner.
//
// It opens the island's own control centre rather than a panel of its own, so
// the sliders arrive where every other island state does — out of the middle
// of the bar. The button needs to know which screen it is on for that: the
// island expands on one monitor at a time, and the one to expand is the one
// the pointer just clicked.
Item {
    id: root

    property var options: ({})
    property var host: null
    property string screenName: ""
    property color foreground: "white"
    property color accent: "white"
    property real hoverOpacity: 0.1
    // 0 follows the theme; the glass capsule passes its own size down.
    property real fontSize: 0

    readonly property string glyph: options.glyph === undefined ? "" : String(options.glyph)
    readonly property bool open: host && screenName !== "" && host.expandedScreen === screenName

    readonly property bool shown: glyph.length > 0
    implicitWidth: button.implicitWidth
    implicitHeight: parent ? parent.height : Style.font.icon

    GlyphButton {
        id: button
        anchors.fill: parent

        glyph: root.glyph
        host: root.host
        tooltipText: root.open ? "Close control centre" : "Control centre"
        fontSize: root.fontSize > 0 ? Math.round(root.fontSize * 1.17) : 0
        foreground: root.open ? root.accent : root.foreground
        hoverOpacity: root.hoverOpacity

        onActivated: function () {
            if (root.host)
                root.host.setExpanded(root.screenName, !root.open);
        }
    }
}
