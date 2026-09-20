import QtQuick
import qs.Commons
import "Motion.js" as Motion

// One of the two frosted capsules flanking the island.
//
// The island is opaque because it is pretending to be hardware; the capsules
// are not, because they are pretending to be glass laid over the wallpaper.
// That is the whole visual difference between them — they share a height, a
// centre line, a corner exponent and a spring, so the three shapes read as one
// bar rather than as three widgets that happen to be on the same row.
//
// A capsule with nothing to show collapses to zero width rather than hiding,
// so the input mask follows it out and an empty capsule cannot swallow clicks
// meant for the desktop behind it.
Item {
    id: root

    property var config: null
    property var host: null
    property var names: []
    property string screenName: ""

    // Set by the window when the island has grown wide enough that the
    // capsule would collide with it.
    property bool retracted: false

    property real capsuleHeight: 34
    property real radius: 10
    property real exponent: 2.6
    property real padX: 10
    property real moduleSpacing: 2
    property real fontSize: 0

    readonly property var motion: config ? config.motion : ({})
    readonly property bool populated: names && names.length > 0 && row.implicitWidth > 0

    // What the capsule would measure if nothing were in its way. The window
    // reads this to decide whether there is still room for it beside the
    // island — asking `width` instead would be circular, since retracting is
    // what makes the width zero in the first place.
    readonly property real naturalWidth: populated ? Math.round(row.implicitWidth + 2 * padX) : 0

    // The animated width, driven by the same spring the island uses so the
    // three shapes settle together.
    property real bodyW: 0
    Binding on bodyW {
        value: root.retracted ? 0 : root.naturalWidth
    }

    readonly property var curve: Motion.curveFor(root.motion.collapseResponse, root.motion.collapseDamping)

    Behavior on bodyW {
        NumberAnimation {
            duration: root.curve.duration
            easing.type: Easing.Bezier
            easing.bezierCurve: root.curve.bezierCurve
        }
    }

    implicitWidth: bodyW
    implicitHeight: capsuleHeight
    width: bodyW
    height: capsuleHeight

    // Below a couple of pixels there is nothing left to draw, and an item of
    // width 0.4 still renders a hairline of colour.
    visible: bodyW > 2
    opacity: bodyW > 2 ? 1 : 0

    Behavior on opacity {
        NumberAnimation {
            duration: 120
        }
    }

    IslandSurface {
        anchors.fill: parent

        bodyWidth: root.width
        bodyHeight: root.height
        radiusTop: root.radius
        radiusBottom: root.radius
        fillet: 0
        exponent: root.exponent

        color: host ? host.capsuleBackground : Qt.rgba(1, 1, 1, 0.12)
        borderColor: host ? host.capsuleBorder : "transparent"
        borderWidth: root.config && root.config.style ? (root.config.style.capsuleBorderWidth || 0) : 0
    }

    // Clipped for the same reason the island's content is: a module whose
    // width is still catching up to the capsule's must not spill past the
    // outline on the way.
    Item {
        anchors.fill: parent
        clip: true

        ModuleRow {
            id: row
            anchors.centerIn: parent

            names: root.names
            config: root.config
            host: root.host
            screenName: root.screenName
            spacing: root.moduleSpacing
            // Square slots, so the status corner keeps an even pitch however
            // wide the individual glyphs turn out to be.
            minSlot: root.capsuleHeight
            fontSize: root.fontSize
            hoverOpacity: root.config && root.config.style ? (root.config.style.capsuleHoverOpacity === undefined ? 0.1 : root.config.style.capsuleHoverOpacity) : 0.1
            foreground: host ? host.foreground : "white"
            accent: host ? host.accent : "white"
            itemHeight: root.capsuleHeight
        }
    }
}
