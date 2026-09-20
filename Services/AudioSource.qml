import QtQuick
import Quickshell.Services.Pipewire
import "../Core/Config.js" as Config

// Volume changes, as an island HUD.
//
// Watches the default sink rather than intercepting keys, so it fires however
// the volume moved — media keys, `wpctl`, a mixer, another app — instead of
// only for the bindings it knows about.
Item {
    id: root

    property var config: null
    property var activities: null

    readonly property var options: Config.activityOptions(config, "volume")
    readonly property bool enabled: options.enabled === true && !capturingOsd

    // When the island is rendering Omarchy's OSD stream, that stream already
    // carries volume and brightness — watching them here as well would push
    // the same event twice on every keypress.
    readonly property bool capturingOsd: config && config.behaviour ? config.behaviour.captureOmarchyOsd === true : false

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property real volume: sink && sink.audio ? sink.audio.volume : 0
    readonly property bool muted: sink && sink.audio ? sink.audio.muted : false

    // PipeWire node properties are only bound while something tracks the node.
    PwObjectTracker {
        objects: root.sink ? [root.sink] : []
    }

    function glyphFor(value, isMuted) {
        if (isMuted || value <= 0)
            return "󰝟";
        if (value < 0.34)
            return "󰕿";
        if (value < 0.67)
            return "󰖀";
        return "󰕾";
    }

    function show() {
        if (!enabled || !activities)
            return;
        activities.push("volume", 60, {
            value: root.volume,
            muted: root.muted,
            glyph: root.glyphFor(root.volume, root.muted)
        }, Number(options.duration) || 1500);
    }

    // The sink's starting volume is not an event. Without priming, the island
    // would throw a HUD on screen every time the shell restarted.
    property bool primed: false

    Component.onCompleted: primeTimer.start()

    Timer {
        id: primeTimer
        // Long enough for PipeWire to resolve the default sink and settle its
        // initial values, which arrive over a few asynchronous updates.
        interval: 1200
        onTriggered: root.primed = true
    }

    onVolumeChanged: if (primed)
        show()
    onMutedChanged: if (primed)
        show()
}
