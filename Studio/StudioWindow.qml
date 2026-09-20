import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Ui

// The Studio: every knob the island has, on one surface, writing straight
// through to shell.json.
//
// It edits the same file a user would hand-edit, through the same channel the
// shell already uses to hot-reload it — so there is no apply button and no
// preview mode. Move a slider and the bar behind the window reshapes, because
// the bar is reading the value you just wrote. Which is also why the window
// is a centred card over a dim rather than fullscreen: you have to be able to
// see what you are editing.
PanelWindow {
    id: win

    required property var modelData
    property var host: null
    property var config: null

    readonly property bool shown: host !== null && host.studioScreen === String(modelData.name)

    screen: modelData
    visible: shown

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "omarchy-dynamic-island-studio"
    WlrLayershell.layer: WlrLayer.Overlay
    // Exclusive while open, so Escape closes it without having to click into
    // it first. Safe enough to grab the keyboard for: Escape, the close
    // button, clicking off, and `omarchy-shell island studio` all release it,
    // and the window only exists while it is open.
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    readonly property color foreground: host ? host.foreground : Color.foreground

    // Clicking off closes. The card eats its own clicks, so only the dim
    // reaches this.
    MouseArea {
        anchors.fill: parent
        onClicked: if (win.host)
            win.host.setStudio("", false)
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.45)
        opacity: win.shown ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: 140
            }
        }
    }

    FocusScope {
        id: keys
        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: function (event) {
            if (win.host)
                win.host.setStudio("", false);
            event.accepted = true;
        }
    }

    BorderSurface {
        id: card

        anchors.centerIn: parent
        // Tall enough to be worth scrolling, short enough to leave the bar
        // visible above it — the point is watching the island change.
        width: Math.min(Style.space(660), win.width - Style.space(64))
        height: Math.min(Style.space(620), win.height - (host ? host.barSize : 0) - Style.space(64))

        color: Color.popups.background
        borderSpec: Border.surfaceSpec("popups", "border", Color.popups.border, Math.max(1, Style.space(2)))
        radius: Math.max(Style.cornerRadius, Style.space(14))
        padding: Style.space(18)

        MouseArea {
            anchors.fill: parent
            // Swallow clicks so the dim's close handler does not fire through
            // the card.
            onClicked: {}
        }

        // BorderSurface exposes its insets but does not apply them to
        // children, so the content has to step inside the border and padding
        // itself.
        Item {
            anchors.fill: parent
            anchors.topMargin: card.contentTopInset
            anchors.bottomMargin: card.contentBottomInset
            anchors.leftMargin: card.contentLeftInset
            anchors.rightMargin: card.contentRightInset

            // ------------------------------------------------------ header

            Item {
                id: header
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: title.implicitHeight + Style.space(14)

                Text {
                    id: title
                    anchors.left: parent.left
                    anchors.top: parent.top
                    text: "Island Studio"
                    color: win.foreground
                    font.family: Style.font.family
                    font.pixelSize: Style.font.heading
                    font.bold: true
                    textFormat: Text.PlainText
                }

                Text {
                    anchors.right: closeButton.left
                    anchors.rightMargin: Style.space(14)
                    anchors.verticalCenter: title.verticalCenter
                    text: "Reset all"
                    color: Qt.rgba(win.foreground.r, win.foreground.g, win.foreground.b, resetMouse.containsMouse ? 0.95 : 0.5)
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    textFormat: Text.PlainText

                    MouseArea {
                        id: resetMouse
                        anchors.fill: parent
                        anchors.margins: -Style.space(5)
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (win.host)
                            win.host.resetAllSettings()
                    }
                }

                Text {
                    id: closeButton
                    anchors.right: parent.right
                    anchors.verticalCenter: title.verticalCenter
                    text: "󰅖"
                    color: Qt.rgba(win.foreground.r, win.foreground.g, win.foreground.b, closeMouse.containsMouse ? 0.95 : 0.5)
                    font.family: Style.font.family
                    font.pixelSize: Style.font.title
                    textFormat: Text.PlainText

                    MouseArea {
                        id: closeMouse
                        anchors.fill: parent
                        anchors.margins: -Style.space(5)
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (win.host)
                            win.host.setStudio("", false)
                    }
                }
            }

            // -------------------------------------------------------- body

            Flickable {
                id: flick
                anchors.top: header.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                clip: true
                contentWidth: width
                contentHeight: body.implicitHeight
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: body
                    width: flick.width
                    spacing: Style.space(20)

                    Section {
                        title: "Layout"
                        hint: "What sits where. Modules that have nothing to show — album art with no music, a battery on a desktop — take up no space, so a row can hold more than it draws."
                        foreground: win.foreground

                        RowEditor {
                            host: win.host
                            path: "left"
                            label: "Left capsule"
                        }
                        RowEditor {
                            host: win.host
                            path: "collapsed"
                            label: "Island"
                            hint: "at rest"
                        }
                        RowEditor {
                            host: win.host
                            path: "hover"
                            label: "Island"
                            hint: "on hover"
                        }
                        RowEditor {
                            host: win.host
                            path: "right"
                            label: "Right capsule"
                        }
                    }

                    Section {
                        title: "Shape"
                        foreground: win.foreground

                        SliderRow {
                            host: win.host
                            paths: ["shape.collapsedHeight"]
                            label: "Bar height"
                            minimum: 18
                            maximum: 64
                            step: 1
                            integer: true
                        }
                        SliderRow {
                            host: win.host
                            paths: ["shape.radiusTop", "shape.radiusBottom"]
                            label: "Corner radius"
                            minimum: 0
                            maximum: 32
                            step: 1
                            integer: true
                        }
                        SliderRow {
                            host: win.host
                            paths: ["shape.topInset"]
                            label: "Gap from screen edge"
                            minimum: 0
                            maximum: 40
                            step: 1
                            integer: true
                            zeroLabel: "flush"
                        }
                        SliderRow {
                            host: win.host
                            paths: ["shape.sideMargin"]
                            label: "Capsule inset"
                            minimum: 0
                            maximum: 90
                            step: 1
                            integer: true
                        }
                        SliderRow {
                            host: win.host
                            paths: ["shape.collapsedWidth"]
                            label: "Island minimum width"
                            minimum: 80
                            maximum: 420
                            step: 5
                            integer: true
                        }
                        SliderRow {
                            host: win.host
                            paths: ["shape.curvature"]
                            label: "Corner curvature"
                            minimum: 2
                            maximum: 8
                            step: 0.2
                        }
                        SliderRow {
                            host: win.host
                            paths: ["shape.capsuleFontSize"]
                            label: "Capsule type size"
                            minimum: 0
                            maximum: 26
                            step: 1
                            integer: true
                            zeroLabel: "auto"
                        }
                    }

                    Section {
                        title: "Material"
                        hint: "The capsules are frosted, not filled. Real refraction is the compositor's job — see the Hyprland blur note in the README."
                        foreground: win.foreground

                        SliderRow {
                            host: win.host
                            paths: ["style.darken"]
                            label: "Island tint"
                            minimum: 0
                            maximum: 1
                            step: 0.05
                            zeroLabel: "black"
                        }
                        SliderRow {
                            host: win.host
                            paths: ["style.opacity"]
                            label: "Island opacity"
                            minimum: 0.2
                            maximum: 1
                            step: 0.05
                        }
                        SliderRow {
                            host: win.host
                            paths: ["style.capsuleOpacity"]
                            label: "Glass density"
                            minimum: 0
                            maximum: 1
                            step: 0.05
                        }
                        SliderRow {
                            host: win.host
                            paths: ["style.capsuleHoverOpacity"]
                            label: "Hover wash"
                            minimum: 0
                            maximum: 0.4
                            step: 0.02
                        }
                    }

                    Section {
                        title: "Motion"
                        hint: "A real spring, not an easing preset. Response is roughly the time to first reach the target; damping below 0.5 visibly bounces."
                        foreground: win.foreground

                        SliderRow {
                            host: win.host
                            paths: ["motion.response"]
                            label: "Response"
                            minimum: 0.15
                            maximum: 0.9
                            step: 0.01
                        }
                        SliderRow {
                            host: win.host
                            paths: ["motion.damping"]
                            label: "Damping"
                            minimum: 0.3
                            maximum: 1
                            step: 0.02
                        }
                    }

                    Section {
                        title: "Behaviour"
                        foreground: win.foreground

                        ChoiceRow {
                            host: win.host
                            path: "behaviour.monitors"
                            label: "Show on"
                            fallback: "all"
                            options: {
                                var out = ["all", "focused"];
                                var screens = Quickshell.screens;
                                for (var i = 0; i < screens.length; i++)
                                    out.push(String(screens[i].name));
                                return out;
                            }
                        }
                        ChoiceRow {
                            host: win.host
                            path: "behaviour.activityMonitors"
                            label: "Notifications and HUDs on"
                            fallback: "all"
                            options: ["all", "focused"]
                        }
                        SwitchRow {
                            host: win.host
                            path: "behaviour.capsules"
                            label: "Side capsules"
                            hint: "Off leaves the bare island"
                        }
                        SwitchRow {
                            host: win.host
                            path: "behaviour.reserveSpace"
                            label: "Reserve screen space"
                            hint: "Windows tile below the resting bar"
                        }
                        SwitchRow {
                            host: win.host
                            path: "behaviour.expandOnHover"
                            label: "Expand on hover"
                        }
                        SwitchRow {
                            host: win.host
                            path: "behaviour.scrollGestures"
                            label: "Scroll to change volume"
                            hint: "Shift-scroll steps tracks"
                        }
                        SwitchRow {
                            host: win.host
                            path: "behaviour.closeOnLeave"
                            label: "Close the control centre on leave"
                        }
                    }

                    Section {
                        title: "Takeovers"
                        hint: "Transient events that own the island. Volume and brightness outrank notifications on purpose: you just pressed a key and want to see the result."
                        foreground: win.foreground

                        SwitchRow {
                            host: win.host
                            path: "activities.notification.enabled"
                            label: "Notifications"
                        }
                        SwitchRow {
                            host: win.host
                            path: "activities.volume.enabled"
                            label: "Volume"
                        }
                        SwitchRow {
                            host: win.host
                            path: "activities.brightness.enabled"
                            label: "Brightness"
                        }
                        SwitchRow {
                            host: win.host
                            path: "activities.media.enabled"
                            label: "Track changes"
                        }
                        SwitchRow {
                            host: win.host
                            path: "activities.power.enabled"
                            label: "Charger and low battery"
                        }
                    }

                    Item {
                        width: 1
                        height: Style.space(6)
                    }
                }
            }
        }
    }
}
