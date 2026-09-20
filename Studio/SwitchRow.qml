import QtQuick
import qs.Commons
import qs.Ui

// One boolean setting.
Item {
    id: root

    property var host: null
    property string path: ""
    property string label: ""
    property string hint: ""
    // What the island does when the key is absent, so the switch shows the
    // truth rather than `false` for everything that defaults on.
    property bool fallback: true

    readonly property bool current: {
        var value = host && path !== "" ? host.setting(path) : undefined;
        return value === undefined || value === null ? fallback : value === true;
    }

    implicitWidth: parent ? parent.width : 0
    implicitHeight: Math.max(toggle.implicitHeight, text.implicitHeight) + Style.space(6)

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.host.setSetting(root.path, !root.current)
    }

    Column {
        id: text
        anchors.left: parent.left
        anchors.right: toggle.left
        anchors.rightMargin: Style.space(12)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(2)

        Text {
            text: root.label
            color: Color.foreground
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            textFormat: Text.PlainText
        }

        Text {
            visible: root.hint !== ""
            width: parent.width
            text: root.hint
            color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.45)
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
            textFormat: Text.PlainText
        }
    }

    ToggleSwitch {
        id: toggle
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        checked: root.current
        foreground: Color.foreground
        accent: Color.accent
        onToggled: root.host.setSetting(root.path, !root.current)
    }
}
