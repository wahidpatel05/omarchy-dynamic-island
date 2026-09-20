import QtQuick
import qs.Commons

// Time, in the island's resting pill.
//
// The tick aligns itself to the next real minute boundary rather than firing
// every second, so a clock showing "h:mm" changes the moment the minute does
// instead of up to a second late.
Item {
    id: root

    property var options: ({})
    property color foreground: "white"

    readonly property string format: options.format || "h:mm AP"
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

    Text {
        id: label
        anchors.centerIn: parent
        text: Qt.formatDateTime(root.now, root.format)
        color: root.foreground
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        font.bold: true
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
    }
}
