import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import "Motion.js" as Motion
import "Config.js" as Config

// One island, on one screen.
//
// The layer surface spans the full width of the screen and is tall enough for
// the island's largest state, but its *input* region is masked down to the
// island itself — so the island can grow to any size without the invisible
// remainder of the surface swallowing clicks meant for the desktop.
//
// Screen space is reserved separately, via the exclusive zone, and only ever
// for the resting height. Windows tile below the collapsed pill and the island
// expands over them, which is what you want: a notification should not reflow
// every window on the desktop.
PanelWindow {
    id: win

    required property var modelData
    property var config: null
    property var host: null

    readonly property var shape: config ? config.shape : ({})
    readonly property var motion: config ? config.motion : ({})
    readonly property var behaviour: config ? config.behaviour : ({})

    screen: modelData

    // ------------------------------------------------------------------ state

    property bool hovered: false
    readonly property bool expanded: host ? host.expandedScreen === String(modelData.name) : false

    // Whether the pointer has been inside since the panel opened.
    //
    // "Close when the pointer leaves" cannot mean "close whenever the pointer
    // is outside", because opening the panel resizes the island, which resizes
    // its input region, which delivers a leave event to a pointer that was
    // never there — so a panel opened from a keybinding would shut before it
    // finished its opening animation. Leaving is only meaningful once there
    // has been an entering.
    property bool pointerWasInside: false
    onExpandedChanged: pointerWasInside = false
    readonly property var activity: host ? host.activeActivity : null

    // Priority runs top down: an explicit click beats an incoming event, which
    // beats a hover, which beats the resting pill.
    readonly property string islandState: {
        if (expanded)
            return "expanded";
        if (activity)
            return "activity";
        if (hovered && behaviour.expandOnHover !== false && hoverRow.names.length > 0)
            return "hover";
        return "collapsed";
    }

    // ------------------------------------------------------------- geometry

    readonly property bool attached: (shape.topInset || 0) <= 0
    readonly property real padX: shape.paddingX === undefined ? 14 : shape.paddingX

    function clampWidth(w) {
        return Math.max(shape.collapsedWidth || 0, Math.min(shape.maxWidth || 680, w));
    }
    function clampHeight(h) {
        return Math.max(shape.collapsedHeight || 0, Math.min(shape.maxHeight || 560, h));
    }

    readonly property real targetWidth: {
        switch (islandState) {
        case "collapsed":
            return clampWidth(Math.max(shape.collapsedWidth || 0, collapsedRow.implicitWidth + 2 * padX));
        case "hover":
            return clampWidth(hoverRow.implicitWidth + 2 * padX + (shape.hoverPadding || 0));
        case "activity":
            return clampWidth(activityLoader.item ? activityLoader.item.implicitWidth : shape.collapsedWidth);
        case "expanded":
            return clampWidth(expandedLoader.item ? expandedLoader.item.implicitWidth : shape.collapsedWidth);
        }
        return shape.collapsedWidth || 0;
    }

    readonly property real targetHeight: {
        switch (islandState) {
        case "activity":
            return clampHeight(activityLoader.item ? activityLoader.item.implicitHeight : shape.collapsedHeight);
        case "expanded":
            return clampHeight(expandedLoader.item ? expandedLoader.item.implicitHeight : shape.collapsedHeight);
        }
        return shape.collapsedHeight || 0;
    }

    // The animated size. Bound to the target so every state change is a
    // spring, never a jump.
    property real bodyW: shape.collapsedWidth || 210
    property real bodyH: shape.collapsedHeight || 32
    Binding on bodyW {
        value: win.targetWidth
    }
    Binding on bodyH {
        value: win.targetHeight
    }

    // Growing and shrinking get different springs. Opening should feel like it
    // has momentum; closing should get out of the way, so it runs stiffer and
    // with less overshoot.
    property bool growing: true
    readonly property real targetArea: targetWidth * targetHeight
    onTargetAreaChanged: growing = targetArea >= bodyW * bodyH

    readonly property var curve: growing ? Motion.curveFor(motion.response, motion.damping) : Motion.curveFor(motion.collapseResponse, motion.collapseDamping)

    Behavior on bodyW {
        NumberAnimation {
            duration: win.curve.duration
            easing.type: Easing.Bezier
            easing.bezierCurve: win.curve.bezierCurve
        }
    }
    Behavior on bodyH {
        NumberAnimation {
            duration: win.curve.duration
            easing.type: Easing.Bezier
            easing.bezierCurve: win.curve.bezierCurve
        }
    }

    // Corner radius tracks height, but not linearly. At rest the island should
    // be a true capsule, so the radius is allowed all the way to half the
    // height. Grown into a card it should not stay proportionally round — a
    // 300px panel with a 150px corner is a lozenge, not a card — so the
    // height-driven term is capped and the shape settles at a fixed rounding.
    readonly property real maxCardRadius: Style.space(28)
    readonly property real radiusBottom: Math.min(bodyH * 0.5, Math.max(shape.radiusBottom || 17, Math.min(maxCardRadius, bodyH * 0.28)))
    readonly property real radiusTop: attached ? (shape.radiusTop || 0) : radiusBottom
    readonly property real fillet: attached ? (shape.fillet || 0) : 0

    // ------------------------------------------------------------- surface

    anchors {
        top: host && host.position === "top"
        bottom: host && host.position === "bottom"
        left: true
        right: true
    }

    implicitHeight: (shape.maxHeight || 560) + (shape.topInset || 0) + Style.space(8)
    color: "transparent"
    surfaceFormat.opaque: false

    exclusionMode: ExclusionMode.Normal
    // Only the resting pill reserves space. Everything above that height is an
    // overlay, so expanding never reflows the desktop.
    exclusiveZone: behaviour.reserveSpace === false ? 0 : Math.round((shape.collapsedHeight || 32) + (shape.topInset || 0))

    WlrLayershell.namespace: "omarchy-dynamic-island"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // Input is confined to the island. Without this the full-width surface
    // would eat every click along the top of the screen.
    mask: Region {
        item: islandRoot
    }

    Item {
        id: islandRoot

        width: surface.implicitWidth
        height: surface.implicitHeight
        x: Math.round((win.width - width) / 2)
        y: host && host.position === "bottom" ? win.height - height - (win.shape.topInset || 0) : (win.shape.topInset || 0)

        IslandSurface {
            id: surface
            anchors.fill: parent

            bodyWidth: win.bodyW
            bodyHeight: win.bodyH
            radiusTop: win.radiusTop
            radiusBottom: win.radiusBottom
            fillet: win.fillet
            exponent: win.shape.curvature || 5

            color: host ? host.islandBackground : "black"
            borderColor: host ? host.islandBorder : "transparent"
            borderWidth: win.config && win.config.style ? (win.config.style.borderWidth || 0) : 0
        }

        // Content sits over the body only, never over the shoulders, and is
        // clipped so a layer that is mid-crossfade cannot spill past the
        // outline while the shape is still catching up to it.
        Item {
            id: contentArea

            x: surface.bodyX
            y: 0
            width: win.bodyW
            height: win.bodyH
            clip: true

            ContentLayer {
                id: collapsedLayer
                activeLayer: win.islandState === "collapsed"

                ModuleRow {
                    id: collapsedRow
                    anchors.centerIn: parent
                    names: win.config ? win.config.collapsed : []
                    config: win.config
                    host: win.host
                    foreground: host ? host.foreground : "white"
                    accent: host ? host.accent : "white"
                    itemHeight: Math.min(win.shape.collapsedHeight || 32, Style.font.body + Style.space(4))
                }
            }

            ContentLayer {
                id: hoverLayer
                activeLayer: win.islandState === "hover"

                ModuleRow {
                    id: hoverRow
                    anchors.centerIn: parent
                    names: win.config ? win.config.hover : []
                    config: win.config
                    host: win.host
                    foreground: host ? host.foreground : "white"
                    accent: host ? host.accent : "white"
                    itemHeight: Math.min(win.shape.collapsedHeight || 32, Style.font.body + Style.space(4))
                }
            }

            ContentLayer {
                id: activityLayer
                activeLayer: win.islandState === "activity"

                Loader {
                    id: activityLoader
                    anchors.centerIn: parent
                    active: win.activity !== null && win.activity !== undefined
                    sourceComponent: host && win.activity ? host.componentForActivity(win.activity) : null

                    onLoaded: {
                        if (!item)
                            return;
                        if ("activity" in item)
                            item.activity = Qt.binding(function () {
                                return win.activity;
                            });
                        if ("options" in item)
                            item.options = Qt.binding(function () {
                                return host ? host.optionsForActivity(win.activity) : ({});
                            });
                        if ("foreground" in item)
                            item.foreground = Qt.binding(function () {
                                return host ? host.foreground : "white";
                            });
                        if ("accent" in item)
                            item.accent = Qt.binding(function () {
                                return host ? host.accent : "white";
                            });
                    }
                }
            }

            ContentLayer {
                id: expandedLayer
                activeLayer: win.islandState === "expanded"

                Loader {
                    id: expandedLoader
                    anchors.centerIn: parent
                    active: win.expanded
                    sourceComponent: host ? host.expandedComponent : null

                    onLoaded: {
                        if (!item)
                            return;
                        if ("host" in item)
                            item.host = win.host;
                        if ("config" in item)
                            item.config = win.config;
                        if ("foreground" in item)
                            item.foreground = Qt.binding(function () {
                                return host ? host.foreground : "white";
                            });
                        if ("accent" in item)
                            item.accent = Qt.binding(function () {
                                return host ? host.accent : "white";
                            });
                    }
                }
            }
        }

        HoverHandler {
            id: hover
            onHoveredChanged: hoverGate.restart()
            // A monitor unplugged mid-hover destroys this surface without ever
            // delivering a leave event, which would strand the island open.
            Component.onDestruction: win.hovered = false
        }

        Timer {
            id: hoverGate
            // Entering is immediate; leaving waits, so brushing past the pill
            // on the way to a window does not flicker it open and shut.
            interval: hover.hovered ? 0 : (win.behaviour.hoverDelay === undefined ? 90 : win.behaviour.hoverDelay)
            onTriggered: {
                win.hovered = hover.hovered;
                if (host)
                    host.setHoverHold(String(win.modelData.name), hover.hovered);

                if (hover.hovered) {
                    win.pointerWasInside = true;
                } else if (win.expanded && win.pointerWasInside && win.behaviour.closeOnLeave !== false) {
                    host.setExpanded("", false);
                }
            }
        }

        // Scrolling the island adjusts volume; Shift-scroll steps tracks.
        // The pointer is already there to read what the island is showing, so
        // acting on it without moving to another surface is the whole point.
        WheelHandler {
            enabled: win.behaviour.scrollGestures !== false
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: function (event) {
                if (!host)
                    return;
                var vertical = event.angleDelta.y;
                var horizontal = event.angleDelta.x;

                // Horizontal travel, or Shift-modified vertical, means "next
                // or previous" — the same convention a trackpad swipe follows.
                var trackStep = horizontal !== 0 ? horizontal : (event.modifiers & Qt.ShiftModifier ? vertical : 0);
                if (trackStep !== 0) {
                    host.stepTrack(trackStep > 0 ? 1 : -1);
                    return;
                }
                if (vertical !== 0)
                    host.stepVolume(vertical > 0 ? 1 : -1);
            }
        }

        TapHandler {
            enabled: win.behaviour.expandOnClick !== false
            onTapped: {
                if (win.activity && host.dismissActivity(win.activity))
                    return;
                host.setExpanded(String(win.modelData.name), !win.expanded);
            }
        }
    }

    // A single state's content: fades and slides as it takes over the island.
    //
    // The delay on the way in is deliberate and is most of the illusion — the
    // shape starts opening first, and the content arrives into a space that is
    // already there, rather than the two racing each other.
    component ContentLayer: Item {
        id: layer

        property bool activeLayer: false

        anchors.fill: parent
        visible: opacity > 0.01
        opacity: activeLayer ? 1 : 0

        transform: Translate {
            y: layer.activeLayer ? 0 : (win.motion.contentSlide === undefined ? 8 : win.motion.contentSlide)

            Behavior on y {
                NumberAnimation {
                    duration: win.motion.contentFade || 150
                    easing.type: Easing.OutCubic
                }
            }
        }

        Behavior on opacity {
            SequentialAnimation {
                PauseAnimation {
                    duration: layer.activeLayer ? (win.motion.contentDelay || 0) : 0
                }
                NumberAnimation {
                    duration: win.motion.contentFade || 150
                    easing.type: Easing.OutCubic
                }
            }
        }
    }
}
