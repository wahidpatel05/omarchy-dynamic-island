import QtQuick
import qs.Commons

// Plugged in, unplugged, or running low.
//
// A glance-sized card: the event is the message, so it carries a glyph, a
// short label, and the level — never a body of text.
Item {
    id: root

    property var activity: null
    property var options: ({})
    property color foreground: "white"
    property color accent: "white"
    readonly property color muted: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.55)

    readonly property var payload: activity ? activity.data : null
    readonly property string label: payload ? String(payload.label || "") : ""
    readonly property string glyph: payload ? String(payload.glyph || "󰁹") : "󰁹"
    readonly property int percent: payload ? Math.round(Number(payload.percent) || 0) : 0
    readonly property bool urgent: payload ? payload.urgent === true : false

    readonly property int pad: Style.space(16)
    readonly property int gap: Style.space(12)

    implicitWidth: pad * 2 + icon.width + gap + textColumn.width
    implicitHeight: Math.max(Style.space(34), textColumn.implicitHeight + pad * 2)

    Text {
        id: icon
        x: root.pad
        anchors.verticalCenter: parent.verticalCenter
        text: root.glyph
        color: root.urgent ? Color.urgent : root.accent
        font.family: Style.font.family
        font.pixelSize: Style.font.display
        textFormat: Text.PlainText
    }

    Column {
        id: textColumn
        x: root.pad + icon.width + root.gap
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(1)
        width: Math.max(labelMetrics.width, levelMetrics.width)

        TextMetrics {
            id: labelMetrics
            font.family: Style.font.family
            font.pixelSize: Style.font.body
            font.bold: true
            text: root.label
        }

        TextMetrics {
            id: levelMetrics
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            text: root.percent + "%"
        }

        Text {
            text: labelMetrics.text
            color: root.foreground
            font: labelMetrics.font
            textFormat: Text.PlainText
        }

        Text {
            text: levelMetrics.text
            color: root.muted
            font: levelMetrics.font
            textFormat: Text.PlainText
        }
    }
}
