import QtQuick
import QtQuick.Shapes

// A progress ring, determinate or not.
//
// The determinate form sweeps clockwise from twelve o'clock. The
// indeterminate form is a short arc going round at a constant rate, which is
// the honest way to say "this is running and I cannot tell you how far" —
// a bar creeping toward an end it does not know is a lie told slowly.
//
// Drawn with the curve renderer rather than the geometry one: the sweep
// changes every frame while a task runs, and the geometry renderer visibly
// stairsteps an arc that is being re-tessellated.
Item {
    id: root

    // 0..1. Ignored while indeterminate.
    property real value: 0
    property bool indeterminate: false

    property color color: "white"
    property color trackColor: Qt.rgba(1, 1, 1, 0.16)
    property real thickness: Math.max(1.5, Math.round(Math.min(width, height) * 0.14))

    // How much of the circle the indeterminate arc covers.
    readonly property real spinnerSweep: 100
    property real spin: 0

    readonly property real radius: Math.max(0.5, Math.min(width, height) / 2 - thickness / 2)
    readonly property real sweep: indeterminate ? spinnerSweep : Math.max(0, Math.min(1, value)) * 360

    implicitWidth: 16
    implicitHeight: 16

    NumberAnimation on spin {
        running: root.indeterminate && root.visible
        from: 0
        to: 360
        duration: 1100
        loops: Animation.Infinite
    }

    // A finished sweep should land on the target rather than snap to it, so a
    // task that jumps from 40% to done still reads as having got there.
    Behavior on value {
        enabled: !root.indeterminate
        NumberAnimation {
            duration: 220
            easing.type: Easing.OutCubic
        }
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        asynchronous: false

        ShapePath {
            strokeColor: root.trackColor
            strokeWidth: root.thickness
            fillColor: "transparent"

            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: root.radius
                radiusY: root.radius
                startAngle: -90
                sweepAngle: 360
            }
        }

        ShapePath {
            // A round cap on a zero-length arc paints a dot, which reads as
            // 1% when the truth is 0.
            strokeColor: root.sweep > 0.5 ? root.color : "transparent"
            strokeWidth: root.thickness
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: root.radius
                radiusY: root.radius
                startAngle: -90 + root.spin
                sweepAngle: root.sweep
            }
        }
    }
}
