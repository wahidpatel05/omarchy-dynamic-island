import QtQuick
import qs.Commons
import "../Core"

// The system logo, at the head of the left capsule.
//
// Position is the whole point: this is the slot the Apple logo occupies on a
// macOS menu bar, so it carries the equivalent — Omarchy's own mark, opening
// Omarchy's menu. The glyph and its font are both options, because the mark a
// user wants there is a matter of taste rather than of function, and the
// Omarchy mark lives in its own `omarchy` font rather than in the Nerd Font
// everything else draws from.
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

    readonly property string glyph: options.glyph === undefined ? "" : String(options.glyph)
    readonly property string glyphFont: options.font === undefined ? "omarchy" : String(options.font)
    // An image file to draw in place of the glyph — any mark that does not
    // live in a font. Absolute paths and file:// URLs both work; a path that
    // does not resolve falls back to the glyph rather than to an empty slot.
    readonly property string icon: options.icon === undefined ? "" : String(options.icon)
    // An Omarchy bar-widget plugin to open on click, in place of running
    // `command` — `omarchy.agents` puts the agent usage dashboard behind the
    // logo, which is where a system menu belongs anyway.
    readonly property string panelPlugin: options.panel === undefined ? "" : String(options.panel)
    readonly property string command: options.command === undefined ? "omarchy-menu toggle root" : String(options.command)
    readonly property string rightCommand: options.rightCommand === undefined ? "" : String(options.rightCommand)

    readonly property bool shown: glyph.length > 0 || icon.length > 0
    implicitWidth: button.implicitWidth
    implicitHeight: parent ? parent.height : Style.font.icon

    PanelSlot {
        id: panelSlot
        anchors.fill: parent
        host: root.host
        screenName: root.screenName
        pluginId: root.panelPlugin
    }

    GlyphButton {
        id: button
        anchors.fill: parent

        glyph: root.glyph
        fontFamily: root.glyphFont
        iconSource: root.icon === "" ? "" : (root.icon.indexOf("://") === -1 ? "file://" + root.icon : root.icon)
        iconSize: options.size > 0 ? options.size : 0
        // The logo carries the bar, so it is set a touch larger than the
        // status glyphs beside it — the same relationship the Apple logo has
        // to the icons in the menu bar's other corner.
        fontSize: {
            if (options.size > 0)
                return options.size;
            return Math.round((root.fontSize > 0 ? root.fontSize * 1.17 : Style.font.icon) * 1.05);
        }
        foreground: root.foreground
        hoverOpacity: root.hoverOpacity
        interactive: panelSlot.available || root.command !== "" || root.rightCommand !== ""

        onActivated: function (mouseButton) {
            if (mouseButton === Qt.RightButton && root.rightCommand !== "") {
                if (root.host)
                    root.host.run(root.rightCommand);
                return;
            }
            if (panelSlot.available) {
                panelSlot.toggle();
                return;
            }
            if (root.host)
                root.host.run(root.command);
        }
    }
}
