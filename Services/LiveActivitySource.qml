import QtQuick
import "../Core/Config.js" as Config

// Long-running tasks, on the island.
//
// This is the thing a Dynamic Island is actually for, and the one kind of
// event the island could not previously carry: not "something happened" but
// "something is still happening". A build, a sync, a download, a long copy —
// anything that has a beginning, a middle you want to glance at, and an end.
//
// Fed over IPC, so it belongs to whatever script wants it:
//
//   omarchy-shell island activity '{"id":"build","label":"Building","value":0.4}'
//   omarchy-shell island activity '{"id":"build","done":true}'
//
// The shape of the behaviour matters more than the drawing. A task
// *announces* itself when it starts and when it ends — the island opens into
// a card for a couple of seconds — and in between it *compacts* to a glyph
// and a ring on the resting pill. That is the difference between a live
// activity and a notification: a notification is over the moment you have
// read it, and this is not.
//
// So the registry here is the truth, and the card is only an announcement.
// The compact modules read this directly and keep drawing long after the
// card has collapsed.
QtObject {
    id: root

    property var config: null
    property var activities: null

    readonly property var options: Config.activityOptions(config, "live")
    readonly property bool enabled: options.enabled !== false

    // Ordered most-recently-updated first, so `primary` is whatever moved
    // last — which is almost always the one you are watching.
    property var tasks: []

    readonly property var primary: tasks.length > 0 ? tasks[0] : null
    readonly property int count: tasks.length
    readonly property bool active: count > 0

    // How long a finished task stays on screen before it is dropped. Long
    // enough to see the ring close, short enough not to be litter.
    readonly property int holdMs: {
        var n = Number(options.hold);
        return isFinite(n) && n >= 0 ? n : 1600;
    }

    readonly property int announceMs: {
        var n = Number(options.announce);
        return isFinite(n) && n >= 0 ? n : 2200;
    }

    readonly property int announcePriority: {
        var n = Number(options.priority);
        // Above a track change, below a notification: a build finishing is
        // worth a glance, but not at the cost of burying something a human
        // sent you.
        return isFinite(n) ? n : 35;
    }

    function _now() {
        return Date.now();
    }

    function _indexOf(id) {
        for (var i = 0; i < tasks.length; i++) {
            if (tasks[i].id === id)
                return i;
        }
        return -1;
    }

    // Move an entry to the front and republish. Assigning a new array rather
    // than mutating is what makes `primary` re-evaluate.
    function _promote(entry, list) {
        var next = [entry];
        for (var i = 0; i < list.length; i++) {
            if (list[i].id !== entry.id)
                next.push(list[i]);
        }
        tasks = next;
        _schedule();
    }

    // Progress as a fraction, or -1 for "running, no idea how far".
    //
    // `value` is read against `max` the way Omarchy's OSD payload is, so a
    // script counting files can send {"value": 37, "max": 210} without doing
    // the division itself. A payload with no value at all is indeterminate,
    // which is the right default: a task that has not said how far along it
    // is has not said.
    function _fraction(payload, previous) {
        if (payload.indeterminate === true)
            return -1;
        if (payload.value === undefined || payload.value === null)
            return previous === undefined ? -1 : previous;
        var value = Number(payload.value);
        if (!isFinite(value))
            return -1;
        var max = Number(payload.max);
        if (isFinite(max) && max > 0)
            value = value / max;
        else if (value > 1)
            value = value / 100;
        return Math.max(0, Math.min(1, value));
    }

    function upsert(payload) {
        if (!enabled)
            return false;
        var id = String(payload.id || "").trim();
        if (id === "")
            return false;

        if (payload.done === true || payload.cancelled === true)
            return finish(id, payload);

        var now = _now();
        var index = _indexOf(id);
        var existing = index === -1 ? null : tasks[index];

        var timeout = Number(payload.timeout);
        var entry = {
            id: id,
            glyph: payload.glyph !== undefined ? String(payload.glyph) : (existing ? existing.glyph : ""),
            label: payload.label !== undefined ? String(payload.label) : (existing ? existing.label : id),
            detail: payload.detail !== undefined ? String(payload.detail) : (existing ? existing.detail : ""),
            accent: payload.accent !== undefined ? String(payload.accent) : (existing ? existing.accent : ""),
            fraction: _fraction(payload, existing ? existing.fraction : undefined),
            state: "running",
            startedAt: existing ? existing.startedAt : now,
            updatedAt: now,
            // 0 means "until it says it is done". A script that dies mid-task
            // would otherwise leave a ring on the bar forever, so anything
            // long-running and unattended should set this.
            expiresAt: isFinite(timeout) && timeout > 0 ? now + timeout : (existing ? existing.expiresAt : 0)
        };

        var isNew = existing === null;
        _promote(entry, tasks);
        if (isNew)
            announce(entry);
        return true;
    }

    function finish(id, payload) {
        var index = _indexOf(String(id));
        if (index === -1)
            return false;

        var now = _now();
        var previous = tasks[index];
        var failed = payload && (payload.ok === false || payload.failed === true || payload.cancelled === true);
        var entry = {
            id: previous.id,
            glyph: payload && payload.glyph !== undefined ? String(payload.glyph) : previous.glyph,
            label: payload && payload.label !== undefined ? String(payload.label) : previous.label,
            detail: payload && payload.detail !== undefined ? String(payload.detail) : previous.detail,
            accent: payload && payload.accent !== undefined ? String(payload.accent) : previous.accent,
            // A cancelled task keeps whatever progress it reached; a finished
            // one closes the ring, because a build that succeeded at "94%" is
            // a drawing bug rather than a fact.
            fraction: failed ? Math.max(0, previous.fraction) : 1,
            state: failed ? "failed" : "done",
            startedAt: previous.startedAt,
            updatedAt: now,
            expiresAt: now + holdMs
        };

        _promote(entry, tasks);
        announce(entry);
        return true;
    }

    function remove(id) {
        var key = String(id);
        var next = [];
        for (var i = 0; i < tasks.length; i++) {
            if (tasks[i].id !== key)
                next.push(tasks[i]);
        }
        if (next.length === tasks.length)
            return false;
        tasks = next;
        _schedule();
        return true;
    }

    function clear() {
        tasks = [];
        _schedule();
        if (activities)
            activities.dismiss("live");
    }

    function snapshot() {
        return tasks.slice();
    }

    // Open the island for a moment. Only on the transitions worth
    // interrupting for — a task appearing, and a task ending — never on the
    // progress updates in between, which is what keeps a chatty script from
    // holding the island open for an hour.
    function announce(entry) {
        if (!activities || announceMs <= 0)
            return;
        activities.push("live", announcePriority, {
            task: entry,
            count: root.count
        }, announceMs);
    }

    property Timer reaper: Timer {
        repeat: false
        onTriggered: root._reap()
    }

    function _schedule() {
        var soonest = 0;
        for (var i = 0; i < tasks.length; i++) {
            var at = tasks[i].expiresAt;
            if (at > 0 && (soonest === 0 || at < soonest))
                soonest = at;
        }
        if (soonest === 0) {
            reaper.stop();
            return;
        }
        reaper.interval = Math.max(16, soonest - _now());
        reaper.restart();
    }

    function _reap() {
        var now = _now();
        var next = [];
        for (var i = 0; i < tasks.length; i++) {
            if (tasks[i].expiresAt <= 0 || tasks[i].expiresAt > now)
                next.push(tasks[i]);
        }
        if (next.length !== tasks.length)
            tasks = next;
        _schedule();
    }

    onEnabledChanged: if (!enabled)
        clear()
}
