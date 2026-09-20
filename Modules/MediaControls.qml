import QtQuick
import qs.Commons

// Transport controls, for the hover row.
//
// A live module like the art and the waveform: absent unless there is
// something to control, so hovering an idle island does not offer buttons that
// would do nothing.
Item {
    id: root

    property var options: ({})
    property var host: null
    property color foreground: "white"
    property color accent: "white"

    readonly property var media: host ? host.mediaSource : null
    readonly property bool hasMedia: media ? media.hasMedia : false

    // Presence is declared to the row through `shown`; see ModuleRow.
    readonly property bool shown: hasMedia

    implicitWidth: hasMedia ? row.implicitWidth : 0
    implicitHeight: parent ? parent.height : Style.font.icon

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(10)

        Repeater {
            model: [
                {
                    glyph: "󰒮",
                    action: "previous"
                },
                {
                    glyph: root.media && root.media.playing ? "󰏤" : "󰐊",
                    action: "toggle"
                },
                {
                    glyph: "󰒭",
                    action: "next"
                }
            ]

            delegate: Text {
                required property var modelData

                anchors.verticalCenter: parent.verticalCenter
                text: modelData.glyph
                color: root.foreground
                font.family: Style.font.family
                font.pixelSize: Style.font.icon
                textFormat: Text.PlainText
                opacity: press.containsMouse ? 1 : 0.75

                Behavior on opacity {
                    NumberAnimation {
                        duration: 110
                    }
                }

                MouseArea {
                    id: press
                    anchors.fill: parent
                    anchors.margins: -Style.space(4)
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (!root.media)
                            return;
                        if (parent.modelData.action === "next")
                            root.media.next();
                        else if (parent.modelData.action === "previous")
                            root.media.previous();
                        else
                            root.media.toggle();
                    }
                }
            }
        }
    }
}
