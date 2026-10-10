import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Bluetooth
import Quickshell.Services.UPower
import Quickshell.Services.Pipewire
import qs.Commons
import "../Core"

// The control sheet: what the right-hand capsule used to hold, one click away.
//
// It hangs *below* the island as a surface of its own rather than growing the
// island into a panel, the same way the launcher's results do. The island
// stays a small pill showing the time and three status dots; this is where
// the detail lives.
//
// Four pages. The main one has the now-playing row, six tiles (Wi-Fi,
// Bluetooth, focus, phone, next prayer, battery), volume and brightness, the
// notification list, and this week. Wi-Fi, Bluetooth and the phone each open
// a page of their own; a secured network asks for its password inline, which
// is the only time the sheet takes the keyboard.
Item {
    id: root

    property var host: null
    property var config: null
    property color foreground: "white"
    property color accent: "white"
    // True while the sheet is on screen, so the Wi-Fi scanner only runs then.
    property bool open: false

    readonly property color muted: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.55)
    readonly property color faint: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.06)
    readonly property color accentWash: Qt.rgba(accent.r, accent.g, accent.b, 0.15)

    readonly property int pad: Style.space(12)
    readonly property int sheetWidth: Style.space(372)
    readonly property int rowH: Style.space(38)
    readonly property int listRows: 6
    readonly property int morphMs: 420
    readonly property var ease: [0.45, 0, 0.2, 1, 1, 1]

    property string page: "main"
    property string pskFor: ""
    // The island window hands the layer keyboard focus only while this is true.
    readonly property bool wantsKeyboard: root.open && root.pskFor !== ""

    onOpenChanged: if (!open) {
        page = "main";
        pskFor = "";
    }

    Connections {
        target: root.host
        ignoreUnknownSignals: true
        function onSheetRequestSerialChanged() {
            if (root.host.sheetRequest !== root.page)
                root.go(root.host.sheetRequest);
        }
    }

    implicitWidth: sheetWidth
    implicitHeight: (page === "main" ? mainPage.implicitHeight : page === "wifi" ? wifiPage.implicitHeight : page === "phone" ? phonePage.implicitHeight : btPage.implicitHeight) + pad * 2

    function go(next) {
        pskFor = "";
        slideX.from = next === "main" ? -10 : 10;
        page = next;
        pageAnim.restart();
    }

    component Morph: NumberAnimation {
        duration: root.morphMs
        easing.type: Easing.BezierSpline
        easing.bezierCurve: root.ease
    }

    // ---------------------------------------------------------------- data

    property date now: new Date()
    Timer {
        interval: 30000
        running: root.open
        repeat: true
        triggeredOnStart: true
        onTriggered: root.now = new Date()
    }

    readonly property var media: host ? host.mediaSource : null
    readonly property var brightness: host ? host.brightnessSource : null
    readonly property var notes: host ? host.notificationSource : null
    readonly property var phone: host ? host.phoneSource : null

    // ------------------------------------------------------------ focus

    readonly property bool focused: notes !== null && notes.focused === true

    // Which of the duration chips the current focus matches.
    readonly property string focusChoice: {
        if (!focused)
            return "";
        if (notes.focusUntil === -1)
            return "off";
        if (nextPrayer && Math.abs(notes.focusUntil - nextPrayer.date.getTime()) < 60000)
            return "prayer";
        return "hour";
    }
    function focusDetail() {
        if (!focused)
            return "Off";
        if (focusChoice === "off")
            return "Until turned off";
        if (focusChoice === "prayer")
            return "Until " + nextPrayer.name;
        return "Until " + Qt.formatTime(new Date(notes.focusUntil), "HH:mm");
    }

    function ago(ms) {
        var mins = Math.max(0, Math.round((root.now - ms) / 60000));
        if (mins < 1)
            return "now";
        if (mins < 60)
            return mins + "m";
        var h = Math.floor(mins / 60);
        return h < 24 ? h + "h" : Math.floor(h / 24) + "d";
    }

    // ------------------------------------------------------------ phone

    function phoneDetail() {
        if (!phone || !phone.present)
            return "Not paired";
        if (!phone.reachable)
            return "Not reachable";
        var bits = [];
        if (phone.battery >= 0)
            bits.push(phone.battery + "%" + (phone.charging ? " 󱐋" : ""));
        if (phone.network)
            bits.push(phone.network);
        return bits.length ? bits.join("  ·  ") : "Connected";
    }

    readonly property var netDevices: Networking.devices ? Networking.devices.values : []
    readonly property var wired: {
        for (var i = 0; i < netDevices.length; i++)
            if (netDevices[i].type === DeviceType.Wired && netDevices[i].connected)
                return netDevices[i];
        return null;
    }
    readonly property var wifi: {
        var first = null;
        for (var i = 0; i < netDevices.length; i++) {
            if (netDevices[i].type !== DeviceType.Wifi)
                continue;
            if (netDevices[i].connected)
                return netDevices[i];
            if (!first)
                first = netDevices[i];
        }
        return first;
    }
    readonly property var networks: wifi && wifi.networks ? wifi.networks.values : []
    readonly property var activeNet: {
        for (var i = 0; i < networks.length; i++)
            if (networks[i].connected)
                return networks[i];
        return null;
    }
    readonly property bool wifiOn: Networking.wifiEnabled !== false

    // Scan only while the list is actually being looked at.
    Binding {
        target: root.wifi
        property: "scannerEnabled"
        value: root.open && root.page === "wifi"
        when: root.wifi !== null
    }

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool btOn: adapter !== null && adapter !== undefined && adapter.enabled === true
    readonly property var btDevices: {
        if (!Bluetooth.devices)
            return [];
        var list = Bluetooth.devices.values.filter(function (d) {
            return d.paired || d.bonded || d.connected;
        });
        list.sort(function (a, b) {
            return (b.connected ? 1 : 0) - (a.connected ? 1 : 0) || String(a.name).localeCompare(String(b.name));
        });
        return list;
    }
    readonly property var btConnected: {
        for (var i = 0; i < btDevices.length; i++)
            if (btDevices[i].connected)
                return btDevices[i];
        return null;
    }

    readonly property var battery: UPower.displayDevice
    readonly property bool hasBattery: battery !== null && battery.isLaptopBattery === true
    readonly property int batteryPct: hasBattery ? Math.round(battery.percentage * 100) : 0
    readonly property bool charging: hasBattery && battery.state === UPowerDeviceState.Charging

    function batteryGlyph() {
        if (!hasBattery)
            return "󰚥";
        if (charging)
            return "󰂄";
        var steps = ["󰂎", "󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"];
        return steps[Math.max(0, Math.min(10, Math.round(batteryPct / 10)))];
    }
    function batteryDetail() {
        if (!hasBattery)
            return "AC power";
        var secs = charging ? battery.timeToFull : battery.timeToEmpty;
        var span = "";
        if (secs > 0) {
            var h = Math.floor(secs / 3600), m = Math.round((secs % 3600) / 60);
            span = (h > 0 ? h + "h " : "") + m + "m " + (charging ? "to full" : "left");
        }
        return span || (charging ? "Charging" : "On battery");
    }
    readonly property var profileNames: ["Saver", "Balanced", "Performance"]
    function cycleProfile() {
        var order = [PowerProfile.PowerSaver, PowerProfile.Balanced];
        if (PowerProfiles.hasPerformanceProfile)
            order.push(PowerProfile.Performance);
        var at = order.indexOf(PowerProfiles.profile);
        PowerProfiles.profile = order[(at + 1) % order.length];
    }

    // Next prayer, from the cache the prayer-times widget keeps fresh.
    property var timings: null
    FileView {
        path: Quickshell.env("HOME") + "/.local/state/omarchy/settings/prayer-times.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                var data = JSON.parse(text());
                root.timings = data && data.timings ? data.timings : null;
            } catch (e) {
                root.timings = null;
            }
        }
    }
    readonly property var nextPrayer: {
        if (!timings)
            return null;
        var n = root.now;
        var names = ["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"];
        function at(hhmm, day) {
            var p = String(hhmm || "").split(":");
            return new Date(n.getFullYear(), n.getMonth(), n.getDate() + day, parseInt(p[0], 10), parseInt(p[1], 10));
        }
        for (var i = 0; i < names.length; i++) {
            var t = at(timings[names[i]], 0);
            if (t > n)
                return { name: names[i], time: timings[names[i]], date: t };
        }
        return { name: "Fajr", time: timings.Fajr, date: at(timings.Fajr, 1) };
    }
    function prayerIn() {
        if (!nextPrayer)
            return "";
        var mins = Math.max(0, Math.round((nextPrayer.date - root.now) / 60000));
        var h = Math.floor(mins / 60);
        return "in " + (h > 0 ? h + "h " : "") + (mins % 60) + "m";
    }

    // ------------------------------------------------------------ chrome

    Rectangle {
        anchors.fill: parent
        radius: Style.space(18)
        color: host ? Qt.rgba(host.islandBackground.r, host.islandBackground.g, host.islandBackground.b, 0.97) : Qt.rgba(0.02, 0.02, 0.03, 0.97)
        border.color: Qt.rgba(1, 1, 1, 0.07)
        border.width: 1
    }

    // Eat clicks on the sheet background so they never reach the desktop.
    MouseArea {
        anchors.fill: parent
    }

    Item {
        id: pages
        x: root.pad
        y: root.pad
        width: root.sheetWidth - root.pad * 2
        height: root.height - root.pad * 2
        clip: true
        transform: Translate {
            id: slide
        }

        ParallelAnimation {
            id: pageAnim
            NumberAnimation {
                target: pages
                property: "opacity"
                from: 0
                to: 1
                duration: 260
                easing.type: Easing.InOutQuad
            }
            Morph {
                id: slideX
                target: slide
                property: "x"
                to: 0
            }
        }

        // ------------------------------------------------------- main

        Column {
            id: mainPage
            width: parent.width
            spacing: Style.space(10)
            visible: root.page === "main"

            // Now playing.
            Item {
                width: parent.width
                visible: root.media !== null && root.media.hasMedia
                height: visible ? Style.space(44) : 0

                AlbumArt {
                    id: art
                    width: Style.space(40)
                    height: width
                    anchors.verticalCenter: parent.verticalCenter
                    source: root.media ? root.media.artUrl : ""
                    foreground: root.foreground
                    accent: root.accent
                }
                Column {
                    anchors.left: art.right
                    anchors.leftMargin: Style.space(10)
                    anchors.right: controls.left
                    anchors.rightMargin: Style.space(8)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1
                    Text {
                        width: parent.width
                        text: root.media ? root.media.title : ""
                        color: root.foreground
                        font.family: Style.font.family
                        font.pixelSize: Style.font.body
                        elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        text: root.media ? root.media.artist : ""
                        color: root.muted
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                        elide: Text.ElideRight
                    }
                }
                Row {
                    id: controls
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Style.space(4)
                    Repeater {
                        model: [
                            { glyph: "󰒮", act: "previous" },
                            { glyph: root.media && root.media.playing ? "󰏤" : "󰐊", act: "toggle" },
                            { glyph: "󰒭", act: "next" }
                        ]
                        IconButton {
                            required property var modelData
                            glyph: modelData.glyph
                            onClicked: {
                                var p = root.media ? root.media.player : null;
                                if (!p)
                                    return;
                                if (modelData.act === "previous")
                                    p.previous();
                                else if (modelData.act === "next")
                                    p.next();
                                else
                                    p.togglePlaying();
                            }
                        }
                    }
                }
            }

            Grid {
                width: parent.width
                columns: 2
                spacing: Style.space(8)
                readonly property real cell: (width - spacing) / 2

                Tile {
                    width: parent.cell
                    active: root.wired !== null || root.activeNet !== null
                    glyph: root.wired ? "󰈀" : !root.wifiOn ? "󰤮" : root.activeNet ? "󰤨" : "󰤯"
                    title: root.wired ? "Ethernet" : "Wi-Fi"
                    detail: root.wired ? "Connected" : !root.wifiOn ? "Off" : root.activeNet ? String(root.activeNet.name) : "Not connected"
                    chevron: true
                    onGlyphClicked: Networking.wifiEnabled = !root.wifiOn
                    onBodyClicked: root.go("wifi")
                }
                Tile {
                    width: parent.cell
                    active: root.btOn
                    glyph: !root.btOn ? "󰂲" : root.btConnected ? "󰂱" : "󰂯"
                    title: "Bluetooth"
                    detail: !root.adapter ? "No adapter" : !root.btOn ? "Off" : root.btConnected ? String(root.btConnected.name) : "On"
                    chevron: true
                    onGlyphClicked: if (root.adapter) root.adapter.enabled = !root.btOn
                    onBodyClicked: root.go("bt")
                }
                Tile {
                    width: parent.cell
                    active: root.focused
                    glyph: "󰽥"
                    title: "Focus"
                    detail: root.focusDetail()
                    onGlyphClicked: if (root.notes) root.notes.toggleFocus()
                    onBodyClicked: if (root.notes) root.notes.toggleFocus()
                }
                Tile {
                    width: parent.cell
                    active: root.phone !== null && root.phone.reachable
                    glyph: "󰄜"
                    title: root.phone && root.phone.present ? root.phone.name : "Phone"
                    detail: root.phoneDetail()
                    chevron: root.phone !== null && root.phone.present
                    onGlyphClicked: if (root.phone && root.phone.present) root.go("phone")
                    onBodyClicked: if (root.phone && root.phone.present) root.go("phone")
                }
                Tile {
                    width: parent.cell
                    active: false
                    glyph: ""
                    title: root.nextPrayer ? root.nextPrayer.name + "  " + root.nextPrayer.time : "Prayer times"
                    detail: root.nextPrayer ? root.prayerIn() : "Not fetched yet"
                }
                Tile {
                    width: parent.cell
                    active: root.charging
                    glyph: root.batteryGlyph()
                    glyphColor: !root.hasBattery || root.charging ? "" : root.batteryPct < 15 ? "#f38ba8" : root.batteryPct < 30 ? "#f9e2af" : "#a6e3a1"
                    title: root.hasBattery ? root.batteryPct + "%  ·  " + root.profileNames[PowerProfiles.profile] : root.profileNames[PowerProfiles.profile]
                    detail: root.batteryDetail()
                    onGlyphClicked: root.cycleProfile()
                    onBodyClicked: root.cycleProfile()
                }
            }

            // How long focus lasts. Only there while it is on.
            Row {
                id: chips
                width: parent.width
                spacing: Style.space(6)
                visible: root.focused
                readonly property real cell: (width - spacing * 2) / 3

                Repeater {
                    model: [
                        { key: "off", label: "Until off" },
                        { key: "hour", label: "1 hour" },
                        { key: "prayer", label: root.nextPrayer ? "Until " + root.nextPrayer.name : "" }
                    ]
                    Rectangle {
                        id: chip
                        required property var modelData
                        readonly property bool selected: root.focusChoice === modelData.key
                        width: chips.cell
                        height: Style.space(26)
                        radius: height / 2
                        visible: modelData.label !== ""
                        color: selected ? root.accentWash : (chipArea.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : root.faint)
                        Behavior on color {
                            ColorAnimation {
                                duration: 220
                            }
                        }
                        Text {
                            anchors.centerIn: parent
                            text: chip.modelData.label
                            color: chip.selected ? root.accent : root.muted
                            font.family: Style.font.family
                            font.pixelSize: Style.font.caption
                        }
                        MouseArea {
                            id: chipArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                var k = chip.modelData.key;
                                root.notes.setFocus(k === "off" ? -1 : k === "hour" ? Date.now() + 3600000 : root.nextPrayer.date.getTime());
                            }
                        }
                    }
                }
            }

            PwObjectTracker {
                objects: Pipewire.defaultAudioSink ? [Pipewire.defaultAudioSink] : []
            }

            Slider {
                width: parent.width
                foreground: root.foreground
                accent: root.accent
                glyph: {
                    var sink = Pipewire.defaultAudioSink;
                    if (!sink || !sink.audio || sink.audio.muted || sink.audio.volume <= 0)
                        return "󰝟";
                    return sink.audio.volume < 0.34 ? "󰕿" : sink.audio.volume < 0.67 ? "󰖀" : "󰕾";
                }
                value: Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio ? Pipewire.defaultAudioSink.audio.volume : 0
                onMoved: function (v) {
                    var sink = Pipewire.defaultAudioSink;
                    if (sink && sink.audio)
                        sink.audio.volume = Math.max(0, Math.min(1, v));
                }
            }

            Slider {
                width: parent.width
                visible: root.brightness ? root.brightness.available : false
                height: visible ? implicitHeight : 0
                foreground: root.foreground
                accent: root.accent
                glyph: "󰃠"
                value: root.brightness ? Math.max(0, root.brightness.value) : 0
                onMoved: function (v) {
                    if (root.brightness)
                        root.brightness.set(v);
                }
            }

            // Notifications the island has kept. Only with its own server;
            // when mirroring, Omarchy's panel holds the history.
            Column {
                width: parent.width
                spacing: Style.space(6)
                visible: root.notes !== null && root.notes.keepsHistory

                Item {
                    width: parent.width
                    height: Style.space(18)
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.focused ? "Notifications  ·  held quietly" : "Notifications"
                        color: root.muted
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                    }
                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        visible: noteList.count > 0
                        text: "Clear"
                        color: clearArea.containsMouse ? root.foreground : root.muted
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                        MouseArea {
                            id: clearArea
                            anchors.fill: parent
                            anchors.margins: -Style.space(4)
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.notes.clearHistory()
                        }
                    }
                }

                ListView {
                    id: noteList
                    readonly property int noteH: Style.space(46)
                    readonly property int shownRows: 4
                    width: parent.width
                    height: count === 0 ? Style.space(28) : Math.min(count, shownRows) * (noteH + spacing) - spacing
                    spacing: Style.space(5)
                    clip: true
                    interactive: count > shownRows
                    boundsBehavior: Flickable.StopAtBounds
                    model: root.notes ? root.notes.history : []

                    delegate: Rectangle {
                        id: note
                        required property var modelData
                        width: noteList.width
                        height: noteList.noteH
                        radius: Style.space(11)
                        color: noteArea.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : root.faint
                        Behavior on color {
                            ColorAnimation {
                                duration: 220
                            }
                        }

                        MouseArea {
                            id: noteArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.notes.dismiss(note.modelData.id)
                        }

                        Rectangle {
                            id: noteIcon
                            x: Style.space(8)
                            anchors.verticalCenter: parent.verticalCenter
                            width: Style.space(28)
                            height: width
                            radius: Style.space(8)
                            color: note.modelData.urgency === 2 ? Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.25) : Qt.rgba(1, 1, 1, 0.06)
                            Image {
                                id: noteImg
                                anchors.centerIn: parent
                                width: Style.space(18)
                                height: width
                                sourceSize.width: width * 2
                                sourceSize.height: height * 2
                                asynchronous: true
                                visible: status === Image.Ready
                                source: {
                                    var icon = String(note.modelData.appIcon || "");
                                    if (icon === "")
                                        return "";
                                    if (icon.indexOf("/") === 0)
                                        return "file://" + icon;
                                    if (icon.indexOf("://") > 0)
                                        return icon;
                                    return Quickshell.iconPath(icon, true);
                                }
                            }
                            Text {
                                anchors.centerIn: parent
                                visible: !noteImg.visible
                                text: note.modelData.glyph || "󰂚"
                                color: root.foreground
                                font.family: Style.font.family
                                font.pixelSize: Style.font.icon
                            }
                        }

                        Column {
                            anchors.left: noteIcon.right
                            anchors.leftMargin: Style.space(8)
                            anchors.right: noteTime.left
                            anchors.rightMargin: Style.space(6)
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 1
                            Text {
                                width: parent.width
                                text: (note.modelData.app ? note.modelData.app + "  ·  " : "") + note.modelData.summary
                                color: root.foreground
                                font.family: Style.font.family
                                font.pixelSize: Style.font.bodySmall
                                elide: Text.ElideRight
                            }
                            Text {
                                width: parent.width
                                visible: text !== ""
                                text: String(note.modelData.body || "").replace(/\s+/g, " ")
                                color: root.muted
                                font.family: Style.font.family
                                font.pixelSize: Style.font.caption
                                elide: Text.ElideRight
                            }
                        }

                        Text {
                            id: noteTime
                            anchors.right: parent.right
                            anchors.rightMargin: Style.space(10)
                            anchors.top: parent.top
                            anchors.topMargin: Style.space(8)
                            text: root.ago(note.modelData.time)
                            color: root.muted
                            font.family: Style.font.family
                            font.pixelSize: Style.font.caption
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: noteList.count === 0
                        text: "All caught up"
                        color: root.muted
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                    }
                }
            }

            // This week.
            Column {
                width: parent.width
                spacing: Style.space(6)

                Text {
                    text: Qt.formatDate(root.now, "dddd, d MMMM")
                    color: root.muted
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                }
                Row {
                    id: week
                    width: parent.width
                    readonly property real cell: width / 7
                    // Monday-first, like Omarchy's calendar.
                    readonly property date monday: {
                        var d = new Date(root.now.getFullYear(), root.now.getMonth(), root.now.getDate());
                        d.setDate(d.getDate() - ((d.getDay() + 6) % 7));
                        return d;
                    }
                    Repeater {
                        model: 7
                        Rectangle {
                            required property int index
                            readonly property date day: new Date(week.monday.getFullYear(), week.monday.getMonth(), week.monday.getDate() + index)
                            readonly property bool today: day.toDateString() === root.now.toDateString()
                            width: week.cell
                            height: Style.space(34)
                            radius: Style.space(8)
                            color: today ? root.accent : "transparent"
                            Column {
                                anchors.centerIn: parent
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: Qt.formatDate(parent.parent.day, "ddd").slice(0, 2)
                                    color: parent.parent.today ? Color.background : root.muted
                                    font.family: Style.font.family
                                    font.pixelSize: Style.font.caption
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: parent.parent.day.getDate()
                                    color: parent.parent.today ? Color.background : root.foreground
                                    font.family: Style.font.family
                                    font.pixelSize: Style.font.body
                                    font.weight: parent.parent.today ? Font.DemiBold : Font.Normal
                                }
                            }
                        }
                    }
                }
            }
        }

        // ------------------------------------------------------- wifi

        Column {
            id: wifiPage
            width: parent.width
            spacing: Style.space(8)
            visible: root.page === "wifi"

            PageHeader {
                title: "Wi-Fi"
                on: root.wifiOn
                onToggled: Networking.wifiEnabled = !root.wifiOn
            }

            ListView {
                id: netList
                width: parent.width
                height: Math.max(root.rowH, Math.min(count, root.listRows) * root.rowH + (root.pskFor !== "" ? root.rowH : 0))
                clip: true
                interactive: count > root.listRows
                boundsBehavior: Flickable.StopAtBounds
                model: {
                    var seen = ({});
                    var list = root.networks.filter(function (n) {
                        var name = String(n.name || "");
                        if (!name || seen[name])
                            return false;
                        seen[name] = true;
                        return true;
                    });
                    list.sort(function (a, b) {
                        return (b.connected - a.connected) || (b.known - a.known) || (b.signalStrength - a.signalStrength);
                    });
                    return root.wifiOn ? list : [];
                }

                delegate: Column {
                    id: netRow
                    required property var modelData
                    readonly property bool secured: modelData.security !== WifiSecurityType.Open && modelData.security !== WifiSecurityType.Owe
                    readonly property bool asking: root.pskFor === String(modelData.name)
                    width: netList.width

                    ListRow {
                        width: parent.width
                        glyph: ["󰤯", "󰤟", "󰤢", "󰤥", "󰤨"][Math.max(0, Math.min(4, Math.ceil(netRow.modelData.signalStrength * 5) - 1))]
                        label: String(netRow.modelData.name)
                        hint: netRow.modelData.connected ? "connected" : netRow.modelData.stateChanging ? "…" : netRow.modelData.known ? "saved" : netRow.secured ? "󰌾" : ""
                        current: netRow.modelData.connected
                        onClicked: {
                            var n = netRow.modelData;
                            if (n.connected)
                                return;
                            if (n.known || !netRow.secured) {
                                root.pskFor = "";
                                n.connect();
                            } else {
                                root.pskFor = root.pskFor === String(n.name) ? "" : String(n.name);
                            }
                        }
                    }

                    // Password, inline under the network that asked for it.
                    Rectangle {
                        width: parent.width
                        height: netRow.asking ? root.rowH - Style.space(4) : 0
                        visible: height > 0
                        radius: Style.space(9)
                        color: root.faint
                        border.color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.4)
                        border.width: 1
                        TextInput {
                            id: psk
                            anchors.fill: parent
                            anchors.leftMargin: Style.space(12)
                            anchors.rightMargin: Style.space(12)
                            verticalAlignment: TextInput.AlignVCenter
                            echoMode: TextInput.Password
                            color: root.foreground
                            font.family: Style.font.family
                            font.pixelSize: Style.font.body
                            onVisibleChanged: if (visible) {
                                text = "";
                                forceActiveFocus();
                            }
                            Keys.onReturnPressed: {
                                netRow.modelData.connectWithPsk(text);
                                root.pskFor = "";
                            }
                            Keys.onEscapePressed: root.pskFor = ""
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: psk.text.length === 0
                                text: "Password, then Enter"
                                color: root.muted
                                font: psk.font
                            }
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: netList.count === 0
                    text: root.wifiOn ? "Scanning…" : "Wi-Fi is off"
                    color: root.muted
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                }
            }
        }

        // ------------------------------------------------------- bluetooth

        Column {
            id: btPage
            width: parent.width
            spacing: Style.space(8)
            visible: root.page === "bt"

            PageHeader {
                title: "Bluetooth"
                on: root.btOn
                onToggled: if (root.adapter) root.adapter.enabled = !root.btOn
            }

            ListView {
                id: btList
                width: parent.width
                height: Math.max(root.rowH, Math.min(count, root.listRows) * root.rowH)
                clip: true
                interactive: count > root.listRows
                boundsBehavior: Flickable.StopAtBounds
                model: root.btOn ? root.btDevices : []

                delegate: ListRow {
                    required property var modelData
                    width: btList.width
                    glyph: String(modelData.icon).indexOf("audio") >= 0 ? "󰋋" : String(modelData.icon).indexOf("input") >= 0 ? "󰌌" : String(modelData.icon).indexOf("phone") >= 0 ? "󰏲" : "󰂯"
                    label: String(modelData.name || modelData.address)
                    hint: modelData.connected ? (modelData.batteryAvailable ? Math.round(modelData.battery * 100) + "%  connected" : "connected") : "paired"
                    current: modelData.connected
                    onClicked: modelData.connected = !modelData.connected
                }

                Text {
                    anchors.centerIn: parent
                    visible: btList.count === 0
                    text: root.btOn ? "No paired devices" : "Bluetooth is off"
                    color: root.muted
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                }
            }
        }

        // ------------------------------------------------------- phone

        Column {
            id: phonePage
            width: parent.width
            spacing: Style.space(8)
            visible: root.page === "phone"

            PageHeader {
                title: root.phone ? root.phone.name : "Phone"
                switchable: false
            }

            ListRow {
                width: parent.width
                glyph: root.phone && root.phone.charging ? "󰂄" : "󰁹"
                label: root.phone && root.phone.battery >= 0 ? root.phone.battery + "%" + (root.phone.charging ? "  charging" : "") : "Battery unknown"
                hint: root.phone && root.phone.network ? root.phone.network + (root.phone.signal >= 0 ? "  " + ["󰢿", "󰢼", "󰢽", "󰢾", "󰣺"][Math.max(0, Math.min(4, root.phone.signal))] : "") : ""
                current: root.phone !== null && root.phone.reachable
            }

            Rectangle {
                width: parent.width
                height: 1
                color: root.faint
            }

            Repeater {
                model: [
                    { glyph: "󰂚", label: "Ring phone", act: "ring" },
                    { glyph: "󰅇", label: "Send clipboard", act: "clip" },
                    { glyph: "󰉋", label: "Browse files", act: "browse" },
                    { glyph: "󰐻", label: "Ping", act: "ping" }
                ]
                ListRow {
                    required property var modelData
                    width: phonePage.width
                    glyph: modelData.glyph
                    label: modelData.label
                    hint: modelData.act === "browse" && root.phone && root.phone.mounted ? "mounted" : ""
                    enabled: root.phone !== null && root.phone.reachable
                    opacity: enabled ? 1 : 0.4
                    onClicked: {
                        var a = modelData.act;
                        if (a === "ring")
                            root.phone.ring();
                        else if (a === "clip")
                            root.phone.sendClipboard();
                        else if (a === "ping")
                            root.phone.ping();
                        else {
                            root.phone.browse();
                            if (root.host)
                                root.host.setExpanded("", false);
                        }
                    }
                }
            }
        }
    }

    // ------------------------------------------------------------ pieces

    component IconButton: Rectangle {
        id: ib
        property string glyph: ""
        signal clicked
        width: Style.space(28)
        height: width
        radius: width / 2
        color: ibArea.containsMouse ? root.faint : "transparent"
        Text {
            anchors.centerIn: parent
            text: ib.glyph
            color: root.foreground
            font.family: Style.font.family
            font.pixelSize: Style.font.icon
        }
        MouseArea {
            id: ibArea
            anchors.fill: parent
            hoverEnabled: true
            onClicked: ib.clicked()
        }
    }

    component Tile: Rectangle {
        id: tile
        property bool active: false
        property string glyph: ""
        property string glyphColor: ""
        property string title: ""
        property string detail: ""
        property bool chevron: false
        signal glyphClicked
        signal bodyClicked

        height: Style.space(50)
        radius: Style.space(13)
        color: active ? root.accentWash : (tileArea.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : root.faint)
        Behavior on color {
            ColorAnimation {
                duration: 220
            }
        }

        MouseArea {
            id: tileArea
            anchors.fill: parent
            hoverEnabled: true
            onClicked: tile.bodyClicked()
        }

        Rectangle {
            id: glyphDisc
            x: Style.space(8)
            anchors.verticalCenter: parent.verticalCenter
            width: Style.space(32)
            height: width
            radius: width / 2
            color: tile.active ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.22) : Qt.rgba(1, 1, 1, 0.06)
            Text {
                anchors.centerIn: parent
                text: tile.glyph
                color: tile.glyphColor !== "" ? tile.glyphColor : (tile.active ? root.accent : root.foreground)
                font.family: Style.font.family
                font.pixelSize: Style.font.icon
            }
            MouseArea {
                anchors.fill: parent
                onClicked: tile.glyphClicked()
            }
        }

        Column {
            anchors.left: glyphDisc.right
            anchors.leftMargin: Style.space(8)
            anchors.right: chev.left
            anchors.rightMargin: Style.space(4)
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1
            Text {
                width: parent.width
                text: tile.title
                color: root.foreground
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                text: tile.detail
                color: root.muted
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                elide: Text.ElideRight
            }
        }

        Text {
            id: chev
            anchors.right: parent.right
            anchors.rightMargin: Style.space(8)
            anchors.verticalCenter: parent.verticalCenter
            // A fixed width, not implicitWidth: a chevron that appears late
            // (the phone tile, once KDE Connect answers) would otherwise loop
            // width through the elided title beside it.
            width: tile.chevron ? Style.space(8) : 0
            visible: tile.chevron
            text: "›"
            color: root.muted
            font.family: Style.font.family
            font.pixelSize: Style.font.title
        }
    }

    component PageHeader: Item {
        id: ph
        property string title: ""
        property bool on: false
        property bool switchable: true
        signal toggled
        width: parent ? parent.width : 0
        height: Style.space(30)

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(6)
            IconButton {
                glyph: "󰁍"
                onClicked: root.go("main")
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: ph.title
                color: root.foreground
                font.family: Style.font.family
                font.pixelSize: Style.font.body
                font.weight: Font.DemiBold
            }
        }

        // On/off switch.
        Rectangle {
            visible: ph.switchable
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: Style.space(38)
            height: Style.space(22)
            radius: height / 2
            color: ph.on ? root.accent : Qt.rgba(1, 1, 1, 0.14)
            Behavior on color {
                ColorAnimation {
                    duration: 220
                }
            }
            Rectangle {
                width: parent.height - Style.space(6)
                height: width
                radius: width / 2
                y: Style.space(3)
                x: ph.on ? parent.width - width - Style.space(3) : Style.space(3)
                color: ph.on ? Color.background : root.foreground
                Behavior on x {
                    Morph {}
                }
            }
            MouseArea {
                anchors.fill: parent
                onClicked: ph.toggled()
            }
        }
    }

    component ListRow: Rectangle {
        id: lr
        property string glyph: ""
        property string label: ""
        property string hint: ""
        property bool current: false
        signal clicked
        height: root.rowH
        radius: Style.space(9)
        color: lrArea.containsMouse ? root.faint : "transparent"

        MouseArea {
            id: lrArea
            anchors.fill: parent
            hoverEnabled: true
            onClicked: lr.clicked()
        }
        Text {
            id: lrGlyph
            x: Style.space(8)
            anchors.verticalCenter: parent.verticalCenter
            width: Style.space(22)
            text: lr.glyph
            color: lr.current ? root.accent : root.muted
            font.family: Style.font.family
            font.pixelSize: Style.font.icon
        }
        Text {
            anchors.left: lrGlyph.right
            anchors.leftMargin: Style.space(6)
            anchors.right: lrHint.left
            anchors.rightMargin: Style.space(8)
            anchors.verticalCenter: parent.verticalCenter
            text: lr.label
            color: lr.current ? root.foreground : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.85)
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            elide: Text.ElideRight
        }
        Text {
            id: lrHint
            anchors.right: parent.right
            anchors.rightMargin: Style.space(10)
            anchors.verticalCenter: parent.verticalCenter
            text: lr.hint
            color: root.muted
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
        }
    }
}
