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
    property color foreground: "white"
    property color accent: "white"
    // Every module is given the same height and centres its own content
    // inside it. Left to their implicit heights, a text label and a row of
    // dots would each sit at their own baseline and the row would look
    // subtly crooked.
    property real itemHeight: Style.font.body

    spacing: Style.spacing.xxl
    height: itemHeight

    function componentFor(name) {
        switch (String(name)) {
        case "clock":
            return clockComponent;
        case "workspaces":
            return workspacesComponent;
        case "media":
            return mediaComponent;
        case "battery":
            return batteryComponent;
        case "volume":
        case "audio":
            return volumeComponent;
        default:
            return null;
        }
    }

    Repeater {
        model: root.names

        delegate: Loader {
            id: slot
            required property var modelData

            height: root.itemHeight
            sourceComponent: root.componentFor(modelData)

            // Modules declare only what they use, so each property is offered
            // rather than assigned blind.
            function inject() {
                if (!item)
                    return;
                if ("options" in item)
                    item.options = Config.moduleOptions(root.config, String(slot.modelData));
                if ("foreground" in item)
                    item.foreground = root.foreground;
                if ("accent" in item)
                    item.accent = root.accent;
                if ("host" in item)
                    item.host = root.host;
            }

            onLoaded: inject()
            Component.onCompleted: inject()
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
        id: batteryComponent
        Battery {}
    }

    Component {
        id: volumeComponent
        Volume {}
    }
}
