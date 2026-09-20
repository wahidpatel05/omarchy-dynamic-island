import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import "../Core/Config.js" as Config

// Feeds notifications into the island.
//
// Only one process on the session can own org.freedesktop.Notifications. So
// rather than competing with Omarchy for the bus, this mirrors the shell's own
// notification service: the island reads the same popup model that drives the
// corner toasts, which means history, do-not-disturb, and the notification
// panel all keep working untouched.
//
// If the user turns Omarchy's notification plugin off — the supported way to
// get island-only notifications, with no corner toast alongside — the bus is
// free and the island stands up its own server instead.
Item {
    id: root

    property var shell: null
    property var config: null
    property var activities: null

    readonly property var options: Config.activityOptions(config, "notification")
    readonly property bool enabled: options.enabled === true

    // "omarchy" mirrors the shell's notification service and never touches the
    // bus. "own" binds org.freedesktop.Notifications directly, which is only
    // correct once Omarchy's own notification plugin has been disabled.
    //
    // There is deliberately no auto-detect. The shell mounts plugin services
    // several seconds after it mounts the bar, so at startup Omarchy's service
    // is indistinguishable from an absent one — and a wrong guess means two
    // servers racing for the bus on every login, which is exactly as bad as it
    // sounds: notifications land in whichever won, and the loser retries
    // forever. Choosing is cheap; guessing wrong is not.
    readonly property string source: String(options.source || "omarchy")

    readonly property var omarchyService: shell && typeof shell.serviceFor === "function" ? shell.serviceFor("omarchy.notifications") : null
    readonly property var popupModel: omarchyService && omarchyService.popupModel ? omarchyService.popupModel : null

    readonly property bool owningServer: enabled && source === "own"

    // Matches Omarchy's own durations so a notification does not linger longer
    // in the island than it would have in the corner.
    function durationFor(urgency, expireTimeout) {
        if (urgency === NotificationUrgency.Critical)
            return 0;
        if (omarchyService && typeof omarchyService.durationFor === "function")
            return omarchyService.durationFor(urgency, expireTimeout);
        var requested = Number(expireTimeout || 0);
        var floor = urgency === NotificationUrgency.Low ? 5000 : 8000;
        return Math.min(30000, Math.max(floor, requested > 0 ? requested : 0));
    }

    // A short in-memory tail of what has come through, for the control
    // centre's recent list. Deliberately not persisted: Omarchy already owns
    // notification history on disk, and a second, divergent copy of it is
    // worse than none.
    property var recent: []
    readonly property int recentLimit: 5

    // ------------------------------------------------------------ residue
    //
    // What a notification leaves behind when it times out unread: a dot on
    // the resting pill, until you look.
    //
    // The distinction that makes this worth having is between a notification
    // you *dismissed* and one that merely *expired*. Clicking the island
    // means "got it" and leaves nothing; walking away while it counted down
    // leaves the dot. Without that, the dot would either never appear or
    // never go away.

    readonly property bool residueEnabled: options.residue !== false

    property bool residue: false
    // Kept so the dot can carry the weight of what is waiting — a critical
    // notification is worth a different colour from a chat message.
    property int residueUrgency: 0

    function clearResidue() {
        residue = false;
    }

    Connections {
        target: root.activities
        enabled: root.activities !== null

        function onExpired(type, byUser) {
            if (type !== "notification")
                return;
            if (byUser || !root.residueEnabled) {
                root.clearResidue();
                return;
            }
            root.residue = true;
        }
    }

    function present(data, urgency, expireTimeout) {
        if (!enabled || !activities)
            return;

        // A fresh notification supersedes whatever the last one left behind;
        // the dot it raises on its own way out is the one that matters.
        residue = false;
        residueUrgency = Number(urgency) || 0;

        var next = recent.slice();
        next.unshift(data);
        while (next.length > recentLimit)
            next.pop();
        recent = next;

        activities.push("notification", 50, data, durationFor(urgency, expireTimeout));
    }

    // ----------------------------------------------------- mirroring path
    //
    // The model is watched through `count` rather than `rowsInserted`: both are
    // emitted, but a ListModel reached across a plugin boundary only reliably
    // delivers its declared QML properties, and `count` is one.
    //
    // What the count cannot do is tell us *what* changed. Omarchy inserts live
    // notifications at index 0 and removes them as they expire, so the count
    // can fall and rise back to where it started between two ticks — and a
    // "has the count grown?" test silently drops the notification that lands in
    // the same slot an expiring one just vacated. So identity is tracked
    // instead: each row is keyed, recently-seen keys are remembered, and the
    // row at index 0 is presented only if its key is genuinely new.

    property var seenKeys: []

    function keyFor(row) {
        if (!row)
            return "";
        var id = row.originalId !== undefined ? row.originalId : (row.id !== undefined ? row.id : "");
        return String(id) + ":" + String(row.timestamp || 0);
    }

    function remember(key) {
        if (!key || seenKeys.indexOf(key) !== -1)
            return;
        var next = seenKeys.slice();
        next.push(key);
        // Bounded: this only needs to cover the handful of notifications that
        // could plausibly still be in the popup model.
        while (next.length > 32)
            next.shift();
        seenKeys = next;
    }

    function scan() {
        if (!popupModel || popupModel.count === 0)
            return;

        var row = popupModel.get(0);
        if (!row)
            return;

        var key = keyFor(row);
        if (key === "" || seenKeys.indexOf(key) !== -1)
            return;
        remember(key);

        // Replayed history rather than a live notification. Opening the
        // notification panel refills this same model with old rows.
        var stamp = Number(row.timestamp || 0);
        if (stamp && Date.now() - stamp > 5000)
            return;
        // The panel's "nothing here" placeholder is a row like any other.
        if (!row.app && row.summary === "No recent notifications")
            return;

        root.present({
            app: row.app || "",
            appIcon: row.appIcon || "",
            summary: row.summary || "",
            body: row.body || "",
            image: row.image || "",
            glyph: row.glyph || "",
            urgency: row.urgency
        }, row.urgency, row.expireTimeout);
    }

    // Adopt whatever is already in the model when it first appears, so a
    // backlog sitting there at startup is not replayed into the island.
    onPopupModelChanged: {
        seenKeys = [];
        if (!popupModel)
            return;
        for (var i = 0; i < popupModel.count; i++)
            remember(keyFor(popupModel.get(i)));
    }

    Connections {
        target: root.enabled ? root.popupModel : null
        ignoreUnknownSignals: true

        function onCountChanged() {
            root.scan();
        }
    }

    // -------------------------------------------------- own-the-bus path

    Loader {
        active: root.owningServer
        sourceComponent: serverComponent
    }

    Component {
        id: serverComponent

        NotificationServer {
            keepOnReload: false
            imageSupported: true
            actionsSupported: true
            bodyMarkupSupported: true
            bodyHyperlinksSupported: true
            persistenceSupported: true

            onNotification: function (notification) {
                // Without this the object is destroyed the moment this handler
                // returns, taking the strings with it.
                notification.tracked = true;
                root.present({
                    app: notification.appName || "",
                    appIcon: notification.appIcon || "",
                    summary: String(notification.summary || ""),
                    body: notification.body || "",
                    image: notification.image || "",
                    glyph: "",
                    urgency: notification.urgency
                }, notification.urgency, notification.expireTimeout);
            }
        }
    }
}
