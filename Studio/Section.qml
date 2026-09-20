import QtQuick
import qs.Commons

// One titled group of controls in the Studio.
Column {
    id: root

    property string title: ""
    property string hint: ""
    property color foreground: Color.foreground

    default property alias content: body.data

    spacing: Style.space(8)
    width: parent ? parent.width : 0

    Text {
        text: root.title.toUpperCase()
        color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.5)
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        font.letterSpacing: 1.2
        font.bold: true
        textFormat: Text.PlainText
    }

    Text {
        visible: root.hint !== ""
        width: root.width
        text: root.hint
        color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.45)
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        wrapMode: Text.WordWrap
        textFormat: Text.PlainText
    }

    Column {
        id: body
        width: root.width
        spacing: Style.space(6)
    }
}
