import QtQuick
import qs.Commons

// The little dancing bars that say "audio is playing".
//
// Deliberately not driven by real audio levels: sampling PipeWire peaks for a
// 20px ornament costs a subscription and a wakeup per frame, and at this size
// nobody can tell the difference between real levels and plausible ones. Each
// bar runs its own loop at its own period and phase, which is what stops the
// group from visibly pulsing in unison.
Row {
    id: root

    property color color: "white"
    property bool active: true
    property int bars: 4
    property real barWidth: Math.max(2, Style.space(2))
    property real maxHeight: Style.space(14)
    property real minScale: 0.28

    spacing: Math.max(2, Style.space(2))
    height: maxHeight

    Repeater {
        model: root.bars

        delegate: Rectangle {
            id: bar
            required property int index

            // Coprime-ish periods so the bars drift out of phase and stay that
            // way, instead of resynchronising every few seconds.
            readonly property int period: 520 + (bar.index * 137) % 380

            width: root.barWidth
            radius: width / 2
            color: root.color
            anchors.verticalCenter: parent.verticalCenter

            height: root.maxHeight * root.minScale

            SequentialAnimation on height {
                running: root.active
                loops: Animation.Infinite
                // Restart from the resting height so pausing and resuming does
                // not leave a bar frozen mid-stretch.
                alwaysRunToEnd: false

                PauseAnimation {
                    duration: bar.index * 90
                }
                NumberAnimation {
                    to: root.maxHeight
                    duration: bar.period
                    easing.type: Easing.InOutSine
                }
                NumberAnimation {
                    to: root.maxHeight * root.minScale
                    duration: bar.period
                    easing.type: Easing.InOutSine
                }
            }

            Behavior on height {
                enabled: !root.active
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.OutCubic
                }
            }
        }
    }
}
