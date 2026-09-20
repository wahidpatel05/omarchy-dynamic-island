import QtQuick
import qs.Commons
import qs.Ui

// One numeric setting: a label, the live value, and a slider that writes it.
//
// Dragging persists as it goes, because watching the island reshape under the
// slider is the whole point of a Studio — but not on every pixel. Writes are
// coalesced into one every 90ms and flushed on release, so a drag across the
// track costs a handful of atomic writes rather than a hundred.
Item {
    id: root

    property var host: null
    // Most settings are one key. A couple are two that should never disagree
    // — the top and bottom corner radii of a floating shape — so this takes a
    // list and writes all of them together.
    property var paths: []
    property string label: ""
    property string hint: ""
    property real minimum: 0
    property real maximum: 1
    property real step: 0.05
    property bool integer: false
    // Shown in place of the number when the value is 0 and 0 means "work it
    // out yourself" rather than "none".
    property string zeroLabel: ""

    readonly property string primaryPath: paths.length > 0 ? String(paths[0]) : ""
    readonly property real current: {
        var value = host && primaryPath !== "" ? host.setting(primaryPath) : undefined;
        var n = Number(value);
        return isFinite(n) ? n : minimum;
    }
    readonly property bool overridden: host && primaryPath !== "" && host.userSetting(primaryPath) !== undefined

    // While dragging, the slider owns the number: reading it back out of the
    // config would make the knob stutter against the coalescing timer.
    property bool dragging: false
    property real pending: current

    readonly property real shownValue: dragging ? pending : current

    implicitWidth: parent ? parent.width : 0
    implicitHeight: column.implicitHeight

    function commit(value) {
        if (!host)
            return;
        for (var i = 0; i < paths.length; i++)
            host.setSetting(String(paths[i]), root.integer ? Math.round(value) : Math.round(value * 1000) / 1000);
    }

    Timer {
        id: coalesce
        interval: 90
        onTriggered: root.commit(root.pending)
    }

    Column {
        id: column
        width: root.width
        spacing: Style.space(3)

        Item {
            width: parent.width
            height: labelText.implicitHeight

            Text {
                id: labelText
                anchors.left: parent.left
                text: root.label
                color: Color.foreground
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                textFormat: Text.PlainText
            }

            Text {
                anchors.right: resetButton.left
                anchors.rightMargin: Style.space(6)
                anchors.verticalCenter: labelText.verticalCenter
                text: {
                    if (root.zeroLabel !== "" && Math.abs(root.shownValue) < 0.0001)
                        return root.zeroLabel;
                    return root.integer ? String(Math.round(root.shownValue)) : root.shownValue.toFixed(2);
                }
                color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.55)
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                textFormat: Text.PlainText
            }

            // Only offered when there is something to undo, so the row stays
            // quiet until the user has actually changed it.
            Text {
                id: resetButton
                anchors.right: parent.right
                anchors.verticalCenter: labelText.verticalCenter
                visible: root.overridden
                text: "󰜉"
                color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, resetMouse.containsMouse ? 0.9 : 0.4)
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                textFormat: Text.PlainText

                MouseArea {
                    id: resetMouse
                    anchors.fill: parent
                    anchors.margins: -Style.space(4)
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        for (var i = 0; i < root.paths.length; i++)
                            root.host.resetSetting(String(root.paths[i]));
                    }
                }
            }
        }

        PanelSlider {
            width: parent.width
            height: Style.spacing.controlHeight
            bar: root.host
            minimum: root.minimum
            maximum: root.maximum
            step: root.step
            integer: root.integer
            value: root.shownValue

            onMoved: function (value) {
                root.dragging = true;
                root.pending = value;
                coalesce.restart();
            }
            onReleased: function (value) {
                coalesce.stop();
                root.pending = value;
                root.commit(value);
                root.dragging = false;
            }
        }
    }
}
