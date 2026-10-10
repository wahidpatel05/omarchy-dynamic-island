import QtQuick
import Quickshell
import Quickshell.Io

// The paired phone, through KDE Connect.
//
// Read with one small shell pass over kdeconnect-cli and the daemon's D-Bus
// properties rather than a binding to the bus: Quickshell has no generic
// D-Bus client, and the numbers here change on the scale of minutes. It runs
// only while something is looking (`active`), so a closed sheet costs nothing.
//
// Absent kdeconnect, or with nothing paired, `present` stays false and the
// sheet simply leaves the phone out.
Item {
    id: root

    property bool active: false

    property bool present: false
    property bool reachable: false
    property string deviceId: ""
    property string name: ""
    property int battery: -1
    property bool charging: false
    property string network: ""
    property int signal: -1
    property bool mounted: false

    readonly property string script: "command -v kdeconnect-cli >/dev/null || exit 0\n"
        + "line=$(kdeconnect-cli -l --id-only 2>/dev/null | head -n1)\n"
        + "[ -z \"$line\" ] && line=$(kdeconnect-cli -a --id-only 2>/dev/null | head -n1)\n"
        + "[ -z \"$line\" ] && exit 0\n"
        + "d=/modules/kdeconnect/devices/$line\n"
        + "p() { busctl --user get-property org.kde.kdeconnect \"$d$1\" \"org.kde.kdeconnect.device$2\" \"$3\" 2>/dev/null | cut -d' ' -f2-; }\n"
        + "echo \"id=$line\"\n"
        + "echo \"name=$(p '' '' name)\"\n"
        + "echo \"reachable=$(p '' '' isReachable)\"\n"
        + "echo \"battery=$(p /battery .battery charge)\"\n"
        + "echo \"charging=$(p /battery .battery isCharging)\"\n"
        + "echo \"network=$(p /connectivity_report .connectivity_report cellularNetworkType)\"\n"
        + "echo \"signal=$(p /connectivity_report .connectivity_report cellularNetworkStrength)\"\n"
        + "echo \"mounted=$(busctl --user call org.kde.kdeconnect \"$d/sftp\" org.kde.kdeconnect.device.sftp isMounted 2>/dev/null | cut -d' ' -f2-)\"\n"

    function refresh() {
        if (!probe.running)
            probe.running = true;
    }

    Timer {
        interval: 20000
        repeat: true
        running: root.active
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Process {
        id: probe
        command: ["sh", "-c", root.script]
        stdout: StdioCollector {
            onStreamFinished: {
                var out = ({});
                String(text).split("\n").forEach(function (l) {
                    var at = l.indexOf("=");
                    if (at > 0)
                        out[l.slice(0, at)] = l.slice(at + 1).replace(/^"|"$/g, "").trim();
                });
                root.present = !!out.id;
                root.deviceId = out.id || "";
                root.name = out.name || "Phone";
                root.reachable = out.reachable === "true";
                var b = parseInt(out.battery, 10);
                root.battery = isFinite(b) ? b : -1;
                root.charging = out.charging === "true";
                root.network = out.network || "";
                var s = parseInt(out.signal, 10);
                root.signal = isFinite(s) ? s : -1;
                root.mounted = out.mounted === "true";
            }
        }
    }

    // ------------------------------------------------------------ actions

    function cli(args) {
        if (!deviceId)
            return;
        Quickshell.execDetached(["kdeconnect-cli", "-d", deviceId].concat(args));
    }

    function ring() {
        cli(["--ring"]);
    }

    function sendClipboard() {
        cli(["--send-clipboard"]);
    }

    function ping() {
        cli(["--ping"]);
    }

    // Mount over sshfs, then open the mount point in the file manager. The
    // two-step is what KDE Connect itself does; mounting is a no-op when the
    // phone is already mounted.
    function browse() {
        if (!deviceId)
            return;
        Quickshell.execDetached(["sh", "-c", "kdeconnect-cli -d \"$1\" --mount && sleep 1 && xdg-open \"$(kdeconnect-cli -d \"$1\" --get-mount-point)\"", "sh", deviceId]);
        refreshSoon.restart();
    }

    Timer {
        id: refreshSoon
        interval: 2500
        onTriggered: root.refresh()
    }
}
