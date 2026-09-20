import QtQuick
import qs.Commons
import "Config.js" as Config
import "../Modules"

// Lays out a list of module names into a row.
//
// Names come straight from the user's config arrays (`collapsed`, `hover`), so
// this is the one place that turns a string into a component. Unknown names
// render as nothing rather than failing the whole row — a typo in shell.json
// should cost the user one module, not their entire bar.
Row {
    id: root

    property var names: []
    property var config: null
    // The plugin root. Modules that need shared services (media, above all)
    // reach them through this rather than opening their own.
    property var host: null
    // Which screen this row is drawn on. Only the modules that act on the
    // island itself — the control centre button — need it, but it is offered
    // to every module the same way everything else is.
    property string screenName: ""
    property color foreground: "white"
    property color accent: "white"
    // Every module is given the same height and centres its own content
    // inside it. Left to their implicit heights, a text label and a row of
    // dots would each sit at their own baseline and the row would look
    // subtly crooked.
    property real itemHeight: Style.font.body
    // Floor for each slot's width. The glass capsules set this to their own
    // height so a row of glyphs keeps an even pitch regardless of how wide
    // each glyph happens to be; the island leaves it at 0 and lets every
    // module take exactly the space it asks for.
    property real minSlot: 0
    // Strength of the wash drawn behind a hovered module, for the modules
    // that are clickable enough to want one.
    property real hoverOpacity: 0
    // Type size for the modules that accept one. 0 leaves every module on
    // the theme's own sizes, which is what the island itself wants; the
    // capsules override it so the status corner scales with the bar.
    property real fontSize: 0

    spacing: Style.spacing.xxl
    height: itemHeight

    // Which of Omarchy's own bar widgets a module name mounts, or "" for the
    // island's own modules. `tray` and `indicators` are named outright
    // because they are things a user wants rather than plumbing they should
    // have to know the plugin id of; `plugin:<id>` is the escape hatch for
    // everything else on the machine.
    function hostedPluginId(name) {
        var key = String(name);
        if (key.indexOf("plugin:") === 0)
            return key.substring("plugin:".length);
        if (key === "tray")
            return "omarchy.tray";
        if (key === "indicators")
            return "omarchy.indicators";
        return "";
    }

    function componentFor(name) {
        switch (String(name)) {
        case "clock":
            return clockComponent;
        case "workspaces":
            return workspacesComponent;
        case "media":
            return mediaComponent;
        case "albumArt":
            return albumArtComponent;
        case "waveform":
            return waveformComponent;
        case "mediaControls":
            return mediaControlsComponent;
        case "battery":
            return batteryComponent;
        case "volume":
        case "audio":
            return volumeComponent;
        case "menu":
        case "logo":
            return menuComponent;
        case "network":
        case "wifi":
            return networkComponent;
        case "bluetooth":
            return bluetoothComponent;
        case "window":
            return windowComponent;
        case "liveIcon":
            return liveIconComponent;
        case "liveRing":
            return liveRingComponent;
        case "controlCentre":
        case "controlCenter":
            return controlCentreComponent;
        default:
            return null;
        }
    }

    Repeater {
        model: root.names

        // Every module sits in a slot rather than directly in the row.
        //
        // The slot is what applies `minSlot`, and it has to be a plain Item:
        // a Loader recomputes its own `implicitWidth` from its item every
        // time it is resized, so `width: Math.max(implicitWidth, …)` on the
        // Loader itself is a genuine cycle in Qt's eyes — it warns about a
        // binding loop and the row settles at whichever width it happened to
        // reach. Sizing the wrapper from the Loader instead leaves the Loader
        // at its natural width and breaks the cycle.
        delegate: Item {
            id: slot
            required property var modelData

            // Omarchy's own widgets are mounted declaratively rather than
            // through `inject()`. They are the one kind of content whose
            // *identity* comes from the module name, and a plugin id that
            // arrives one tick late leaves the slot looking permanently
            // empty with nothing to say why.
            readonly property string hostedId: root.hostedPluginId(modelData)
            readonly property var item: hostedId !== "" ? hosted : loader.item

            height: root.itemHeight
            readonly property real contentWidth: hostedId !== "" ? hosted.implicitWidth : loader.implicitWidth
            // `minSlot` is a floor for content, not a reservation: something
            // with nothing to draw takes no room at all, or an empty tray
            // would hold a square of nothing open in the status corner.
            width: contentWidth > 0 ? Math.max(contentWidth, root.minSlot) : 0

            // A Row reserves spacing around a zero-width child, which would
            // leave a gap where a hidden live module used to be, so absent
            // modules have to leave the layout entirely.
            //
            // Modules declare that through `shown`, never through `visible`.
            // Qt propagates `visible` *down* — an invisible parent forces its
            // children's `visible` to false — so binding this slot's
            // `visible` to its own item's `visible` makes each drive the
            // other and both latch to false the moment either is. `shown` is
            // an ordinary property with no such coupling.
            visible: item ? item.shown !== false : false

            PanelSlot {
                id: hosted
                anchors.centerIn: parent
                height: root.itemHeight
                width: implicitWidth

                chrome: true
                host: root.host
                screenName: root.screenName
                settings: Config.moduleOptions(root.config, String(slot.modelData))
                // Empty for every module that is the island's own, which
                // leaves this inert: no component, nothing loaded.
                pluginId: slot.hostedId
            }

            Loader {
                id: loader
                active: slot.hostedId === ""
                // Centred, so a module given a slot wider than it asked for
                // sits in the middle of it rather than against one edge.
                anchors.centerIn: parent
                height: root.itemHeight
                sourceComponent: root.componentFor(slot.modelData)

                // Modules declare only what they use, so each property is
                // offered rather than assigned blind.
                //
                // Everything that can change while the module is alive is
                // handed over as a binding rather than a value. Options in
                // particular: the whole config hot-reloads on save, and a
                // one-shot assignment here would quietly pin every module to
                // whatever `shell.json` said when the row was built.
                function inject() {
                    if (!item)
                        return;
                    if ("options" in item)
                        item.options = Qt.binding(function () {
                            return Config.moduleOptions(root.config, String(slot.modelData));
                        });
                    if ("foreground" in item)
                        item.foreground = Qt.binding(function () {
                            return root.foreground;
                        });
                    if ("accent" in item)
                        item.accent = Qt.binding(function () {
                            return root.accent;
                        });
                    if ("host" in item)
                        item.host = root.host;
                    if ("screenName" in item)
                        item.screenName = Qt.binding(function () {
                            return root.screenName;
                        });
                    if ("hoverOpacity" in item)
                        item.hoverOpacity = Qt.binding(function () {
                            return root.hoverOpacity;
                        });
                    if ("fontSize" in item)
                        item.fontSize = Qt.binding(function () {
                            return root.fontSize;
                        });
                }

                onLoaded: inject()
                Component.onCompleted: inject()
            }
        }
    }

    Component {
        id: clockComponent
        Clock {}
    }

    Component {
        id: workspacesComponent
        Workspaces {}
    }

    Component {
        id: mediaComponent
        Media {}
    }

    Component {
        id: albumArtComponent
        NowPlayingArt {}
    }

    Component {
        id: waveformComponent
        Waveform {}
    }

    Component {
        id: mediaControlsComponent
        MediaControls {}
    }

    Component {
        id: batteryComponent
        Battery {}
    }

    Component {
        id: volumeComponent
        Volume {}
    }

    Component {
        id: menuComponent
        Menu {}
    }

    Component {
        id: networkComponent
        Network {}
    }

    Component {
        id: controlCentreComponent
        ControlCentre {}
    }

    Component {
        id: bluetoothComponent
        Bluetooth {}
    }

    Component {
        id: windowComponent
        ActiveWindow {}
    }

    Component {
        id: liveIconComponent
        LiveIcon {}
    }

    Component {
        id: liveRingComponent
        LiveRing {}
    }
}
