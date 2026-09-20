import QtQuick
import qs.Commons
import "../Core"

// Time, in the status corner or the island's resting pill.
//
// The tick aligns itself to the next real minute boundary rather than firing
// every second, so a clock showing "h:mm" changes the moment the minute does
// instead of up to a second late.
Item {
    id: root

    property var options: ({})
    property var host: null
    property string screenName: ""
    property color foreground: "white"
    property real hoverOpacity: 0.1
    // 0 follows the theme; the glass capsules pass their own size down so
    // the status corner scales with the bar rather than with the theme.
    property real fontSize: 0

    readonly property string format: options.format || "h:mm AP"
    // An Omarchy bar-widget plugin to open on click — `omarchy.clock` is the
    // calendar. Mounted invisibly behind the label; see Core/PanelSlot.qml.
    readonly property string panelPlugin: options.panel === undefined ? "" : String(options.panel)

    property var now: new Date()

    implicitWidth: label.implicitWidth
    implicitHeight: label.implicitHeight

    function retick() {
        root.now = new Date();
        var showsSeconds = /s/.test(root.format);
        tick.interval = showsSeconds ? 1000 : Math.max(250, 60000 - (root.now.getSeconds() * 1000 + root.now.getMilliseconds()));
        tick.restart();
    }

    Component.onCompleted: retick()

    Timer {
        id: tick
        repeat: false
        onTriggered: root.retick()
    }

    PanelSlot {
        id: panelSlot
        anchors.fill: parent
        host: root.host
        screenName: root.screenName
        pluginId: root.panelPlugin
    }

    SlotButton {
        anchors.fill: parent
        foreground: root.foreground
        hoverOpacity: root.hoverOpacity
        interactive: panelSlot.available
        onActivated: panelSlot.toggle()

        Text {
            id: label
            anchors.centerIn: parent
            text: Qt.formatDateTime(root.now, root.format)
            color: root.foreground
            font.family: Style.font.family
            font.pixelSize: root.fontSize > 0 ? root.fontSize : Style.font.body
            font.bold: true
            textFormat: Text.PlainText
            renderType: Text.NativeRendering
        }
    }
}
