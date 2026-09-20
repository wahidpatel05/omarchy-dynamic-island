import QtQuick
import qs.Commons
import qs.Ui
import "../Core/Config.js" as Config

// The editor for one of the island's four rows.
//
// Modules are chips in the order they will appear. Each carries the two
// things you actually want to do to it — move it along the row, or take it
// out — and a dropdown at the end offers whatever is not in the row yet.
//
// Reordering is buttons rather than drag. A drag would be nicer to use once
// and worse to use repeatedly: the chips are small, the rows are short, and
// nudging an icon one place left should not require aiming.
Column {
    id: root

    property var host: null
    property string path: ""
    property string label: ""
    property string hint: ""

    readonly property var items: {
        var value = host && path !== "" ? host.setting(path) : undefined;
        return Array.isArray(value) ? value : [];
    }

    readonly property var catalogue: Config.moduleCatalogue()

    readonly property var unused: {
        var out = [];
        for (var i = 0; i < catalogue.length; i++) {
            if (items.indexOf(catalogue[i].id) === -1)
                out.push(catalogue[i].label);
        }
        return out;
    }

    function idForLabel(label) {
        for (var i = 0; i < catalogue.length; i++) {
            if (catalogue[i].label === label)
                return catalogue[i].id;
        }
        return "";
    }

    function write(next) {
        if (host)
            host.setSetting(path, next);
    }

    function add(label) {
        var id = idForLabel(label);
        if (id === "")
            return;
        write(items.concat([id]));
    }

    function removeAt(index) {
        var next = items.slice();
        next.splice(index, 1);
        write(next);
    }

    function move(index, delta) {
        var target = index + delta;
        if (target < 0 || target >= items.length)
            return;
        var next = items.slice();
        var moved = next.splice(index, 1)[0];
        next.splice(target, 0, moved);
        write(next);
    }

    spacing: Style.space(6)
    width: parent ? parent.width : 0

    Item {
        width: parent.width
        height: rowLabel.implicitHeight

        Text {
            id: rowLabel
            anchors.left: parent.left
            text: root.label
            color: Color.foreground
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            textFormat: Text.PlainText
        }

        Text {
            anchors.left: rowLabel.right
            anchors.leftMargin: Style.space(8)
            anchors.baseline: rowLabel.baseline
            text: root.hint
            color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.4)
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            textFormat: Text.PlainText
        }
    }

    Flow {
        width: parent.width
        spacing: Style.space(6)

        Repeater {
            model: root.items

            delegate: Rectangle {
                id: chip
                required property var modelData
                required property int index

                readonly property bool hot: chipHover.hovered

                implicitWidth: chipRow.implicitWidth + Style.space(16)
                implicitHeight: Style.spacing.controlHeight
                radius: height * 0.34
                color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, chip.hot ? 0.16 : 0.09)

                Behavior on color {
                    ColorAnimation {
                        duration: 120
                    }
                }

                HoverHandler {
                    id: chipHover
                }

                Row {
                    id: chipRow
                    anchors.centerIn: parent
                    spacing: Style.space(6)

                    ChipButton {
                        anchors.verticalCenter: parent.verticalCenter
                        glyph: "󰅁"
                        shown: chip.hot && chip.index > 0
                        onTriggered: root.move(chip.index, -1)
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Config.moduleLabel(chip.modelData)
                        color: Color.foreground
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                        textFormat: Text.PlainText
                    }

                    ChipButton {
                        anchors.verticalCenter: parent.verticalCenter
                        glyph: "󰅂"
                        shown: chip.hot && chip.index < root.items.length - 1
                        onTriggered: root.move(chip.index, 1)
                    }

                    ChipButton {
                        anchors.verticalCenter: parent.verticalCenter
                        glyph: "󰅖"
                        shown: chip.hot
                        onTriggered: root.removeAt(chip.index)
                    }
                }
            }
        }

        Text {
            visible: root.items.length === 0
            height: Style.spacing.controlHeight
            verticalAlignment: Text.AlignVCenter
            text: "empty"
            color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.35)
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            textFormat: Text.PlainText
        }

        Dropdown {
            id: adder

            // Picking from this is an action, not a state, so it carries a
            // sentinel as its "selection" and snaps back to it. A dropdown
            // left showing the last module you added would read as though
            // that module were somehow still selected.
            readonly property string placeholder: "Add…"

            visible: root.unused.length > 0
            width: Style.space(150)
            showLabel: false
            options: [placeholder].concat(root.unused)
            value: placeholder
            foreground: Color.foreground
            onChanged: function (picked) {
                adder.value = adder.placeholder;
                if (picked !== adder.placeholder)
                    root.add(picked);
            }
        }
    }

    // The little affordances inside a chip. They fade in on hover so a row at
    // rest reads as a list of names rather than a row of controls.
    component ChipButton: Text {
        id: button

        property string glyph: ""
        property bool shown: false

        signal triggered()

        text: glyph
        color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, buttonMouse.containsMouse ? 1.0 : 0.5)
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        textFormat: Text.PlainText
        opacity: shown ? 1 : 0
        visible: opacity > 0.01

        Behavior on opacity {
            NumberAnimation {
                duration: 110
            }
        }

        MouseArea {
            id: buttonMouse
            anchors.fill: parent
            anchors.margins: -Style.space(3)
            enabled: button.shown
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: button.triggered()
        }
    }
}
