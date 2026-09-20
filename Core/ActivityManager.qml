import QtQuick

// Decides what the island is currently showing.
//
// Several things can want the island at once — a notification arrives while a
// track is playing and you nudge the volume — so sources do not drive the
// island directly. They push an activity here, and this picks the winner.
//
// One activity per type. A second volume nudge replaces the first rather than
// queueing behind it, because nobody wants to sit through a backlog of stale
// volume levels. Notifications are the exception: a new one supersedes the
// visible one, but the card handles that as a content swap so the island does
// not collapse and re-open between two messages.
QtObject {
    id: root

    // Sorted best-first. Replaced wholesale rather than mutated, so QML
    // bindings on `current` actually re-evaluate.
    property var stack: []

    readonly property var current: stack.length > 0 ? stack[0] : null

    // While held, nothing expires. Used to freeze a notification's dismissal
    // countdown under the pointer.
    property bool paused: false

    signal expired(string type)

    function _now() {
        return Date.now();
    }

    function _sorted(list) {
        var next = list.slice();
        next.sort(function (a, b) {
            if (b.priority !== a.priority)
                return b.priority - a.priority;
            // Equal priority: most recent wins, so a second notification takes
            // the island from the first.
            return b.pushedAt - a.pushedAt;
        });
        return next;
    }

    // `duration` of 0 means sticky — it stays until something dismisses it.
    function push(type, priority, data, duration) {
        var entry = {
            type: String(type),
            priority: Number(priority) || 0,
            data: data,
            duration: Number(duration) || 0,
            pushedAt: _now(),
            remaining: Number(duration) || 0
        };
        entry.expiresAt = entry.duration > 0 && !root.paused ? entry.pushedAt + entry.duration : 0;

        var next = [];
        for (var i = 0; i < stack.length; i++) {
            if (stack[i].type !== entry.type)
                next.push(stack[i]);
        }
        next.push(entry);
        stack = _sorted(next);
        _schedule();
    }

    function dismiss(type) {
        var key = String(type);
        var next = [];
        var found = false;
        for (var i = 0; i < stack.length; i++) {
            if (stack[i].type === key)
                found = true;
            else
                next.push(stack[i]);
        }
        if (!found)
            return false;
        stack = next;
        _schedule();
        expired(key);
        return true;
    }

    function clear() {
        stack = [];
        _schedule();
    }

    function has(type) {
        var key = String(type);
        for (var i = 0; i < stack.length; i++)
            if (stack[i].type === key)
                return true;
        return false;
    }

    // Pausing banks each entry's remaining time; resuming spends it from now.
    // Without the banking step, a notification hovered for a minute would
    // vanish the instant the pointer left.
    onPausedChanged: {
        var now = _now();
        var next = [];
        for (var i = 0; i < stack.length; i++) {
            var e = stack[i];
            if (e.duration <= 0) {
                next.push(e);
                continue;
            }
            if (paused) {
                e.remaining = Math.max(0, e.expiresAt - now);
                e.expiresAt = 0;
            } else {
                e.expiresAt = now + Math.max(0, e.remaining);
            }
            next.push(e);
        }
        stack = next;
        _schedule();
    }

    function _schedule() {
        if (paused) {
            timer.stop();
            return;
        }
        var soonest = 0;
        for (var i = 0; i < stack.length; i++) {
            var at = stack[i].expiresAt;
            if (at > 0 && (soonest === 0 || at < soonest))
                soonest = at;
        }
        if (soonest === 0) {
            timer.stop();
            return;
        }
        // A single timer set to the next deadline, rather than one timer per
        // activity or a polling tick.
        timer.interval = Math.max(16, soonest - _now());
        timer.restart();
    }

    function _reap() {
        var now = _now();
        var next = [];
        var dropped = [];
        for (var i = 0; i < stack.length; i++) {
            var e = stack[i];
            if (e.expiresAt > 0 && e.expiresAt <= now)
                dropped.push(e.type);
            else
                next.push(e);
        }
        if (dropped.length > 0) {
            stack = next;
            for (var d = 0; d < dropped.length; d++)
                expired(dropped[d]);
        }
        _schedule();
    }

    property Timer timer: Timer {
        repeat: false
        onTriggered: root._reap()
    }
}
