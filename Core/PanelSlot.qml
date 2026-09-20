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
// Two ways to use one:
//
//   chrome: false   mounted for its panel alone — zero opacity, deaf to the
//                   pointer — with one of the island's own glyphs over the
//                   top driving it. That is what lets the status corner keep
//                   its own look and still open the real panels.
//   chrome: true    the plugin draws itself. The tray and the indicator row
//                   are whole widgets rather than one glyph and a panel, so
//                   there is nothing to reimplement and no reason to.
//
// Either way it fills this item, and that is load bearing: `PopupCard`
// anchors to the widget's button, so the button's rect is what decides where
// the popup lands. Filling the slot puts it under the glyph that was clicked.
//
// Emptiness is read off `implicitWidth`, never off `visible`. Reading a
// child's `visible` gives the *effective* value, which already folds in the
// parent's — so a row that hides a slot because its widget is hidden makes
// the widget hidden, and the pair latches to false and never recovers. Both
// widgets worth hosting here collapse their implicit width to zero when they
// have nothing to show, which says the same thing without the cycle.
Item {
    id: root

    property var host: null
    property string pluginId: ""
    // Which screen this copy lives on. There is one per island, and
    // `summonBarWidget` needs to know which of them a keybinding meant.
    property string screenName: ""
    property bool chrome: false
    // The widget's own settings, in the shape its manifest documents. The
    // island passes its `modules.<name>` block straight through, so
    // `modules.indicators.alwaysShow` reaches the indicator row exactly as
    // it would from an inline bar entry.
    property var settings: ({})

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

    // A chromed widget is the slot's content and sizes it. One mounted for
    // its panel alone is laid over whatever is already there and contributes
    // nothing to the row's width.
    readonly property bool occupies: chrome && available && widget.implicitWidth > 0

    // How the row decides whether to leave a gap for this. See ModuleRow.
    // Availability, not emptiness.
    //
    // The tempting test is "does it measure wider than nothing", and for the
    // tray that works — its width is driven by how many icons it has. The
    // indicator row is not so obliging: hidden, it reports zero width, so a
    // row that hid it for being zero-wide would keep it zero-wide forever.
    // Same latch as reading `visible`, wearing a different hat.
    //
    // So the slot stays in the layout whenever the plugin is there at all,
    // and emptiness is expressed as zero width instead. The only cost is
    // that a present-but-empty widget still earns the row's spacing, which
    // at the capsule's two pixels is not worth another mechanism.
    readonly property bool shown: !chrome || available

    implicitWidth: occupies ? widget.implicitWidth : 0
    implicitHeight: occupies ? widget.implicitHeight : 0

    Loader {
        id: loader
        anchors.fill: parent
        sourceComponent: root.component

        opacity: root.chrome ? 1 : 0
        // `enabled` propagates down, which is what stops a widget mounted for
        // its panel alone from swallowing the click meant for the glyph drawn
        // over it. The panel is a separate window and is unaffected.
        enabled: root.chrome

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
                item.settings = Qt.binding(function () {
                    return root.settings;
                });
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
