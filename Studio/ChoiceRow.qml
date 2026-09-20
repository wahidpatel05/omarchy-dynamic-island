import QtQuick
import qs.Commons
import qs.Ui

// One setting picked from a list.
Item {
    id: root

    property var host: null
    property string path: ""
    property string label: ""
    property var options: []
    property string fallback: ""

    readonly property string current: {
        var value = host && path !== "" ? host.setting(path) : undefined;
        if (value === undefined || value === null || value === "")
            return fallback;
        // A list-valued `monitors` is legal but not something a dropdown can
        // represent, so it shows as the custom entry rather than snapping
        // silently back to "all".
        return Array.isArray(value) ? value.join(", ") : String(value);
    }

    implicitWidth: parent ? parent.width : 0
    implicitHeight: Math.max(labelText.implicitHeight, dropdown.implicitHeight) + Style.space(6)

    Text {
        id: labelText
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        text: root.label
        color: Color.foreground
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
        textFormat: Text.PlainText
    }

    Dropdown {
        id: dropdown
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: Style.space(180)
        showLabel: false
        options: root.options
        value: root.current
        foreground: Color.foreground
        onChanged: function (value) {
            if (value !== root.current)
                root.host.setSetting(root.path, value);
        }
    }
}
