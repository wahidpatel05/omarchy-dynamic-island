import QtQuick
import qs.Commons

// Hosts one of Omarchy's own bar-widget plugins inside the island.
//
// The network list, the Bluetooth list, the calendar, the power panel and the
// agent usage dashboard are all `bar-widget` plugins: a bar button bundled
// with the popup it opens, and the popup anchors itself to that button. The
// shell hands them out as ready-built `Component`s through
// `barWidgetRegistry`, and routes `omarchy-shell shell toggle <id>` through
// whatever bar is active — so a bar that does not mount them leaves those
// panels unreachable from anywhere, not just from itself. That was the
// island's situation until this existed.
//
// The widget is mounted for its panel alone: drawn at zero opacity and deaf
// to the pointer, with one of the island's own glyphs over the top driving it.
// That is what lets the status corner keep its own look and still open the
// real panels.
//
// It fills this item rather than sitting in a corner of it, and that is load
// bearing: `PopupCard` anchors to the widget's button, so the button's rect
// is what decides where the popup lands. Filling the slot puts it under the
// glyph the user actually clicked.
Item {
    id: root

    property var host: null
    property string pluginId: ""
    // Which screen this copy lives on. There is one per island, and
    // `summonBarWidget` needs to know which of them a keybinding meant.
    property string screenName: ""

    // Reading `widgets` rather than calling a lookup helper is what makes
    // this re-evaluate when a plugin is enabled, disabled or reloaded — the
    // registry replaces the whole map rather than mutating it.
    readonly property var component: {
        var registry = host ? host.barWidgetRegistry : null;
        var widgets = registry ? registry.widgets : null;
        if (!widgets || pluginId === "")
            return null;
        var entry = widgets[pluginId];
        return entry ? entry.component : null;
    }

    readonly property var widget: loader.item
    // A plugin that is disabled, missing, or not yet registered has no
    // component. Callers check this rather than assuming the panel is there.
    readonly property bool available: widget !== null && widget !== undefined
    readonly property bool opened: available && widget.opened === true

    function toggle() {
        if (available && typeof widget.toggle === "function")
            widget.toggle();
    }

    function open() {
        if (available && typeof widget.open === "function")
            widget.open();
    }

    function close() {
        if (available && typeof widget.close === "function")
            widget.close();
    }

    // Never takes up room: it is laid over whatever is already in the slot.
    implicitWidth: 0
    implicitHeight: 0

    Loader {
        id: loader
        anchors.fill: parent
        sourceComponent: root.component

        opacity: 0
        // `enabled` propagates down, which is what stops the hidden widget's
        // own button from swallowing the click meant for the glyph drawn over
        // it. The panel is a separate window and is unaffected.
        enabled: false

        // The whole contract Omarchy's bar injects into a widget. Applied
        // again on the next tick because a widget that builds its button in
        // `Component.onCompleted` reads `bar` before this handler runs.
        function inject() {
            if (!item)
                return;
            if ("bar" in item)
                item.bar = root.host;
            if ("moduleName" in item)
                item.moduleName = root.pluginId;
            if ("settings" in item)
                item.settings = ({});
        }

        onLoaded: {
            inject();
            Qt.callLater(inject);
        }
    }

    // Registration follows `host`, not construction.
    //
    // The island injects `host` into a module *after* the module and its
    // children have been built, so a slot that registered in
    // `Component.onCompleted` would register with nothing and never be found
    // again — `omarchy-shell shell toggle omarchy.clock` would answer
    // "unknown" while the calendar sat there, mounted and working.
    property var registeredHost: null

    function syncRegistration() {
        if (registeredHost === host)
            return;
        if (registeredHost && typeof registeredHost.unregisterPanelSlot === "function")
            registeredHost.unregisterPanelSlot(root);
        registeredHost = host;
        if (registeredHost && typeof registeredHost.registerPanelSlot === "function")
            registeredHost.registerPanelSlot(root);
    }

    onHostChanged: syncRegistration()
    Component.onCompleted: syncRegistration()
    Component.onDestruction: {
        if (registeredHost && typeof registeredHost.unregisterPanelSlot === "function")
            registeredHost.unregisterPanelSlot(root);
    }
}
