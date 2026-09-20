import QtQuick
import Quickshell.Services.Pipewire
import qs.Commons
import "../Core"

// The click-to-open panel.
//
// Sections are listed by name in `expanded`, so a user who only wants the
// player gets a small card rather than a half-empty one. Each section reports
// its own height and the island springs to the total, which is why removing a
// section shrinks the panel instead of leaving a gap where it used to be.
Item {
    id: root

    property var host: null
    property var config: null
    property color foreground: "white"
    property color accent: "white"
    readonly property color muted: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.55)

    readonly property var media: host ? host.mediaSource : null
    readonly property var notifications: host ? host.notificationSource : null
    readonly property var brightness: host ? host.brightnessSource : null
    readonly property var sections: config && config.expanded ? config.expanded : []

    readonly property int pad: Style.space(18)
    readonly property int panelWidth: Style.space(360)

    implicitWidth: panelWidth
    implicitHeight: column.implicitHeight + pad * 2

    function has(name) {
        return sections.indexOf(name) !== -1;
    }

    function formatTime(seconds) {
        var total = Math.max(0, Math.floor(Number(seconds) || 0));
        var m = Math.floor(total / 60);
        var s = total % 60;
        return m + ":" + (s < 10 ? "0" : "") + s;
    }

    Column {
        id: column

        x: root.pad
        y: root.pad
        width: root.panelWidth - root.pad * 2
        spacing: Style.space(16)

        // ---------------------------------------------------------- media

        Item {
            width: parent.width
            visible: root.has("media") && root.media && root.media.hasMedia
            height: visible ? mediaBlock.implicitHeight : 0

            Column {
                id: mediaBlock
                width: parent.width
                spacing: Style.space(10)

                Row {
                    width: parent.width
                    spacing: Style.space(12)

                    AlbumArt {
                        width: Style.space(56)
                        height: Style.space(56)
                        source: root.media ? root.media.artUrl : ""
                        foreground: root.foreground
                        accent: root.accent
                    }

                    Column {
                        width: parent.width - Style.space(56) - Style.space(12)
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Style.space(3)

                        Text {
                            width: parent.width
                            text: root.media ? root.media.title : ""
                            color: root.foreground
                            font.family: Style.font.family
                            font.pixelSize: Style.font.subtitle
                            font.bold: true
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            textFormat: Text.PlainText
                        }

                        Text {
                            width: parent.width
                            text: root.media ? root.media.artist : ""
                            visible: text.length > 0
                            color: root.muted
                            font.family: Style.font.family
                            font.pixelSize: Style.font.bodySmall
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            textFormat: Text.PlainText
                        }
                    }
                }

                // Scrubber. Hidden for streams, which report no length and
                // would otherwise show a bar pinned at zero forever.
                Item {
                    width: parent.width
                    visible: root.media && root.media.length > 0
                    height: visible ? scrub.implicitHeight + timeRow.implicitHeight + Style.space(4) : 0

                    Slider {
                        id: scrub
                        width: parent.width
                        foreground: root.foreground
                        accent: root.accent
                        value: root.media ? root.media.position : 0
                        maximum: root.media && root.media.length > 0 ? root.media.length : 1
                        onMoved: function (v) {
                            if (root.media && root.media.length > 0)
                                root.media.seek(v / root.media.length);
                        }
                    }

                    Row {
                        id: timeRow
                        width: parent.width
                        anchors.top: scrub.bottom

                        Text {
                            text: root.formatTime(root.media ? root.media.position : 0)
                            color: root.muted
                            font.family: Style.font.family
                            font.pixelSize: Style.font.caption
                            textFormat: Text.PlainText
                        }
                        Item {
                            width: parent.width - 2 * Style.space(40)
                            height: 1
                        }
                        Text {
                            width: Style.space(40)
                            horizontalAlignment: Text.AlignRight
                            text: root.formatTime(root.media ? root.media.length : 0)
                            color: root.muted
                            font.family: Style.font.family
                            font.pixelSize: Style.font.caption
                            textFormat: Text.PlainText
                        }
                    }
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Style.space(24)

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
                            readonly property bool primary: modelData.action === "toggle"

                            text: modelData.glyph
                            color: root.foreground
                            font.family: Style.font.family
                            font.pixelSize: primary ? Style.font.display : Style.font.iconLarge
                            textFormat: Text.PlainText
                            opacity: control.containsMouse ? 1 : 0.82

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 120
                                }
                            }

                            MouseArea {
                                id: control
                                anchors.fill: parent
                                anchors.margins: -Style.space(6)
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
        }

        // -------------------------------------------------------- sliders

        Column {
            width: parent.width
            visible: root.has("sliders")
            height: visible ? implicitHeight : 0
            spacing: Style.space(10)

            PwObjectTracker {
                objects: Pipewire.defaultAudioSink ? [Pipewire.defaultAudioSink] : []
            }

            Slider {
                width: parent.width
                foreground: root.foreground
                accent: root.accent
                glyph: {
                    var sink = Pipewire.defaultAudioSink;
                    if (!sink || !sink.audio || sink.audio.muted || sink.audio.volume <= 0)
                        return "󰝟";
                    if (sink.audio.volume < 0.34)
                        return "󰕿";
                    if (sink.audio.volume < 0.67)
                        return "󰖀";
                    return "󰕾";
                }
                value: {
                    var sink = Pipewire.defaultAudioSink;
                    return sink && sink.audio ? sink.audio.volume : 0;
                }
                onMoved: function (v) {
                    var sink = Pipewire.defaultAudioSink;
                    if (sink && sink.audio)
                        sink.audio.volume = Math.max(0, Math.min(1, v));
                }
            }

            Slider {
                width: parent.width
                visible: root.brightness ? root.brightness.available : false
                height: visible ? implicitHeight : 0
                foreground: root.foreground
                accent: root.accent
                glyph: "󰃠"
                value: root.brightness ? Math.max(0, root.brightness.value) : 0
                onMoved: function (v) {
                    if (root.brightness)
                        root.brightness.set(v);
                }
            }
        }

        // -------------------------------------------------- notifications

        Column {
            width: parent.width
            visible: root.has("notifications") && recentRepeater.count > 0
            height: visible ? implicitHeight : 0
            spacing: Style.space(8)

            Text {
                text: "Recent"
                color: root.muted
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                textFormat: Text.PlainText
            }

            Repeater {
                id: recentRepeater
                model: root.notifications ? root.notifications.recent : []

                delegate: Row {
                    required property var modelData

                    width: column.width
                    spacing: Style.space(8)

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.glyph ? String(modelData.glyph) : "󰂚"
                        color: root.accent
                        font.family: Style.font.family
                        font.pixelSize: Style.font.body
                        textFormat: Text.PlainText
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - Style.space(24)
                        text: (modelData.app ? modelData.app + " · " : "") + (modelData.summary || "")
                        color: root.foreground
                        font.family: Style.font.family
                        font.pixelSize: Style.font.bodySmall
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        textFormat: Text.PlainText
                    }
                }
            }
        }
    }
}
