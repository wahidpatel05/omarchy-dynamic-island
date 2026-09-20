import QtQuick
import Quickshell.Hyprland
import qs.Commons

// Workspace indicator.
//
// "dots" is the island-native style: occupied workspaces are dots and the
// focused one stretches into a capsule. The stretch is animated rather than
// swapped, so moving between workspaces reads as the indicator sliding its
// weight across instead of two separate shapes blinking.
Item {
    id: root

    property var options: ({})
    property color foreground: "white"
    property color accent: "white"

    readonly property string style: options.style || "dots"
    readonly property bool showEmpty: options.showEmpty !== false
    readonly property int maxWorkspaces: options.max || 10

    readonly property int focusedId: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : -1

    readonly property var ids: {
        // Always show 1..5 so the indicator has a stable width to sit at, then
        // fold in any higher workspace that actually exists.
        var base = root.showEmpty ? [1, 2, 3, 4, 5] : [];
        var values = Hyprland.workspaces.values;
        for (var i = 0; i < values.length; i++) {
            var id = values[i].id;
            if (id > 0 && id <= root.maxWorkspaces && base.indexOf(id) === -1)
                base.push(id);
        }
        if (root.focusedId > 0 && base.indexOf(root.focusedId) === -1)
            base.push(root.focusedId);
        base.sort(function (a, b) {
            return a - b;
        });
        return base;
    }

    function occupied(id) {
        var values = Hyprland.workspaces.values;
        for (var i = 0; i < values.length; i++) {
            if (values[i].id === id)
                return values[i].windows > 0;
        }
        return false;
    }

    function focusWorkspace(id) {
        Hyprland.dispatch("workspace " + id);
    }

    implicitWidth: row.implicitWidth
    implicitHeight: Math.max(dotSize, Style.font.body)

    readonly property real dotSize: Math.max(5, Math.round(Style.font.body * 0.42))

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Math.max(4, Math.round(root.dotSize * 0.9))

        Repeater {
            model: root.ids

            delegate: Item {
                id: dot
                required property var modelData

                readonly property bool focused: modelData === root.focusedId
                readonly property bool hasWindows: root.occupied(modelData)

                width: marker.width
                height: root.implicitHeight

                Rectangle {
                    id: marker
                    anchors.verticalCenter: parent.verticalCenter
                    // The focused workspace stretches; everything else stays a
                    // dot. Width is the only thing that changes, so the
                    // animation has a single, readable axis.
                    width: dot.focused ? root.dotSize * 3.2 : root.dotSize
                    height: root.dotSize
                    radius: height / 2
                    color: dot.focused ? root.accent : root.foreground
                    opacity: dot.focused ? 1.0 : (dot.hasWindows ? 0.55 : 0.22)

                    Behavior on width {
                        NumberAnimation {
                            duration: 260
                            easing.type: Easing.OutCubic
                        }
                    }
                    Behavior on opacity {
                        NumberAnimation {
                            duration: 180
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -3
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.focusWorkspace(dot.modelData)
                }
            }
        }
    }
}
