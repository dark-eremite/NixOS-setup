import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import Quickshell.Networking
import Quickshell.Services.Pipewire
import Quickshell.Services.Mpris
import qs

ShellRoot {
    id: root

    readonly property color fallbackBg: "#111318"
    readonly property color fallbackFg: "#e1e2e9"
    readonly property color fallbackAccent: "#a7c8ff"
    readonly property color fallbackOnAccent: "#132f60"
    readonly property color fallbackBorder: "#59FFFFFF"

    property color bgColor: fallbackBg
    property color fgColor: fallbackFg
    property color accentColor: fallbackAccent
    property color onAccentColor: fallbackOnAccent
    property color borderColor: fallbackBorder

    property bool btEnabled: Bluetooth.defaultAdapter
        ? Bluetooth.defaultAdapter.enabled : false
    property bool btConnected: false
    property string btGlyph: !btEnabled ? "\u{f00b2}"
        : (btConnected ? "\u{f00b1}" : "\uf294")
    property color btColor: btConnected ? accentColor : fgColor

    property var audioSink: Pipewire.defaultAudioSink
    property bool audioMuted: audioSink && audioSink.audio
        ? audioSink.audio.muted : false
    property bool audioActive: audioSink && audioSink.audio
        ? (audioSink.audio.volume > 0 && !audioSink.audio.muted) : false
    property string audioGlyph: audioMuted ? "\u{f0581}" : "\uf028"
    property color audioColor: audioActive ? accentColor : fgColor

    property var micSource: Pipewire.defaultAudioSource
    property bool micMuted: micSource && micSource.audio
        ? micSource.audio.muted : true
    property string micGlyph: micMuted ? "\u{f036d}" : "\u{f036c}"
    property color micColor: micMuted ? fgColor : accentColor

    PwObjectTracker { objects: audioSink ? [ audioSink ] : [] }
    PwObjectTracker { objects: micSource ? [ micSource ] : [] }

    function refreshBt(): void {
        var n = 0;
        var vals = Bluetooth.devices ? Bluetooth.devices.values : [];
        for (var i = 0; i < vals.length; i++) {
            if (vals[i] && vals[i].connected) n++;
        }
        root.btConnected = n > 0;
    }

    readonly property string albumGlyph: "\u{f0025}"
    readonly property string previousGlyph: "\u{f04ae}"
    readonly property string playGlyph: "\u{f040a}"
    readonly property string pauseGlyph: "\u{f03e4}"
    readonly property string nextGlyph: "\u{f04ad}"

    property var musicPlayer: null

    function selectPlayer(): void {
        var vals = Mpris.players.values;
        var yandex = null;
        var first = null;
        for (var i = 0; i < vals.length; i++) {
            var p = vals[i];
            if (!p) continue;
            if (!first) first = p;
            var id = "" + p.identity;
            var bus = "" + p.dbusName;
            if (id.indexOf("yandex") !== -1 || bus.indexOf("yandex") !== -1) {
                yandex = p;
                break;
            }
        }
        musicPlayer = yandex || first;
    }

    function musicPosition(): real {
        return musicPlayer ? musicPlayer.position : 0;
    }

    function musicLength(): real {
        return musicPlayer ? musicPlayer.length : 0;
    }

    function formatTime(seconds): string {
        var s = Math.max(0, Math.floor(seconds || 0));
        var m = Math.floor(s / 60);
        var r = s % 60;
        return "" + m + ":" + (r < 10 ? "0" : "") + r;
    }

    readonly property string musicTitle: musicPlayer ? musicPlayer.trackTitle : ""
    readonly property string musicArtist: musicPlayer ? musicPlayer.trackArtist : ""
    readonly property string musicArtUrl: musicPlayer ? musicPlayer.trackArtUrl : ""
    readonly property bool musicPlaying: musicPlayer ? musicPlayer.isPlaying : false
    readonly property bool musicCanPrevious: musicPlayer ? musicPlayer.canGoPrevious : false
    readonly property bool musicCanNext: musicPlayer ? musicPlayer.canGoNext : false
    readonly property bool musicCanToggle: musicPlayer ? musicPlayer.canTogglePlaying : false
    readonly property bool musicCanSeek: musicPlayer ? musicPlayer.canSeek : false
    readonly property bool musicHasTrack: musicTitle.length > 0
    readonly property string musicElapsedLabel: formatTime(musicPosition())
    readonly property string musicRemainingLabel: formatTime(Math.max(0, musicLength() - musicPosition()))
    readonly property real musicProgress: musicLength() > 0
        ? Math.max(0, Math.min(1, musicPosition() / musicLength())) : 0

    Connections {
        target: Mpris.players
        function onValuesChanged(): void { root.selectPlayer(); }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (musicPlayer)
                musicPlayer.positionChanged();
        }
    }

    Component.onCompleted: {
        refreshBt();
        refreshWifi();
        selectPlayer();
    }

    Connections {
        target: Bluetooth.devices
        function onValuesChanged(): void { root.refreshBt(); }
    }

    Instantiator {
        model: Bluetooth.devices
        delegate: Connections {
            required property var modelData
            target: modelData
            function onConnectedChanged(): void { root.refreshBt(); }
        }
    }

    readonly property var wifiGlyphs: [
        "\u{f091f}", "\u{f0922}", "\u{f0925}", "\u{f0928}"
    ]
    readonly property var wifiAlertGlyphs: [
        "\u{f0920}", "\u{f0923}", "\u{f0926}", "\u{f0929}"
    ]
    readonly property var wifiLockGlyphs: [
        "\u{f0921}", "\u{f0924}", "\u{f0927}", "\u{f092a}"
    ]
    readonly property string wifiOffGlyph: "\u{f092e}"
    readonly property string wifiOutlineGlyph: "\u{f092f}"
    readonly property string ethernetGlyph: "\u{f0201}"

    property int wifiBars: 1
    property int wifiConnectivity: 0
    property string wifiGlyph: wifiOffGlyph
    property color wifiColor: fgColor

    function barsFor(signal): int {
        var s = Math.max(0, Math.min(1, signal || 0));
        return Math.max(1, Math.min(4, Math.ceil(s * 4)));
    }

    function refreshWifi(): void {
        var devs = Networking.devices ? Networking.devices.values : [];
        var wifiOn = Networking.wifiEnabled;
        var active = null;
        var ethConnected = false;

        for (var i = 0; i < devs.length; i++) {
            var d = devs[i];
            if (!d) continue;
            if (d.type === DeviceType.Wired && d.connected)
                ethConnected = true;
            if (d.type !== DeviceType.Wifi || !wifiOn) continue;

            var nets = d.networks ? d.networks.values : [];
            for (var j = 0; j < nets.length; j++) {
                if (nets[j] && nets[j].connected) {
                    active = nets[j];
                    break;
                }
            }
            if (active) break;
        }

        var conn = Networking.connectivity;
        root.wifiConnectivity = conn;

        if (!wifiOn && ethConnected) {
            root.wifiGlyph = root.ethernetGlyph;
            root.wifiColor = root.accentColor;
            return;
        }
        if (!wifiOn) {
            root.wifiGlyph = root.wifiOffGlyph;
            root.wifiColor = root.fgColor;
            return;
        }
        if (!active) {
            root.wifiGlyph = root.wifiOutlineGlyph;
            root.wifiColor = root.fgColor;
            return;
        }

        var b = root.barsFor(active.signalStrength) - 1;
        var glyph = root.wifiGlyphs[b];
        if (conn === NetworkConnectivity.Portal)
            glyph = root.wifiLockGlyphs[b];
        else if (conn === NetworkConnectivity.Limited
                 || conn === NetworkConnectivity.None)
            glyph = root.wifiAlertGlyphs[b];

        root.wifiBars = b + 1;
        root.wifiGlyph = glyph;
        root.wifiColor = root.accentColor;
    }

    property string wifiPortalUrl: ""

    Process {
        id: portalUriProc
        running: false
        command: [
            "busctl", "get-property",
            "org.freedesktop.NetworkManager",
            "/org/freedesktop/NetworkManager",
            "org.freedesktop.NetworkManager",
            "ConnectivityCheckUri"
        ]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                var m = ("" + this.text).match(/s\s+"([^"]*)"/);
                root.wifiPortalUrl = m ? m[1] : "";
            }
        }
    }

    Timer {
        id: wifiPollTimer
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            Networking.checkConnectivity();
            root.refreshWifi();
            portalUriProc.running = true;
        }
    }

    Connections {
        target: Networking
        function onWifiEnabledChanged(): void { root.refreshWifi(); }
        function onConnectivityChanged(): void { root.refreshWifi(); }
    }

    Connections {
        target: Networking.devices
        function onValuesChanged(): void { root.refreshWifi(); }
    }

    Instantiator {
        model: Networking.devices
        delegate: Connections {
            required property var modelData
            target: modelData
            function onConnectedChanged(): void { root.refreshWifi(); }
        }
    }

    readonly property var weekdayNames: [
        "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"
    ]

    function pad2(n): string {
        return (n < 10 ? "0" : "") + n;
    }

    function formatClock(d): string {
        return pad2(d.getMonth() + 1) + "." + pad2(d.getDate())
            + " " + weekdayNames[d.getDay()]
            + " " + pad2(d.getHours()) + ":" + pad2(d.getMinutes());
    }

    function parseColor(s): color {
        s = ("" + s).trim();
        if (s.charAt(0) === "#")
            return s;
        var m = s.match(/rgba?\(\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)\s*(?:,\s*([\d.]+)\s*)?\)/i);
        if (m)
            return Qt.rgba(
                +m[1] / 255, +m[2] / 255, +m[3] / 255,
                m[4] === undefined ? 1 : +m[4]
            );
        return "#00000000";
    }

    function readColor(text, name): color {
        var re = new RegExp("property\\s+color\\s+" + name + "\\s*:\\s*[\"']([^\"']+)[\"']");
        var m = re.exec(text);
        return m ? parseColor(m[1]) : "#00000000";
    }

    function applyPalette(text): void {
        if (!text || text.length === 0) {
            bgColor = fallbackBg;
            fgColor = fallbackFg;
            accentColor = fallbackAccent;
            onAccentColor = fallbackOnAccent;
            borderColor = fallbackBorder;
            return;
        }
        var keys = [ "bg", "fg", "accent", "on_accent", "border" ];
        for (var i = 0; i < keys.length; i++) {
            var re = new RegExp("property\\s+color\\s+" + keys[i] + "\\s*:\\s*[\"']([^\"']+)[\"']");
            if (!re.test(text)) continue;
            var c = readColor(text, keys[i]);
            if (keys[i] === "bg") bgColor = c;
            else if (keys[i] === "fg") fgColor = c;
            else if (keys[i] === "accent") accentColor = c;
            else if (keys[i] === "on_accent") onAccentColor = c;
            else borderColor = c;
        }
    }

    FileView {
        id: paletteFile
        path: String(Quickshell.env("HOME")) + "/.config/quickshell/colors.qml"
        watchChanges: true
        preload: true
        blockLoading: true
        printErrors: false
        onLoaded: applyPalette(this.text())
        onFileChanged: paletteFile.reload()
        onLoadFailed: applyPalette("")
    }

    IpcHandler {
        target: "theme"

        function reload(): void {
            paletteFile.reload();
            wsProc.running = true;
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: paletteFile.reload()
    }

    Timer {
        interval: 100
        running: true
        repeat: true
        onTriggered: wsProc.running = true
    }

    Process {
        id: wsProc
        command: [ "niri", "msg", "--json", "workspaces" ]

        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                try {
                    var list = JSON.parse(this.text);
                    var idx = bar.currentIndex;
                    var external = false;
                    for (var i = 0; i < list.length; i++) {
                        if (!list[i].is_focused)
                            continue;
                        var name = list[i].name ? "" + list[i].name : "";
                        var m = name.match(/^ws-(\d+)$/);
                        if (m && +m[1] >= 1 && +m[1] <= bar.workspaceCount) {
                            idx = +m[1];
                        } else if (!m && list[i].idx >= 1
                                   && list[i].idx <= bar.workspaceCount) {
                            idx = list[i].idx;
                        } else {
                            external = true;
                        }
                        break;
                    }
                    bar.externalFocus = external;
                    bar.currentIndex = idx;
                } catch (e) {
                }
            }
        }
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    BluetoothPanel {
        id: btPanel
        topInset: bar.margins.top + bar.implicitHeight
        bgColor: root.bgColor
        fgColor: root.fgColor
        accentColor: root.accentColor
        borderColor: root.borderColor
    }

    WifiPanel {
        id: wifiPanel
        topInset: bar.margins.top + bar.implicitHeight
        bgColor: root.bgColor
        fgColor: root.fgColor
        accentColor: root.accentColor
        borderColor: root.borderColor
        connectivity: root.wifiConnectivity
        portalUrl: root.wifiPortalUrl
        onNetworksChanged: root.refreshWifi()
    }

    AudioPanel {
        id: audioPanel
        topInset: bar.margins.top + bar.implicitHeight
        bgColor: root.bgColor
        fgColor: root.fgColor
        accentColor: root.accentColor
        borderColor: root.borderColor
    }

    MicrophonePanel {
        id: micPanel
        topInset: bar.margins.top + bar.implicitHeight
        bgColor: root.bgColor
        fgColor: root.fgColor
        accentColor: root.accentColor
        borderColor: root.borderColor
    }

    MusicPanel {
        id: musicPanel
        topInset: bar.margins.top + bar.implicitHeight
        bgColor: root.bgColor
        fgColor: root.fgColor
        accentColor: root.accentColor
        borderColor: root.borderColor

        trackTitle: root.musicTitle
        trackArtist: root.musicArtist
        artUrl: root.musicArtUrl
        elapsedLabel: root.musicElapsedLabel
        remainingLabel: root.musicRemainingLabel
        progress: root.musicProgress
        playing: root.musicPlaying
        canPrevious: root.musicCanPrevious
        canNext: root.musicCanNext
        canToggle: root.musicCanToggle
        canSeek: root.musicCanSeek
        hasTrack: root.musicHasTrack

        onPreviousRequested: { if (root.musicPlayer) root.musicPlayer.previous(); }
        onToggleRequested: { if (root.musicPlayer) root.musicPlayer.togglePlaying(); }
        onNextRequested: { if (root.musicPlayer) root.musicPlayer.next(); }
        onSeekRequested: function (fraction) {
            if (root.musicPlayer && root.musicLength() > 0)
                root.musicPlayer.position = fraction * root.musicLength();
        }
    }

    PanelWindow {
        id: bar

        property int currentIndex: 1
        property bool externalFocus: false
        readonly property int workspaceCount: 7
        readonly property real cell: 16
        readonly property real gap: 10
        readonly property real sliderWidth: 26
        readonly property real sliderPad: (sliderWidth - cell) / 2
        readonly property real step: cell + gap
        readonly property real sliderIndex: externalFocus
            ? workspaceCount + 0.5
            : currentIndex
        readonly property real sliderX: wsRow.x
            + (sliderIndex - 1) * step - sliderPad

        readonly property int sliderZ: 2
        readonly property int squareZ: 1

        anchors {
            top: true
            left: true
            right: true
        }
        margins {
            left: 12
            right: 12
            top: 8
        }
        implicitHeight: 40
        color: Qt.rgba(bgColor.r, bgColor.g, bgColor.b, 0.75)

        Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.width: 2
            border.color: borderColor
        }

        Rectangle {
            id: clockRect
            anchors {
                left: parent.left
                verticalCenter: parent.verticalCenter
            }
            width: clockText.implicitWidth + 24
            height: bar.height
            color: accentColor
            z: bar.squareZ

            Text {
                id: clockText
                anchors.centerIn: parent
                text: root.formatClock(clock.date)
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
                color: onAccentColor
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }

        Rectangle {
            id: musicWidget
            anchors {
                left: clockRect.right
                leftMargin: 10
                verticalCenter: parent.verticalCenter
            }
            width: 234
            height: bar.height - 8
            color: Qt.rgba(bgColor.r, bgColor.g, bgColor.b, 0.92)
            border.width: 1
            border.color: borderColor
            z: bar.squareZ

            Row {
                id: musicControls
                anchors {
                    left: parent.left
                    leftMargin: 4
                    verticalCenter: parent.verticalCenter
                }
                spacing: 2

                Repeater {
                    model: [
                        { glyph: root.previousGlyph, action: "prev", active: root.musicCanPrevious },
                        { glyph: root.playGlyph, action: "toggle", active: root.musicCanToggle },
                        { glyph: root.nextGlyph, action: "next", active: root.musicCanNext }
                    ]

                    delegate: Item {
                        width: 22
                        height: 24

                        property string action: modelData.action
                        property bool active: modelData.active
                        property string glyph: action === "toggle"
                            ? (root.musicPlaying ? root.pauseGlyph : root.playGlyph)
                            : modelData.glyph

                        Text {
                            anchors.centerIn: parent
                            width: implicitWidth
                            height: implicitHeight
                            text: parent.glyph
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 13
                            color: parent.action === "toggle"
                                && root.musicPlaying ? accentColor : fgColor
                            opacity: parent.active ? 1 : 0.35
                        }

                        MouseArea {
                            anchors.fill: parent
                            enabled: parent.active
                            cursorShape: enabled ? Qt.PointingHandCursor
                                : Qt.ArrowCursor
                            onClicked: {
                                if (!root.musicPlayer) return;
                                if (parent.action === "prev")
                                    root.musicPlayer.previous();
                                else if (parent.action === "toggle")
                                    root.musicPlayer.togglePlaying();
                                else root.musicPlayer.next();
                            }
                        }
                    }
                }
            }

            Text {
                id: musicTitleText
                anchors {
                    left: musicControls.right
                    leftMargin: 6
                    right: parent.right
                    rightMargin: 6
                    verticalCenter: parent.verticalCenter
                }
                height: parent.height
                text: root.musicHasTrack ? root.musicTitle : "Нет музыки"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 11
                color: fgColor
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignRight
                verticalAlignment: Text.AlignVCenter
            }

            MouseArea {
                anchors.fill: parent
                z: -1
                cursorShape: Qt.PointingHandCursor
                onClicked: musicPanel.shown = !musicPanel.shown
            }
        }

        Row {
            id: wsRow
            anchors.centerIn: parent
            spacing: bar.gap
            z: bar.squareZ

            Repeater {
                model: bar.workspaceCount

                delegate: Item {
                    width: bar.cell
                    height: bar.cell

                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"
                        border.width: 2
                        border.color: borderColor
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: bar.focusWorkspace(index + 1)
                    }
                }
            }
        }

        Rectangle {
            id: indicator
            width: bar.sliderWidth
            height: bar.height
            color: accentColor
            x: bar.sliderX
            y: 0
            z: bar.sliderZ

            Text {
                anchors.centerIn: parent
                text: bar.currentIndex
                visible: !bar.externalFocus
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 11
                color: onAccentColor
            }

            Behavior on x {
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.OutCubic
                }
            }
        }

        MouseArea {
            anchors {
                top: parent.top
                horizontalCenter: parent.horizontalCenter
            }
            width: wsRow.width
            height: bar.height
            z: -1

            onClicked: {
                var idx = Math.floor(mouseX / (bar.cell + bar.gap)) + 1;
                if (idx >= 1 && idx <= bar.workspaceCount)
                    bar.focusWorkspace(idx);
            }
        }

        Row {
            id: trayRow
            anchors {
                right: parent.right
                verticalCenter: parent.verticalCenter
            }
            spacing: bar.gap
            z: bar.squareZ

            Repeater {
                model: [
                    { glyph: "\uf185", label: "brightness" },
                    { glyph: root.micGlyph, label: "microphone", dynamic: true },
                    { glyph: root.audioGlyph, label: "volume", dynamic: true },
                    { glyph: root.btGlyph, label: "bluetooth", dynamic: true },
                    { glyph: root.wifiGlyph, label: "wifi", dynamic: true },
                    { glyph: "\uf313", label: "nixos" }
                ]

                delegate: Item {
                    width: isNixos ? bar.height : 24
                    height: bar.height

                    property bool isBt: modelData.label === "bluetooth"
                    property bool isWifi: modelData.label === "wifi"
                    property bool isVolume: modelData.label === "volume"
                    property bool isMic: modelData.label === "microphone"
                    property bool isNixos: modelData.label === "nixos"
                    property string icon: isBt ? root.btGlyph
                        : (isWifi ? root.wifiGlyph
                        : (isVolume ? root.audioGlyph
                        : (isMic ? root.micGlyph : modelData.glyph)))
                    property color tint: isNixos ? onAccentColor
                        : (isBt ? root.btColor
                        : (isWifi ? root.wifiColor
                        : (isVolume ? root.audioColor
                        : (isMic ? root.micColor : fgColor))))

                    Rectangle {
                        anchors.centerIn: parent
                        width: bar.height
                        height: bar.height
                        visible: parent.isNixos
                        color: accentColor
                    }

                    Text {
                        anchors.centerIn: parent
                        text: parent.icon
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 16
                        color: parent.tint
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: parent.isBt || parent.isWifi
                            || parent.isVolume || parent.isMic
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                            if (parent.isBt) btPanel.shown = !btPanel.shown;
                            else if (parent.isWifi) wifiPanel.shown = !wifiPanel.shown;
                            else if (parent.isVolume) audioPanel.shown = !audioPanel.shown;
                            else micPanel.shown = !micPanel.shown;
                        }
                    }
                }
            }
        }

        function focusWorkspace(idx: int): void {
            currentIndex = idx;
            Quickshell.execDetached([
                "niri", "msg", "action", "focus-workspace", "ws-" + idx
            ]);
        }
    }
}
